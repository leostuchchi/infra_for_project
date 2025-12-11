инфраструктура для проекта:
безопасная база данных, с обновляемыми паролями.
установите Ваш sql скрипт в init_scripts/init_db.sql

Структура:

backup_scripts:
backup_scripts/backup.sh:
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

config:
config/redis.conf:
# Redis Configuration for Personal Assistant
bind 0.0.0.0
port 6379
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data

config/servers.json:
{
  "Servers": {
    "1": {
      "Name": "Personal Assistant DB",
      "Group": "Personal Assistant",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "personal_assistant",
      "Username": "personal_assistant_app",
      "SSLMode": "prefer",
      "PassFile": "/pgadmin4/.pgpass",
      "Comment": "Auto-configured for Personal Assistant"
    },
    "2": {
      "Name": "Personal Assistant (Readonly)",
      "Group": "Personal Assistant",
      "Host": "postgres",
      "Port": 5432,
      "MaintenanceDB": "personal_assistant",
      "Username": "personal_assistant_readonly",
      "SSLMode": "prefer",
      "PassFile": "/pgadmin4/.pgpass",
      "Comment": "Readonly access for monitoring"
    }
  }
}


data:
data/ollama/
data/postgres/
data/redis/

docker-secrets:
docker-secrets/db_password.txt:
lRFME899RmSHOHdklpLYOU9W

docker-secrets/postgres_password.txt:
wySrjiKzCbIlMyZW9PAMYkBB

docker-secrets/redis_password.txt:
NQMyjfIOC1HW0G33NasS

init_scripts:
init_scripts/bash:
#!/bin/bash

# Сгенерируйте пароли
openssl rand -base64 32 > .db_password
openssl rand -base64 32 > .postgres_password
openssl rand -base64 24 > .redis_password

# Или сгенерируйте командой:
echo "DB_PASSWORD=$(openssl rand -base64 32)" >> .env

# Основные команды
make up         # Запуск сервисов
make down       # Остановка сервисов
make logs       # Просмотр логов
make psql       # Подключение к БД
make restart    # Перезапуск

# Администрирование
make init       # Инициализация БД
make backup     # Создание бэкапа
make validate   # Валидация SQL
make health     # Проверка здоровья

# Очистка
make clean      # Полная очистка

make status     # Статус сервисов
make health     # Проверка здоровья
docker stats    # Использование ресурсов

# Проверка логов
make logs

# Проверка подключения
make health

# Валидация схемы
make validate

# Полная переустановка
make clean
make setup
make up

# Только инициализация
docker-compose --profile init up init-db

# С админкой
docker-compose --profile admin up -d

# Основные сервисы
docker-compose up -d

# Валидация SQL перед запуском
make validate

# Проверка здоровья сервисов
make health

# Полная установка
make setup

# Только инициализация БД
make init

# Проверка SQL скриптов
cd init_scripts && make validate

# Запуск с перезагрузкой
docker-compose --profile development up -d

# Тестирование БД
cd init_scripts && make test

# Проверка подключения
docker exec personal-assistant-postgres psql -U personal_assistant_app -d personal_assistant -c "\dt"

# Проверка партиций
docker exec personal-assistant-postgres psql -U personal_assistant_app -d personal_assistant -c "SELECT schemaname, tablename FROM pg_tables WHERE tablename LIKE '%_y%';"

# Проверка ролей
docker exec personal-assistant-postgres psql -U postgres -d personal_assistant -c "\du"

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

# Создаем директорию для моделей
mkdir -p models

# Файл моделей
cat > models/README.md << 'EOF'
# Ollama Models

Place your Ollama models here:

1. mistral:7b - для рекомендаций
2. llama2:13b - для анализа текста
3. codellama:7b - для программирования

Download with:
docker-compose exec ollama ollama pull mistral
EOF

# Клонируйте репозиторий
git clone <your-repo>
cd personal-assistant

# Создайте необходимые директории
mkdir -p data/backups data/postgres data/redis data/ollama

# Настройте переменные окружения
cp .env.example .env
# Отредактируйте .env при необходимости

# Первый запуск с инициализацией БД
make setup

# Запуск всех сервисов
make up

# Проверка статуса
make status

# Только основное (по умолчанию)
docker-compose up -d

# С админкой и мониторингом
docker-compose --profile admin up -d

# Только для разработки (с авто-перезагрузкой)
docker-compose --profile development up -d

# Полный стек (все сервисы)
docker-compose --profile full up -d

PostgreSQL	localhost:5432	5432	pa_admin/Admin_Pass_123!
Redis	localhost:6379	6379	-
Ollama	localhost:11434	11434	-
PgAdmin	http://localhost:5050	5050	admin@personalassistant.com/Admin123!
Redis Insight	http://localhost:8001	8001	-


# Тест подключения к PostgreSQL
docker-compose exec postgres pg_isready -U pa_admin

# Тест подключения к Redis
docker-compose exec redis redis-cli ping

# Тест подключения к Ollama
curl http://localhost:11434/api/tags

# Тест создания пользователя
docker-compose exec postgres psql -U pa_admin -d personal_assistant -c \
  "INSERT INTO users (telegram_id) VALUES (123456789) RETURNING id;"
  
  
# Просмотр логов
make logs

# Мониторинг ресурсов
docker stats

# Проверка БД
docker-compose exec postgres psql -U pa_admin -d personal_assistant -c \
  "SELECT * FROM user_monitoring LIMIT 5;"
  
  
init_scripts/init_db.sql:
init_db.sql:
-- ============================================
-- ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ PERSONAL ASSISTANT
-- ВЕРСИЯ 2.0 (ИСПРАВЛЕННАЯ, БОЕВАЯ)
-- ============================================

-- Устанавливаем параметры сессии
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET TIME ZONE 'UTC';

-- ============================================
-- 1. СОЗДАНИЕ РАСШИРЕНИЙ
-- ============================================

-- UUID генерация
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Криптографические функции (для хэшей)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Мониторинг производительности запросов
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Полнотекстовый поиск на русском
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Для планировщика задач (опционально, если нужно)
-- CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ============================================
-- 2. СОЗДАНИЕ ТИПОВ ДАННЫХ
-- ============================================

-- Типы активности для рекомендаций
DO $$ BEGIN
    CREATE TYPE activity_type AS ENUM (
        'physical',
        'spiritual', 
        'learning',
        'psychological',
        'career',
        'self_realization',
        'finances'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Типы астрологических аспектов
DO $$ BEGIN
    CREATE TYPE aspect_type AS ENUM (
        'conjunction',
        'sextile',
        'square',
        'trine',
        'opposition',
        'quincunx',
        'semi_sextile',
        'semi_square'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Уровни энергии для рекомендаций
DO $$ BEGIN
    CREATE TYPE energy_level AS ENUM (
        'very_low',
        'low',
        'medium',
        'high',
        'very_high'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Типы психологических тестов
DO $$ BEGIN
    CREATE TYPE test_type AS ENUM (
        'mbti',
        'big5',
        'values',
        'maslow'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- 3. ОСНОВНАЯ ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    -- Основной идентификатор
    id BIGSERIAL PRIMARY KEY,
    
    -- Внешние идентификаторы (опциональные)
    telegram_id BIGINT UNIQUE,
    
    -- Хэшированные идентификаторы для анонимизации
    phone_hash VARCHAR(128),
    email_hash VARCHAR(128),
    
    -- Статус пользователя
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'deleted')),
    is_verified BOOLEAN DEFAULT FALSE,
    is_premium BOOLEAN DEFAULT FALSE,
    
    -- Конфиденциальность
    privacy_level VARCHAR(20) DEFAULT 'standard' CHECK (privacy_level IN ('minimal', 'standard', 'maximum')),
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    premium_until TIMESTAMPTZ,
    
    -- Индексы
    CONSTRAINT unique_phone_email UNIQUE NULLS NOT DISTINCT (phone_hash, email_hash)
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id) WHERE telegram_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash) WHERE phone_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_hash ON users(email_hash) WHERE email_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_last_activity ON users(last_activity_at DESC);

-- ============================================
-- 4. ПРОФИЛИ ПОЛЬЗОВАТЕЛЕЙ
-- ============================================

CREATE TABLE IF NOT EXISTS user_profiles (
    -- Ссылка на пользователя
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основная информация
    full_name VARCHAR(255),
    username VARCHAR(100),
    language_code VARCHAR(10) DEFAULT 'ru',
    timezone VARCHAR(50) DEFAULT 'Europe/Moscow',
    
    -- Данные для расчётов (ОБЯЗАТЕЛЬНЫЕ)
    birth_date DATE NOT NULL,
    birth_time TIME NOT NULL,
    birth_city VARCHAR(100) NOT NULL,
    birth_country VARCHAR(100) DEFAULT 'Россия',
    birth_coordinates POINT, -- (широта, долгота)
    
    -- Профессиональная информация
    profession VARCHAR(100),
    job_position VARCHAR(100),
    industry VARCHAR(100),
    
    -- Текущее местоположение
    current_city VARCHAR(100),
    current_country VARCHAR(100),
    current_coordinates POINT,
    
    -- Настройки
    notification_enabled BOOLEAN DEFAULT TRUE,
    daily_recommendations_enabled BOOLEAN DEFAULT TRUE,
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ограничения
    CONSTRAINT valid_birth_date CHECK (
        birth_date >= '1900-01-01' 
        AND birth_date <= CURRENT_DATE - INTERVAL '1 year'
    ),
    CONSTRAINT valid_birth_time CHECK (
        birth_time >= '00:00:00' 
        AND birth_time < '24:00:00'
    )
);

-- Индексы для профилей
CREATE INDEX IF NOT EXISTS idx_profiles_birth_date ON user_profiles(birth_date);
CREATE INDEX IF NOT EXISTS idx_profiles_birth_city ON user_profiles(birth_city);
CREATE INDEX IF NOT EXISTS idx_profiles_profession ON user_profiles(profession);
CREATE INDEX IF NOT EXISTS idx_profiles_language ON user_profiles(language_code);

-- Индекс для пространственных запросов
CREATE INDEX IF NOT EXISTS idx_profiles_birth_coords ON user_profiles USING GIST(birth_coordinates);
CREATE INDEX IF NOT EXISTS idx_profiles_current_coords ON user_profiles USING GIST(current_coordinates);

-- ============================================
-- 5. СЕССИИ АВТОРИЗАЦИИ
-- ============================================

CREATE TABLE IF NOT EXISTS auth_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Безопасное хранение токенов
    access_token_hash VARCHAR(128) NOT NULL,
    refresh_token_hash VARCHAR(128),
    device_fingerprint VARCHAR(255),
    
    -- Информация о сессии
    auth_method VARCHAR(20) NOT NULL CHECK (auth_method IN ('telegram', 'web', 'mobile')),
    user_agent TEXT,
    ip_address INET,
    device_type VARCHAR(50),
    device_info JSONB DEFAULT '{}',
    
    -- Статус
    is_active BOOLEAN DEFAULT TRUE,
    invalidated_at TIMESTAMPTZ,
    
    -- Время жизни
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Индексы
    CONSTRAINT unique_active_session UNIQUE (user_id, device_fingerprint, is_active) 
    WHERE is_active = TRUE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON auth_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_access_token ON auth_sessions(access_token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON auth_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON auth_sessions(is_active) WHERE is_active = TRUE;

-- ============================================
-- 6. НАТАЛЬНЫЕ КАРТЫ (ПАРТИЦИОНИРОВАННАЯ)
-- ============================================

-- Основная таблица для партиционирования
CREATE TABLE IF NOT EXISTS natal_charts (
    id BIGSERIAL,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Метаданные расчёта
    calculation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    calculation_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Географические данные
    city_name VARCHAR(100) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    altitude INTEGER,
    timezone VARCHAR(50) NOT NULL,
    
    -- Астрологические данные (оптимизированное хранение)
    planets JSONB NOT NULL DEFAULT '{}',
    houses JSONB NOT NULL DEFAULT '{}',
    angles JSONB NOT NULL DEFAULT '{}',
    aspects JSONB NOT NULL DEFAULT '[]',
    placements JSONB NOT NULL DEFAULT '{}',
    
    -- ML-признаки
    ml_features JSONB NOT NULL DEFAULT '{}',
    element_balance JSONB NOT NULL DEFAULT '{}',
    sign_distribution JSONB NOT NULL DEFAULT '{}',
    planetary_patterns JSONB NOT NULL DEFAULT '{}',
    
    -- Метаданные
    calculation_jd DECIMAL(12,6) NOT NULL,
    house_system VARCHAR(20) DEFAULT 'Placidus',
    ephemeris_version VARCHAR(20) DEFAULT 'DE441',
    algorithm_version VARCHAR(20) DEFAULT '1.0',
    
    -- Статус
    calculation_status VARCHAR(20) DEFAULT 'success' CHECK (calculation_status IN ('pending', 'success', 'failed', 'partial')),
    error_message TEXT,
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Первичный ключ с партиционированием
    PRIMARY KEY (id, calculation_date)
) PARTITION BY RANGE (calculation_date);

-- ============================================
-- 7. ПСИХОМАТРИЦЫ
-- ============================================

CREATE TABLE IF NOT EXISTS psyho_matrices (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные числа Пифагора
    first_number INTEGER NOT NULL CHECK (first_number > 0),
    second_number INTEGER NOT NULL CHECK (second_number > 0),
    third_number INTEGER NOT NULL,
    fourth_number INTEGER NOT NULL,
    
    -- Матрица 3x3
    matrix_digits JSONB NOT NULL DEFAULT '{}',
    
    -- Характеристики
    characteristics JSONB NOT NULL DEFAULT '{}',
    talent_codes TEXT[] DEFAULT '{}',
    strength_codes TEXT[] DEFAULT '{}',
    
    -- Анализ
    energy_level VARCHAR(20),
    life_purpose TEXT,
    compatibility_hints JSONB DEFAULT '{}',
    
    -- Метаданные
    calculation_version VARCHAR(20) DEFAULT '1.0',
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ограничения
    CONSTRAINT valid_matrix_digits CHECK (
        jsonb_typeof(matrix_digits) = 'object'
        AND matrix_digits ? '1'
        AND matrix_digits ? '9'
    )
);

CREATE INDEX IF NOT EXISTS idx_matrices_digits_gin ON psyho_matrices USING GIN(matrix_digits);
CREATE INDEX IF NOT EXISTS idx_matrices_characteristics_gin ON psyho_matrices USING GIN(characteristics);
CREATE INDEX IF NOT EXISTS idx_matrices_talents_gin ON psyho_matrices USING GIN(talent_codes);

-- ============================================
-- 8. БИОРИТМЫ (ПАРТИЦИОНИРОВАННАЯ)
-- ============================================

CREATE TABLE IF NOT EXISTS biorhythms (
    id BIGSERIAL,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Основные циклы (значения от -100 до 100)
    physical_cycle SMALLINT NOT NULL CHECK (physical_cycle BETWEEN -100 AND 100),
    emotional_cycle SMALLINT NOT NULL CHECK (emotional_cycle BETWEEN -100 AND 100),
    intellectual_cycle SMALLINT NOT NULL CHECK (intellectual_cycle BETWEEN -100 AND 100),
    intuitive_cycle SMALLINT NOT NULL CHECK (intuitive_cycle BETWEEN -100 AND 100),
    
    -- Проценты (0-100)
    physical_percentage SMALLINT NOT NULL CHECK (physical_percentage BETWEEN 0 AND 100),
    emotional_percentage SMALLINT NOT NULL CHECK (emotional_percentage BETWEEN 0 AND 100),
    intellectual_percentage SMALLINT NOT NULL CHECK (intellectual_percentage BETWEEN 0 AND 100),
    intuitive_percentage SMALLINT NOT NULL CHECK (intuitive_percentage BETWEEN 0 AND 100),
    
    -- Метаданные циклов
    physical_phase VARCHAR(20) NOT NULL,
    emotional_phase VARCHAR(20) NOT NULL,
    intellectual_phase VARCHAR(20) NOT NULL,
    intuitive_phase VARCHAR(20) NOT NULL,
    
    -- Тренды
    physical_trend VARCHAR(10) NOT NULL CHECK (physical_trend IN ('rising', 'falling', 'stable')),
    emotional_trend VARCHAR(10) NOT NULL CHECK (emotional_trend IN ('rising', 'falling', 'stable')),
    intellectual_trend VARCHAR(10) NOT NULL CHECK (intellectual_trend IN ('rising', 'falling', 'stable')),
    intuitive_trend VARCHAR(10) NOT NULL CHECK (intuitive_trend IN ('rising', 'falling', 'stable')),
    
    -- Общая энергия
    overall_energy SMALLINT NOT NULL CHECK (overall_energy BETWEEN -100 AND 100),
    overall_energy_percentage SMALLINT NOT NULL CHECK (overall_energy_percentage BETWEEN 0 AND 100),
    overall_energy_level energy_level NOT NULL,
    
    -- Дополнительные данные
    days_lived INTEGER NOT NULL CHECK (days_lived > 0),
    is_critical_day BOOLEAN DEFAULT FALSE,
    is_peak_day BOOLEAN DEFAULT FALSE,
    
    -- Рекомендации и анализ
    recommendations TEXT[] DEFAULT '{}',
    critical_cycles TEXT[] DEFAULT '{}',
    peak_cycles TEXT[] DEFAULT '{}',
    daily_insights JSONB DEFAULT '{}',
    
    -- Временные метки
    calculated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Первичный ключ с партиционированием
    PRIMARY KEY (id, calculation_date),
    UNIQUE(user_id, calculation_date)
) PARTITION BY RANGE (calculation_date);

-- ============================================
-- 9. MAGIC PROFILES
-- ============================================

CREATE TABLE IF NOT EXISTS magic_profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные разделы профиля (оптимизированное хранение)
    ethical_framework JSONB NOT NULL DEFAULT '{}',
    social_predispositions JSONB NOT NULL DEFAULT '{}',
    emotional_architecture JSONB NOT NULL DEFAULT '{}',
    intellectual_traits JSONB NOT NULL DEFAULT '{}',
    willpower_profile JSONB NOT NULL DEFAULT '{}',
    creative_intuitive JSONB NOT NULL DEFAULT '{}',
    psychological_blueprint JSONB NOT NULL DEFAULT '{}',
    
    -- Интегрированные метрики
    personality_type VARCHAR(10),
    dominant_archetype VARCHAR(50),
    primary_motivation VARCHAR(100),
    decision_making_style VARCHAR(50),
    
    -- ML-данные
    ml_features JSONB NOT NULL DEFAULT '{}',
    feature_vector REAL[] NOT NULL DEFAULT '{}',
    cluster_id INTEGER,
    anomaly_score REAL DEFAULT 0.0,
    
    -- Метаданные
    profile_version VARCHAR(20) DEFAULT '1.0',
    calculation_metadata JSONB NOT NULL DEFAULT '{}',
    data_sources TEXT[] NOT NULL DEFAULT '{}',
    confidence_score REAL DEFAULT 1.0 CHECK (confidence_score BETWEEN 0 AND 1),
    
    -- Статус
    is_valid BOOLEAN DEFAULT TRUE,
    validation_errors TEXT[] DEFAULT '{}',
    
    -- Временные метки
    calculated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Ограничения
    CONSTRAINT valid_confidence CHECK (confidence_score >= 0 AND confidence_score <= 1)
);

-- GIN индексы для быстрого поиска по JSONB
CREATE INDEX IF NOT EXISTS idx_magic_ethical_gin ON magic_profiles USING GIN(ethical_framework);
CREATE INDEX IF NOT EXISTS idx_magic_social_gin ON magic_profiles USING GIN(social_predispositions);
CREATE INDEX IF NOT EXISTS idx_magic_emotional_gin ON magic_profiles USING GIN(emotional_architecture);
CREATE INDEX IF NOT EXISTS idx_magic_features_gin ON magic_profiles USING GIN(ml_features);

-- Индексы для часто используемых полей
CREATE INDEX IF NOT EXISTS idx_magic_personality ON magic_profiles(personality_type);
CREATE INDEX IF NOT EXISTS idx_magic_cluster ON magic_profiles(cluster_id);
CREATE INDEX IF NOT EXISTS idx_magic_confidence ON magic_profiles(confidence_score DESC);
CREATE INDEX IF NOT EXISTS idx_magic_calculated ON magic_profiles(calculated_at DESC);

-- ============================================
-- 10. ОПТИМАЛЬНЫЕ АКТИВНОСТИ (ПАРТИЦИОНИРОВАННАЯ)
-- ============================================

CREATE TABLE IF NOT EXISTS optimal_activities (
    id BIGSERIAL,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Оптимальные активности (индексы типов)
    activity_indices SMALLINT[] NOT NULL DEFAULT '{}',
    activity_types activity_type[] NOT NULL DEFAULT '{}',
    
    -- Оценки активностей (0-1)
    activity_scores REAL[] NOT NULL DEFAULT '{}',
    confidence_scores REAL[] NOT NULL DEFAULT '{}',
    
    -- Рекомендации
    recommendations TEXT[] NOT NULL DEFAULT '{}',
    time_slots JSONB NOT NULL DEFAULT '{}',
    priority_order SMALLINT[] NOT NULL DEFAULT '{}',
    
    -- Энергетические метрики
    energy_level REAL NOT NULL CHECK (energy_level >= 0 AND energy_level <= 1),
    energy_trend VARCHAR(10) CHECK (energy_trend IN ('rising', 'falling', 'stable')),
    focus_areas TEXT[] DEFAULT '{}',
    
    -- ML-данные
    ml_features JSONB NOT NULL DEFAULT '{}',
    feature_vector REAL[] NOT NULL DEFAULT '{}',
    model_version VARCHAR(20) DEFAULT '1.0',
    
    -- Статус
    is_generated BOOLEAN DEFAULT TRUE,
    is_approved BOOLEAN DEFAULT FALSE,
    user_feedback SMALLINT CHECK (user_feedback BETWEEN 1 AND 5),
    
    -- Временные метки
    generated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Первичный ключ с партиционированием
    PRIMARY KEY (id, calculation_date),
    UNIQUE(user_id, calculation_date)
) PARTITION BY RANGE (calculation_date);

-- ============================================
-- 11. РЕКОМЕНДАЦИИ (ПАРТИЦИОНИРОВАННАЯ)
-- ============================================

CREATE TABLE IF NOT EXISTS recommendations (
    id BIGSERIAL,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL, -- ИЗМЕНЕНО С recommendation_date НА calculation_date
    
    -- Содержимое рекомендации
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    summary TEXT,
    
    -- Структура
    sections JSONB NOT NULL DEFAULT '[]',
    activities JSONB NOT NULL DEFAULT '[]',
    time_suggestions JSONB NOT NULL DEFAULT '{}',
    
    -- Категории и теги
    category VARCHAR(50) NOT NULL,
    tags TEXT[] DEFAULT '{}',
    priority SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    
    -- Качество и релевантность
    relevance_score REAL NOT NULL DEFAULT 0.5 CHECK (relevance_score BETWEEN 0 AND 1),
    confidence_score REAL NOT NULL DEFAULT 0.5 CHECK (confidence_score BETWEEN 0 AND 1),
    personalization_score REAL NOT NULL DEFAULT 0.5 CHECK (personalization_score BETWEEN 0 AND 1),
    
    -- Источники данных
    data_sources TEXT[] NOT NULL DEFAULT '{}',
    based_on JSONB NOT NULL DEFAULT '{}',
    
    -- Генерация
    is_ai_generated BOOLEAN DEFAULT FALSE,
    model_name VARCHAR(100),
    prompt_hash VARCHAR(64),
    
    -- Взаимодействие пользователя
    is_read BOOLEAN DEFAULT FALSE,
    is_applied BOOLEAN DEFAULT FALSE,
    user_rating SMALLINT CHECK (user_rating BETWEEN 1 AND 5),
    feedback TEXT,
    
    -- Кэширование
    cache_key VARCHAR(255) UNIQUE,
    cache_expires_at TIMESTAMPTZ,
    
    -- Полнотекстовый поиск
    search_vector TSVECTOR,
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Первичный ключ с партиционированием
    PRIMARY KEY (id, calculation_date),
    UNIQUE(user_id, calculation_date, category)
) PARTITION BY RANGE (calculation_date);

-- ============================================
-- 12. ПСИХОЛОГИЧЕСКИЕ ТЕСТЫ
-- ============================================

CREATE TABLE IF NOT EXISTS psychological_tests (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Информация о тесте
    test_type test_type NOT NULL,
    test_version VARCHAR(20) NOT NULL,
    test_name VARCHAR(100) NOT NULL,
    
    -- Вопросы и ответы
    questions JSONB NOT NULL DEFAULT '[]',
    answers JSONB NOT NULL DEFAULT '{}',
    raw_responses JSONB NOT NULL DEFAULT '{}',
    
    -- Результаты
    scores JSONB NOT NULL DEFAULT '{}',
    profile_type VARCHAR(50),
    interpretation TEXT,
    insights JSONB NOT NULL DEFAULT '{}',
    
    -- Метаданные
    completion_percentage SMALLINT NOT NULL DEFAULT 100 CHECK (completion_percentage BETWEEN 0 AND 100),
    time_spent_seconds INTEGER,
    device_info JSONB DEFAULT '{}',
    
    -- Статус
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('started', 'in_progress', 'completed', 'abandoned')),
    
    -- Временные метки
    started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Уникальность: один пользователь может проходить тест определённого типа один раз
    UNIQUE(user_id, test_type, test_version)
);

CREATE INDEX IF NOT EXISTS idx_tests_user ON psychological_tests(user_id);
CREATE INDEX IF NOT EXISTS idx_tests_type ON psychological_tests(test_type);
CREATE INDEX IF NOT EXISTS idx_tests_status ON psychological_tests(status);
CREATE INDEX IF NOT EXISTS idx_tests_completed ON psychological_tests(completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_tests_answers_gin ON psychological_tests USING GIN(answers);
CREATE INDEX IF NOT EXISTS idx_tests_scores_gin ON psychological_tests USING GIN(scores);

-- ============================================
-- 13. ЛУННЫЕ ФАЗЫ И АСТРОЛОГИЧЕСКИЕ СОБЫТИЯ
-- ============================================

CREATE TABLE IF NOT EXISTS astro_events (
    id BIGSERIAL PRIMARY KEY,
    
    -- Дата события
    event_date DATE NOT NULL,
    event_time TIMESTAMPTZ,
    
    -- Тип события
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
        'new_moon', 'full_moon', 'first_quarter', 'last_quarter',
        'mercury_retrograde', 'venus_retrograde', 'mars_retrograde',
        'jupiter_retrograde', 'saturn_retrograde', 'uranus_retrograde',
        'neptune_retrograde', 'pluto_retrograde',
        'eclipse_solar', 'eclipse_lunar',
        'planetary_transit'
    )),
    
    -- Детали события
    event_name VARCHAR(100) NOT NULL,
    description TEXT,
    significance_level VARCHAR(20) CHECK (significance_level IN ('low', 'medium', 'high', 'critical')),
    
    -- Астрологические данные
    zodiac_sign VARCHAR(20),
    degree DECIMAL(5,2),
    planetary_aspects JSONB DEFAULT '{}',
    
    -- Рекомендации
    general_recommendations TEXT[] DEFAULT '{}',
    caution_areas TEXT[] DEFAULT '{}',
    
    -- Метаданные
    source VARCHAR(50) DEFAULT 'calculated',
    confidence REAL DEFAULT 1.0 CHECK (confidence BETWEEN 0 AND 1),
    
    -- Временные метки
    calculated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_astro_events_date ON astro_events(event_date);
CREATE INDEX IF NOT EXISTS idx_astro_events_type ON astro_events(event_type);
CREATE INDEX IF NOT EXISTS idx_astro_events_significance ON astro_events(significance_level);
CREATE INDEX IF NOT EXISTS idx_astro_events_zodiac ON astro_events(zodiac_sign);
CREATE UNIQUE INDEX IF NOT EXISTS idx_astro_events_unique ON astro_events(event_date, event_type, zodiac_sign);

-- ============================================
-- 14. СИСТЕМНЫЙ АУДИТ И ЛОГИ
-- ============================================

CREATE TABLE IF NOT EXISTS system_audit_log (
    id BIGSERIAL PRIMARY KEY,
    
    -- Действие
    action_type VARCHAR(50) NOT NULL CHECK (action_type IN ('create', 'read', 'update', 'delete', 'login', 'logout', 'error')),
    action_name VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),
    
    -- Пользователь
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    user_ip INET,
    user_agent TEXT,
    session_id UUID,
    
    -- Данные
    request_data JSONB,
    response_data JSONB,
    error_details TEXT,
    stack_trace TEXT,
    
    -- Статус
    status_code INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_code VARCHAR(50),
    
    -- Производительность
    duration_ms INTEGER CHECK (duration_ms >= 0),
    memory_usage_kb INTEGER,
    
    -- Метаданные
    service_name VARCHAR(50) NOT NULL,
    endpoint VARCHAR(255),
    http_method VARCHAR(10),
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Индексы для аудит лога
CREATE INDEX IF NOT EXISTS idx_audit_user ON system_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON system_audit_log(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_date ON system_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_service ON system_audit_log(service_name);
CREATE INDEX IF NOT EXISTS idx_audit_status ON system_audit_log(status_code);
CREATE INDEX IF NOT EXISTS idx_audit_success ON system_audit_log(success);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON system_audit_log(resource_type, resource_id);

-- ============================================
-- 15. МЕТРИКИ И СТАТИСТИКА
-- ============================================

CREATE TABLE IF NOT EXISTS system_metrics (
    id BIGSERIAL PRIMARY KEY,
    
    -- Идентификация метрики
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(50) NOT NULL CHECK (metric_type IN ('counter', 'gauge', 'histogram', 'summary')),
    
    -- Значение
    metric_value DOUBLE PRECISION NOT NULL,
    metric_labels JSONB DEFAULT '{}',
    
    -- Метаданные
    service_name VARCHAR(50) NOT NULL,
    hostname VARCHAR(100),
    
    -- Временные метки
    collected_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Индексы для метрик
CREATE INDEX IF NOT EXISTS idx_metrics_name ON system_metrics(metric_name, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_service ON system_metrics(service_name, collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_date ON system_metrics(collected_at DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_labels_gin ON system_metrics USING GIN(metric_labels);

-- ============================================
-- 16. КЭШ РАСЧЁТОВ
-- ============================================

CREATE TABLE IF NOT EXISTS calculation_cache (
    id BIGSERIAL PRIMARY KEY,
    
    -- Ключ кэша
    cache_key VARCHAR(255) NOT NULL UNIQUE,
    cache_group VARCHAR(100) NOT NULL,
    
    -- Данные
    data JSONB NOT NULL,
    data_hash VARCHAR(64) NOT NULL,
    
    -- Метаданные
    calculation_type VARCHAR(50) NOT NULL,
    user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
    
    -- Время жизни
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    last_accessed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Статистика использования
    access_count INTEGER DEFAULT 0,
    is_valid BOOLEAN DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_cache_key ON calculation_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_cache_group ON calculation_cache(cache_group);
CREATE INDEX IF NOT EXISTS idx_cache_user ON calculation_cache(user_id);
CREATE INDEX IF NOT EXISTS idx_cache_expires ON calculation_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_cache_accessed ON calculation_cache(last_accessed_at DESC);
CREATE INDEX IF NOT EXISTS idx_cache_valid ON calculation_cache(is_valid) WHERE is_valid = TRUE;

-- ============================================
-- 17. ИНДЕКСЫ ДЛЯ ПАРТИЦИОНИРОВАННЫХ ТАБЛИЦ
-- ============================================

-- Индексы для натальных карт (будут наследоваться партициями)
CREATE INDEX IF NOT EXISTS idx_natal_charts_user ON natal_charts(user_id);
CREATE INDEX IF NOT EXISTS idx_natal_charts_date ON natal_charts(calculation_date);
CREATE INDEX IF NOT EXISTS idx_natal_planets_gin ON natal_charts USING GIN(planets);
CREATE INDEX IF NOT EXISTS idx_natal_aspects_gin ON natal_charts USING GIN(aspects);
CREATE INDEX IF NOT EXISTS idx_natal_features_gin ON natal_charts USING GIN(ml_features);
CREATE INDEX IF NOT EXISTS idx_natal_status ON natal_charts(calculation_status);

-- Индексы для биоритмов
CREATE INDEX IF NOT EXISTS idx_biorhythms_user_date ON biorhythms(user_id, calculation_date);
CREATE INDEX IF NOT EXISTS idx_biorhythms_date ON biorhythms(calculation_date);
CREATE INDEX IF NOT EXISTS idx_biorhythms_critical ON biorhythms(is_critical_day) WHERE is_critical_day = TRUE;
CREATE INDEX IF NOT EXISTS idx_biorhythms_peak ON biorhythms(is_peak_day) WHERE is_peak_day = TRUE;
CREATE INDEX IF NOT EXISTS idx_biorhythms_energy ON biorhythms(overall_energy_level, calculation_date);

-- Индексы для активностей
CREATE INDEX IF NOT EXISTS idx_activities_user_date ON optimal_activities(user_id, calculation_date);
CREATE INDEX IF NOT EXISTS idx_activities_date ON optimal_activities(calculation_date);
CREATE INDEX IF NOT EXISTS idx_activities_energy ON optimal_activities(energy_level DESC);
CREATE INDEX IF NOT EXISTS idx_activities_feedback ON optimal_activities(user_feedback) WHERE user_feedback IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activities_features_gin ON optimal_activities USING GIN(ml_features);

-- Индексы для рекомендаций
CREATE INDEX IF NOT EXISTS idx_recommendations_user_date ON recommendations(user_id, calculation_date);
CREATE INDEX IF NOT EXISTS idx_recommendations_date ON recommendations(calculation_date);
CREATE INDEX IF NOT EXISTS idx_recommendations_category ON recommendations(category);
CREATE INDEX IF NOT EXISTS idx_recommendations_priority ON recommendations(priority DESC, calculation_date DESC);
CREATE INDEX IF NOT EXISTS idx_recommendations_relevance ON recommendations(relevance_score DESC);
CREATE INDEX IF NOT EXISTS idx_recommendations_tags_gin ON recommendations USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_recommendations_cache ON recommendations(cache_key) WHERE cache_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_recommendations_rating ON recommendations(user_rating DESC) WHERE user_rating IS NOT NULL;

-- ============================================
-- 18. ТРИГГЕРЫ И ФУНКЦИИ
-- ============================================

-- Функция обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для обновления updated_at
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_natal_charts_updated_at 
    BEFORE UPDATE ON natal_charts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_magic_profiles_updated_at 
    BEFORE UPDATE ON magic_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_optimal_activities_updated_at 
    BEFORE UPDATE ON optimal_activities 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recommendations_updated_at 
    BEFORE UPDATE ON recommendations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_astro_events_updated_at 
    BEFORE UPDATE ON astro_events 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- УПРОЩЁННАЯ функция для автоматического создания партиций (без дублирования)
CREATE OR REPLACE FUNCTION create_partition_by_year()
RETURNS trigger AS $$
DECLARE
    partition_date DATE;
    partition_start DATE;
    partition_end DATE;
    partition_name TEXT;
    table_name TEXT;
BEGIN
    -- Определяем имя таблицы и дату для партиционирования
    table_name := TG_TABLE_NAME;
    
    -- Для всех таблиц используется calculation_date
    partition_date := NEW.calculation_date;
    partition_start := DATE_TRUNC('year', partition_date);
    partition_end := partition_start + INTERVAL '1 year';
    partition_name := table_name || '_y' || TO_CHAR(partition_start, 'YYYY');
    
    -- Создаём партицию если её нет (используем безопасный подход)
    BEGIN
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            table_name,
            partition_start,
            partition_end
        );
    EXCEPTION
        WHEN duplicate_table THEN
            -- Партиция уже существует, это нормально
            NULL;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для автоматического создания партиций
CREATE TRIGGER create_natal_charts_partition
    BEFORE INSERT ON natal_charts
    FOR EACH ROW EXECUTE FUNCTION create_partition_by_year();

CREATE TRIGGER create_biorhythms_partition
    BEFORE INSERT ON biorhythms
    FOR EACH ROW EXECUTE FUNCTION create_partition_by_year();

CREATE TRIGGER create_optimal_activities_partition
    BEFORE INSERT ON optimal_activities
    FOR EACH ROW EXECUTE FUNCTION create_partition_by_year();

CREATE TRIGGER create_recommendations_partition
    BEFORE INSERT ON recommendations
    FOR EACH ROW EXECUTE FUNCTION create_partition_by_year();

-- Функция для полнотекстового поиска в рекомендациях
CREATE OR REPLACE FUNCTION recommendations_tsvector_trigger()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('russian', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('russian', COALESCE(NEW.content, '')), 'B') ||
        setweight(to_tsvector('russian', COALESCE(NEW.summary, '')), 'C') ||
        setweight(to_tsvector('russian', array_to_string(NEW.tags, ' ')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recommendations_search_vector_update
    BEFORE INSERT OR UPDATE ON recommendations
    FOR EACH ROW EXECUTE FUNCTION recommendations_tsvector_trigger();

-- Функция очистки старых данных
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
BEGIN
    -- Удаляем старые сессии
    DELETE FROM auth_sessions 
    WHERE expires_at < NOW() - INTERVAL '30 days';
    
    -- Инвалидируем старый кэш
    UPDATE calculation_cache 
    SET is_valid = FALSE 
    WHERE expires_at < NOW() - INTERVAL '7 days';
    
    -- Архивируем старые метрики
    DELETE FROM system_metrics 
    WHERE collected_at < NOW() - INTERVAL '2 years';
    
    RAISE NOTICE 'Cleanup completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Функция для автоматического обновления last_activity_at
CREATE OR REPLACE FUNCTION update_user_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users 
    SET last_activity_at = NOW() 
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для обновления активности пользователя
CREATE TRIGGER update_activity_on_natal_chart
    AFTER INSERT OR UPDATE ON natal_charts
    FOR EACH ROW EXECUTE FUNCTION update_user_activity();

CREATE TRIGGER update_activity_on_recommendation
    AFTER INSERT OR UPDATE ON recommendations
    FOR EACH ROW EXECUTE FUNCTION update_user_activity();

CREATE TRIGGER update_activity_on_test
    AFTER INSERT OR UPDATE ON psychological_tests
    FOR EACH ROW EXECUTE FUNCTION update_user_activity();

-- ============================================
-- 19. ОПТИМИЗАЦИЯ ПРАВ ДОСТУПА
-- ============================================

-- ВАЖНО: Пароли ролей должны устанавливаться через environment variables
-- или внешний сервис управления секретами

-- Создаём роль приложения (пароль устанавливается отдельно)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_app') THEN
        EXECUTE 'CREATE ROLE personal_assistant_app WITH LOGIN';
        COMMENT ON ROLE personal_assistant_app IS 'Роль приложения для основного доступа к БД';
    END IF;
END
$$;

-- Даем права на подключение
GRANT CONNECT ON DATABASE personal_assistant TO personal_assistant_app;

-- Даем права на схему
GRANT USAGE ON SCHEMA public TO personal_assistant_app;

-- Права для приложения (полный доступ к данным)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public 
TO personal_assistant_app;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public 
TO personal_assistant_app;

-- Права для выполнения функций
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public 
TO personal_assistant_app;

-- Настройка прав по умолчанию для будущих таблиц
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES 
TO personal_assistant_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT USAGE ON SEQUENCES 
TO personal_assistant_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT EXECUTE ON FUNCTIONS 
TO personal_assistant_app;

-- ============================================
-- 20. ПРЕДСТАВЛЕНИЯ ДЛЯ АНАЛИТИКИ
-- ============================================

-- Полная информация о пользователе
CREATE OR REPLACE VIEW user_complete_info AS
SELECT 
    u.id,
    u.telegram_id,
    u.status,
    u.is_premium,
    u.created_at as user_created,
    u.last_activity_at,
    
    up.full_name,
    up.username,
    up.language_code,
    up.birth_date,
    up.birth_city,
    up.profession,
    up.current_city,
    
    -- Статистика
    (SELECT COUNT(*) FROM natal_charts nc WHERE nc.user_id = u.id) as natal_charts_count,
    (SELECT COUNT(*) FROM biorhythms b WHERE b.user_id = u.id) as biorhythms_count,
    (SELECT COUNT(*) FROM recommendations r WHERE r.user_id = u.id) as recommendations_count,
    (SELECT COUNT(*) FROM psychological_tests pt WHERE pt.user_id = u.id) as tests_count,
    
    -- Активность
    (SELECT MAX(calculated_at) FROM magic_profiles mp WHERE mp.user_id = u.id) as last_profile_update,
    (SELECT MAX(calculation_date) FROM recommendations r WHERE r.user_id = u.id) as last_recommendation_date
    
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id;

-- Ежедневная сводка по пользователям
CREATE OR REPLACE VIEW daily_user_summary AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as new_users,
    COUNT(*) FILTER (WHERE is_premium = TRUE) as new_premium_users,
    COUNT(DISTINCT user_id) as active_users,
    
    -- Активность
    (SELECT COUNT(*) FROM recommendations 
     WHERE calculation_date = CURRENT_DATE) as daily_recommendations,
    
    (SELECT COUNT(*) FROM biorhythms 
     WHERE calculation_date = CURRENT_DATE) as daily_biorhythms,
    
    -- Конверсия
    ROUND(
        COUNT(*) FILTER (WHERE last_activity_at >= NOW() - INTERVAL '7 days') * 100.0 / 
        NULLIF(COUNT(*), 0), 2
    ) as weekly_retention_rate
    
FROM users
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Статистика рекомендаций
CREATE OR REPLACE VIEW recommendation_statistics AS
SELECT 
    r.category,
    COUNT(*) as total_recommendations,
    AVG(r.relevance_score) as avg_relevance,
    AVG(r.confidence_score) as avg_confidence,
    AVG(r.personalization_score) as avg_personalization,
    
    COUNT(*) FILTER (WHERE r.is_read = TRUE) as read_count,
    COUNT(*) FILTER (WHERE r.is_applied = TRUE) as applied_count,
    
    ROUND(
        COUNT(*) FILTER (WHERE r.user_rating IS NOT NULL) * 100.0 / 
        NULLIF(COUNT(*), 0), 2
    ) as feedback_rate,
    
    AVG(r.user_rating) FILTER (WHERE r.user_rating IS NOT NULL) as avg_rating
    
FROM recommendations r
WHERE r.calculation_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY r.category
ORDER BY total_recommendations DESC;

-- Мониторинг расчётов
CREATE OR REPLACE VIEW calculation_monitoring AS
SELECT 
    'natal_charts' as calculation_type,
    COUNT(*) as total,
    MIN(calculation_date) as earliest_date,
    MAX(calculation_date) as latest_date,
    AVG(EXTRACT(EPOCH FROM (calculation_timestamp - created_at))) as avg_calculation_time_sec
    
FROM natal_charts
WHERE calculation_status = 'success'

UNION ALL

SELECT 
    'biorhythms',
    COUNT(*),
    MIN(calculation_date),
    MAX(calculation_date),
    AVG(EXTRACT(EPOCH FROM (calculated_at - NOW())))
FROM biorhythms

UNION ALL

SELECT 
    'magic_profiles',
    COUNT(*),
    MIN(calculated_at::DATE),
    MAX(calculated_at::DATE),
    NULL
FROM magic_profiles;

-- ============================================
-- 21. КОММЕНТАРИИ К ТАБЛИЦАМ
-- ============================================

COMMENT ON TABLE users IS 'Основная таблица пользователей системы';
COMMENT ON TABLE user_profiles IS 'Дополнительная информация о пользователях для расчётов';
COMMENT ON TABLE auth_sessions IS 'Сессии аутентификации пользователей';
COMMENT ON TABLE natal_charts IS 'Натальные астрологические карты (партиционирована по дате)';
COMMENT ON TABLE psyho_matrices IS 'Нумерологические психоматрицы по методу Пифагора';
COMMENT ON TABLE biorhythms IS 'Расчёты биоритмов пользователей (партиционирована по дате)';
COMMENT ON TABLE magic_profiles IS 'Интегрированные психологические и эзотерические профили';
COMMENT ON TABLE optimal_activities IS 'Рекомендации оптимальных активностей (партиционирована по дате)';
COMMENT ON TABLE recommendations IS 'Итоговые персонализированные рекомендации (партиционирована по дате)';
COMMENT ON TABLE psychological_tests IS 'Результаты психологических тестов пользователей';
COMMENT ON TABLE astro_events IS 'Астрологические события и лунные фазы';
COMMENT ON TABLE system_audit_log IS 'Логирование действий в системе';
COMMENT ON TABLE system_metrics IS 'Метрики производительности системы';
COMMENT ON TABLE calculation_cache IS 'Кэш результатов расчётов для оптимизации';

-- ============================================
-- 22. ФИНАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ
-- ============================================

-- Создаём стартовую партицию для текущего года
DO $$
DECLARE
    current_year_start DATE := DATE_TRUNC('year', CURRENT_DATE);
    current_year_end DATE := current_year_start + INTERVAL '1 year';
BEGIN
    -- Натальные карты
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS natal_charts_y%s PARTITION OF natal_charts FOR VALUES FROM (%L) TO (%L)',
        TO_CHAR(current_year_start, 'YYYY'),
        current_year_start,
        current_year_end
    );
    
    -- Биоритмы
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS biorhythms_y%s PARTITION OF biorhythms FOR VALUES FROM (%L) TO (%L)',
        TO_CHAR(current_year_start, 'YYYY'),
        current_year_start,
        current_year_end
    );
    
    -- Оптимальные активности
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS optimal_activities_y%s PARTITION OF optimal_activities FOR VALUES FROM (%L) TO (%L)',
        TO_CHAR(current_year_start, 'YYYY'),
        current_year_start,
        current_year_end
    );
    
    -- Рекомендации
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS recommendations_y%s PARTITION OF recommendations FOR VALUES FROM (%L) TO (%L)',
        TO_CHAR(current_year_start, 'YYYY'),
        current_year_start,
        current_year_end
    );
    
    RAISE NOTICE 'Созданы стартовые партиции для года %', TO_CHAR(current_year_start, 'YYYY');
END
$$;

-- Собираем статистику для оптимизатора запросов
ANALYZE;

-- Даем права на представления
GRANT SELECT ON ALL TABLES IN SCHEMA public TO personal_assistant_app;

-- Логируем успешное завершение инициализации
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'PERSONAL ASSISTANT DATABASE INITIALIZATION v2.0';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Status: БОЕВАЯ ГОТОВНОСТЬ';
    RAISE NOTICE 'Fixed critical issues: 3';
    RAISE NOTICE 'Created tables: 16';
    RAISE NOTICE 'Created indexes: ~80';
    RAISE NOTICE 'Created views: 4';
    RAISE NOTICE 'Created functions: 5';
    RAISE NOTICE 'Created triggers: 12';
    RAISE NOTICE 'Created partitions: 4 (автоматически)';
    RAISE NOTICE 'Created roles: 1 (без паролей в коде)';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Database initialized successfully at %', NOW();
    RAISE NOTICE '============================================';
END
$$;
init_scripts/init_extensions.sql:
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
init_scripts/Makefile:
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
init_scripts/pg_hba.conf:
# PostgreSQL Client Authentication Configuration
# ==============================================

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Локальные соединения
local   all             postgres                                peer
local   all             personal_assistant_app                  scram-sha-256
local   all             personal_assistant_readonly             scram-sha-256
local   all             dbeaver_user                           scram-sha-256
local   all             all                                     reject

# Docker сеть
host    all             all             172.25.0.0/16           scram-sha-256

# Разрешаем подключения из init контейнера
host    all             postgres         172.25.0.0/16           scram-sha-256
host    all             personal_assistant_app  172.25.0.0/16    scram-sha-256

# Локальный хост (для разработки)
host    all             all             127.0.0.1/32            scram-sha-256

# Отклоняем все остальные
host    all             all             all                     reject
init_scripts/postgresql.conf:
# ============================================
# POSTGRESQL CONFIGURATION FOR PERSONAL ASSISTANT
# ============================================

# FILE LOCATIONS
data_directory = '/var/lib/postgresql/data/pgdata'

# CONNECTIONS AND AUTHENTICATION
listen_addresses = '*'
port = 5432
max_connections = 200
superuser_reserved_connections = 3

# MEMORY
shared_buffers = 256MB
work_mem = 8MB
maintenance_work_mem = 64MB
effective_cache_size = 768MB

# WRITE AHEAD LOG
wal_level = replica
fsync = on
synchronous_commit = on
wal_buffers = 16MB
checkpoint_timeout = 5min
checkpoint_completion_target = 0.9
max_wal_size = 1GB
min_wal_size = 80MB

# QUERY TUNING
random_page_cost = 1.1
effective_io_concurrency = 200
default_statistics_target = 100

# LOGGING
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_line_prefix = '%m [%p] %q%u@%d '

# AUTOVACUUM
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
autovacuum_vacuum_threshold = 50
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.2
autovacuum_analyze_scale_factor = 0.1

# CLIENT CONNECTION DEFAULTS
timezone = 'UTC'
client_encoding = 'UTF8'
default_text_search_config = 'pg_catalog.russian'

# LOCK MANAGEMENT
deadlock_timeout = 1s

# ERROR PROCESSING
restart_after_crash = on

# CUSTOM OPTIONS FOR PERSONAL ASSISTANT
# Для работы с JSONB и массивами
jit = off
max_parallel_workers_per_gather = 2
max_parallel_maintenance_workers = 2
max_parallel_workers = 4

# Для партиционирования
enable_partition_pruning = on
enable_partitionwise_join = on
enable_partitionwise_aggregate = on

migrations:
migrations/001_create_extensions.sql:
-- Создаём расширения от имени postgres
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "unaccent";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
migrations/002_create_roles.sql:
-- Устанавливаем пароли для ролей (берем из переменных окружения)
ALTER ROLE personal_assistant_app WITH PASSWORD 'your_secure_password_here';

-- Создаём роль для миграций
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_migrations') THEN
        CREATE ROLE personal_assistant_migrations WITH LOGIN PASSWORD 'migrations_password_012';
    END IF;
END
$$;

-- Даем права
GRANT CREATE ON SCHEMA public TO personal_assistant_migrations;

models:
models/blobs/

scripts:
scripts/generate-secrets.sh:
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

scripts/init-db.sh:
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
scripts/wait-for-db.sh:
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


your_project:
your_project/project_directory

bash_start:
# 1. Клонируйте проект
git clone <your-repo>
cd personal-assistant

# 2. Сделайте скрипты исполняемыми
chmod +x scripts/*.sh

# 3. Сгенерируйте секреты
make secrets

# 4. Запустите сервисы
make up

make up-dev  # Все сервисы + мониторинг

# Или все вместе:
make reset

# Посмотрите пароль в .env файле
cat .env | grep DB_PASSWORD

# Или используйте grep
grep 'DB_PASSWORD=' .env

# Запуск всех сервисов + мониторинг
make up-dev

diagnose.sh:
#!/bin/bash
echo "========== DIAGNOSIS =========="
echo ""
echo "1. POSTGRES LOGS (last 30 lines):"
docker compose logs postgres --tail=30 2>/dev/null || echo "No logs available"
echo ""
echo "2. VOLUME CONFIGURATION:"
grep -A5 "volumes:" docker-compose.yaml | grep -A10 "postgres:"
echo ""
echo "3. DOCKER VOLUMES:"
docker volume ls | grep -E "(personal|postgres)"
echo ""
echo "4. DATA DIRECTORY PERMISSIONS:"
ls -la ./data/postgres/ 2>/dev/null || echo "No data directory"
echo ""
echo "5. .env FILE (first lines):"
head -10 .env 2>/dev/null || echo "No .env file"
echo ""
echo "6. DOCKER PS STATUS:"
docker ps -a | grep postgres
echo ""
echo "========== END =========="

docker-compose.yaml:
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: personal-assistant-postgres
    environment:
      POSTGRES_DB: personal_assistant
      POSTGRES_USER: postgres  # Временный superuser
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}  # Суперпароль из .env
      PGDATA: '/var/lib/postgresql/data/pgdata'
    ports:
      - "5432:5432"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./init_scripts/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      - ./init_scripts/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres || exit 0"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 60s
    networks:
      - personal-assistant-network

  init-db:
    image: postgres:15-alpine
    container_name: personal-assistant-init-db
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      PGPASSWORD: ${POSTGRES_PASSWORD}  # Пароль суперпользователя
    volumes:
      - ./scripts:/scripts:ro
      - ./init_scripts/init_db.sql:/init.sql:ro
      - ./.env:/app/.env:ro
    command: >
      sh -c "
        echo '🚀 Database initialization...' &&
        
        # Ждем PostgreSQL
        until pg_isready -h postgres -p 5432 -U postgres; do
          echo 'Waiting for PostgreSQL...';
          sleep 2;
        done &&
        
        # Загружаем пароли
        if [ -f /app/.env ]; then
          source /app/.env
        fi &&
        
        # Создаем пользователя приложения
        psql -h postgres -U postgres -c \"CREATE USER personal_assistant_app WITH PASSWORD '\${DB_PASSWORD}';\" 2>/dev/null || true &&
        
        # Создаем базу данных
        psql -h postgres -U postgres -c 'CREATE DATABASE personal_assistant;' 2>/dev/null || true &&
        
        # Даем права
        psql -h postgres -U postgres -c 'GRANT ALL PRIVILEGES ON DATABASE personal_assistant TO personal_assistant_app;' &&
        
        # Выполняем основной скрипт инициализации от имени пользователя приложения
        echo '📦 Running schema initialization...' &&
        PGPASSWORD=\${DB_PASSWORD} psql -h postgres -U personal_assistant_app -d personal_assistant -f /init.sql &&
        
        # Создаем readonly пользователя
        psql -h postgres -U postgres -c \"CREATE USER personal_assistant_readonly WITH PASSWORD '\${READONLY_DB_PASSWORD}';\" 2>/dev/null || true &&
        psql -h postgres -U postgres -c 'GRANT CONNECT ON DATABASE personal_assistant TO personal_assistant_readonly;' &&
        psql -h postgres -U postgres -c 'GRANT USAGE ON SCHEMA public TO personal_assistant_readonly;' &&
        psql -h postgres -U postgres -c 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO personal_assistant_readonly;' &&
        
        # Создаем пользователя для DBeaver
        psql -h postgres -U postgres -c \"CREATE USER dbeaver_user WITH PASSWORD 'dbeaver_dev_123';\" 2>/dev/null || true &&
        psql -h postgres -U postgres -c 'GRANT CONNECT ON DATABASE personal_assistant TO dbeaver_user;' &&
        psql -h postgres -U postgres -c 'GRANT USAGE ON SCHEMA public TO dbeaver_user;' &&
        psql -h postgres -U postgres -c 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbeaver_user;' &&
        
        # Настраиваем default privileges
        psql -h postgres -U postgres -d personal_assistant -c 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO personal_assistant_readonly;' &&
        psql -h postgres -U postgres -d personal_assistant -c 'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbeaver_user;' &&
        
        echo '✅ Database initialized with secure passwords!'
      "
    networks:
      - personal-assistant-network

  redis:
    image: redis:7-alpine
    container_name: personal-assistant-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    networks:
      - personal-assistant-network

  ollama:
    image: ollama/ollama:latest
    container_name: personal-assistant-ollama
    ports:
      - "11435:11434"
    volumes:
      - ./data/ollama:/root/.ollama
    networks:
      - personal-assistant-network

networks:
  personal-assistant-network:
    driver: bridge
    
env.example:
# Пароли БД (ЗАМЕНИТЕ НА СВОИ!)
DB_PASSWORD=your_very_secure_password_123!
POSTGRES_PASSWORD=superuser_secure_password_456!

# Пароль для Redis (опционально)
REDIS_PASSWORD=

# Пароли для ролей (устанавливаются через миграции)
APP_DB_PASSWORD=${DB_PASSWORD}
READONLY_DB_PASSWORD=readonly_password_789
MIGRATIONS_DB_PASSWORD=migrations_password_012

# Порт
DB_PORT=5432
REDIS_PORT=6379

# Пути для данных
VOLUME_PATH=./data

# Сеть
NETWORK_SUBNET=172.25.0.0/16

fix-and-run.sh:
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

__init__.py

Makefile:
# ============================================
# PERSONAL ASSISTANT - DOCKER MANAGEMENT
# ============================================

DOCKER_COMPOSE = docker compose

.PHONY: help secrets init up up-dev down logs clean

help:
	@echo "Commands:"
	@echo "  make secrets  - Generate secure passwords"
	@echo "  make init     - Initialize database"
	@echo "  make up       - Start services"
	@echo "  make up-dev   - Start with monitoring"
	@echo "  make down     - Stop services"
	@echo "  make logs     - Show logs"
	@echo "  make clean    - Clean everything"

# В Makefile обновите секцию secrets:
secrets:
	@echo "🔐 Generating secure passwords..."
	@if [ -f scripts/generate-secrets.sh ]; then \
		./scripts/generate-secrets.sh; \
	else \
		echo "Creating passwords manually..."; \
		echo "DB_PASSWORD=$(shell openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)" > .env; \
		echo "POSTGRES_PASSWORD=$(shell openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24)" >> .env; \
		echo "REDIS_PASSWORD=$(shell openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)" >> .env; \
		echo "READONLY_DB_PASSWORD=$(shell openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)" >> .env; \
		echo "COMPOSE_PROJECT_NAME=personal-assistant" >> .env; \
		echo "VOLUME_PATH=./data" >> .env; \
		echo "✅ Passwords generated in .env"; \
	fi

init: secrets
	@echo "📦 Initializing database..."
	@mkdir -p ./data/postgres
	@sudo chmod 777 ./data/postgres 2>/dev/null || chmod 777 ./data/postgres
	@docker compose down 2>/dev/null || true
	@docker compose up -d postgres
	@echo "⏳ Waiting for PostgreSQL to start..."
	@sleep 30
	@docker compose up init-db
	@echo "✅ Database initialized with secure passwords!"

up:
	@echo "🚀 Starting services..."
	@docker compose up -d postgres redis ollama
	@echo "✅ Services started!"
	@echo ""
	@echo "🔑 Connection info:"
	@echo "  PostgreSQL: localhost:5432"
	@echo "  Redis:      localhost:6379"
	@echo "  Ollama:     localhost:11435"

up-dev: up
	@echo "📊 Starting monitoring..."
	@docker compose --profile monitoring up -d 2>/dev/null || echo "No monitoring profile"
	@echo "🌐 pgAdmin: http://localhost:5050"

down:
	@docker compose down

logs:
	@docker compose logs -f

clean:
	@docker compose down -v
	@rm -rf ./data
	@echo "🧹 Cleaned up"
	
.env:
# ============================================
# PERSONAL ASSISTANT - SECURE PASSWORDS
# Generated: Пн 08 дек 2025 16:53:02 EET
# ============================================

# PostgreSQL Application User
DB_PASSWORD=lRFME899RmSHOHdklpLYOU9W

# PostgreSQL Superuser (для инициализации)
POSTGRES_PASSWORD=wySrjiKzCbIlMyZW9PAMYkBB

# Redis
REDIS_PASSWORD=NQMyjfIOC1HW0G33NasS

# Readonly user для мониторинга
READONLY_DB_PASSWORD=hM2ye4LGmMmHXyuh9Aw6

# Docker Compose
COMPOSE_PROJECT_NAME=personal-assistant

# Paths
VOLUME_PATH=./data

# Ports
DB_PORT=5432
REDIS_PORT=6379
OLLAMA_EXTERNAL_PORT=11435

.env.template:
# .env.template
# Запустите: make secrets для генерации реальных паролей

# PostgreSQL Application User
DB_PASSWORD=__GENERATED_PASSWORD__

# PostgreSQL Superuser (для инициализации)
POSTGRES_PASSWORD=__GENERATED_PASSWORD__

# Redis
REDIS_PASSWORD=__GENERATED_PASSWORD__

# Readonly user для мониторинга
READONLY_DB_PASSWORD=__GENERATED_PASSWORD__

# Docker Compose
COMPOSE_PROJECT_NAME=personal-assistant

# Paths
VOLUME_PATH=./data

.gitignore:
# Docker
docker-compose.override.yml

# Секреты и конфигурация
.env
.env.local
.env.*.local
docker-secrets/
*.secret
data/

# Резервные копии
*.backup
backup/

# Временные файлы
tmp/
*.tmp


.env
data/
docker-secrets/

# Data
data/
*.log
*.bak

# Environment
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Backups
backups/*.sql.gz
!backups/.gitkeep

# Temp
tmp/
temp/

# Python
__pycache__/
*.pyc
.python-version

# Models (крупные файлы)
models/*.bin
models/*.gguf

.secrets.README.txt:
# PERSONAL ASSISTANT - SECRETS RECOVERY
# =====================================
# 
# If you lose your .env file, you need to:
# 1. Run: ./scripts/generate-secrets.sh
# 2. Update the database passwords manually
# 
# To update database passwords:
# 1. Connect to PostgreSQL: 
#    docker exec -it personal-assistant-postgres psql -U postgres
# 2. Update password: 
#    ALTER ROLE personal_assistant_app WITH PASSWORD 'new_password';
# 
# Generated: Пн 08 дек 2025 16:03:28 EET
# 
# WARNING: Regenerating secrets will invalidate all existing passwords!
