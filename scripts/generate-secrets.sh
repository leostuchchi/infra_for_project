#!/bin/bash
echo "🔐 Generating secure passwords..."

# Создаем папку для секретов
mkdir -p docker-secrets

# Генерируем пароли БЕЗ спецсимволов, которые могут сломать PostgreSQL
DB_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
POSTGRES_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
REDIS_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)
READONLY_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)

# Создаем .env файл
cat > .env << ENV_EOF
# ============================================
# PERSONAL ASSISTANT - SECURE PASSWORDS
# Generated: $(date)
# ============================================

# PostgreSQL Application User
DB_PASSWORD=${DB_PASS}

# PostgreSQL Superuser (для инициализации)
POSTGRES_PASSWORD=${POSTGRES_PASS}

# Redis
REDIS_PASSWORD=${REDIS_PASS}

# Readonly user для мониторинга
READONLY_DB_PASSWORD=${READONLY_PASS}

# Docker Compose
COMPOSE_PROJECT_NAME=personal-assistant

# Paths
VOLUME_PATH=./data

# Ports
DB_PORT=5432
REDIS_PORT=6379
OLLAMA_EXTERNAL_PORT=11435
ENV_EOF

# Сохраняем пароли отдельно (опционально)
echo "${DB_PASS}" > docker-secrets/db_password.txt
echo "${POSTGRES_PASS}" > docker-secrets/postgres_password.txt
echo "${REDIS_PASS}" > docker-secrets/redis_password.txt

# Защищаем файлы
chmod 600 .env docker-secrets/*.txt 2>/dev/null || true

echo "✅ Secure passwords generated in .env"
echo ""
echo "🔑 Generated passwords:"
echo "  DB_PASSWORD:         ${DB_PASS}"
echo "  POSTGRES_PASSWORD:   ${POSTGRES_PASS}"
echo "  REDIS_PASSWORD:      ${REDIS_PASS}"
echo "  READONLY_DB_PASSWORD: ${READONLY_PASS}"
echo ""
echo "⚠️  IMPORTANT: Backup the .env file!"
