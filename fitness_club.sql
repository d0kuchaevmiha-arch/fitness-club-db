-- ============================================================
-- База данных фитнес-клуба. Полный скрипт: структура, данные,
-- представления, триггеры и процедуры. MySQL 8.0
-- Запуск в MySQL Workbench: File -> Open SQL Script -> выполнить весь файл
-- ============================================================

-- База данных фитнес-клуба. Сценарий создания объектов (MySQL 8.0)
DROP DATABASE IF EXISTS fitness_club;
CREATE DATABASE fitness_club
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE fitness_club;

-- Типы абонементов (тарифы)
CREATE TABLE membership_type (
  type_id       INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  type_name     VARCHAR(60)       NOT NULL,
  duration_days SMALLINT UNSIGNED NOT NULL,
  visit_limit   SMALLINT UNSIGNED NULL,
  price         DECIMAL(10,2)     NOT NULL,
  freeze_days   TINYINT UNSIGNED  NOT NULL DEFAULT 0,
  CONSTRAINT pk_membership_type PRIMARY KEY (type_id),
  CONSTRAINT uq_type_name UNIQUE (type_name),
  CONSTRAINT chk_type_price CHECK (price >= 0),
  CONSTRAINT chk_type_duration CHECK (duration_days > 0)
) ENGINE = InnoDB;

-- Клиенты
CREATE TABLE client (
  client_id   INT UNSIGNED   NOT NULL AUTO_INCREMENT,
  last_name   VARCHAR(50)    NOT NULL,
  first_name  VARCHAR(50)    NOT NULL,
  middle_name VARCHAR(50)    NULL,
  birth_date  DATE           NOT NULL,
  gender      ENUM('М','Ж')  NOT NULL,
  phone       CHAR(12)       NOT NULL,
  email       VARCHAR(100)   NULL,
  reg_date    DATE           NOT NULL,
  CONSTRAINT pk_client PRIMARY KEY (client_id),
  CONSTRAINT uq_client_phone UNIQUE (phone),
  CONSTRAINT uq_client_email UNIQUE (email)
) ENGINE = InnoDB;

-- Абонементы (клубные карты), проданные клиентам
CREATE TABLE membership (
  membership_id INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  client_id     INT UNSIGNED  NOT NULL,
  type_id       INT UNSIGNED  NOT NULL,
  card_number   CHAR(8)       NOT NULL,
  start_date    DATE          NOT NULL,
  end_date      DATE          NOT NULL,
  price_paid    DECIMAL(10,2) NOT NULL,
  status        ENUM('активен','заморожен','истёк')
                              NOT NULL DEFAULT 'активен',
  CONSTRAINT pk_membership PRIMARY KEY (membership_id),
  CONSTRAINT uq_membership_card UNIQUE (card_number),
  CONSTRAINT fk_membership_client FOREIGN KEY (client_id)
    REFERENCES client (client_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_membership_type FOREIGN KEY (type_id)
    REFERENCES membership_type (type_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_membership_dates CHECK (end_date >= start_date),
  CONSTRAINT chk_membership_price CHECK (price_paid >= 0)
) ENGINE = InnoDB;

-- Тренеры
CREATE TABLE trainer (
  trainer_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  last_name      VARCHAR(50)   NOT NULL,
  first_name     VARCHAR(50)   NOT NULL,
  middle_name    VARCHAR(50)   NULL,
  specialization VARCHAR(80)   NOT NULL,
  phone          CHAR(12)      NOT NULL,
  hire_date      DATE          NOT NULL,
  hour_rate      DECIMAL(8,2)  NOT NULL,
  CONSTRAINT pk_trainer PRIMARY KEY (trainer_id),
  CONSTRAINT uq_trainer_phone UNIQUE (phone),
  CONSTRAINT chk_trainer_rate CHECK (hour_rate > 0)
) ENGINE = InnoDB;

-- Залы
CREATE TABLE hall (
  hall_id   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  hall_name VARCHAR(60)       NOT NULL,
  capacity  SMALLINT UNSIGNED NOT NULL,
  area      DECIMAL(6,1)      NOT NULL,
  CONSTRAINT pk_hall PRIMARY KEY (hall_id),
  CONSTRAINT uq_hall_name UNIQUE (hall_name)
) ENGINE = InnoDB;

-- Оборудование, закреплённое за залами
CREATE TABLE equipment (
  equipment_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  hall_id        INT UNSIGNED NOT NULL,
  equipment_name VARCHAR(100) NOT NULL,
  inventory_no   VARCHAR(10)  NOT NULL,
  purchase_date  DATE         NOT NULL,
  state          ENUM('исправно','в ремонте','списано')
                              NOT NULL DEFAULT 'исправно',
  CONSTRAINT pk_equipment PRIMARY KEY (equipment_id),
  CONSTRAINT uq_equipment_inv UNIQUE (inventory_no),
  CONSTRAINT fk_equipment_hall FOREIGN KEY (hall_id)
    REFERENCES hall (hall_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Виды тренировок
CREATE TABLE workout (
  workout_id   INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  workout_name VARCHAR(80)       NOT NULL,
  workout_kind ENUM('групповая','персональная') NOT NULL,
  duration_min SMALLINT UNSIGNED NOT NULL,
  extra_price  DECIMAL(8,2)      NOT NULL DEFAULT 0,
  CONSTRAINT pk_workout PRIMARY KEY (workout_id),
  CONSTRAINT uq_workout_name UNIQUE (workout_name),
  CONSTRAINT chk_workout_duration CHECK (duration_min BETWEEN 15 AND 240)
) ENGINE = InnoDB;

-- Расписание занятий
CREATE TABLE schedule (
  schedule_id INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  workout_id  INT UNSIGNED      NOT NULL,
  trainer_id  INT UNSIGNED      NOT NULL,
  hall_id     INT UNSIGNED      NOT NULL,
  start_time  DATETIME          NOT NULL,
  max_places  SMALLINT UNSIGNED NOT NULL,
  CONSTRAINT pk_schedule PRIMARY KEY (schedule_id),
  CONSTRAINT uq_schedule_hall UNIQUE (hall_id, start_time),
  CONSTRAINT uq_schedule_trainer UNIQUE (trainer_id, start_time),
  CONSTRAINT fk_schedule_workout FOREIGN KEY (workout_id)
    REFERENCES workout (workout_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_schedule_trainer FOREIGN KEY (trainer_id)
    REFERENCES trainer (trainer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_schedule_hall FOREIGN KEY (hall_id)
    REFERENCES hall (hall_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_schedule_places CHECK (max_places > 0)
) ENGINE = InnoDB;

-- Записи клиентов на занятия
CREATE TABLE booking (
  booking_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  schedule_id INT UNSIGNED NOT NULL,
  client_id   INT UNSIGNED NOT NULL,
  booked_at   DATETIME     NOT NULL,
  status      ENUM('записан','посетил','отменил')
                           NOT NULL DEFAULT 'записан',
  CONSTRAINT pk_booking PRIMARY KEY (booking_id),
  CONSTRAINT uq_booking UNIQUE (schedule_id, client_id),
  CONSTRAINT fk_booking_schedule FOREIGN KEY (schedule_id)
    REFERENCES schedule (schedule_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_booking_client FOREIGN KEY (client_id)
    REFERENCES client (client_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Посещения клуба (проход по клубной карте)
CREATE TABLE visit (
  visit_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  membership_id INT UNSIGNED NOT NULL,
  entry_time    DATETIME     NOT NULL,
  exit_time     DATETIME     NULL,
  CONSTRAINT pk_visit PRIMARY KEY (visit_id),
  CONSTRAINT fk_visit_membership FOREIGN KEY (membership_id)
    REFERENCES membership (membership_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_visit_times
    CHECK (exit_time IS NULL OR exit_time > entry_time)
) ENGINE = InnoDB;

-- Индексы для частых условий поиска
CREATE INDEX idx_client_name     ON client (last_name, first_name);
CREATE INDEX idx_membership_end  ON membership (end_date, status);
CREATE INDEX idx_schedule_start  ON schedule (start_time);
CREATE INDEX idx_visit_entry     ON visit (entry_time);

-- Представление: расписание в читаемом виде
CREATE VIEW v_schedule_full AS
SELECT s.schedule_id,
       s.start_time,
       w.workout_name,
       w.workout_kind,
       CONCAT(t.last_name, ' ', t.first_name) AS trainer_name,
       h.hall_name,
       s.max_places
FROM schedule s
  INNER JOIN workout w ON w.workout_id = s.workout_id
  INNER JOIN trainer t ON t.trainer_id = s.trainer_id
  INNER JOIN hall    h ON h.hall_id    = s.hall_id;

-- Заполнение таблиц тестовыми данными

INSERT INTO membership_type
  (type_id, type_name, duration_days, visit_limit, price, freeze_days) VALUES
  (1, 'Разовое посещение',            1,   1,     800.00,  0),
  (2, 'Месяц, 8 посещений',          30,   8,    3200.00,  0),
  (3, 'Месяц, безлимит',             30,   NULL, 4500.00,  0),
  (4, 'Три месяца, безлимит',        90,   NULL, 11500.00, 14),
  (5, 'Полгода, безлимит',          180,   NULL, 19900.00, 30),
  (6, 'Год, безлимит',              365,   NULL, 32000.00, 60),
  (7, 'Дневной, месяц (до 17:00)',   30,   NULL, 2900.00,  0);

INSERT INTO client
  (client_id, last_name, first_name, middle_name, birth_date, gender,
   phone, email, reg_date) VALUES
  (1,  'Соколов',    'Артём',     'Игоревич',   '1998-03-14', 'М',
       '+79161110101', 'sokolov.a@example.ru',   '2025-11-02'),
  (2,  'Кузнецова',  'Мария',     'Андреевна',  '2001-07-22', 'Ж',
       '+79161110102', 'kuznetsova.m@example.ru','2026-09-20'),
  (3,  'Орлов',      'Дмитрий',   'Сергеевич',  '1989-12-05', 'М',
       '+79161110103', 'orlov.d@example.ru',     '2026-04-28'),
  (4,  'Белова',     'Анна',      'Викторовна', '1995-05-30', 'Ж',
       '+79161110104', 'belova.a@example.ru',    '2026-09-25'),
  (5,  'Тихонов',    'Павел',     'Олегович',   '2003-09-11', 'М',
       '+79161110105', 'tikhonov.p@example.ru',  '2026-07-15'),
  (6,  'Громова',    'Екатерина', 'Юрьевна',    '1992-01-19', 'Ж',
       '+79161110106', 'gromova.e@example.ru',   '2026-08-20'),
  (7,  'Зайцев',     'Илья',      'Романович',  '1985-08-08', 'М',
       '+79161110107', 'zaytsev.i@example.ru',   '2025-12-01'),
  (8,  'Мельникова', 'Ольга',     'Павловна',   '1978-04-27', 'Ж',
       '+79161110108', NULL,                     '2026-09-28'),
  (9,  'Фролов',     'Никита',    'Алексеевич', '2005-02-16', 'М',
       '+79161110109', 'frolov.n@example.ru',    '2026-08-01'),
  (10, 'Жукова',     'Дарья',     'Максимовна', '1999-10-03', 'Ж',
       '+79161110110', 'zhukova.d@example.ru',   '2026-10-06');

INSERT INTO membership
  (membership_id, client_id, type_id, card_number, start_date, end_date,
   price_paid, status) VALUES
  (1,  1, 6, 'FC000001', '2026-01-10', '2027-01-10', 32000.00, 'активен'),
  (2,  2, 3, 'FC000002', '2026-09-20', '2026-10-20',  4500.00, 'активен'),
  (3,  3, 5, 'FC000003', '2026-05-01', '2026-10-28', 19900.00, 'активен'),
  (4,  4, 2, 'FC000004', '2026-09-25', '2026-10-25',  3200.00, 'активен'),
  (5,  5, 4, 'FC000005', '2026-07-15', '2026-10-13', 11500.00, 'активен'),
  (6,  6, 3, 'FC000006', '2026-08-20', '2026-09-19',  4500.00, 'истёк'),
  (7,  7, 6, 'FC000007', '2025-12-01', '2026-12-01', 30400.00, 'активен'),
  (8,  8, 7, 'FC000008', '2026-09-28', '2026-10-28',  2900.00, 'активен'),
  (9,  9, 4, 'FC000009', '2026-08-01', '2026-11-13', 11500.00, 'заморожен'),
  (10, 6, 2, 'FC000010', '2026-10-01', '2026-10-31',  3200.00, 'активен');

INSERT INTO trainer
  (trainer_id, last_name, first_name, middle_name, specialization,
   phone, hire_date, hour_rate) VALUES
  (1, 'Воронин',   'Алексей', 'Петрович',   'Силовой тренинг',
      '+79162220201', '2022-03-01', 1800.00),
  (2, 'Лебедева',  'Ирина',   'Сергеевна',  'Йога и пилатес',
      '+79162220202', '2023-09-15', 1500.00),
  (3, 'Назаров',   'Тимур',   'Рашидович',  'Бокс',
      '+79162220203', '2021-11-10', 1700.00),
  (4, 'Савельева', 'Юлия',    'Олеговна',   'Кардиопрограммы',
      '+79162220204', '2024-02-05', 1400.00),
  (5, 'Крылов',    'Максим',  'Денисович',  'Функциональный тренинг',
      '+79162220205', '2023-01-20', 1600.00),
  (6, 'Ершова',    'Полина',  'Игоревна',   'Стретчинг',
      '+79162220206', '2025-06-01', 1300.00),
  (7, 'Абрамов',   'Роман',   'Витальевич', 'Плавание',
      '+79162220207', '2026-09-01', 1500.00);

INSERT INTO hall (hall_id, hall_name, capacity, area) VALUES
  (1, 'Тренажёрный зал',         40, 320.0),
  (2, 'Зал групповых программ',  20, 110.5),
  (3, 'Зал йоги',                14,  72.0),
  (4, 'Кардиозона',              18,  95.0),
  (5, 'Зал единоборств',         12,  80.5),
  (6, 'Бассейн',                 16, 250.0);

INSERT INTO equipment
  (equipment_id, hall_id, equipment_name, inventory_no, purchase_date,
   state) VALUES
  (1, 4, 'Беговая дорожка',            'CD-0001', '2023-02-14', 'исправно'),
  (2, 4, 'Велотренажёр для сайкла',    'CD-0002', '2023-02-14', 'исправно'),
  (3, 4, 'Эллиптический тренажёр',     'CD-0003', '2022-08-30', 'в ремонте'),
  (4, 1, 'Силовая рама',               'TZ-0001', '2021-10-05', 'исправно'),
  (5, 1, 'Скамья для жима',            'TZ-0002', '2021-10-05', 'исправно'),
  (6, 1, 'Гантельный ряд 2-40 кг',     'TZ-0003', '2024-04-18', 'исправно'),
  (7, 5, 'Боксёрский мешок',           'ED-0001', '2020-06-22', 'списано'),
  (8, 3, 'Комплект ковриков для йоги', 'YG-0001', '2025-01-12', 'исправно');

INSERT INTO workout
  (workout_id, workout_name, workout_kind, duration_min, extra_price) VALUES
  (1, 'Йога',                    'групповая',    60,    0.00),
  (2, 'Пилатес',                 'групповая',    55,    0.00),
  (3, 'Функциональный тренинг',  'групповая',    60,    0.00),
  (4, 'Сайкл',                   'групповая',    45,    0.00),
  (5, 'Бокс',                    'групповая',    90,  300.00),
  (6, 'Стретчинг',               'групповая',    50,    0.00),
  (7, 'Персональная тренировка', 'персональная', 60, 2500.00);

INSERT INTO schedule
  (schedule_id, workout_id, trainer_id, hall_id, start_time, max_places)
VALUES
  (1,  1, 2, 3, '2026-10-05 19:00:00', 12),
  (2,  3, 5, 2, '2026-10-05 20:00:00', 15),
  (3,  5, 3, 5, '2026-10-06 19:30:00', 10),
  (4,  4, 4, 4, '2026-10-06 18:00:00',  8),
  (5,  2, 2, 3, '2026-10-07 10:00:00', 12),
  (6,  7, 1, 1, '2026-10-07 18:00:00',  1),
  (7,  6, 6, 2, '2026-10-08 19:00:00', 15),
  (8,  1, 2, 3, '2026-10-08 20:00:00', 12),
  (9,  5, 3, 5, '2026-10-09 19:30:00', 10),
  (10, 3, 5, 2, '2026-10-10 12:00:00', 15);

INSERT INTO booking
  (booking_id, schedule_id, client_id, booked_at, status) VALUES
  (1,  1, 2, '2026-10-03 12:10:00', 'посетил'),
  (2,  1, 4, '2026-10-04 09:35:00', 'посетил'),
  (3,  1, 6, '2026-10-04 21:02:00', 'отменил'),
  (4,  2, 1, '2026-10-02 18:44:00', 'посетил'),
  (5,  2, 5, '2026-10-05 08:15:00', 'посетил'),
  (6,  2, 3, '2026-10-05 10:20:00', 'посетил'),
  (7,  3, 7, '2026-10-01 14:00:00', 'посетил'),
  (8,  3, 5, '2026-10-05 22:30:00', 'посетил'),
  (9,  4, 1, '2026-10-05 21:15:00', 'посетил'),
  (10, 4, 2, '2026-10-06 08:05:00', 'отменил'),
  (11, 5, 8, '2026-10-05 11:40:00', 'посетил'),
  (12, 5, 4, '2026-10-06 19:20:00', 'посетил'),
  (13, 6, 3, '2026-10-01 09:00:00', 'посетил'),
  (14, 7, 6, '2026-10-06 20:50:00', 'записан'),
  (15, 8, 2, '2026-10-06 20:11:00', 'записан'),
  (16, 8, 4, '2026-10-07 08:30:00', 'записан'),
  (17, 9, 7, '2026-10-06 21:40:00', 'записан'),
  (18, 9, 5, '2026-10-07 07:55:00', 'записан'),
  (19, 10, 1, '2026-10-06 22:05:00', 'записан'),
  (20, 10, 8, '2026-10-07 11:25:00', 'записан');

INSERT INTO visit (visit_id, membership_id, entry_time, exit_time) VALUES
  (1,  9,  '2026-08-05 18:00:00', '2026-08-05 19:20:00'),
  (2,  6,  '2026-09-10 19:00:00', '2026-09-10 20:20:00'),
  (3,  6,  '2026-09-17 19:05:00', '2026-09-17 20:30:00'),
  (4,  3,  '2026-09-29 07:30:00', '2026-09-29 08:45:00'),
  (5,  1,  '2026-10-01 18:05:00', '2026-10-01 19:40:00'),
  (6,  2,  '2026-10-02 18:30:00', '2026-10-02 19:50:00'),
  (7,  7,  '2026-10-03 11:00:00', '2026-10-03 12:30:00'),
  (8,  2,  '2026-10-05 18:40:00', '2026-10-05 20:10:00'),
  (9,  4,  '2026-10-05 18:50:00', '2026-10-05 20:05:00'),
  (10, 1,  '2026-10-05 19:45:00', '2026-10-05 21:10:00'),
  (11, 3,  '2026-10-05 19:50:00', '2026-10-05 21:15:00'),
  (12, 5,  '2026-10-05 19:55:00', '2026-10-05 21:05:00'),
  (13, 1,  '2026-10-06 17:50:00', '2026-10-06 19:05:00'),
  (14, 7,  '2026-10-06 19:15:00', '2026-10-06 21:10:00'),
  (15, 5,  '2026-10-06 19:20:00', '2026-10-06 21:05:00'),
  (16, 8,  '2026-10-07 09:45:00', '2026-10-07 11:15:00'),
  (17, 4,  '2026-10-07 09:50:00', '2026-10-07 11:10:00'),
  (18, 3,  '2026-10-07 17:50:00', NULL);

-- Представление с действующими абонементами (запрос ж)
CREATE OR REPLACE VIEW v_active_membership AS
SELECT c.client_id,
       c.last_name,
       c.first_name,
       c.phone,
       m.card_number,
       t.type_name,
       m.end_date
FROM client c
  INNER JOIN membership m      ON m.client_id = c.client_id
  INNER JOIN membership_type t ON t.type_id   = m.type_id
WHERE m.status = 'активен';

-- Триггеры и хранимые процедуры

DELIMITER //

-- Триггер 1. При продаже абонемента сам рассчитывает дату окончания
-- и стоимость по выбранному тарифу, если они не указаны
CREATE TRIGGER trg_membership_bi
BEFORE INSERT ON membership
FOR EACH ROW
BEGIN
  DECLARE v_days  SMALLINT UNSIGNED;
  DECLARE v_price DECIMAL(10,2);

  SELECT duration_days, price INTO v_days, v_price
  FROM membership_type
  WHERE type_id = NEW.type_id;

  IF NEW.end_date IS NULL THEN
    SET NEW.end_date = DATE_ADD(NEW.start_date, INTERVAL v_days DAY);
  END IF;
  IF NEW.price_paid IS NULL THEN
    SET NEW.price_paid = v_price;
  END IF;
END//

-- Триггер 2. Не пропускает в клуб по недействующему абонементу
-- и следит за лимитом посещений
CREATE TRIGGER trg_visit_bi
BEFORE INSERT ON visit
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_start  DATE;
  DECLARE v_end    DATE;
  DECLARE v_limit  SMALLINT UNSIGNED;
  DECLARE v_used   INT;

  SELECT m.status, m.start_date, m.end_date, t.visit_limit
    INTO v_status, v_start, v_end, v_limit
  FROM membership m
    INNER JOIN membership_type t ON t.type_id = m.type_id
  WHERE m.membership_id = NEW.membership_id;

  IF v_status <> 'активен'
     OR DATE(NEW.entry_time) NOT BETWEEN v_start AND v_end THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Проход запрещён: абонемент не действует';
  END IF;

  IF v_limit IS NOT NULL THEN
    SELECT COUNT(*) INTO v_used
    FROM visit
    WHERE membership_id = NEW.membership_id;
    IF v_used >= v_limit THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Проход запрещён: лимит посещений исчерпан';
    END IF;
  END IF;
END//

-- Триггер 3. Не даёт записать на занятие больше людей, чем есть мест,
-- и клиента без действующего абонемента
CREATE TRIGGER trg_booking_bi
BEFORE INSERT ON booking
FOR EACH ROW
BEGIN
  DECLARE v_max   SMALLINT UNSIGNED;
  DECLARE v_date  DATE;
  DECLARE v_taken INT;
  DECLARE v_valid INT;

  SELECT max_places, DATE(start_time) INTO v_max, v_date
  FROM schedule
  WHERE schedule_id = NEW.schedule_id;

  SELECT COUNT(*) INTO v_taken
  FROM booking
  WHERE schedule_id = NEW.schedule_id AND status <> 'отменил';

  IF v_taken >= v_max THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Запись невозможна: свободных мест нет';
  END IF;

  SELECT COUNT(*) INTO v_valid
  FROM membership
  WHERE client_id = NEW.client_id
    AND status = 'активен'
    AND v_date BETWEEN start_date AND end_date;

  IF v_valid = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Запись невозможна: нет действующего абонемента';
  END IF;
END//

-- Процедура 1. Заморозка абонемента на заданное число дней
CREATE PROCEDURE sp_freeze_membership (
  IN p_membership_id INT UNSIGNED,
  IN p_days          INT
)
BEGIN
  DECLARE v_status  VARCHAR(20);
  DECLARE v_allowed INT;

  SELECT m.status, t.freeze_days INTO v_status, v_allowed
  FROM membership m
    INNER JOIN membership_type t ON t.type_id = m.type_id
  WHERE m.membership_id = p_membership_id;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Абонемент не найден';
  ELSEIF v_status <> 'активен' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Заморозить можно только активный абонемент';
  ELSEIF p_days <= 0 OR p_days > v_allowed THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Срок заморозки превышает допустимый по тарифу';
  END IF;

  UPDATE membership
  SET status   = 'заморожен',
      end_date = DATE_ADD(end_date, INTERVAL p_days DAY)
  WHERE membership_id = p_membership_id;
END//

-- Процедура 2. Перевод просроченных абонементов в статус "истёк"
CREATE PROCEDURE sp_close_expired (
  IN  p_date  DATE,
  OUT p_count INT
)
BEGIN
  UPDATE membership
  SET status = 'истёк'
  WHERE end_date < p_date
    AND status = 'активен';

  SET p_count = ROW_COUNT();
END//

DELIMITER ;
