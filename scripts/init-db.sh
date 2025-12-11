#!/bin/bash
# ============================================
# DATABASE INITIALIZATION SCRIPT
# ============================================

set -e

echo "🚀 Starting database initialization..."

# Проверяем наличие .env файла
if [ ! -f .env ]; then
    echo "❌ .env file not found. Generating secrets first..."
    ./scripts/generate-secrets.sh
fi

# Загружаем переменные окружения
source .env

# Ждем готовности PostgreSQL
echo "⏳ Waiting for PostgreSQL to be ready..."
./scripts/wait-for-db.sh

# Подготавливаем SQL файл с подстановкой паролей
echo "🔧 Preparing SQL with actual passwords..."

# Создаем временный SQL файл с подставленными паролями
cat > /tmp/init_db_with_passwords.sql << EOF
-- ============================================
-- PERSONAL ASSISTANT DATABASE INITIALIZATION
-- Auto-generated with actual passwords
-- Generated: $(date)
-- ============================================

-- Устанавливаем пароли для ролей
ALTER ROLE personal_assistant_app WITH PASSWORD '${DB_PASSWORD}';

-- Создаем readonly роль если её нет
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_readonly') THEN
        CREATE ROLE personal_assistant_readonly WITH LOGIN PASSWORD '${READONLY_DB_PASSWORD}';
        GRANT CONNECT ON DATABASE personal_assistant TO personal_assistant_readonly;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO personal_assistant_readonly;
        RAISE NOTICE 'Readonly role created successfully';
    END IF;
END
\$\$;

-- Создаем роль для миграций если её нет
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_migrations') THEN
        CREATE ROLE personal_assistant_migrations WITH LOGIN PASSWORD '${MIGRATIONS_DB_PASSWORD}';
        GRANT CREATE ON SCHEMA public TO personal_assistant_migrations;
        RAISE NOTICE 'Migrations role created successfully';
    END IF;
END
\$\$;

-- Проверяем существование таблиц
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE tablename = 'users') THEN
        RAISE NOTICE 'Creating database schema from init_db.sql...';
        -- Здесь будет вставлен основной SQL
    ELSE
        RAISE NOTICE 'Database already initialized. Skipping schema creation.';
    END IF;
END
\$\$;
EOF

# Добавляем основной SQL скрипт
cat init_scripts/init_db.sql >> /tmp/init_db_with_passwords.sql

# Выполняем инициализацию
echo "📦 Initializing database..."

# Исполняем SQL с паролями
docker exec -i personal-assistant-postgres psql \
    -U postgres \
    -d personal_assistant \
    -c "CREATE DATABASE personal_assistant;" 2>/dev/null || true

docker exec -i personal-assistant-postgres psql \
    -U postgres \
    -d personal_assistant \
    -f /tmp/init_db_with_passwords.sql

# Очищаем временный файл
rm -f /tmp/init_db_with_passwords.sql

echo "✅ Database initialization completed!"
echo ""
echo "📊 Connection information:"
echo "   Host:     ${DB_HOST}:${DB_PORT}"
echo "   Database: ${POSTGRES_DB}"
echo "   User:     ${POSTGRES_USER}"
echo ""
echo "🔑 Passwords are stored in .env file"
