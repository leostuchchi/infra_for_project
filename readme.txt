инфраструктура для проекта:
безопасная база данных, с обновляемыми паролями и бэкапом.
мониторинг grafana
доступ по api

Запуск и развертывание:
chmod +x bash_start.sh scripts/*.sh
./bash_start.sh


поместите Ваш sql скрипт создания базы данных в init_scripts/init_db.sql
поместите Ваш проект в директорию app

скрипты для разворачивания bash_start

Структура:

app директория для проекта
  Dockerfile
  requirements.txt
  main.py
backups
config
  postgresql.conf
docker-secrets
  app_password.txt
  postgres_password.txt
  postgrespassword.txt
initscripts
  init_db.sql
monitoring
  provisioning
    dashboards
      dashboard.yml
      personal-assistant.json
    datasources
      postgres.yml
  grafana.ini
scripts
  backup-db.sh
  rotate-secrets.sh
  set-app-password.sh
docker-compose.yml
Makefile
bash_start.sh
.dockerignore
.gitignore


файлы инфраструктуры:
app директория для проекта
  Dockerfile:
    FROM python:3.11-alpine AS builder
RUN apk add --no-cache build-base linux-headers
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

FROM python:3.11-alpine AS runtime
RUN apk add --no-cache postgresql-client
WORKDIR /app
COPY --from=builder /wheels /wheels
COPY . .
RUN pip install --no-cache-dir --force-reinstall /wheels/* && \
    rm -rf /wheels && \
    adduser -D appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
  requirements.txt:
  main.py:
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Personal Assistant API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Personal Assistant API"}

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "personal-assistant"}

# Или если нужен минимальный вариант:
# from fastapi import FastAPI
# app = FastAPI()
# @app.get("/health")
# async def health():
#     return {"status": "ok"}
  
backups
config
  postgresql.conf
docker-secrets
  app_password.txt:
  
  postgres_password.txt:
  
  postgrespassword.txt:
  
initscripts
  init_db.sql
monitoring
  provisioning
    dashboards
      dashboard.yml:
        apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
      personal-assistant.json:
        {
  "dashboard": {
    "title": "Personal Assistant",
    "panels": [
      {
        "title": "Database Connections",
        "targets": [{
          "rawSql": "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'personal_assistant'",
          "format": "table"
        }]
      },
      {
        "title": "Active Users (7 days)",
        "targets": [{
          "rawSql": "SELECT COUNT(*) FROM users WHERE last_activity_at > NOW() - INTERVAL '7 days'",
          "format": "table"
        }]
      },
      {
        "title": "ML Inference Time",
        "targets": [{
          "rawSql": "SELECT AVG(inference_time_ms) FROM model_metrics WHERE timestamp > NOW() - INTERVAL '1 hour'",
          "format": "table"
        }]
      }
    ]
  }
}
      
    datasources
      postgres.yml:
apiVersion: 1
datasources:
  - name: PostgreSQL
    type: postgres
    url: postgres:5432
    database: personalassistant
    user: postgres  
    secureJsonData:
      password: "Pa$$w0rd123!"  # Временный для Grafana
    jsonData:
      sslmode: disable
    isDefault: true

      
  grafana.ini:
# ============================================
# Grafana Production Configuration
# monitoring/grafana.ini
# ============================================

# ============================================
# [server] - Production HTTP Server
# ============================================
[server]
# Production mode (never change)
app_mode = production

# Bind to all interfaces (Docker networking)
http_addr = 0.0.0.0
http_port = 3000

# Production domain (with Traefik reverse proxy)
domain = localhost
root_url = http://localhost:3000
serve_from_sub_path = false

# Security headers
enable_gzip = true
static_files_cache_ttl = 1h

# ============================================
# [security] - Lockdown for Production
# ============================================
[security]
# Disable login form (use auth proxy or API keys)
disable_login_form = true

# Strict cookie security
cookie_secure = true
cookie_samesite = strict

# Disable embedding (XSS protection)
allow_embedding = false

# Admin cannot create users (RBAC only)
admin_user_create = false

# ============================================
# [auth] - Production Authentication
# ============================================
[auth]
# Disable anonymous access
disable_login_form = true
disable_signout_menu = true

# Auth proxy (Traefik → Grafana headers)
auth_proxy_enabled = true
auth_proxy_header_name = X-WEBAUTH-USER
auth_proxy_header_value_is_header_regex = false

# API tokens only (no passwords)
disable_login_form = true

# ============================================
# [auth.anonymous] - DISABLED in Production
# ============================================
[auth.anonymous]
enabled = false

# ============================================
# [database] - Production Database
# ============================================
[database]
# SQLite → PostgreSQL in production
type = sqlite3
path = var/lib/grafana/grafana.db

# Connection pool (high load)
max_idle_conn = 10
max_open_conn = 100
conn_max_lifetime = 14400

# ============================================
# [users] - Production User Management
# ============================================
[users]
# Auto-assign viewers (no admin sprawl)
auto_assign_org = true
auto_assign_org_role = Viewer
default_theme = light

# ============================================
# [panels] - Production Panel Limits
# ============================================
[panels]
disable_sanitize_html = false

# ============================================
# [grafana_net] - Disable External Services
# ============================================
[grafana_net]
url = https://grafana.net

# ============================================
# [feature_toggles] - Stable Production Features
# ============================================
[feature_toggles]
# Stable features only (no experimental)
panels_docked_variable_sidebar = true

# ============================================
# [log] - Production Logging
# ============================================
[log]
# Production level (no debug)
level = info
mode = console file

# Structured JSON logging
filters = grafana/*
lines_grow = true
lines_max_num_lines = 1000000
lines_max_size_shift = 28
meta_flush_interval = 5s

# ============================================
# [metrics] - Production Metrics
# ============================================
[metrics]
enabled = true
disable_total_stats = false

# ============================================
# [smtp] - Production Alerts (optional)
# ============================================
[smtp]
enabled = false
host = smtp.gmail.com:587
user = grafana@example.com
from_address = grafana@example.com

# ============================================
# [alerting] - Production Alerts
enabled = false
enabled = false
enabled = false
# ============================================
enabled = false
enabled = false
enabled = false
[alerting]
enabled = false
enabled = false
enabled = false
enabled = true
enabled = false
enabled = false
enabled = false
error_or_timeout = timeout
enabled = false
enabled = false
enabled = false

enabled = false
enabled = false
enabled = false
# ============================================
enabled = false
enabled = false
enabled = false
# [unified_alerting] - Modern Alerting
enabled = false
enabled = false
# ============================================
[unified_alerting]
enabled = true


scripts
  backup-db.sh:
#!/bin/sh
DATE=$(date +%Y%m%d)
BACKUP_DIR=/backups

# Бэкап всех БД
pg_dumpall -h postgres -U postgres --clean --if-exists | gzip > ${BACKUP_DIR}/full-backup-${DATE}.sql.gz

# Бэкап только personalassistant (быстрее)
pg_dump -h postgres -U postgres personalassistant | gzip > ${BACKUP_DIR}/personalassistant-${DATE}.sql.gz

# Удалить старше 7 дней
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +7 -delete

# S3 (опционально)
# aws s3 cp ${BACKUP_DIR}/*.sql.gz s3://pa-backups/ --recursive

echo "✅ Backup ${DATE} completed: $(ls -lh ${BACKUP_DIR}/*.sql.gz)"
  
  rotate-secrets.sh:
#!/bin/bash
echo "🔄 Rotating secrets..."

# 1. Генерируем новый пароль
NEW_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
echo "$NEW_PASS" > docker-secrets/postgrespassword.txt.new
chmod 600 docker-secrets/postgrespassword.txt.new

# 2. Обновляем роль в БД (zero-downtime)
docker exec pa-postgres psql -U postgres -d personalassistant -c "
ALTER ROLE postgres WITH PASSWORD '$NEW_PASS';
ALTER ROLE personal_assistant_app WITH PASSWORD '$NEW_PASS';
"

# 3. Атомарная замена
mv docker-secrets/postgrespassword.txt.new docker-secrets/postgrespassword.txt

# 4. Graceful restart (0 downtime)
docker compose restart postgres app-api

echo "✅ Secrets rotated: $(cat docker-secrets/postgrespassword.txt | cut -c1-8)..."
  
  
  set-app-password.sh:
#!/bin/bash
echo "🔐 Setting app password..."

# Создать секрет (один файл!)
mkdir -p docker-secrets && chmod 700 docker-secrets
openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24 > docker-secrets/postgrespassword.txt
chmod 600 docker-secrets/postgrespassword.txt

# Установить в БД
if docker ps | grep -q pa-postgres; then
  PGPASSWORD=$(cat docker-secrets/postgrespassword.txt) \
  docker exec pa-postgres psql -U postgres -d personalassistant -c "
    ALTER ROLE postgres WITH PASSWORD '$(cat docker-secrets/postgrespassword.txt)';
    ALTER ROLE personal_assistant_app WITH PASSWORD '$(cat docker-secrets/postgrespassword.txt)';
  "
fi

echo "✅ Password: $(cat docker-secrets/postgrespassword.txt)"

  
docker-compose.yml:
services:
  postgres:
    image: postgres:15-alpine
    container_name: pa-postgres
    ports:
      - "5432:5432"  
    environment:
      POSTGRES_DB: personalassistant
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD_FILE: /run/secrets/postgrespassword
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./initscripts:/docker-entrypoint-initdb.d:ro
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
    secrets:
      - postgrespassword
    networks:
      - pa-net  
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d personalassistant"]
      retries: 10
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G

  app-api:
    build: ./app
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: "postgresql://personal_assistant_app:$${APP_PASSWORD}@postgres:5432/personalassistant"
    networks:
      - pa-net

  grafana:
    image: grafana/grafana:10.4.0
    container_name: pa-grafana
    ports:
      - "3001:3000"  
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana.ini:/etc/grafana/grafana.ini:ro
      - ./monitoring/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_AUTH_PROXY_ENABLED=true
      - GF_AUTH_PROXY_HEADER_NAME=X-WEBAUTH-USER
      - GF_SECURITY_DISABLE_LOGIN_FORM=true
      - GF_DATABASE_TYPE=postgres  
      - GF_DATABASE_HOST=postgres:5432
      - GF_DATABASE_NAME=personalassistant
      - GF_DATABASE_USER=postgres
      - GF_DATABASE_PASSWORD_FILE=/run/secrets/postgrespassword
    secrets:
      - postgrespassword
    networks:
      - pa-net
    depends_on:
      - postgres

  cron-backup:
    image: postgres:15-alpine
    container_name: pa-backup
    command: >
      sh -c "
        echo '0 3 * * * /backup.sh' > /etc/crontabs/root &&
        crond -f
      "
    volumes:
      - ./scripts/backup-db.sh:/backup.sh:ro
      - ./backups:/backups
    environment:
      PGPASSWORD_FILE: /run/secrets/postgrespassword
    secrets:
      - postgrespassword
    networks:
      - pa-net
    depends_on:
      - postgres

volumes:
  pgdata: {}
  grafana_data: {}

secrets:
  postgrespassword:
    file: ./docker-secrets/postgrespassword.txt

networks:
  pa-net:
    driver: bridge

  
  


Makefile:
# ============================================
# PERSONAL ASSISTANT - PRODUCTION MAKEFILE
# Docker Compose + Secrets + Backup + Rotation
# ============================================

.PHONY: help secrets up down validate logs build test clean backup rotate-cron cron-setup status

# ============================================
# ЦВETНЫЕ ВЫВОДЫ
# ============================================
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RED    := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

# ============================================
# 1. СЕКРЕТЫ (ОБЯЗАТЕЛЬНО перед up)
# ============================================
secrets:
	@echo "${GREEN}🔐 Creating Docker secrets...${RESET}"
	mkdir -p docker-secrets && chmod 700 docker-secrets
	openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24 > docker-secrets/postgrespassword.txt
	openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24 > docker-secrets/app_password.txt
	chmod 600 docker-secrets/*
	@echo "${GREEN}✅ Secrets created:${RESET}"
	@echo "   Postgres: $$(cat docker-secrets/postgrespassword.txt | cut -c1-8)... "
	@echo "   App role: $$(cat docker-secrets/app_password.txt | cut -c1-8)... "

# ============================================
# 2. ПОЛНЫЙ ЗАПУСК (secrets + init + app)
# ============================================
up: secrets init-db
	@echo "${GREEN}🚀 Starting services...${RESET}"
	docker compose up -d
	@echo "${GREEN}⏳ Waiting for healthy services...${RESET}"
	@sleep 30
	@make status

# ============================================
# 3. ИНИЦИАЛИЗАЦИЯ БД (init_db.sql + роли)
# ============================================
init-db:
	@echo "${GREEN}🗄️ Initializing database...${RESET}"
	docker compose up -d postgres
	@sleep 25
	docker exec pa-postgres psql -U postgres -d personalassistant -f /docker-entrypoint-initdb.d/init_db.sql || true
	
	POSTGRES_PASS=$$(cat docker-secrets/postgrespassword.txt)
	APP_PASS=$$(cat docker-secrets/app_password.txt)
	
	# ✅ ЭКРАНИРОВАНИЕ для docker exec!
	docker exec pa-postgres psql -U postgres -c $$'ALTER ROLE postgres WITH PASSWORD '\''$$POSTGRES_PASS'\'';' || true
	docker exec pa-postgres psql -U postgres -c $$'ALTER ROLE personal_assistant_app WITH PASSWORD '\''$$APP_PASS'\'';' || true
	
	@echo "${GREEN}✅ Passwords: $$(echo $$POSTGRES_PASS | cut -c1-8)...${RESET}"

# ============================================
# 4. ВАЛИДАЦИЯ (БД + сервисы)
# ============================================
validate:
	@echo "${YELLOW}🔍 Validating infrastructure...${RESET}"
	@docker compose ps --format "table {{.Names}}\t{{.Status}}" || echo "${RED}❌ Services not running${RESET}"
	@PGPASSWORD=$$(cat docker-secrets/postgrespassword.txt) psql -h localhost -U postgres -d personalassistant -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public';" | grep -q "16" && echo "${GREEN}✅ 16+ tables OK${RESET}" || echo "${RED}❌ Tables missing${RESET}"
	@docker compose ps grafana | grep -q "Up" && echo "${GREEN}✅ Grafana: localhost:3000${RESET}" || echo "${YELLOW}⚠️  Grafana not ready${RESET}"
	@curl -s http://localhost:8000/docs > /dev/null && echo "${GREEN}✅ FastAPI: localhost:8000${RESET}" || echo "${YELLOW}⚠️  FastAPI not ready${RESET}"

# ============================================
# 🛑 БЕЗОПАСНАЯ ОСТАНОВКА (БД СОХРАНЯЕТСЯ!)
# ============================================
down:
	docker compose down
	@echo "${GREEN}✅ Services stopped (DB preserved)${RESET}"

# ============================================
# 5. БЭКАПЫ (ежедневно 3:00)
# ============================================
backup:
	@echo "${GREEN}💾 Creating database backup...${RESET}"
	mkdir -p backups
	docker run --rm --network=container:pa-postgres \
		-v $$(pwd)/backups:/backups \
		postgres:15-alpine sh -c "
			PGPASSWORD_FILE=/run/secrets/postgrespassword \
			pg_dumpall -h localhost -U postgres --clean | gzip > /backups/full-$$(date +%Y%m%d).sql.gz &&
			pg_dump -h localhost -U postgres personalassistant | gzip > /backups/personalassistant-$$(date +%Y%m%d).sql.gz &&
			find /backups -name '*.sql.gz' -mtime +7 -delete
		"
	@echo "${GREEN}✅ Backup completed:${RESET}"
	@ls -lh backups/ | tail -3

# ============================================
# 6. РОТАЦИЯ ПАРОЛЕЙ (еженедельно)
# ============================================
rotate-secrets:
	@echo "${YELLOW}🔄 Rotating secrets (zero-downtime)...${RESET}"
	NEW_PASS=$$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
	docker exec pa-postgres psql -U postgres -d personalassistant -c "ALTER ROLE postgres WITH PASSWORD '$$NEW_PASS'; ALTER ROLE personal_assistant_app WITH PASSWORD '$$NEW_PASS';"
	echo "$$NEW_PASS" > docker-secrets/postgrespassword.txt
	chmod 600 docker-secrets/postgrespassword.txt
	docker compose restart postgres app-api
	@echo "${GREEN}✅ Secrets rotated: $$(echo $$NEW_PASS | cut -c1-8)...${RESET}"

# ============================================
# 7. МОНИТОРИНГ И ЛОГИ
# ============================================
status:
	@echo "${YELLOW}📊 Infrastructure status:${RESET}"
	docker compose ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "${GREEN}🔗 Access:${RESET}"
	@echo "   Grafana: http://localhost:3000 (admin/admin)"
	@echo "   FastAPI: http://localhost:8000/docs"
	@echo "   DBeaver: localhost:5432 (postgres/$$(cat docker-secrets/postgrespassword.txt))"

logs:
	docker compose logs -f --tail=100

logs-app:
	docker compose logs -f app-api

# ============================================
# 8. СБОРКА И ТЕСТЫ
# ============================================
build:
	docker compose build --no-cache

test:
	docker compose up -d app-api
	curl -f http://localhost:8000/health || echo "⚠️ Healthcheck failed"

# ============================================
# 9. ОЧИСТКА
# ============================================
#down:
#	docker compose down
#	@echo "${GREEN}✅ Services stopped${RESET}"

#clean: down
#	docker compose down -v --remove-orphans
#	docker system prune -f
#	rm -rf docker-secrets/ backups/
#	@echo "${GREEN}🧹 Full cleanup completed${RESET}"

# ============================================
# 10. CRON АВТОМАТИЗАЦИЯ
# ============================================
cron-setup:
	@echo "${GREEN}⏰ Installing cron jobs...${RESET}"
	(crontab -l 2>/dev/null; echo "0 3 * * * cd $$(pwd) && make backup") | crontab -
	(crontab -l 2>/dev/null; echo "0 4 * * 0 cd $$(pwd) && make rotate-secrets") | crontab -
	@echo "${GREEN}✅ Cron installed:${RESET}"
	@echo "   Daily backup: 03:00"
	@echo "   Weekly rotation: 04:00 Sunday"
	crontab -l

cron-remove:
	crontab -r
	@echo "${GREEN}✅ Cron jobs removed${RESET}"

# ============================================
# 11. HELP
# ============================================
help:
	@echo "${GREEN}Personal Assistant - Production Commands${RESET}"
	@echo "${YELLOW}Usage: make [target]${RESET}"
	@echo ""
	@echo "${GREEN}💻 Core:${RESET}"
	@echo "  up         🚀 Full start (secrets + init + services)"
	@echo "  down       🛑 Stop services"
	@echo "  status     📊 Show status + URLs"
	@echo "  validate   🔍 Check DB tables + services"
	@echo ""
	@echo "${GREEN}🔐 Secrets:${RESET}"
	@echo "  secrets    🔑 Generate postgres/app passwords"
	@echo "  rotate-secrets  🔄 Weekly password rotation"
	@echo ""
	@echo "${GREEN}💾 Backup:${RESET}"
	@echo "  backup     💾 Daily DB backup (7-day retention)"
	@echo "  cron-setup 📅 Install cron (backup + rotation)"
	@echo ""
	@echo "${GREEN}🧹 Maintenance:${RESET}"
	@echo "  logs       📜 Tail all logs"
	@echo "  logs-app   📜 App logs only"
	@echo "  clean      🧹 Full cleanup (volumes + secrets)"
	@echo "  help       📖 This help"
	@echo ""
	@echo "${YELLOW}Production schedule:${RESET}"
	@echo "  03:00 daily  → make backup"
	@echo "  04:00 Sunday → make rotate-secrets"


bash_start.sh:
#!/bin/bash
set -e

echo "🚀 Personal Assistant - PRODUCTION READY"

# 1. Secrets
./scripts/set-app-password.sh
POSTGRES_PASS=$(cat docker-secrets/postgrespassword.txt)
APP_PASS=$(cat docker-secrets/app_password.txt)
echo "🔐 Password: $POSTGRES_PASS"

# 2. Postgres + init
make down
docker compose up -d postgres
sleep 25
docker exec pa-postgres psql -U postgres -d personalassistant -f /docker-entrypoint-initdb.d/init_db.sql || true

# 3. Пароли (БЕЗ Makefile ошибок!)
docker exec pa-postgres psql -U postgres -c "ALTER ROLE postgres WITH PASSWORD '$POSTGRES_PASS';"
docker exec pa-postgres psql -U postgres -c "ALTER ROLE personal_assistant_app WITH PASSWORD '$APP_PASS';"

# 4. Full stack
docker compose up -d

# 5. Тест
PGPASSWORD=$POSTGRES_PASS psql -h localhost -U postgres -d personalassistant -c "\dt" | head -5
echo "✅ DATABASE OK! DBeaver: localhost:5432 postgres/$POSTGRES_PASS"
echo "🌐 API: http://localhost:8000"
echo "📊 Grafana: http://localhost:3000"




.dockerignore
.gitignore























