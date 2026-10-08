-- Запросы к базе данных фитнес-клуба (раздел 2.3) и проверки (раздел 2.4)
-- Сначала выполните fitness_club.sql
USE fitness_club;

-- Запрос а. Соединение таблиц по равенству полей в условии WHERE
SELECT c.last_name   AS Фамилия,
       c.first_name  AS Имя,
       m.card_number AS Карта,
       t.type_name   AS Тариф,
       m.end_date    AS Действует_до
FROM client c, membership m, membership_type t
WHERE c.client_id = m.client_id
  AND m.type_id   = t.type_id
  AND m.status    = 'активен'
ORDER BY m.end_date;

-- Запрос б. Тот же запрос с использованием INNER JOIN
SELECT c.last_name   AS Фамилия,
       c.first_name  AS Имя,
       m.card_number AS Карта,
       t.type_name   AS Тариф,
       m.end_date    AS Действует_до
FROM client c
  INNER JOIN membership m      ON m.client_id = c.client_id
  INNER JOIN membership_type t ON t.type_id   = m.type_id
WHERE m.status = 'активен'
ORDER BY m.end_date;

-- Запрос в. Использование процедурных возможностей SQL (команда CASE)
SELECT m.card_number AS Карта,
       CONCAT(c.last_name, ' ', c.first_name) AS Клиент,
       m.end_date AS Действует_до,
       DATEDIFF(m.end_date, '2026-10-07') AS Осталось_дней,
       CASE
         WHEN m.status = 'заморожен' THEN 'Заморожен'
         WHEN m.end_date < '2026-10-07' THEN 'Срок истёк'
         WHEN DATEDIFF(m.end_date, '2026-10-07') <= 7
              THEN 'Истекает в течение недели'
         WHEN DATEDIFF(m.end_date, '2026-10-07') <= 30
              THEN 'Истекает в течение месяца'
         ELSE 'Действует'
       END AS Состояние
FROM membership m
  INNER JOIN client c ON c.client_id = m.client_id
ORDER BY m.end_date;

-- Запрос г. Группировка, групповые функции и условие на группы (HAVING)
SELECT CONCAT(t.last_name, ' ', t.first_name) AS Тренер,
       COUNT(DISTINCT s.schedule_id) AS Занятий,
       COUNT(b.booking_id)           AS Записей,
       ROUND(COUNT(b.booking_id) /
             COUNT(DISTINCT s.schedule_id), 1) AS В_среднем_на_занятие
FROM trainer t
  INNER JOIN schedule s ON s.trainer_id = t.trainer_id
  LEFT JOIN booking b   ON b.schedule_id = s.schedule_id
                       AND b.status <> 'отменил'
WHERE s.start_time >= '2026-10-05'
  AND s.start_time <  '2026-10-12'
GROUP BY t.trainer_id, t.last_name, t.first_name
HAVING COUNT(DISTINCT s.schedule_id) >= 2
ORDER BY Записей DESC;

-- Запрос д. Левое внешнее соединение (LEFT JOIN)
SELECT CONCAT(c.last_name, ' ', c.first_name) AS Клиент,
       COUNT(DISTINCT m.membership_id) AS Абонементов,
       COUNT(v.visit_id)               AS Посещений,
       MAX(DATE(v.entry_time))         AS Последний_визит
FROM client c
  LEFT JOIN membership m ON m.client_id = c.client_id
  LEFT JOIN visit v      ON v.membership_id = m.membership_id
GROUP BY c.client_id, c.last_name, c.first_name
ORDER BY Посещений DESC, Клиент;

-- Запрос е. Вложенный подзапрос
SELECT m.card_number AS Карта,
       CONCAT(c.last_name, ' ', c.first_name) AS Клиент,
       t.type_name  AS Тариф,
       m.price_paid AS Оплачено
FROM membership m
  INNER JOIN client c          ON c.client_id = m.client_id
  INNER JOIN membership_type t ON t.type_id   = m.type_id
WHERE m.price_paid > (SELECT AVG(price_paid) FROM membership)
ORDER BY m.price_paid DESC;

-- Запрос ж. Представление создаётся в fitness_club.sql; выборка из него:
SELECT last_name   AS Фамилия,
       first_name  AS Имя,
       phone       AS Телефон,
       type_name   AS Тариф,
       end_date    AS Действует_до
FROM v_active_membership
WHERE end_date <= '2026-10-31'
ORDER BY end_date;

-- ============================================================
-- ПРОВЕРКИ ТРИГГЕРОВ И ПРОЦЕДУР (раздел 2.4).
-- Эти команды меняют данные. Команды с пометкой ОШИБКА должны
-- завершаться сообщением об ошибке: так и задумано.
-- Чтобы вернуть базу в исходное состояние, заново выполните fitness_club.sql
-- ============================================================

-- Триггер 1: дата окончания и цена подставляются сами
INSERT INTO membership (client_id, type_id, card_number, start_date)
VALUES (10, 3, 'FC000011', '2026-10-07');
SELECT card_number AS Карта, start_date AS Начало, end_date AS Окончание,
       price_paid AS Оплачено, status AS Статус
FROM membership
WHERE card_number = 'FC000011';

-- Триггер 2: ОШИБКА, абонемент истёк
INSERT INTO visit (membership_id, entry_time)
VALUES (6, '2026-10-07 18:30:00');

-- Триггер 2: проход по действующему абонементу
INSERT INTO visit (membership_id, entry_time)
VALUES (11, '2026-10-07 18:35:00');
SELECT v.visit_id AS Номер, m.card_number AS Карта,
       v.entry_time AS Вход, v.exit_time AS Выход
FROM visit v
  INNER JOIN membership m ON m.membership_id = v.membership_id
WHERE m.card_number = 'FC000011';

-- Триггер 3: ОШИБКА, мест нет
INSERT INTO booking (schedule_id, client_id, booked_at)
VALUES (6, 1, '2026-10-07 12:00:00');

-- Триггер 3: ОШИБКА, абонемент заморожен
INSERT INTO booking (schedule_id, client_id, booked_at)
VALUES (9, 9, '2026-10-07 12:05:00');

-- Триггер 3: запись проходит
INSERT INTO booking (schedule_id, client_id, booked_at)
VALUES (9, 10, '2026-10-07 12:10:00');
SELECT b.booking_id AS Номер, s.start_time AS Занятие,
       c.last_name AS Клиент, b.status AS Статус
FROM booking b
  INNER JOIN schedule s ON s.schedule_id = b.schedule_id
  INNER JOIN client c   ON c.client_id   = b.client_id
WHERE b.schedule_id = 9;

-- Процедура 1: ОШИБКА, заморозка не предусмотрена тарифом
CALL sp_freeze_membership(2, 10);

-- Процедура 1: заморозка на 14 дней
CALL sp_freeze_membership(3, 14);
SELECT card_number AS Карта, end_date AS Окончание, status AS Статус
FROM membership
WHERE membership_id = 3;

-- Процедура 2: закрытие просроченных абонементов
CALL sp_close_expired('2026-10-15', @closed);
SELECT @closed AS Закрыто_абонементов;
SELECT card_number AS Карта, end_date AS Окончание, status AS Статус
FROM membership
WHERE end_date < '2026-10-15'
ORDER BY end_date;

