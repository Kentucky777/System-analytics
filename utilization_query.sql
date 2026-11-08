-- Аналитический запрос: Расчёт загрузки мест (Utilization Rate)
-- за прошлую календарную неделю с разбивкой по клубам

WITH bounds AS (
    -- 1. Определяем точные временные границы прошлой недели (ПН 00:00 - ПН 00:00)
    SELECT 
        date_trunc('week', NOW()) - INTERVAL '1 week' AS week_start,
        date_trunc('week', NOW())                     AS week_end
),

club_seats AS (
    -- 2. Считаем общее количество мест в каждом клубе для определения фонда часов
    SELECT 
        club_id,
        COUNT(seat_id) AS total_seats
    FROM seats
    GROUP BY club_id
),

sess_hours AS (
    -- 3. Наигранные игроками часы с интервальной обрезкой хвостов сессий
    SELECT 
        st.club_id, 
        SUM(
            EXTRACT(EPOCH FROM (
                LEAST(COALESCE(ses.time_end, NOW()), b.week_end) 
                - 
                GREATEST(ses.time_start, b.week_start)
            )) / 3600.0
        ) AS hours
    FROM sessions ses 
    JOIN seats st ON st.seat_id = ses.seat_id 
    CROSS JOIN bounds b
    -- Оставляем только те сессии, которые пересекались с прошлой неделей
    WHERE ses.time_start < b.week_end 
      AND COALESCE(ses.time_end, NOW()) > b.week_start
    GROUP BY st.club_id
),

unavail_hours AS (
    -- 4. Часы нерабочего состояния ПК
    SELECT 
        st.club_id, 
        SUM(
            EXTRACT(EPOCH FROM (
                LEAST(COALESCE(u.time_end, NOW()), b.week_end) 
                - 
                GREATEST(u.time_start, b.week_start)
            )) / 3600.0
        ) AS hours
    FROM unavailable u
    JOIN seats st ON st.seat_id = u.seat_id 
    CROSS JOIN bounds b
    WHERE u.time_start < b.week_end 
      AND COALESCE(u.time_end, NOW()) > b.week_start
    GROUP BY st.club_id
)

-- 5. Итоговый расчет: Отыгранные часы / (Теоретический фонд - Часы простоев)
SELECT 
    cs.club_id,
    cs.total_seats,
    ROUND(COALESCE(s.hours, 0)::numeric, 2) AS played_hours,
    -- Доступный фонд: (количество компов * 168 ч) минус часы простоя
    ROUND(((cs.total_seats * 168) - COALESCE(u.hours, 0))::numeric, 2) AS available_hours,
    -- Процент загрузки с защитой от деления на 0 через NULLIF
    ROUND(
        (
            COALESCE(s.hours, 0) * 100.0 
            / 
            NULLIF((cs.total_seats * 168) - COALESCE(u.hours, 0), 0)
        )::numeric, 
        2
    ) AS utilization_pct
FROM club_seats cs
LEFT JOIN sess_hours s ON s.club_id = cs.club_id
LEFT JOIN unavail_hours u ON u.club_id = cs.club_id
ORDER BY cs.club_id;
