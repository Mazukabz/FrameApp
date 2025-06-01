-- Frame Database Schema
-- Архитектура "Калашников": простая, надежная, расширяемая

-- Удаление таблиц если существуют (для чистой установки)
DROP TABLE IF EXISTS watch_history CASCADE;
DROP TABLE IF EXISTS favorites CASCADE;
DROP TABLE IF EXISTS movies CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ==================== ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ ====================
-- Хранит основную информацию о пользователях системы
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,      -- Email для входа
    username VARCHAR(50) NOT NULL,           -- Отображаемое имя
    password_hash VARCHAR(255) NOT NULL,     -- Хеш пароля (bcrypt)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE           -- Для деактивации аккаунтов
);

-- Индексы для таблицы users
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_username ON users (username);

-- ==================== ТАБЛИЦА ФИЛЬМОВ ====================
-- Основная таблица с информацией о фильмах
CREATE TABLE movies (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,             -- Название фильма
    genre VARCHAR(50) NOT NULL,              -- Жанр
    duration INTEGER NOT NULL CHECK (duration > 0),  -- Длительность в минутах
    rating DECIMAL(2,1) CHECK (rating >= 0 AND rating <= 5),  -- Рейтинг от 0 до 5
    description TEXT,                        -- Описание
    poster_url VARCHAR(500),                 -- URL постера
    is_new BOOLEAN DEFAULT FALSE,            -- Флаг новинки
    views_count INTEGER DEFAULT 0,           -- Счетчик просмотров
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL  -- Кто загрузил
);

-- Индексы для таблицы movies
CREATE INDEX idx_movies_genre ON movies (genre);
CREATE INDEX idx_movies_created_at ON movies (created_at DESC);
CREATE INDEX idx_movies_rating ON movies (rating DESC);
CREATE INDEX idx_movies_user_id ON movies (user_id);

-- ==================== ТАБЛИЦА ИЗБРАННОГО ====================
-- Связь пользователей с их любимыми фильмами
CREATE TABLE favorites (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Уникальный индекс предотвращает дубликаты
    UNIQUE(user_id, movie_id)
);

-- Индексы для таблицы favorites
CREATE INDEX idx_favorites_user_id ON favorites (user_id);
CREATE INDEX idx_favorites_movie_id ON favorites (movie_id);

-- ==================== ТАБЛИЦА ИСТОРИИ ПРОСМОТРОВ ====================
-- История просмотров фильмов пользователями
CREATE TABLE watch_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id INTEGER NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Время просмотра
    progress INTEGER DEFAULT 0,                      -- Прогресс просмотра в процентах
    
    -- Один фильм может быть в истории только один раз
    UNIQUE(user_id, movie_id)
);

-- Индексы для таблицы watch_history
CREATE INDEX idx_history_user_id ON watch_history (user_id);
CREATE INDEX idx_history_movie_id ON watch_history (movie_id);
CREATE INDEX idx_history_watched_at ON watch_history (watched_at DESC);

-- ==================== ТЕСТОВЫЕ ДАННЫЕ ====================
-- Добавляем начальные данные для тестирования

-- Тестовый пользователь (пароль: password123)
INSERT INTO users (email, username, password_hash) VALUES
('test@example.com', 'Test User', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiGBzf4/XrBa'),
('admin@frame.com', 'Admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiGBzf4/XrBa');

-- Тестовые фильмы с реальными постерами
INSERT INTO movies (title, genre, duration, rating, description, poster_url, is_new, user_id) VALUES
('Neural City', 'scifi', 15, 4.8, 'In a world where artificial intelligence controls urban infrastructure, one programmer discovers a hidden threat.', 'https://i.ibb.co/WkFLPVh/0-11.jpg', true, 1),
('Digital Dreams', 'drama', 8, 4.5, 'A touching story about a person who can see dreams created by AI.', 'https://i.ibb.co/7gX5PXg/0-1.jpg', true, 1),
('Algorithm of Love', 'comedy', 22, 4.2, 'A romantic comedy about a programmer who creates an AI to find the perfect partner.', 'https://i.ibb.co/WPLSTQY/0-12.jpg', false, 1),
('The Last Human', 'postapoc', 25, 4.9, 'In a world populated only by AI, the last human searches for traces of humanity.', 'https://i.ibb.co/Bq6Y7hG/0-2.jpg', false, 2),
('Forest Spirit', 'fantasy', 19, 4.7, 'A mystical encounter in an ancient forest where technology meets nature.', 'https://i.ibb.co/xfn4hPn/0-9.jpg', true, 2),
('Realm of Powers', 'adventure', 24, 4.8, 'Three children discover magical powers in a world threatened by darkness.', 'https://i.ibb.co/Kh8LMKG/0-10.jpg', false, 1),
('Ocean Call', 'adventure', 21, 4.5, 'Fishermen encounter mysterious forces in the deep sea.', 'https://i.ibb.co/QPqzG7F/0-3.jpg', true, 2),
('Ancient Secrets', 'adventure', 23, 4.6, 'Archaeologists uncover a civilization that should not exist.', 'https://i.ibb.co/Pt0sYqG/0-4.jpg', false, 1);

-- Добавляем несколько фильмов в избранное для тестового пользователя
INSERT INTO favorites (user_id, movie_id) VALUES
(1, 1), (1, 3), (1, 5);

-- Добавляем историю просмотров
INSERT INTO watch_history (user_id, movie_id, progress) VALUES
(1, 1, 100), (1, 2, 75), (1, 3, 100), (1, 4, 30);

-- ==================== ПОЛЕЗНЫЕ ЗАПРОСЫ ====================
-- Примеры запросов для работы с данными

-- Получить популярные фильмы (по рейтингу и просмотрам)
-- SELECT * FROM movies ORDER BY rating DESC, views_count DESC LIMIT 10;

-- Получить фильмы пользователя из избранного
-- SELECT m.* FROM movies m 
-- JOIN favorites f ON m.id = f.movie_id 
-- WHERE f.user_id = 1;

-- Статистика пользователя
-- SELECT 
--     COUNT(DISTINCT wh.movie_id) as watched_count,
--     COUNT(DISTINCT f.movie_id) as favorites_count,
--     COUNT(DISTINCT m.id) as uploaded_count
-- FROM users u
-- LEFT JOIN watch_history wh ON u.id = wh.user_id
-- LEFT JOIN favorites f ON u.id = f.user_id
-- LEFT JOIN movies m ON u.id = m.user_id
-- WHERE u.id = 1;

-- Создание резервной копии
-- pg_dump -U frame_user -d frame_db > backup.sql

-- Восстановление из резервной копии
-- psql -U frame_user -d frame_db < backup.sql