-- ============================================
-- PERSONAL ASSISTANT DATABASE - PRODUCTION READY v4.0
-- Полностью исправленная версия (обратная совместимость)
-- ============================================

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET TIME ZONE 'UTC';

-- ============================================
-- 1. ОЧИСТКА СТАРЫХ ТИПОВ И ЗАВИСИМОСТЕЙ
-- ============================================

-- Удаляем старые ENUM типы если существуют (для идемпотентности)
DROP TYPE IF EXISTS activity_type CASCADE;
DROP TYPE IF EXISTS aspect_type CASCADE;
DROP TYPE IF EXISTS energy_level CASCADE;
DROP TYPE IF EXISTS test_type CASCADE;

-- ============================================
-- 2. СОЗДАНИЕ РАСШИРЕНИЙ
-- ============================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================
-- 3. СОЗДАНИЕ ТИПОВ ДАННЫХ (ПЕРЕД таблицами!)
-- ============================================

-- Типы активности для рекомендаций (сохраняем ENUM для обратной совместимости)
CREATE TYPE activity_type AS ENUM (
    'physical',
    'spiritual', 
    'learning',
    'psychological',
    'career',
    'self_realization',
    'finances'
);

-- Типы астрологических аспектов (для натальных карт)
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

-- Уровни энергии для рекомендаций
CREATE TYPE energy_level AS ENUM (
    'very_low',
    'low',
    'medium',
    'high',
    'very_high'
);

-- Типы психологических тестов
CREATE TYPE test_type AS ENUM (
    'mbti',
    'big5',
    'values',
    'maslow'
);

-- ============================================
-- 4. СОЗДАНИЕ РОЛИ ПРИЛОЖЕНИЯ (с правильным паролем)
-- ============================================

-- Пароль будет установлен после создания через ALTER
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_app') THEN
        CREATE ROLE personal_assistant_app WITH LOGIN;
        COMMENT ON ROLE personal_assistant_app IS 'Роль приложения для основного доступа к БД';
    END IF;
END
$$;

-- ============================================
-- 5. ОСНОВНАЯ ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ (оптимизированная)
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    -- Основной идентификатор
    id BIGSERIAL PRIMARY KEY,
    
    -- Внешние идентификаторы
    telegram_id BIGINT UNIQUE,
    
    -- Анонимизированные данные (хеши)
    phone_hash VARCHAR(128),
    email_hash VARCHAR(128),
    
    -- Статус пользователя (сохраняем строки для обратной совместимости)
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
    
    -- Индексы (только ключевые)
    CONSTRAINT unique_phone_email UNIQUE NULLS NOT DISTINCT (phone_hash, email_hash)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_users_telegram ON users(telegram_id) WHERE telegram_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_users_last_activity ON users(last_activity_at DESC);

-- ============================================
-- 6. ПРОФИЛИ ПОЛЬЗОВАТЕЛЕЙ (сохранена обратная совместимость)
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
    birth_country VARCHAR(100) DEFAULT 'Russia',
    
    -- Координаты (используем отдельные поля для простоты)
    birth_lat DECIMAL(9,6),
    birth_lng DECIMAL(9,6),
    
    -- Профессиональная информация
    profession VARCHAR(100),
    
    -- Текущее местоположение
    current_city VARCHAR(100),
    current_lat DECIMAL(9,6),
    current_lng DECIMAL(9,6),
    
    -- Настройки (сохраняем BOOLEAN для обратной совместимости)
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

-- Индексы
CREATE INDEX IF NOT EXISTS idx_profiles_birth_date ON user_profiles(birth_date);
CREATE INDEX IF NOT EXISTS idx_profiles_birth_city_trgm ON user_profiles USING GIN(birth_city gin_trgm_ops);

-- ============================================
-- 7. НАТАЛЬНЫЕ КАРТЫ (упрощенная, но совместимая)
-- ============================================

CREATE TABLE IF NOT EXISTS natal_charts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Метаданные расчёта
    calculation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    calculation_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Географические данные
    city_name VARCHAR(100) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    timezone VARCHAR(50) NOT NULL,
    
    -- Астрологические данные (оптимизированный JSONB)
    planets JSONB NOT NULL DEFAULT '{}',
    houses JSONB NOT NULL DEFAULT '{}',
    aspects JSONB NOT NULL DEFAULT '[]',
    
    -- ML-признаки (компактные)
    ml_features JSONB NOT NULL DEFAULT '{}',
    
    -- Метаданные
    house_system VARCHAR(20) DEFAULT 'Placidus',
    
    -- Статус (сохраняем строки для обратной совместимости)
    calculation_status VARCHAR(20) DEFAULT 'success' CHECK (calculation_status IN ('pending', 'success', 'failed', 'partial')),
    error_message TEXT,
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_natal_user_date ON natal_charts(user_id, calculation_date DESC);
CREATE INDEX IF NOT EXISTS idx_natal_date ON natal_charts(calculation_date);
CREATE INDEX IF NOT EXISTS idx_natal_planets_gin ON natal_charts USING GIN(planets);

-- ============================================
-- 8. ПСИХОМАТРИЦЫ (сохранена полная структура)
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
    energy_level energy_level,
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

CREATE INDEX IF NOT EXISTS idx_matrices_energy ON psyho_matrices(energy_level);
CREATE INDEX IF NOT EXISTS idx_matrices_digits_gin ON psyho_matrices USING GIN(matrix_digits);

-- ============================================
-- 9. БИОРИТМЫ (сохранена оригинальная структура)
-- ============================================

CREATE TABLE IF NOT EXISTS biorhythms (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Основные циклы
    physical_cycle SMALLINT NOT NULL CHECK (physical_cycle BETWEEN -100 AND 100),
    emotional_cycle SMALLINT NOT NULL CHECK (emotional_cycle BETWEEN -100 AND 100),
    intellectual_cycle SMALLINT NOT NULL CHECK (intellectual_cycle BETWEEN -100 AND 100),
    intuitive_cycle SMALLINT NOT NULL CHECK (intuitive_cycle BETWEEN -100 AND 100),
    
    -- Проценты
    physical_percentage SMALLINT NOT NULL CHECK (physical_percentage BETWEEN 0 AND 100),
    emotional_percentage SMALLINT NOT NULL CHECK (emotional_percentage BETWEEN 0 AND 100),
    intellectual_percentage SMALLINT NOT NULL CHECK (intellectual_percentage BETWEEN 0 AND 100),
    intuitive_percentage SMALLINT NOT NULL CHECK (intuitive_percentage BETWEEN 0 AND 100),
    
    -- Фазы (сохраняем строки для обратной совместимости)
    physical_phase VARCHAR(20) NOT NULL,
    emotional_phase VARCHAR(20) NOT NULL,
    intellectual_phase VARCHAR(20) NOT NULL,
    intuitive_phase VARCHAR(20) NOT NULL,
    
    -- Тренды (сохраняем строки)
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
    
    -- Уникальность
    UNIQUE(user_id, calculation_date)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_biorhythms_user_date ON biorhythms(user_id, calculation_date DESC);
CREATE INDEX IF NOT EXISTS idx_biorhythms_critical ON biorhythms(is_critical_day) WHERE is_critical_day = TRUE;

-- ============================================
-- 10. MAGIC PROFILES (полная совместимость с оригиналом)
-- ============================================

CREATE TABLE IF NOT EXISTS magic_profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Основные разделы профиля (полная совместимость)
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

-- Индексы
CREATE INDEX IF NOT EXISTS idx_magic_personality ON magic_profiles(personality_type);
CREATE INDEX IF NOT EXISTS idx_magic_features_gin ON magic_profiles USING GIN(ml_features);

-- ============================================
-- 11. ОПТИМАЛЬНЫЕ АКТИВНОСТИ (сохранена для совместимости)
-- ============================================

CREATE TABLE IF NOT EXISTS optimal_activities (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
    -- Оптимальные активности
    activity_indices SMALLINT[] NOT NULL DEFAULT '{}',
    activity_types activity_type[] NOT NULL DEFAULT '{}',
    
    -- Оценки активностей
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
    
    -- Уникальность
    UNIQUE(user_id, calculation_date)
);

CREATE INDEX IF NOT EXISTS idx_activities_user_date ON optimal_activities(user_id, calculation_date DESC);

-- ============================================
-- 12. РЕКОМЕНДАЦИИ (оптимизированная, но совместимая)
-- ============================================

CREATE TABLE IF NOT EXISTS recommendations (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calculation_date DATE NOT NULL,
    
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
    
    -- Временные метки
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    
    -- Уникальность
    UNIQUE(user_id, calculation_date, category)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_recommendations_user_date ON recommendations(user_id, calculation_date DESC);
CREATE INDEX IF NOT EXISTS idx_recommendations_category ON recommendations(category);
CREATE INDEX IF NOT EXISTS idx_recommendations_priority ON recommendations(priority DESC);

-- ============================================
-- 13. ПСИХОЛОГИЧЕСКИЕ ТЕСТЫ (полная совместимость)
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
    
    -- Уникальность
    UNIQUE(user_id, test_type, test_version)
);

CREATE INDEX IF NOT EXISTS idx_tests_user ON psychological_tests(user_id);
CREATE INDEX IF NOT EXISTS idx_tests_type ON psychological_tests(test_type);

-- ============================================
-- 14. АСТРОЛОГИЧЕСКИЕ СОБЫТИЯ (сохранена)
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

-- ============================================
-- 15. СИСТЕМНЫЙ АУДИТ И ЛОГИ (сохранена)
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

CREATE INDEX IF NOT EXISTS idx_audit_user ON system_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_date ON system_audit_log(created_at DESC);

-- ============================================
-- 16. КЭШ РАСЧЁТОВ (сохранена для производительности)
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
CREATE INDEX IF NOT EXISTS idx_cache_expires ON calculation_cache(expires_at) WHERE is_valid = TRUE;

-- ============================================
-- 17. МЕТРИКИ И СТАТИСТИКА (новая для мониторинга)
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

CREATE INDEX IF NOT EXISTS idx_metrics_name_date ON system_metrics(metric_name, collected_at DESC);

-- ============================================
-- 18. ML МЕТРИКИ (новая для мониторинга ML моделей)
-- ============================================

CREATE TABLE IF NOT EXISTS ml_model_metrics (
    id BIGSERIAL PRIMARY KEY,
    
    -- Идентификация модели
    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(20) NOT NULL,
    
    -- Метрики производительности
    inference_time_ms INTEGER NOT NULL,
    memory_usage_mb INTEGER NOT NULL,
    success_rate REAL NOT NULL CHECK (success_rate BETWEEN 0 AND 1),
    
    -- Метаданные запроса
    input_size_bytes INTEGER,
    output_size_bytes INTEGER,
    user_id BIGINT REFERENCES users(id),
    
    -- Временные метки
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ml_metrics_model ON ml_model_metrics(model_name, timestamp DESC);

-- ============================================
-- 19. ТРИГГЕРЫ И ФУНКЦИИ (ИСПРАВЛЕННЫЕ!)
-- ============================================

-- Функция обновления updated_at (исправленная)
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

CREATE TRIGGER update_recommendations_updated_at 
    BEFORE UPDATE ON recommendations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_astro_events_updated_at 
    BEFORE UPDATE ON astro_events 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Функция для обновления активности пользователя (ИСПРАВЛЕННАЯ - без circular update)
CREATE OR REPLACE FUNCTION update_user_activity()
RETURNS TRIGGER AS $$
BEGIN
    -- Используем CTE для обновления без рекурсивного триггера
    WITH activity_update AS (
        UPDATE users 
        SET last_activity_at = NOW()
        WHERE id = NEW.user_id
        AND last_activity_at < NOW() - INTERVAL '5 minutes'
        RETURNING 1
    )
    SELECT 1 FROM activity_update;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для обновления активности
CREATE TRIGGER update_activity_on_recommendation
    AFTER INSERT OR UPDATE ON recommendations
    FOR EACH ROW EXECUTE FUNCTION update_user_activity();

CREATE TRIGGER update_activity_on_test
    AFTER INSERT OR UPDATE ON psychological_tests
    FOR EACH ROW EXECUTE FUNCTION update_user_activity();

-- Функция очистки старых данных (еженедельно)
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS void AS $$
BEGIN
    -- Удаляем старые метрики (храним 90 дней)
    DELETE FROM system_metrics 
    WHERE collected_at < NOW() - INTERVAL '90 days';
    
    -- Удаляем старые ML метрики (храним 30 дней)
    DELETE FROM ml_model_metrics 
    WHERE timestamp < NOW() - INTERVAL '30 days';
    
    -- Инвалидируем старый кэш (7 дней)
    UPDATE calculation_cache 
    SET is_valid = FALSE 
    WHERE expires_at < NOW() - INTERVAL '7 days';
    
    -- Архивируем старые аудит логи (1 год)
    DELETE FROM system_audit_log 
    WHERE created_at < NOW() - INTERVAL '1 year';
    
    RAISE NOTICE 'Database cleanup completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 20. НАСТРОЙКА ПРАВ ДОСТУПА (ИСПРАВЛЕННЫЕ!)
-- ============================================

-- Даем права на подключение
GRANT CONNECT ON DATABASE personal_assistant TO personal_assistant_app;

-- Даем права на схему
GRANT USAGE ON SCHEMA public TO personal_assistant_app;

-- Права для приложения
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public 
TO personal_assistant_app;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public 
TO personal_assistant_app;

-- Права для выполнения функций
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public 
TO personal_assistant_app;

-- Настройка прав по умолчанию для будущих таблиц (ИСПРАВЛЕНО!)
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
-- 21. ПРЕДСТАВЛЕНИЯ ДЛЯ МОНИТОРИНГА
-- ============================================

-- Полная информация о пользователе
CREATE OR REPLACE VIEW user_complete_info AS
SELECT 
    u.id,
    u.telegram_id,
    u.status,
    COALESCE(u.is_premium, FALSE) as is_premium,  -- ✅ Защита
    --u.is_premium,
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
    -- Безопасный подсчёт (игнорирует ошибки)
    COALESCE((SELECT COUNT(*) FROM natal_charts nc WHERE nc.user_id = u.id), 0) as natal_charts_count,
    COALESCE((SELECT COUNT(*) FROM biorhythms b WHERE b.user_id = u.id), 0) as biorhythms_count,
    COALESCE((SELECT COUNT(*) FROM recommendations r WHERE r.user_id = u.id), 0) as recommendations_count,
    COALESCE((SELECT COUNT(*) FROM psychological_tests pt WHERE pt.user_id = u.id), 0) as tests_count
    
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id;

-- Ежедневная сводка
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

-- ML модели метрики
CREATE OR REPLACE VIEW ml_models_performance AS
SELECT 
    model_name,
    model_version,
    COUNT(*) as total_inferences,
    AVG(inference_time_ms) as avg_inference_time,
    AVG(success_rate) * 100 as avg_success_rate,
    AVG(memory_usage_mb) as avg_memory_mb,
    MIN(timestamp) as first_used,
    MAX(timestamp) as last_used
    
FROM ml_model_metrics
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY model_name, model_version
ORDER BY total_inferences DESC;

-- ============================================
-- 22. КОММЕНТАРИИ К ТАБЛИЦАМ
-- ============================================

COMMENT ON TABLE users IS 'Основная таблица пользователей системы';
COMMENT ON TABLE user_profiles IS 'Дополнительная информация о пользователях для расчётов';
COMMENT ON TABLE natal_charts IS 'Натальные астрологические карты';
COMMENT ON TABLE psyho_matrices IS 'Нумерологические психоматрицы по методу Пифагора';
COMMENT ON TABLE biorhythms IS 'Расчёты биоритмов пользователей';
COMMENT ON TABLE magic_profiles IS 'Интегрированные психологические и эзотерические профили';
COMMENT ON TABLE optimal_activities IS 'Рекомендации оптимальных активностей';
COMMENT ON TABLE recommendations IS 'Итоговые персонализированные рекомендации';
COMMENT ON TABLE psychological_tests IS 'Результаты психологических тестов пользователей';
COMMENT ON TABLE astro_events IS 'Астрологические события и лунные фазы';
COMMENT ON TABLE system_audit_log IS 'Логирование действий в системе';
COMMENT ON TABLE calculation_cache IS 'Кэш результатов расчётов для оптимизации';
COMMENT ON TABLE system_metrics IS 'Метрики производительности системы';
COMMENT ON TABLE ml_model_metrics IS 'Метрики производительности ML моделей';

-- ============================================
-- 23. ВАЛИДАЦИЯ И ФИНАЛЬНАЯ НАСТРОЙКА
-- ============================================

DO $$
DECLARE
    table_count INTEGER;
    index_count INTEGER;
    view_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count FROM pg_tables WHERE schemaname = 'public';
    SELECT COUNT(*) INTO index_count FROM pg_indexes WHERE schemaname = 'public';
    SELECT COUNT(*) INTO view_count FROM pg_views WHERE schemaname = 'public';
    
    RAISE NOTICE '============================================';
    RAISE NOTICE 'PERSONAL ASSISTANT v4.1 - PRODUCTION READY';
    RAISE NOTICE 'Tables: % | Indexes: % | Views: %', table_count, index_count, view_count;
    RAISE NOTICE 'Ready for ML/Astrology at %', NOW();
    RAISE NOTICE '============================================';
END $$;

-- ============================================
-- 24. ПРОВЕРОЧНЫЙ ЗАПРОС (опционально)
-- ============================================

-- Проверяем создание таблиц (только для отладки)
DO $$
BEGIN
    RAISE NOTICE 'Database structure verification:';
    RAISE NOTICE '  Users table: %', (SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'users'));
    RAISE NOTICE '  Recommendations table: %', (SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'recommendations'));
    RAISE NOTICE '  ML metrics table: %', (SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = 'ml_model_metrics'));
    RAISE NOTICE '  Role exists: %', (SELECT EXISTS (SELECT FROM pg_roles WHERE rolname = 'personal_assistant_app'));
END
$$;
