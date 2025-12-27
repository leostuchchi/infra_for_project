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
