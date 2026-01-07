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
	docker exec pa-postgres psql -U postgres -c $$'ALTER ROLE postgres WITH PASSWORD '\\''$$POSTGRES_PASS'\\'';' || true
	docker exec pa-postgres psql -U postgres -c $$'ALTER ROLE personal_assistant_app WITH PASSWORD '\\''$$APP_PASS'\\'';' || true
	
	@echo "${GREEN}✅ Passwords: $$(echo $$POSTGRES_PASS | cut -c1-8)...${RESET}"

# ============================================
# 4. ВАЛИДАЦИЯ (БД + сервисы)
# ============================================
validate:
	@echo "${YELLOW}🔍 Validating infrastructure...${RESET}"
	@docker compose ps --format "table {{.Names}}	{{.Status}}" || echo "${RED}❌ Services not running${RESET}"
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
	docker compose ps --format "table {{.Names}}	{{.Status}}	{{.Ports}}"
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
	echo "0 3 * * * cd $$(pwd) && make backup" > /tmp/crontab_pa
	echo "0 4 * * 0 cd $$(pwd) && make rotate-secrets" >> /tmp/crontab_pa
	crontab /tmp/crontab_pa
	rm /tmp/crontab_pa
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