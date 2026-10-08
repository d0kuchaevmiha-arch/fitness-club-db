-- Триггеры и хранимые процедуры
USE fitness_club;

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
