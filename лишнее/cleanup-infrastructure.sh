#!/bin/bash
set -e

echo "🧹 CLEANING INFRASTRUCTURE FOR PRODUCTION"
echo "=========================================="

# 1. Создаем резервную копию (ВАЖНО!)
echo "📦 Creating backup..."
BACKUP_FILE="backup-$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" . \
  --exclude='*.tar.gz' \
  --exclude='*.dump' \
  --exclude='node_modules' \
  --exclude='__pycache__' \
  --exclude='.git'
echo "✅ Backup created: $BACKUP_FILE"

# 2. УДАЛЕНИЕ ФАЙЛОВ (17 файлов/директорий)
echo -e "\n🗑️  DELETING FILES..."

# Критические (пароли/безопасность)
echo "Removing .env files..."
rm -f .env .env.template .env.local .env.* 2>/dev/null || true

# Устаревшие скрипты инициализации
echo "Removing outdated scripts..."
rm -f scripts/init-db.sh scripts/generate-secrets.sh scripts/wait-for-db.sh 2>/dev/null || true
rm -f diagnose.sh fix-and-run.sh 2>/dev/null || true

# Миграции (дублируют initscripts)
echo "Removing migrations..."
rm -rf migrations/ 2>/dev/null || true

# Неиспользуемые/редкие
echo "Removing unused configs..."
rm -rf backup_scripts/ 2>/dev/null || true
rm -f config/redis.conf config/servers.json 2>/dev/null || true
rm -rf your_project/ 2>/dev/null || true
rm -f .secrets.README.txt 2>/dev/null || true

# Остатки data (после миграции на volumes)
echo "Cleaning old data directories..."
rm -rf data/redis/ 2>/dev/null || true

# Старые docker-secrets (пересоздадим новые)
echo "Removing old secrets..."
if [ -d docker-secrets ]; then
    echo "Backup old secrets..."
    cp -r docker-secrets docker-secrets-backup-$(date +%Y%m%d) 2>/dev/null || true
    rm -rf docker-secrets
fi

# 3. СОЗДАНИЕ НОВОЙ СТРУКТУРЫ
echo -e "\n📁 CREATING NEW STRUCTURE..."

# Обязательные директории
mkdir -p docker-secrets initscripts models data/ollama monitoring/grafana/provisioning/{datasources,dashboards}

# Создать новый .env.template БЕЗ паролей
cat > .env.template << 'ENVEOF'
# ============================================
# PERSONAL ASSISTANT - PRODUCTION
# ============================================

# Database
POSTGRES_DB=personal_assistant
POSTGRES_USER=postgres
POSTGRES_PORT=5432

# Monitoring
GRAFANA_ADMIN_PASSWORD=__SET_IN_SECRETS__
GRAFANA_PORT=3001

# Security (will be set via make secrets)
# DB_PASSWORD=__GENERATE_WITH_MAKE_SECRETS__
# APP_DB_PASSWORD=__GENERATE_WITH_MAKE_SECRETS__

# Paths
VOLUME_PATH=./data
BACKUP_PATH=./backups

# Network
NETWORK_NAME=personal-assistant-network
ENVEOF

# Создать новый .gitignore
cat > .gitignore << 'GITIGNOREEOF'
# Docker
docker-compose.override.yml

# Secrets and configuration
.env
.env.local
.env.*.local
docker-secrets/
*.secret

# Backups
*.backup
backup/
*.tar.gz
*.dump

# Temporary files
tmp/
*.tmp
*.log

# Data
data/redis/
data/postgres/  # Keep only structure, not actual DB files
!data/postgres/.gitkeep

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Python
__pycache__/
*.pyc
.python-version

# Models (large files)
models/*.bin
models/*.gguf
models/*.pkl

# Ollama models
data/ollama/models/
GITIGNOREEOF

# Создать скрипт установки паролей
cat > scripts/set-app-password.sh << 'SCRIPTEOF'
#!/bin/bash
echo "🔑 Setting application database password..."

if [ ! -f docker-secrets/app_password.txt ]; then
    echo "❌ app_password.txt not found"
    echo "Run: make secrets"
    exit 1
fi

if [ ! -f docker-secrets/postgrespassword.txt ]; then
    echo "❌ postgrespassword.txt not found"
    echo "Run: make secrets"
    exit 1
fi

APP_PASSWORD=$(cat docker-secrets/app_password.txt)
POSTGRES_PASSWORD=$(cat docker-secrets/postgrespassword.txt)

echo "Updating PostgreSQL password for personal_assistant_app..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d personal_assistant \
    -c "ALTER ROLE personal_assistant_app WITH PASSWORD '$APP_PASSWORD';" 2>/dev/null || \
    echo "⚠️  Could not update password (role might not exist yet)"

echo "✅ Password updated"
echo ""
echo "Application should use:"
echo "  DATABASE_URL=postgresql://personal_assistant_app:$(cat docker-secrets/app_password.txt)@localhost:5432/personal_assistant"
SCRIPTEOF
chmod +x scripts/set-app-password.sh

# 4. СОЗДАТЬ PRODUCTION DOCKER-COMPOSE
cat > docker-compose.perfect.yml << 'COMPOSEEOF'
version: '3.8'

x-postgres-common: &postgres-common
  image: postgres:15-alpine
  environment:
    POSTGRES_DB: personal_assistant
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD_FILE: /run/secrets/postgrespassword
    POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --data-checksums"
  volumes:
    - ./initscripts:/docker-entrypoint-initdb.d:ro
  secrets:
    - postgrespassword
  networks:
    - personal-assistant-network
  restart: unless-stopped

services:
  # Primary PostgreSQL
  postgres:
    <<: *postgres-common
    container_name: pa-postgres
    hostname: postgres-primary
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d personal_assistant"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'

  # Grafana для мониторинга
  grafana:
    image: grafana/grafana:10.4.0
    container_name: pa-grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-admin123}
      GF_INSTALL_PLUGINS: "grafana-postgresql-datasource"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    ports:
      - "${GRAFANA_PORT:-3001}:3000"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - personal-assistant-network
    restart: unless-stopped

  # Backup service (ежедневные бэкапы)
  backup:
    image: postgres:15-alpine
    container_name: pa-backup
    volumes:
      - ./backups:/backups:rw
      - ./scripts/backup.sh:/backup.sh:ro
    secrets:
      - postgrespassword
    networks:
      - personal-assistant-network
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    command: >
      bash -c "
        chmod +x /backup.sh
        echo '0 2 * * * /backup.sh' > /etc/crontabs/root
        crond -f
      "

volumes:
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${PWD}/data/postgres
  grafana_data:

secrets:
  postgrespassword:
    file: ./docker-secrets/postgrespassword.txt

networks:
  personal-assistant-network:
    driver: bridge
COMPOSEEOF

# 5. СОЗДАТЬ PRODUCTION MAKEFILE
cat > Makefile.perfect << 'MAKEFILEEOF'
# ============================================
# PERSONAL ASSISTANT - PRODUCTION MAKEFILE
# ============================================

DOCKER_COMPOSE = docker compose -f docker-compose.perfect.yml
DB_NAME = personal_assistant
DB_USER = postgres

.PHONY: help perfect production secrets up down logs backup restore health clean validate monitor

help:
	@echo "🏭 PRODUCTION COMMANDS"
	@echo ""
	@echo "  make production - Full production setup (secrets + up + monitoring)"
	@echo "  make perfect    - Alias for production"
	@echo "  make secrets    - Generate secure passwords"
	@echo "  make up         - Deploy services"
	@echo "  make down       - Stop services"
	@echo "  make logs       - View logs"
	@echo "  make backup     - Create database backup"
	@echo "  make restore    - Restore from backup"
	@echo "  make health     - Health check all services"
	@echo "  make clean      - Clean services (keep data)"
	@echo "  make destroy    - Destroy everything (including data)"
	@echo "  make validate   - Validate infrastructure"
	@echo "  make monitor    - Open monitoring dashboard"

production: secrets up validate monitor
	@echo ""
	@echo "✅ PRODUCTION INFRASTRUCTURE READY"
	@echo "========================================"
	@echo "🌐 Grafana:     http://localhost:$${GRAFANA_PORT:-3001} (admin:$${GRAFANA_ADMIN_PASSWORD:-admin123})"
	@echo "🗄️  PostgreSQL: localhost:5432 (postgres:password in docker-secrets/)"
	@echo "💾 Backups:     ./backups/ (automated daily)"
	@echo "========================================"

perfect: production
	@echo "✅ Perfect infrastructure deployed!"

secrets:
	@echo "🔐 GENERATING PRODUCTION SECRETS..."
	@mkdir -p docker-secrets
	@chmod 700 docker-secrets
	@# PostgreSQL superuser password
	@openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32 > docker-secrets/postgrespassword.txt
	@# Application database user password
	@openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32 > docker-secrets/app_password.txt
	@# Grafana admin password
	@openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32 > docker-secrets/grafana_password.txt
	@chmod 600 docker-secrets/*.txt
	@echo "✅ SECRETS GENERATED IN docker-secrets/"
	@echo ""
	@echo "📝 Update .env.template or set environment variables:"
	@echo "  export GRAFANA_ADMIN_PASSWORD=$$(cat docker-secrets/grafana_password.txt)"

up:
	@echo "🚀 DEPLOYING PRODUCTION SERVICES..."
	@mkdir -p data/postgres backups
	@chmod 755 data/postgres
	@${DOCKER_COMPOSE} up -d --wait
	@echo "⏳ Waiting for services to stabilize..."
	@sleep 30
	@echo "✅ SERVICES DEPLOYED"
	@${DOCKER_COMPOSE} ps

down:
	@echo "🛑 STOPPING SERVICES..."
	@${DOCKER_COMPOSE} down
	@echo "✅ Services stopped"

logs:
	@echo "📜 PRODUCTION LOGS (Ctrl+C to exit)..."
	@${DOCKER_COMPOSE} logs -f --tail=100

backup:
	@echo "💾 CREATING DATABASE BACKUP..."
	@mkdir -p backups
	@${DOCKER_COMPOSE} exec -T postgres pg_dump -U ${DB_USER} -d ${DB_NAME} \
		--format=custom --compress=9 \
		> backups/backup_$(date +%Y%m%d_%H%M%S).dump
	@echo "✅ Backup created: backups/backup_$(date +%Y%m%d_%H%M%S).dump"
	@echo "📦 Size: $$(du -h backups/backup_$(date +%Y%m%d_%H%M%S).dump | cut -f1)"

restore:
	@echo "🔄 RESTORING DATABASE..."
	@test -n "$(file)" || (echo "❌ Usage: make restore file=backups/backup_YYYYMMDD_HHMMSS.dump" && exit 1)
	@test -f "$(file)" || (echo "❌ File $(file) not found" && exit 1)
	@${DOCKER_COMPOSE} stop grafana 2>/dev/null || true
	@cat "$(file)" | ${DOCKER_COMPOSE} exec -T postgres pg_restore -U ${DB_USER} -d ${DB_NAME} --clean --if-exists
	@${DOCKER_COMPOSE} start grafana 2>/dev/null || true
	@echo "✅ Database restored from $(file)"

health:
	@echo "🏥 PRODUCTION HEALTH CHECK"
	@echo "=========================="
	@echo "1. Service Status:"
	@${DOCKER_COMPOSE} ps
	@echo ""
	@echo "2. PostgreSQL Health:"
	@if ${DOCKER_COMPOSE} exec postgres pg_isready -U ${DB_USER} -d ${DB_NAME} >/dev/null 2>&1; then \
		echo "✅ PostgreSQL is healthy"; \
		echo "   Active connections:"; \
		PGPASSWORD=$$(cat docker-secrets/postgrespassword.txt) psql -h localhost -U ${DB_USER} -d ${DB_NAME} \
			-tAc "SELECT COUNT(*) FROM pg_stat_activity WHERE datname='${DB_NAME}';" 2>/dev/null || echo "   (Could not query)"; \
	else \
		echo "❌ PostgreSQL is not responding"; \
	fi
	@echo ""
	@echo "3. Grafana Health:"
	@if curl -s http://localhost:$${GRAFANA_PORT:-3001}/api/health >/dev/null 2>&1; then \
		echo "✅ Grafana is healthy"; \
	else \
		echo "⚠️  Grafana may be starting up..."; \
	fi
	@echo ""
	@echo "4. Disk Usage:"
	@df -h . | grep -E "(Filesystem|$(shell pwd))"
	@echo "✅ Health check completed"

clean:
	@echo "🧹 CLEANING SERVICES (keeping data)..."
	@${DOCKER_COMPOSE} down
	@echo "✅ Services cleaned"

destroy:
	@echo "💀 DESTROYING EVERYTHING (including data!)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		${DOCKER_COMPOSE} down -v; \
		sudo rm -rf data/* backups/* docker-secrets/*; \
		docker system prune -af; \
		echo "✅ Everything destroyed"; \
	else \
		echo "❌ Cancelled"; \
	fi

validate:
	@echo "🔍 VALIDATING INFRASTRUCTURE..."
	@echo ""
	@echo "1. Secrets check:"
	@for secret in postgrespassword.txt app_password.txt grafana_password.txt; do \
		if [ -f "docker-secrets/$$secret" ]; then \
			echo "✅ $$secret exists"; \
		else \
			echo "❌ $$secret missing"; \
		fi; \
	done
	@echo ""
	@echo "2. Database check:"
	@sleep 5
	@if PGPASSWORD=$$(cat docker-secrets/postgrespassword.txt) psql -h localhost -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT 1;" 2>/dev/null; then \
		echo "✅ Database connection successful"; \
		PGPASSWORD=$$(cat docker-secrets/postgrespassword.txt) psql -h localhost -U ${DB_USER} -d ${DB_NAME} \
			-tAc "SELECT 'Tables: ' || COUNT(*) FROM pg_tables WHERE schemaname='public';"; \
	else \
		echo "❌ Cannot connect to database"; \
	fi
	@echo ""
	@echo "✅ Validation completed"

monitor:
	@echo "📊 OPENING MONITORING DASHBOARD..."
	@echo "Grafana: http://localhost:$${GRAFANA_PORT:-3001}"
	@echo "Default admin password is in docker-secrets/grafana_password.txt"
	@echo ""
	@echo "To configure datasource:"
	@echo "1. Go to http://localhost:$${GRAFANA_PORT:-3001}"
	@echo "2. Login with admin:$$(cat docker-secrets/grafana_password.txt 2>/dev/null || echo 'admin123')"
	@echo "3. Add PostgreSQL datasource:"
	@echo "   - Host: pa-postgres:5432"
	@echo "   - Database: personal_assistant"
	@echo "   - User: personal_assistant_app"
	@echo "   - Password: $$(cat docker-secrets/app_password.txt 2>/dev/null || echo 'from secrets')"

# Utility commands
test-db:
	@echo "🧪 TESTING DATABASE..."
	@PGPASSWORD=$$(cat docker-secrets/postgrespassword.txt) psql -h localhost -U ${DB_USER} -d ${DB_NAME} << 'EOF'
SELECT 'Database:' || current_database() as info;
SELECT 'User:' || current_user as info;
SELECT 'Tables:' || COUNT(*) as count FROM pg_tables WHERE schemaname='public';
SELECT tablename, pg_size_pretty(pg_total_relation_size(tablename)) as size 
FROM pg_tables WHERE schemaname='public' ORDER BY size DESC LIMIT 5;
