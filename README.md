Personal Assistant Ecosystem 



## Идея проекта и ценность

### Проблема
Современные системы рекомендаций работают на поверхностных данных: история покупок, клики, явные предпочтения. Они не учитывают:
- Врожденные особенности личности (астрологическая карта)
- Энергетические циклы (биоритмы, лунные фазы)
- Глубинные психологические паттерны (MBTI, Big5)
- Истинные потребности (пирамида Маслоу)

Результат: обезличенные рекомендации, конфликт между "хочу" и "могу", низкая эффективность саморазвития.

### Решение
Personal Assistant Ecosystem создает глубинную интеграцию трех уровней личности:
1. Астрологический слой - врожденные склонности и потенциал
2. Психологический слой - актуальное состояние и черты личности
3. Потребностный слой - текущие нужды и ценности

### Ценность для пользователя
- Гиперперсонализация - рекомендации учитывают не поведение, а сущность
- Проактивность - система предсказывает оптимальные дни для активностей
- Согласованность - рекомендации не противоречат энергетическому состоянию
- Личностный рост - система помогает раскрывать потенциал, а не потреблять контент

### Ценность для бизнеса
- Уникальное предложение на рынке personal assistant
- Высокая лояльность благодаря глубине персонализации
- Мультиканальность (Telegram, Unity, Web)
- Монетизация через insights - пользователи платят за понимание себя

---

## Уникальность решения

### 1. Научно-эзотерический синтез
Впервые системно объединяются:
- Точная астрономия (Swiss Ephemeris)
- Нумерология Пифагора (математические расчеты)
- Современная психология (MBTI, Big5, Maslow)
- Машинное обучение для интеграции данных

### 2. Динамическая адаптация
Система учитывает не статичный профиль, а динамические изменения:
- Ежедневные биоритмы (физический, эмоциональный, интеллектуальный циклы)
- Лунные фазы и их влияние
- Планетарные транзиты - изменение энергий
- Результаты тестирования - эволюция личности

### 3. Многоуровневая валидация
Каждая рекомендация проверяется на трех уровнях:
1. Астрологическая согласованность - соответствует ли врожденным склонностям
2. Психологическая релевантность - подходит ли текущему состоянию
3. Потребностная актуальность - отвечает ли истинным нуждам

### 4. Resilience by design
Система продолжает работать даже при частичных отказах:
- Circuit Breaker - защита от каскадных сбоев
- Graceful degradation - снижение качества, а не полный отказ
- Кэширование - работа без пересчета при падении сервисов

---

## Архитектура

### Общая концепция
Минималистичная микросервисная архитектура с тремя специализированными сервисами, оптимизированная для 1000 пользователей с возможностью плавного роста до 10k.

### Архитектурные принципы
1. Количество сервисов - три
2. HTTP/REST - разработка и отладка
3. Redis 
4. PostgreSQL аналитика 
5. Progressive enhancement - добавляем сложность по мере роста

### Компонентная диаграмма
```
┌─────────────────────────────────────────────────────────┐
│                   КЛИЕНТСКИЕ ИНТЕРФЕЙСЫ                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Telegram │  │   Unity  │  │   Web    │              │
│  │   Bot    │  │   App    │  │  Portal  │              │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘              │
└───────┼─────────────┼─────────────┼────────────────────┘
        │             │             │
        ▼             ▼             ▼
┌─────────────────────────────────────────────────────────┐
│                   API GATEWAY                           │
│  • Единая точка входа                                  │
│  • JWT аутентификация                                  │
│  • Rate limiting (50 RPM/user)                         │
│  • Circuit Breaker к сервисам                          │
│  • Логирование всех запросов                           │
└──────────────┬──────────────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│PROFILING│ │  RECO   │ │ SHARED  │
│ SERVICE │ │ SERVICE │ │  INFRA  │
│         │ │         │ │         │
│ • Astra │ │ • Ollama│ │ • Redis │
│ • Test  │ │ • Cache │ │ • Post- │
│ • Quest │ │ • LLM   │ │   gres  │
└─────────┘ └─────────┘ └─────────┘
```

### Технологический стек
- API Gateway: FastAPI + JWT + aiogram (Telegram)
- Profiling Service: FastAPI + Swiss Ephemeris + numpy
- Recommendation Service: FastAPI + Ollama + Redis
- База данных: PostgreSQL 15 + Redis 7
- Очереди задач: Celery + Redis
- Мониторинг: Prometheus + Grafana + Loki
- Контейнеризация: Docker + Docker Compose

---

## База данных

### Общая структура
Единая база данных PostgreSQL с логическими схемами для каждого домена. Для MVP 1000 пользователей достаточно одного инстанса.

### Схема `users`
```
users.profiles
├── telegram_id (BIGINT PRIMARY KEY)
├── birth_date, birth_time, birth_city
├── registration_date
├── last_activity
└── subscription_status

users.sessions
├── session_token
├── telegram_id
├── created_at
├── expires_at
└── device_info
```

### Схема `profiling` (все расчетные данные)
```
profiling.astro_data
├── natal_chart (JSONB) - натальная карта
├── planetary_positions (JSONB) - позиции планет
├── houses (JSONB) - дома гороскопа
├── aspects (JSONB) - аспекты между планетами
└── calculated_at

profiling.biorhythms
├── calculation_date
├── physical_cycle (FLOAT)
├── emotional_cycle (FLOAT)
├── intellectual_cycle (FLOAT)
├── intuitive_cycle (FLOAT)
└── overall_energy (FLOAT)

profiling.psychology_data
├── mbti_type (VARCHAR) - результат MBTI
├── big5_scores (JSONB) - OCEAN оценки
├── maslow_levels (JSONB) - пирамида Маслоу
├── values_ranking (JSONB) - ранжирование ценностей
└── assessment_date

profiling.ml_profiles
├── feature_vector (FLOAT[]) - [100+] ML признаки
├── optimal_activities (JSONB) - рекомендованные активности
├── confidence_score (FLOAT) - уверенность расчета
└── profile_version (INTEGER)
```

### Схема `recommendations`
```
recommendations.daily_recommendations
├── recommendation_date
├── generated_text (TEXT) - текст рекомендации
├── activities_list (JSONB) - список активностей
├── energy_level (FLOAT) - рекомендованный уровень энергии
├── cache_key (VARCHAR) - ключ кэша
└── feedback_score (INTEGER) - оценка пользователя

recommendations.feedback
├── recommendation_id
├── rating (1-5)
├── completed_activities (JSONB)
├── comments (TEXT)
└── feedback_date
```

### Схема `system`
```
system.audit_log
├── event_type (CREATE/UPDATE/DELETE/ERROR)
├── telegram_id
├── service_name
├── endpoint
├── request_data (JSONB)
├── response_status (INTEGER)
└── timestamp

system.metrics
├── service_name
├── metric_name (latency/errors/cache_hits)
├── metric_value (FLOAT)
├── metric_timestamp
└── tags (JSONB)
```

### Оптимизации для 1000 пользователей
1. Индексы: Только по часто используемым полям (telegram_id, date)
2. Партиционирование: По датам для recommendations и biorhythms
3. Кэширование: Redis для горячих данных (ML профили, рекомендации)
4. Materialized Views: Для аналитических запросов

---

## Структура проектов

### Корневая структура
```
personal_assistant/
├── docker-compose.yml          # Все сервисы + БД + Redis
├── .env                        # Единые переменные окружения
├── README.md                   # Основная документация
├── Makefile                    # Команды разработки
│
├── api_gateway/                # Сервис 1: Единая точка входа
├── profiling_service/          # Сервис 2: Все расчеты
├── recommendation_service/     # Сервис 3: Генерация рекомендаций
│
├── shared/                     # Общие библиотеки
├── infra/                      # Инфраструктура
├── docs/                       # Документация
└── scripts/                    # Вспомогательные скрипты
```

### 1. API Gateway (`api_gateway/`)
Единая точка входа для всех клиентов. Отвечает за безопасность, маршрутизацию и мониторинг.

```
api_gateway/
├── src/
│   ├── api/                   # REST API endpoints
│   │   ├── auth/             # JWT аутентификация
│   │   ├── users/            # Управление пользователями
│   │   ├── recommendations/  # Прокси к recommendation_service
│   │   └── profiling/        # Прокси к profiling_service
│   │
│   ├── clients/              # Клиентские интерфейсы
│   │   ├── telegram/         # Telegram бот на aiogram
│   │   │   ├── handlers/    # Команды и сообщения
│   │   │   ├── keyboards/   # Инлайн-клавиатуры
│   │   │   ├── states/      # Finite State Machine
│   │   │   └── middleware/  # Промежуточное ПО
│   │   │
│   │   ├── unity/           # Unity WebGL интеграция
│   │   │   ├── api_client/  # HTTP клиент на C#
│   │   │   ├── models/      # Data модели
│   │   │   └── ui/          # Unity UI компоненты
│   │   │
│   │   └── web/             # Веб-интерфейс
│   │       └── spa/         # Single Page Application
│   │
│   ├── middleware/           # Глобальное middleware
│   │   ├── rate_limiter.py   # Ограничение запросов
│   │   ├── circuit_breaker.py # Защита от сбоев сервисов
│   │   ├── request_logger.py # Логирование запросов
│   │   ├── error_handler.py  # Обработка ошибок
│   │   └── metrics.py        # Сбор метрик Prometheus
│   │
│   ├── config/              # Конфигурация
│   │   ├── settings.py      # Настройки приложения
│   │   ├── routes.py        # Маршрутизация запросов
│   │   └── security.py      # Настройки безопасности
│   │
│   ├── utils/               # Вспомогательные функции
│   │   ├── validators.py    # Валидация данных
│   │   ├── formatters.py    # Форматирование ответов
│   │   └── helpers.py       # Общие утилиты
│   │
│   └── models/              # Модели данных
│       ├── requests.py      # Pydantic модели запросов
│       ├── responses.py     # Pydantic модели ответов
│       └── database.py      # Модели БД (если нужны)
│
├── tests/                   # Тесты
│   ├── unit/               # Юнит-тесты
│   ├── integration/        # Интеграционные тесты
│   └── e2e/               # End-to-end тесты
│
├── migrations/             # Миграции БД (если нужны)
├── static/                # Статические файлы
├── templates/             # HTML шаблоны
│
├── Dockerfile             # Сборка Docker образа
├── requirements.txt       # Python зависимости
├── alembic.ini           # Конфигурация миграций
├── .env.example          # Пример переменных окружения
└── gunicorn.conf.py      # Конфигурация WSGI сервера
```

### 2. Profiling Service (`profiling_service/`)
Ядро системы. Выполняет все расчеты и создает единый психологический профиль.

```
profiling_service/
├── src/
│   ├── core/                 # Бизнес-логика
│   │   ├── astro/           # Астрологические расчеты
│   │   │   ├── natal_chart/ # Натальная карта
│   │   │   │   ├── calculator.py      # Расчет карты
│   │   │   │   ├── interpreter.py     # Интерпретация
│   │   │   │   └── validator.py       # Валидация данных
│   │   │   │
│   │   │   ├── biorhythms/  # Биоритмы
│   │   │   │   ├── cycles.py          # 4 цикла
│   │   │   │   ├── energy.py          # Уровень энергии
│   │   │   │   └── forecast.py        # Прогноз на неделю
│   │   │   │
│   │   │   ├── lunar/       # Лунные фазы
│   │   │   │   └── phases.py          # Расчет фаз луны
│   │   │   │
│   │   │   └── transits/    # Планетарные транзиты
│   │   │       └── calculator.py      # Текущие транзиты
│   │   │
│   │   ├── numerology/      # Нумерология
│   │   │   ├── pythagoras/  # Матрица Пифагора
│   │   │   │   ├── matrix.py          # Построение матрицы
│   │   │   │   ├── numbers.py         # Анализ чисел
│   │   │   │   └── characteristics.py # Характеристики
│   │   │   │
│   │   │   └── calculator.py          # Основной калькулятор
│   │   │
│   │   ├── psychology/      # Психологические тесты
│   │   │   ├── personality/ # Тесты личности
│   │   │   │   ├── mbti.py           # MBTI
│   │   │   │   ├── big5.py           # Большая пятерка
│   │   │   │   └── interpreter.py    # Интерпретация
│   │   │   │
│   │   │   ├── needs/       # Потребности
│   │   │   │   ├── maslow.py         # Пирамида Маслоу
│   │   │   │   ├── values.py         # Ценности
│   │   │   │   └── assessment.py     # Оценка
│   │   │   │
│   │   │   └── tests/       # Управление тестированием
│   │   │       ├── manager.py       # Менеджер тестов
│   │   │       ├── progress.py      # Прогресс тестирования
│   │   │       └── results.py       # Результаты
│   │   │
│   │   ├── ml/              # Машинное обучение
│   │   │   ├── feature_extraction/ # Извлечение признаков
│   │   │   │   ├── astro_features.py   # Признаки из астрологии
│   │   │   │   ├── psych_features.py   # Признаки из психологии
│   │   │   │   └── needs_features.py   # Признаки из потребностей
│   │   │   │
│   │   │   ├── profile_building/    # Построение профиля
│   │   │   │   ├── integrator.py        # Интеграция данных
│   │   │   │   ├── normalizer.py        # Нормализация
│   │   │   │   └── vectorizer.py        # Создание вектора
│   │   │   │
│   │   │   ├── optimization/        # Оптимизация
│   │   │   │   ├── activity_optimizer.py # Оптимальные активности
│   │   │   │   ├── similarity.py        # Сходство с другими
│   │   │   │   └── clustering.py        # Кластеризация
│   │   │   │
│   │   │   └── validation/          # Валидация
│   │   │       ├── consistency.py       # Согласованность
│   │   │       ├── confidence.py        # Уверенность
│   │   │       └── anomalies.py         # Аномалии
│   │   │
│   │   └── orchestration/   # Оркестрация расчетов
│   │       ├── pipeline.py      # Конвейер расчетов
│   │       ├── scheduler.py     # Планировщик
│   │       └── cache_manager.py # Управление кэшем
│   │
│   ├── api/                 # Внутреннее API
│   │   ├── v1/             # API версия 1
│   │   │   ├── profiles.py    # Работа с профилями
│   │   │   ├── calculations.py # Запуск расчетов
│   │   │   ├── tests.py       # Управление тестами
│   │   │   └── ml.py          # ML endpoints
│   │   │
│   │   └── health.py           # Health checks
│   │
│   ├── database/           # Работа с БД
│   │   ├── models/        # SQLAlchemy модели
│   │   ├── repositories/  # Repository pattern
│   │   ├── migrations/    # Alembic миграции
│   │   └── seeders/       # Тестовые данные
│   │
│   ├── services/          # Сервисный слой
│   │   ├── user_service.py   # Сервис пользователей
│   │   ├── calculation_service.py # Сервис расчетов
│   │   └── profile_service.py # Сервис профилей
│   │
│   ├── utils/             # Утилиты
│   │   ├── date_utils.py     # Работа с датами
│   │   ├── math_utils.py     # Математические функции
│   │   ├── validation_utils.py # Валидация
│   │   └── logging_utils.py  # Логирование
│   │
│   └── config/            # Конфигурация
│       ├── settings.py       # Настройки приложения
│       ├── database.py       # Настройки БД
│       ├── cache.py          # Настройки кэша
│       └── ephemeris.py      # Настройки Swiss Ephemeris
│
├── ephe/                  # Файлы Swiss Ephemeris
├── tests/                 # Все виды тестов
├── migrations/            # Миграции БД
├── scripts/               # Скрипты
│   ├── setup_ephemeris.sh # Установка Swiss Ephemeris
│   └── calculate_sample.sh # Пример расчета
│
├── Dockerfile            # Сборка Docker образа
├── requirements.txt      # Python зависимости
├── alembic.ini          # Конфигурация миграций
└── .env.example         # Пример переменных
```

### 3. Recommendation Service (`recommendation_service/`)
Генерация персонализированных рекомендаций на основе профиля пользователя.

```
recommendation_service/
├── src/
│   ├── core/                 # Бизнес-логика
│   │   ├── generation/      # Генерация рекомендаций
│   │   │   ├── prompt_engineering/ # Конструирование промптов
│   │   │   │   ├── builder.py      # Построитель промптов
│   │   │   │   ├── templates.py    # Шаблоны промптов
│   │   │   │   └── context.py      # Контекст пользователя
│   │   │   │
│   │   │   ├── llm_integration/    # Интеграция с LLM
│   │   │   │   ├── ollama_client.py # Клиент Ollama
│   │   │   │   ├── model_manager.py # Управление моделями
│   │   │   │   └── response_parser.py # Парсинг ответов
│   │   │   │
│   │   │   └── quality/           # Качество генерации
│   │   │       ├── validator.py       # Валидация ответов
│   │   │       ├── scorer.py          # Оценка качества
│   │   │       └── fallback.py        # Fallback механизмы
│   │   │
│   │   ├── personalization/ # Персонализация
│   │   │   ├── context_builder/    # Сбор контекста
│   │   │   │   ├── profile_loader.py   # Загрузка профиля
│   │   │   │   ├── history_manager.py  # История пользователя
│   │   │   │   └── preferences.py      # Предпочтения
│   │   │   │
│   │   │   ├── relevance_scoring/  # Релевантность
│   │   │   │   ├── scorer.py          # Оценщик релевантности
│   │   │   │   ├── filters.py         # Фильтры
│   │   │   │   └── ranker.py          # Ранжирование
│   │   │   │
│   │   │   └── adaptation/         # Адаптация
│   │   │       ├── feedback_processor.py # Обработка фидбека
│   │   │       ├── learning.py          # Обучение на фидбеке
│   │   │       └── adjustment.py        # Корректировки
│   │   │
│   │   ├── optimization/    # Оптимизация
│   │   │   ├── caching/     # Кэширование
│   │   │   │   ├── redis_manager.py # Менеджер Redis
│   │   │   │   ├── strategy.py      # Стратегии кэширования
│   │   │   │   └── invalidation.py  # Инвалидация кэша
│   │   │   │
│   │   │   ├── batching/    # Пакетная обработка
│   │   │   │   ├── batch_manager.py # Менеджер батчей
│   │   │   │   ├── scheduler.py     # Планировщик
│   │   │   │   └── processor.py     # Обработчик
│   │   │   │
│   │   │   └── performance/ # Производительность
│   │   │       ├── metrics.py       # Метрики
│   │   │       ├── monitoring.py    # Мониторинг
│   │   │       └── optimization.py  # Оптимизации
│   │   │
│   │   └── templates/       # Шаблоны рекомендаций
│   │       ├── basic_templates.py   # Базовые шаблоны
│   │       ├── energy_templates.py  # По уровням энергии
│   │       ├── activity_templates.py # По типам активностей
│   │       └── fallback_templates.py # Fallback шаблоны
│   │
│   ├── api/                 # REST API
│   │   ├── v1/
│   │   │   ├── recommendations.py # Генерация рекомендаций
│   │   │   ├── feedback.py        # Прием фидбека
│   │   │   ├── cache.py           # Управление кэшем
│   │   │   └── health.py          # Health checks
│   │   │
│   │   └── middleware/      # Middleware
│   │       ├── rate_limit.py     # Rate limiting
│   │       ├── validation.py     # Валидация
│   │       └── metrics.py        # Метрики
│   │
│   ├── database/           # Работа с БД (только рекомендации)
│   ├── services/          # Сервисный слой
│   ├── utils/             # Утилиты
│   └── config/            # Конфигурация
│
├── tests/                 # Тесты
├── Dockerfile            # Docker образ
└── requirements.txt      # Зависимости
```

### 4. Shared Libraries (`shared/`)
Общие библиотеки и конфигурации, используемые всеми сервисами.

```
shared/
├── python/                  # Python библиотеки
│   ├── common_models/      # Общие модели данных
│   │   ├── user.py         # Модель пользователя
│   │   ├── profile.py      # Модель профиля
│   │   ├── recommendation.py # Модель рекомендации
│   │   └── enums.py        # Перечисления
│   │
│   ├── database/           # Общие утилиты БД
│   │   ├── connection.py   # Пул соединений
│   │   ├── migrations/     # Общие миграции
│   │   └── utils.py        # Утилиты БД
│   │
│   ├── logging/            # Единое логирование
│   │   ├── config.py       # Конфигурация логов
│   │   ├── formatters.py   # Форматтеры
│   │   ├── handlers.py     # Обработчики
│   │   └── middleware.py   # Middleware для логирования
│   │
│   ├── monitoring/         # Мониторинг
│   │   ├── metrics.py      # Метрики Prometheus
│   │   ├── tracing.py      # Distributed tracing
│   │   └── health.py       # Health checks
│   │
│   ├── security/           # Безопасность
│   │   ├── auth.py         # Аутентификация
│   │   ├── jwt.py          # JWT токены
│   │   ├── encryption.py   # Шифрование
│   │   └── validation.py   # Валидация
│   │
│   └── utils/              # Общие утилиты
│       ├── date_utils.py   # Дата/время
│       ├── math_utils.py   # Математика
│       ├── string_utils.py # Строки
│       └── file_utils.py   # Работа с файлами
│
├── configs/               # Общие конфигурации
│   ├── docker/            # Docker образы
│   │   ├── base.Dockerfile # Базовый образ
│   │   ├── python.Dockerfile # Python образ
│   │   └── node.Dockerfile # Node.js образ
│   │
│   ├── kubernetes/        # Kubernetes манифесты
│   │   ├── namespace.yaml # Namespace
│   │   ├── configmaps/    # ConfigMaps
│   │   ├── secrets/       # Secrets
│   │   └── deployments/   # Deployments
│   │
│   ├── monitoring/        # Мониторинг
│   │   ├── prometheus/    # Prometheus конфигурация
│   │   ├── grafana/       # Grafana дашборды
│   │   └── alerts/        # Правила алертинга
│   │
│   └── nginx/             # Nginx конфигурации
│       ├── api_gateway.conf # Конфиг для API Gateway
│       └── ssl/           # SSL сертификаты
│
└── scripts/               # Общие скрипты
    ├── deployment/        # Скрипты деплоя
    ├── backup/           # Скрипты бекапа
    ├── monitoring/       # Скрипты мониторинга
    └── testing/          # Скрипты тестирования
```

---

## Детализация модулей

### Profiling Service - Ключевые модули

#### Астрологический модуль (`core/astro/`)
Назначение: Точные астрономические расчеты на основе Swiss Ephemeris.

Компоненты:
1. Natal Chart Calculator: Расчет натальной карты по дате, времени и месту рождения
2. House System Calculator: Определение 12 домов по системе Placidus
3. Planetary Positions: Расчет точных позиций 10 планет + Лунные узлы
4. Aspect Calculator: Определение аспектов между небесными телами
5. Elemental Balance: Анализ баланса 4 стихий (огонь, земля, воздух, вода)

Входные данные: Дата рождения, время рождения, город рождения
Выходные данные: Структурированная натальная карта с планетами, домами, аспектами

#### Биоритмический модуль (`core/astro/biorhythms/`)
Назначение: Расчет физических, эмоциональных и интеллектуальных циклов.

Компоненты:
1. Cycle Calculator: Расчет 4 основных циклов (23, 28, 33, 38 дней)
2. Energy Level Calculator: Определение общего уровня энергии (0-100%)
3. Critical Day Detector: Выявление критических дней (переход через 0)
4. Peak Period Identifier: Определение пиковых периодов (максимум цикла)
5. Forecast Generator: Генерация прогноза на неделю вперед

Входные данные: Дата рождения, целевая дата
Выходные данные: Значения циклов, уровень энергии, прогнозы

#### Нумерологический модуль (`core/numerology/`)
Назначение: Расчет психоматрицы по методу Пифагора.

Компоненты:
1. Matrix Calculator: Построение психоматрицы 3×3 из цифр даты рождения
2. Number Analysis: Анализ количества цифр 1-9 в матрице
3. Characteristic Calculator: Определение 9 характеристик личности
4. Talent Identifier: Выявление врожденных талантов и склонностей
5. Life Path Calculator: Расчет чисел жизненного пути

Входные данные: Дата рождения
Выходные данные: Психоматрица, характеристики, таланты, числа пути

#### Психологический модуль (`core/psychology/`)
Назначение: Проведение психологических тестов и оценка потребностей.

Компоненты:
1. Personality Tests: MBTI (16 типов) и Big5 (OCEAN модель)
2. Needs Assessment: Пирамида Маслоу (5 уровней потребностей)
3. Values Ranking: Ранжирование личных ценностей
4. Test Progress Manager: Отслеживание прогресса тестирования
5. Result Interpreter: Интерпретация результатов тестов

Входные данные: Ответы на вопросы тестов
Выходные данные: Тип личности, оценки по шкалам, уровни потребностей

#### ML-модуль (`core/ml/`)
Назначение: Интеграция всех данных в единый ML-профиль и оптимизация рекомендаций.

Компоненты:
1. Feature Extractor: Извлечение признаков из всех источников данных
2. Profile Integrator: Создание единого психологического профиля
3. Activity Optimizer: Определение оптимальных активностей на день
4. Similarity Calculator: Расчет сходства с другими пользователями
5. Consistency Validator: Проверка согласованности данных из разных источников

Входные данные: Данные из астрологии, нумерологии, психологии
Выходные данные: Единый ML-профиль, feature vector, оптимальные активности

### Recommendation Service - Ключевые модули

#### Генерационный модуль (`core/generation/`)
Назначение: Генерация текстовых рекомендаций на основе профиля.

Компоненты:
1. Prompt Engineer: Конструирование контекстных промптов для LLM
2. LLM Integrator: Взаимодействие с Ollama для генерации текста
3. Response Parser: Парсинг и очистка ответов от LLM
4. Quality Validator: Проверка качества сгенерированного текста
5. Fallback Manager: Управление fallback на шаблоны при ошибках

Входные данные: ML-профиль, контекст дня, история рекомендаций
Выходные данные: Персонализированные текстовые рекомендации

#### Кэширующий модуль (`core/optimization/caching/`)
Назначение: Оптимизация производительности через многоуровневое кэширование.

Компоненты:
1. Redis Manager: Работа с Redis кластером для хранения кэша
2. Cache Strategy: Стратегии кэширования для разных типов данных
3. TTL Manager: Управление временем жизни кэшированных данных
4. Invalidation Logic: Логика инвалидации кэша при изменении данных
5. Metrics Collector: Сбор метрик эффективности кэширования

Входные данные: Данные для кэширования, TTL настройки
Выходные данные: Кэшированные данные, метрики hit/miss ratio

#### Персонализационный модуль (`core/personalization/`)
Назначение: Адаптация рекомендаций под конкретного пользователя.

Компоненты:
1. Context Builder: Сбор полного контекста пользователя (профиль, история, предпочтения)
2. Relevance Scorer: Оценка релевантности различных активностей
3. Feedback Processor: Обработка обратной связи от пользователя
4. Learning System: Обучение на фидбеке для улучшения рекомендаций
5. Adjustment Engine: Корректировка рекомендаций на основе истории

Входные данные: Профиль пользователя, история взаимодействий, фидбек
Выходные данные: Адаптированные рекомендации, обновленные предпочтения

---

## Потоки данных

### 1. Основной поток: Получение ежедневных рекомендаций

```
ШАГ 1: Пользователь запрашивает рекомендации
  ↓
ШАГ 2: API Gateway принимает запрос
  ├── Аутентификация по JWT токену
  ├── Rate limiting проверка
  └── Логирование запроса
  ↓
ШАГ 3: Маршрутизация в Recommendation Service
  ↓
ШАГ 4: Проверка кэша рекомендаций
  ├── Если есть в кэше (90% случаев):
  │   ↓
  │   Возврат кэшированных рекомендаций
  │
  └── Если нет в кэше (10% случаев):
      ↓
      ШАГ 5: Запрос профиля в Profiling Service
        ↓
      ШАГ 6: Profiling Service:
        ├── Проверка актуальности расчетов
        ├── При необходимости пересчет биоритмов
        ├── Извлечение ML-профиля
        └── Возврат актуального профиля
        ↓
      ШАГ 7: Recommendation Service:
        ├── Формирование промпта на основе профиля
        ├── Генерация рекомендации через Ollama
        ├── Кэширование результата
        └── Возврат рекомендации
        ↓
ШАГ 8: API Gateway возвращает ответ пользователю
```

Время выполнения: 50-150ms (90% cache hit) или 1-3s (10% cache miss + LLM генерация)

### 2. Поток создания профиля (новый пользователь)

```
ШАГ 1: Регистрация пользователя
  ↓
ШАГ 2: Ввод основных данных
  ├── Дата, время, место рождения
  ├── Демографическая информация
  └── Начальные предпочтения
  ↓
ШАГ 3: Параллельные расчеты:
  ├── Астрологический расчет (30-50ms)
  ├── Нумерологический расчет (5-10ms)
  ├── Базовое психологическое тестирование
  └── Инициализация биоритмов
  ↓
ШАГ 4: Интеграция данных в единый профиль
  ↓
ШАГ 5: Сохранение профиля в БД
  ↓
ШАГ 6: Генерация первых рекомендаций
```

### 3. Фоновые процессы

#### Ежедневное обновление биоритмов
```
ТРИГГЕР: Каждый день в 00:01
ДЕЙСТВИЕ: Profiling Service обновляет биоритмы для всех активных пользователей
  ├── Для каждого пользователя:
  │   ├── Пересчет 4 циклов на текущий день
  │   ├── Определение критических дней
  │   ├── Расчет уровня энергии
  │   └── Обновление данных в БД
  │
  └── При значительных изменениях:
      Триггер перегенерации рекомендаций
```

#### Периодическое тестирование
```
ТРИГГЕР: По расписанию (раз в 2 недели) или по запросу
ДЕЙСТВИЕ: Testing модуль предлагает пройти тест
  ├── Короткие тесты (5-10 минут)
  ├── Адаптивная сложность вопросов
  ├── Обновление психологического профиля
  └── Корректировка рекомендаций
```

#### Аналитика и оптимизация
```
ТРИГГЕР: Еженедельно (воскресенье 03:00)
ДЕЙСТВИЕ: Системный анализ и оптимизация
  ├── Сбор метрик эффективности рекомендаций
  ├── Анализ обратной связи пользователей
  ├── Корректировка весов в ML-моделях
  └── A/B тестирование новых алгоритмов
```

---

## Развертывание для 1000 пользователей

### Локальная разработка (Docker Compose)

```yaml
# docker-compose.yml
version: '3.8'

services:
  # База данных
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: personal_assistant
      POSTGRES_USER: pa_user
      POSTGRES_PASSWORD: pa_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init/01-init.sql:/docker-entrypoint-initdb.d/01.sql

  # Redis для кэша и очередей
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes --maxmemory 512mb
    volumes:
      - redis_data:/data

  # Ollama для генерации рекомендаций
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama

  # API Gateway
  api_gateway:
    build: ./api_gateway
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgresql://pa_user:pa_password@postgres:5432/personal_assistant
      REDIS_URL: redis://redis:6379/0
      PROFILING_SERVICE_URL: http://profiling_service:8000
      RECOMMENDATION_SERVICE_URL: http://recommendation_service:8001
    depends_on:
      - postgres
      - redis

  # Profiling Service
  profiling_service:
    build: ./profiling_service
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://pa_user:pa_password@postgres:5432/personal_assistant
      REDIS_URL: redis://redis:6379/0
      EPHE_PATH: /app/ephe
    volumes:
      - ./ephe:/app/ephe  # Swiss Ephemeris файлы
    depends_on:
      - postgres
      - redis

  # Recommendation Service
  recommendation_service:
    build: ./recommendation_service
    ports:
      - "8001:8001"
    environment:
      DATABASE_URL: postgresql://pa_user:pa_password@postgres:5432/personal_assistant
      REDIS_URL: redis://redis:6379/0
      OLLAMA_URL: http://ollama:11434
      PROFILING_SERVICE_URL: http://profiling_service:8000
    depends_on:
      - postgres
      - redis
      - ollama

volumes:
  postgres_data:
  redis_data:
  ollama_data:
```

### Продакшен развертывание

#### Вариант 1: Single Server (до 1000 пользователей)
```
Серверные требования:
- CPU: 4 ядра (2 для PostgreSQL, 2 для приложений)
- RAM: 8GB (4GB PostgreSQL, 4GB приложения + Redis)
- Disk: 50GB SSD (PostgreSQL + backups)
- Network: 100Mbps

Стек:
- Docker Compose в production режиме
- Nginx как reverse proxy
- Let's Encrypt для SSL
- Daily backups в S3
```

#### Вариант 2: Docker Swarm (1000-5000 пользователей)
```
Архитектура:
- 3 ноды Docker Swarm
- PostgreSQL на отдельной ноде с репликацией
- Redis кластер из 3 нод
- Сервисы с 2-3 репликами
- Load balancer (HAProxy)
```

### Мониторинг и алертинг

#### Базовый мониторинг
```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"

  loki:
    image: grafana/loki

  promtail:
    image: grafana/promtail
```

#### Ключевые метрики для мониторинга
1. API Gateway: RPS, latency, error rate
2. Profiling Service: Расчетное время, cache hit ratio
3. Recommendation Service: LLM latency, generation quality
4. PostgreSQL: Connections, query time, locks
5. Redis: Memory usage, hit ratio, connections

---

## Мониторинг и метрики

### Технические метрики

#### Latency метрики (целевые значения)
- API Gateway P95: < 100ms
- Profiling Service P95: < 200ms
- Recommendation Service P95: < 2s (с LLM)
- Кэшированные рекомендации P95: < 50ms

#### Throughput метрики
- Максимальный RPS на API Gateway: 50 RPS
- Одновременных пользователей: до 100
- Ежедневных рекомендаций: до 1000

#### Reliability метрики
- Error rate: < 1%
- Uptime: > 99.5%
- Cache hit ratio: > 90%
- LLM success rate: > 95%

### Бизнес метрики

#### User engagement
- Daily active users (DAU): > 30% от зарегистрированных
- Session duration: > 5 минут
- Recommendation views: > 80% от DAU
- Test completion rate: > 70%

#### Recommendation quality
- User rating average: > 4/5
- Activity completion rate: > 60%
- Feedback submission rate: > 20%
- Retention after 30 days: > 50%

#### Growth metrics
- New users per day: Целевой рост
- User acquisition cost: < $5
- Lifetime value: > $50
- Monthly recurring revenue: По модели подписки

### Dashboards

#### Технический дашборд (Grafana)
1. Общее состояние системы: Сервисы, БД, Redis
2. Производительность API: Latency, RPS, errors
3. Использование ресурсов: CPU, RAM, Disk, Network
4. Кэширование: Hit ratio, memory usage
5. Очереди и задачи: Pending, processing, completed

#### Бизнес дашборд (Metabase)
1. Пользовательская активность: DAU, WAU, MAU
2. Качество рекомендаций: Рейтинги, completion rate
3. Тестирование: Completion rate, результаты
4. Удержание: Retention cohorts
5. Монетизация: Подписки, конверсии

#### Исследовательский дашборд (Jupyter)
1. Корреляционный анализ: Астрология vs психология
2. Кластеризация пользователей: Похожие профили
3. Эффективность рекомендаций: A/B тестирование
4. Визуализация данных: Графики и диаграммы
5. Научные отчеты: Статистическая значимость

#### Инфраструктурные затраты
```
Фаза 1 (1000 users): $100-200/мес
Фаза 2 (5000 users): $300-500/мес  
Фаза 3 (10000 users): $800-1200/мес
Фаза 4 (20000+ users): $2000+/мес
```

#### Оптимизации стоимости
1. Reserved instances для долгосрочной экономии
2. Spot instances для фоновых задач
3. Auto-scaling по нагрузке
4. Caching для снижения нагрузки на БД
5. CDN для статики

---

## Ключевые преимущества архитектуры

### Для пользователей
- Глубокая персонализация на основе множества факторов
- Быстрые рекомендации благодаря кэшированию
- Надежность даже при частичных отказах
- Конфиденциальность - данные хранятся анонимно

### Для разработчиков
- Простая разработка - четкие границы сервисов
- Легкое тестирование - изолированные компоненты
- Гибкое развертывание - независимое обновление сервисов
- Полная наблюдаемость - метрики, логи, трейсинг

### Для бизнеса
- Масштабируемость - рост без переписывания
- Экономичность - оптимальное использование ресурсов
- Надежность - высокая доступность
- Аналитика - данные для принятия решений

### Для исследователей
- Богатый датасет - коррелированные данные
- Инструменты анализа - дашборды и визуализация
- Экспериментальная платформа - A/B тестирование
- Научная ценность - валидация методологий

---

## Резюме

Документированная архитектура представляет собой оптимальный баланс между сложностью и функциональностью для целевой аудитории 1000 пользователей. Она обеспечивает:

1. Глубокую персонализацию через интеграцию астрологии, психологии и ML
2. Высокую производительность благодаря кэшированию и оптимизациям
3. Надежность через resilience patterns и graceful degradation
4. Масштабируемость с четким планом роста до 10000+ пользователей
5. Развитость для исследовательской работы и научной валидации


# Personal Assistant Ecosystem

Полная микросервисная экосистема для персонализированных рекомендаций.

## 🚀 Быстрый старт

### Предварительные требования
- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ свободной памяти

### Установка

```bash
# 1. Клонирование репозитория
git clone <repository>
cd personal_assistant

# 2. Настройка окружения
cp .env.example .env
# Отредактируйте .env при необходимости

# 3. Полная установка
make setup

# 4. Запуск сервисов
make up

# 5. Проверка статуса
make status


