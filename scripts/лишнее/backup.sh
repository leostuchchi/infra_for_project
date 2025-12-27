#!/bin/bash
set -e

echo "💾 Starting production backup..."

export PGPASSWORD=$(cat /run/secrets/postgrespassword)

# Create backup filename with timestamp
BACKUP_FILE="/backups/backup_$(date +%Y%m%d_%H%M%S).dump"

# Perform backup
echo "Creating backup: $BACKUP_FILE"
pg_dump -h pa-postgres -U postgres -d personal_assistant \
    --format=custom --compress=9 \
    --exclude-table-data='system_audit_log' \
    --exclude-table-data='calculation_cache' \
    --exclude-table-data='system_metrics' \
    -f "$BACKUP_FILE"

# Verify backup
if pg_restore -l "$BACKUP_FILE" > /dev/null 2>&1; then
    echo "✅ Backup verified successfully"
    
    # Cleanup old backups (keep 7 daily, 4 weekly)
    echo "Cleaning old backups..."
    find /backups -name "*.dump" -mtime +30 -delete
    
    echo "Backup completed: $BACKUP_FILE"
    exit 0
else
    echo "❌ Backup verification failed!"
    rm -f "$BACKUP_FILE"
    exit 1
fi
