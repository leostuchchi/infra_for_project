-- ============================================
-- ДОПОЛНИТЕЛЬНЫЕ РАСШИРЕНИЯ POSTGRESQL
-- ============================================

-- Для полнотекстового поиска на русском
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Для статистики производительности
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Для более эффективной работы с JSONB
CREATE EXTENSION IF NOT EXISTS "jsquery";

-- Для работы с массивами
CREATE EXTENSION IF NOT EXISTS "intarray";

-- Если нужны математические функции
CREATE EXTENSION IF NOT EXISTS "tablefunc";

-- Создаем схему security для чувствительных данных
CREATE SCHEMA IF NOT EXISTS security;

-- Права на схему security
GRANT USAGE ON SCHEMA security TO personal_assistant_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA security TO personal_assistant_app;
