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
