#!/bin/bash
echo "🚀 QUICK PRODUCTION START"
echo "========================"

# Make sure we have the right Makefile
if [ ! -f Makefile ] && [ -f Makefile.perfect ]; then
    echo "Linking Makefile.perfect to Makefile..."
    ln -sf Makefile.perfect Makefile
fi

# Generate secrets if not exists
if [ ! -d docker-secrets ] || [ ! -f docker-secrets/postgrespassword.txt ]; then
    echo "Generating secrets..."
    make secrets 2>/dev/null || chmod +x Makefile && make secrets
fi

# Start services
echo "Starting services..."
make up

echo ""
echo "✅ Production services started!"
echo ""
echo "Quick commands:"
echo "  make health      - Check service status"
echo "  make logs        - View logs"
echo "  make monitor     - Open Grafana"
echo "  make test-db     - Test database"
echo ""
echo "Grafana: http://localhost:3001"
echo "PostgreSQL: localhost:5432"
