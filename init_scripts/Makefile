# ============================================
# INIT SCRIPTS MAKEFILE
# ============================================

.PHONY: help validate clean test

DB_NAME = personal_assistant
DB_USER = pa_admin
DB_HOST = localhost
DB_PORT = 5432

help:
	@echo "Init Scripts Management"
	@echo ""
	@echo "Usage:"
	@echo "  make validate  - Validate SQL syntax"
	@echo "  make clean     - Clean generated files"
	@echo "  make test      - Test SQL scripts"
	@echo "  make lint      - Lint SQL files"

validate:
	@echo "🔍 Validating init_db.sql..."
	@docker run --rm -v $(PWD):/scripts postgres:15-alpine \
		psql -v ON_ERROR_STOP=1 -f /scripts/init_db.sql --echo-errors > /dev/null 2>&1 && \
		echo "✅ init_db.sql is valid"
	
	@echo "🔍 Validating init_extensions.sql..."
	@docker run --rm -v $(PWD):/scripts postgres:15-alpine \
		psql -v ON_ERROR_STOP=1 -f /scripts/init_extensions.sql --echo-errors > /dev/null 2>&1 && \
		echo "✅ init_extensions.sql is valid"

clean:
	@rm -f *.log *.bak
	@echo "✅ Cleaned temporary files"

test:
	@echo "🧪 Testing database initialization..."
	@docker-compose --profile init up init-db --build --abort-on-container-exit
	@echo "✅ Test completed"

lint:
	@echo "📝 Linting SQL files..."
	@if command -v sqlfluff > /dev/null; then \
		sqlfluff lint init_db.sql; \
		sqlfluff lint init_extensions.sql; \
	else \
		echo "⚠️ sqlfluff not installed. Install with: pip install sqlfluff"; \
	fi

backup-config:
	@echo "💾 Backing up PostgreSQL config..."
	@cp postgresql.conf postgresql.conf.backup.$(shell date +%Y%m%d_%H%M%S)
	@echo "✅ Config backed up"

diff-config:
	@echo "🔍 Diff with default PostgreSQL config..."
	@docker run --rm postgres:15-alpine cat /usr/local/share/postgresql/postgresql.conf.sample > default.conf
	@diff -u default.conf postgresql.conf || true
	@rm -f default.conf
