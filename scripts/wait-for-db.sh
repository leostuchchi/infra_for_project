#!/bin/bash
# ============================================
# WAIT FOR DATABASE UTILITY
# ============================================

set -e

# Загружаем .env если существует
if [ -f .env ]; then
    source .env
fi

# Параметры по умолчанию
DB_HOST=${DB_HOST:-postgres}
DB_PORT=${DB_PORT:-5432}
MAX_RETRIES=30
RETRY_INTERVAL=2

echo "⏳ Waiting for database at ${DB_HOST}:${DB_PORT}..."

for i in $(seq 1 $MAX_RETRIES); do
    if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null; then
        echo "✅ Database is ready!"
        
        # Дополнительная проверка через pg_isready
        if command -v pg_isready >/dev/null 2>&1; then
            if pg_isready -h $DB_HOST -p $DB_PORT 2>/dev/null; then
                echo "✅ PostgreSQL is accepting connections"
                exit 0
            fi
        fi
        
        exit 0
    fi
    
    echo "⏱️  Attempt $i/$MAX_RETRIES: Database not ready yet..."
    sleep $RETRY_INTERVAL
done

echo "❌ ERROR: Database not available after $MAX_RETRIES attempts"
exit 1
