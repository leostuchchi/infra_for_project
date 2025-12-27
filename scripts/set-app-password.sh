#!/bin/bash
echo "🔐 Generating Docker secrets..."

# Создаём папку (если нет)
mkdir -p docker-secrets && chmod 700 docker-secrets

# Только 2 пароля (Postgres superuser + app роль)
POSTGRES_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)
APP_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)

# Сохраняем в Docker secrets формат
echo "$POSTGRES_PASS" > docker-secrets/postgrespassword.txt
echo "$APP_PASS"     > docker-secrets/app_password.txt

# Права доступа
chmod 600 docker-secrets/*

# Устанавливаем пароль роли (если postgres запущен)
if docker ps | grep -q pa-postgres; then
    docker exec pa-postgres psql -U postgres -d personalassistant -c \
        "ALTER ROLE personal_assistant_app WITH PASSWORD '$APP_PASS';"
    echo "✅ App role password set"
fi

echo "✅ Docker secrets ready: postgrespassword.txt, app_password.txt"
echo "⚠️  НЕТ .env файла! Используйте docker-compose.prod.yml secrets."

