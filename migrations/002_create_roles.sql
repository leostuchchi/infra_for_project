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
