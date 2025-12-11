#!/bin/bash

# Конфигурация
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql.gz"

# Создание бэкапа
echo "Creating backup: $BACKUP_FILE"
pg_dump -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" --no-password | gzip > "$BACKUP_FILE"

# Проверка результата
if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully: $BACKUP_FILE"
    
    # Удаление старых бэкапов (храним 30 дней)
    find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +30 -delete
    echo "✅ Old backups cleaned"
    
    # Отправка уведомления (опционально)
    # curl -X POST -H "Content-Type: application/json" \
    #   -d '{"text":"Backup completed successfully"}' \
    #   https://hooks.slack.com/services/...
else
    echo "❌ Backup failed!"
    exit 1
fi
