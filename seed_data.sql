-- ==========================================================
-- Тестовые данные для проверки расчета утилизации
-- Включают все граничные случаи:
-- 1. Сессия строго внутри недели
-- 2. Сессия через границу начала недели (стартовала до ПН)
-- 3. Сессия через границу конца недели (ушла на след. неделю)
-- 4. Активная незавершённая сессия (time_end IS NULL)
-- 5. Место на ремонте (законченный ремонт и текущий ремонт)
-- ==========================================================

-- Добавляем клубы
INSERT INTO clubs (club_id, name, address) VALUES
(1, 'Colizeum Тверская', 'Москва, ул. Тверская, 7'),
(2, 'Colizeum Арена', 'Москва, Ленинградский пр-т, 36')
ON CONFLICT (club_id) DO NOTHING;

-- Добавляем места (в клубе 1 - 3 места, в клубе 2 - 2 места)
INSERT INTO seats (seat_id, club_id, seat_number, seat_type) VALUES
(1, 1, 1, 'VIP'),
(2, 1, 2, 'Standard'),
(3, 1, 3, 'Standard'),
(4, 2, 1, 'Standard'),
(5, 2, 2, 'Bootcamp')
ON CONFLICT (seat_id) DO NOTHING;

-- Динамические даты относительно прошлой недели:
-- w_start = понедельник прошлой недели 00:00:00
-- w_end   = понедельник текущей недели 00:00:00
DO $$
DECLARE
    w_start TIMESTAMPTZ := date_trunc('week', NOW()) - INTERVAL '1 week';
    w_end   TIMESTAMPTZ := date_trunc('week', NOW());
BEGIN
    -- Сессия 1: Полностью внутри прошлой недели (Вторник 10:00 - 15:00, ровно 5 часов)
    INSERT INTO sessions (seat_id, time_start, time_end)
    VALUES (1, w_start + INTERVAL '1 day 10 hours', w_start + INTERVAL '1 day 15 hours');

    -- Сессия 2: Пересекает начало недели (Началась в воскресенье позапрошлой недели в 20:00,
    -- закончилась в понедельник в 04:00. В зачет должно пойти ровно 4 часа!)
    INSERT INTO sessions (seat_id, time_start, time_end)
    VALUES (2, w_start - INTERVAL '4 hours', w_start + INTERVAL '4 hours');

    -- Сессия 3: Пересекает конец недели (Началась в воскресенье в 22:00,
    -- закончилась в понедельник текущей недели в 03:00. В зачет должно пойти ровно 2 часа!)
    INSERT INTO sessions (seat_id, time_start, time_end)
    VALUES (3, w_end - INTERVAL '2 hours', w_end + INTERVAL '3 hours');

    -- Сессия 4 (Клуб 2): Активная сессия, начавшаяся в пятницу прошлой недели и всё ещё длящаяся (NULL)
    -- В зачет прошлой недели должно пойти время от пятницы до конца недели w_end!
    INSERT INTO sessions (seat_id, time_start, time_end)
    VALUES (4, w_start + INTERVAL '4 days 12 hours', NULL);

    -- Простой 1 (Клуб 1, Место 2): Ремонт видеокарты со среды 00:00 до четверга 00:00 (ровно 24 часа)
    INSERT INTO unavailable (seat_id, time_start, time_end, reason)
    VALUES (2, w_start + INTERVAL '2 days', w_start + INTERVAL '3 days', 'Замена кулера на GPU');

END $$;
