#!/bin/bash
echo "🔧 FIXING PERSONAL ASSISTANT INSTALLATION..."

# 1. Cleanup
docker compose down 2>/dev/null || true

# 2. Fix permissions
echo "📁 Fixing permissions..."
sudo rm -rf ./data/postgres 2>/dev/null || true
mkdir -p ./data/postgres
sudo chmod 777 ./data/postgres

# 3. Create simple .env
echo "🔐 Creating simple passwords..."
cat > .env << 'ENVEOF'
# SIMPLE PASSWORDS FOR DEVELOPMENT
DB_PASSWORD=Admin123
POSTGRES_PASSWORD=Postgres456
REDIS_PASSWORD=Redis789
COMPOSE_PROJECT_NAME=personal-assistant
ENVEOF

# 4. Start PostgreSQL alone
echo "🚀 Starting PostgreSQL..."
docker compose up -d postgres

# 5. Wait and check
echo "⏳ Waiting for PostgreSQL to start..."
sleep 15

echo "📊 Checking status..."
if docker compose logs postgres 2>&1 | grep -q "database system is ready"; then
    echo "✅ PostgreSQL is RUNNING!"
    echo "📦 Now starting all services..."
    docker compose up -d
    echo "🎉 ALL SERVICES STARTED!"
else
    echo "❌ PostgreSQL failed to start. Showing logs:"
    docker compose logs postgres --tail=30
fi
