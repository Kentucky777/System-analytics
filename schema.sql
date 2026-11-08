-- ==========================================================
-- Схема базы данных сети киберспортивных клубов Colizeum
-- СУБД: PostgreSQL (версия 13+)
-- ==========================================================

-- 1. Справочник клубов
CREATE TABLE IF NOT EXISTS clubs (
    club_id     SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    address     VARCHAR(255) NOT NULL,
    timezone    VARCHAR(50)  NOT NULL DEFAULT 'Europe/Moscow',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 2. Места (игровые ПК / консоли)
CREATE TABLE IF NOT EXISTS seats (
    seat_id     SERIAL PRIMARY KEY,
    club_id     INT NOT NULL REFERENCES clubs(club_id) ON DELETE CASCADE,
    seat_number INT NOT NULL,
    seat_type   VARCHAR(30) NOT NULL DEFAULT 'Standard', -- Standard, VIP, Bootcamp, Console
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_club_seat UNIQUE (club_id, seat_number)
);

-- 3. Бронирования мест пользователями
CREATE TABLE IF NOT EXISTS bookings (
    booking_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     INT NOT NULL,
    seat_id     INT NOT NULL REFERENCES seats(seat_id) ON DELETE RESTRICT,
    time_start  TIMESTAMPTZ NOT NULL,
    time_end    TIMESTAMPTZ NOT NULL,
    price       NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    status      VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, CONFIRMED, CANCELLED, COMPLETED
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_booking_dates CHECK (time_end > time_start)
);

-- 4. Фактические игровые сессии
CREATE TABLE IF NOT EXISTS sessions (
    session_id  SERIAL PRIMARY KEY,
    seat_id     INT NOT NULL REFERENCES seats(seat_id) ON DELETE RESTRICT,
    booking_id  UUID REFERENCES bookings(booking_id) ON DELETE SET NULL, -- NULL, если посадка без брони
    time_start  TIMESTAMPTZ NOT NULL,
    time_end    TIMESTAMPTZ, -- NULL означает активную игровую сессию
    CONSTRAINT chk_session_dates CHECK (time_end IS NULL OR time_end > time_start)
);

-- 5. Журнал технического обслуживания и поломок оборудования
CREATE TABLE IF NOT EXISTS unavailable (
    unavailable_id SERIAL PRIMARY KEY,
    seat_id        INT NOT NULL REFERENCES seats(seat_id) ON DELETE RESTRICT,
    time_start     TIMESTAMPTZ NOT NULL,
    time_end       TIMESTAMPTZ, -- NULL означает, что место прямо сейчас в ремонте
    reason         VARCHAR(255) NOT NULL,
    CONSTRAINT chk_unavail_dates CHECK (time_end IS NULL OR time_end > time_start)
);

-- Индексы для оптимизации выборок за интервалы времени
CREATE INDEX IF NOT EXISTS idx_sessions_time ON sessions(time_start, time_end);
CREATE INDEX IF NOT EXISTS idx_unavailable_time ON unavailable(time_start, time_end);
CREATE INDEX IF NOT EXISTS idx_bookings_seat_time ON bookings(seat_id, time_start, time_end);
