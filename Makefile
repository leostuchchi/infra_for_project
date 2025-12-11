# ============================================
# PERSONAL ASSISTANT - DOCKER MANAGEMENT
# ============================================

DOCKER_COMPOSE = docker compose

.PHONY: help secrets init up up-dev down logs clean

help:
	@echo "Commands:"
	@echo "  make secrets  - Generate secure passwords"
	@echo "  make init     - Initialize database"
	@echo "  make up       - Start services"
	@echo "  make up-dev   - Start with monitoring"
	@echo "  make down     - Stop services"
	@echo "  make logs     - Show logs"
	@echo "  make clean    - Clean everything"

# В Makefile обновите секцию secrets:
secrets:
	@echo "🔐 Generating secure passwords..."
	@if [ -f scripts/generate-secrets.sh ]; then \
		./scripts/generate-secrets.sh; \
	else \
		echo "Creating passwords manually..."; \
		echo "DB_PASSWORD=$(shell openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)" > .env; \
		echo "POSTGRES_PASSWORD=$(shell openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)" >> .env; \
		echo "REDIS_PASSWORD=$(shell openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)" >> .env; \
		echo "READONLY_DB_PASSWORD=$(shell openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)" >> .env; \
		echo "COMPOSE_PROJECT_NAME=personal-assistant" >> .env; \
		echo "VOLUME_PATH=./data" >> .env; \
		echo "✅ Passwords generated in .env"; \
	fi

init: secrets
	@echo "📦 Initializing database..."
	@mkdir -p ./data/postgres
	@sudo chmod 777 ./data/postgres 2>/dev/null || chmod 777 ./data/postgres
	@docker compose down 2>/dev/null || true
	@docker compose up -d postgres
	@echo "⏳ Waiting for PostgreSQL to start..."
	@sleep 30
	@docker compose up init-db
	@echo "✅ Database initialized with secure passwords!"

up:
	@echo "🚀 Starting services..."
	@docker compose up -d postgres redis ollama
	@echo "✅ Services started!"
	@echo ""
	@echo "🔑 Connection info:"
	@echo "  PostgreSQL: localhost:5432"
	@echo "  Redis:      localhost:6379"
	@echo "  Ollama:     localhost:11435"

up-dev: up
	@echo "📊 Starting monitoring..."
	@docker compose --profile monitoring up -d 2>/dev/null || echo "No monitoring profile"
	@echo "🌐 pgAdmin: http://localhost:5050"

down:
	@docker compose down

logs:
	@docker compose logs -f

clean:
	@docker compose down -v
	@rm -rf ./data
	@echo "🧹 Cleaned up"
