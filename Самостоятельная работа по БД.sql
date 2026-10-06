-- ============================================================================
-- Самостоятельная работа № 1 по дисциплине «Базы данных»
-- Тема № 12: «Тендерная платформа: организации, заявки, победители»
-- Автор: Октамов Шохрухбек
-- Группа: Компьютерный инжиниринг - 271-25 SIr
-- СУБД: MySQL 8.0.31 и выше (проверено на MySQL 8.4)
--
-- Как запустить: открыть файл в MySQL Workbench и выполнить целиком
-- (кнопка «выполнить скрипт»). Скрипт можно перезапускать: он сам
-- удаляет и заново создаёт базу данных.
-- ============================================================================

DROP DATABASE IF EXISTS tender_platform_oktamov;
CREATE DATABASE tender_platform_oktamov
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE tender_platform_oktamov;

-- ============================================================================
-- 1. DDL: создание таблиц
-- Порядок учитывает зависимости внешних ключей:
-- сначала независимые справочники, затем таблицы со ссылками на них.
-- company + tender_category -> accreditation / tender -> application -> victory_protocol
-- ============================================================================

-- Компании-участники платформы (заказчики и/или поставщики)
CREATE TABLE company (
  company_id   INT AUTO_INCREMENT PRIMARY KEY,
  company_name VARCHAR(150) NOT NULL,
  stir         CHAR(9)      NOT NULL UNIQUE,               -- ИНН: ровно 9 цифр
  company_role VARCHAR(10)  NOT NULL DEFAULT 'supplier'
               CHECK (company_role IN ('customer','supplier','both')),
  city         VARCHAR(60)  NOT NULL,
  email        VARCHAR(100) NOT NULL,
  phone        VARCHAR(20),                                -- необязательное поле
  reg_date     DATE         NOT NULL,
  rating       DECIMAL(3,1) CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);

-- Справочник категорий закупок
CREATE TABLE tender_category (
  cat_id      INT AUTO_INCREMENT PRIMARY KEY,
  cat_name    VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
);

-- Связь M:N: аккредитация компаний по категориям (с уровнем допуска)
CREATE TABLE accreditation (
  company_id   INT         NOT NULL,
  cat_id       INT         NOT NULL,
  accred_date  DATE        NOT NULL,
  accred_level VARCHAR(10) NOT NULL DEFAULT 'basic'
               CHECK (accred_level IN ('basic','standard','premium')),
  PRIMARY KEY (company_id, cat_id),                        -- составной первичный ключ
  FOREIGN KEY (company_id) REFERENCES company (company_id) ON DELETE CASCADE,
  FOREIGN KEY (cat_id)     REFERENCES tender_category (cat_id) ON DELETE CASCADE
);

-- Тендеры, публикуемые заказчиками
CREATE TABLE tender (
  tender_id     INT AUTO_INCREMENT PRIMARY KEY,
  tender_title  VARCHAR(200)  NOT NULL,
  cat_id        INT           NOT NULL,
  client_id     INT           NOT NULL,                    -- компания-заказчик
  start_price   DECIMAL(15,2) NOT NULL CHECK (start_price > 0),
  published_on  DATE          NOT NULL,
  deadline      DATE          NOT NULL,
  tender_status VARCHAR(10)   NOT NULL DEFAULT 'open'
                CHECK (tender_status IN ('open','closed','completed','cancelled')),
  delivery_city VARCHAR(60)   NOT NULL DEFAULT 'Ташкент',
  CHECK (deadline > published_on),                         -- срок позже публикации
  FOREIGN KEY (cat_id)    REFERENCES tender_category (cat_id),
  FOREIGN KEY (client_id) REFERENCES company (company_id)
);

-- Заявки компаний-поставщиков на тендеры
CREATE TABLE application (
  appl_id      INT AUTO_INCREMENT PRIMARY KEY,
  tender_id    INT           NOT NULL,
  company_id   INT           NOT NULL,
  offered_sum  DECIMAL(15,2) NOT NULL CHECK (offered_sum > 0),
  submitted_on DATE          NOT NULL,
  appl_status  VARCHAR(10)   NOT NULL DEFAULT 'submitted'
               CHECK (appl_status IN ('submitted','accepted','rejected')),
  UNIQUE (tender_id, company_id),     -- одна компания — одна заявка на тендер
  UNIQUE (appl_id, tender_id),         -- цель составного внешнего ключа из протокола
  FOREIGN KEY (tender_id)  REFERENCES tender (tender_id) ON DELETE CASCADE,
  FOREIGN KEY (company_id) REFERENCES company (company_id)
);

-- Протокол победы: один протокол на тендер (связь 1:1) + победившая заявка
CREATE TABLE victory_protocol (
  tender_id       INT           PRIMARY KEY,               -- 1:1 с tender
  appl_id         INT           NOT NULL UNIQUE,
  protocol_no     VARCHAR(20)   NOT NULL UNIQUE,           -- номер протокола
  signed_on       DATE          NOT NULL,
  final_sum       DECIMAL(15,2) NOT NULL CHECK (final_sum > 0),
  commission_note VARCHAR(255),
  FOREIGN KEY (tender_id) REFERENCES tender (tender_id),
  -- составной внешний ключ гарантирует, что победившая заявка (appl_id)
  -- относится именно к этому тендеру (tender_id), а не к чужому
  FOREIGN KEY (appl_id, tender_id) REFERENCES application (appl_id, tender_id)
);

-- ============================================================================
-- 2. DDL: изменение структуры (ALTER TABLE) и индексы
-- ============================================================================

ALTER TABLE company
  ADD COLUMN director VARCHAR(100);                        -- добавление столбца

ALTER TABLE company
  MODIFY COLUMN email VARCHAR(120) NOT NULL;               -- изменение типа столбца

ALTER TABLE company
  ADD CONSTRAINT uq_company_email UNIQUE (email);           -- добавление ограничения

CREATE INDEX idx_tender_status ON tender (tender_status);  -- индекс для выборок по статусу
CREATE INDEX idx_application_status ON application (appl_status);

-- ============================================================================
-- 3. DML: наполнение таблиц (INSERT)
-- ============================================================================

INSERT INTO company
  (company_id, company_name, stir, company_role, city, email, phone, reg_date, rating) VALUES
(1,  'ООО «Chilonzor Qurilish»',                    '401234561', 'supplier', 'Ташкент',   'info@chilonzor-qurilish.uz', '+998712001101', '2018-05-14', 4.2),
(2,  'СП «Fergana Valley Agro»',                    '402345672', 'supplier', 'Фергана',   'office@fva-agro.uz',         '+998732001102', '2017-08-03', 4.5),
(3,  'ООО «Samarqand Soft»',                        '403456783', 'both',     'Самарканд', 'contact@samsoft.uz',         '+998662001103', '2016-11-21', 4.8),
(4,  'ООО «Bukhara Cotton Trade»',                  '404567894', 'supplier', 'Бухара',    'sales@bct-trade.uz',         '+998652001104', '2019-02-17', 3.9),
(5,  'ЧП «Urgench Logistics»',                      '405678905', 'supplier', 'Ургенч',    'info@urgench-log.uz',        '+998622001105', '2020-07-30', 4.0),
(6,  'ООО «Nukus MedTech»',                         '406789016', 'supplier', 'Нукус',     'service@nukusmed.uz',        '+998612001106', '2015-04-09', 4.6),
(7,  'Хокимият Мирзо-Улугбекского района',          '407890127', 'customer', 'Ташкент',   'zakup@mu-tashkent.uz',       '+998712001107', '2011-06-01', NULL),
(8,  'Управление здравоохранения Джизакской области','408901238','customer', 'Джизак',    'tender@jizzakh-med.uz',      '+998722001108', '2013-09-12', NULL),
(9,  'IT-Park Tashkent',                            '409012349', 'customer', 'Ташкент',   'procurement@itpark.uz',      NULL,            '2020-12-05', NULL),
(10, 'АО «Uzbektelecom Hudud»',                     '410123450', 'both',     'Ташкент',   'tender@uztelecom-hudud.uz',  '+998712001110', '2014-03-25', 4.3),
(11, 'ООО «Jizzakh Office Supply»',                 '411234561', 'supplier', 'Джизак',    'mail@jizzakh-office.uz',     NULL,            '2022-04-18', 3.7),
(12, 'ООО «Qoqon Green Agro»',                      '412345672', 'supplier', 'Коканд',    'info@qokon-agro.uz',         '+998735001112', '2023-06-27', 4.1);

INSERT INTO tender_category (cat_id, cat_name, description) VALUES
(1, 'Строительство и капремонт',    'Капитальный ремонт и строительные работы'),
(2, 'IT-услуги и софт',             'Разработка ПО и цифровые услуги'),
(3, 'Медтехника',                   'Поставка и монтаж медицинского оборудования'),
(4, 'Агропродукция и удобрения',    'Семена, саженцы, удобрения и СЗР'),
(5, 'Офисные товары и мебель',      'Канцелярия, мебель и оргтехника'),
(6, 'Логистика и перевозки',        'Грузовые перевозки и экспедирование');

INSERT INTO accreditation (company_id, cat_id, accred_date, accred_level) VALUES
(1, 1, '2022-02-11', 'standard'), (1, 6, '2023-04-02', 'basic'),
(2, 4, '2021-06-15', 'premium'),  (2, 6, '2022-10-01', 'standard'),
(3, 2, '2020-03-12', 'premium'),  (3, 5, '2021-08-20', 'standard'),
(4, 4, '2021-12-05', 'basic'),    (4, 5, '2022-05-14', 'standard'),
(4, 6, '2022-09-19', 'basic'),    (5, 6, '2022-07-07', 'premium'),
(6, 3, '2019-09-09', 'premium'),  (10, 2, '2020-07-19', 'standard'),
(10, 3, '2021-01-25', 'basic'),   (11, 5, '2023-03-10', 'basic'),
(12, 4, '2024-02-20', 'standard'),(12, 1, '2023-08-11', 'basic');

INSERT INTO tender
  (tender_id, tender_title, cat_id, client_id, start_price, published_on, deadline, tender_status, delivery_city) VALUES
(1,  'Капремонт школы № 45 Мирзо-Улугбекского района',      1, 7, 920000000,  '2026-01-20', '2026-02-20', 'completed', 'Ташкент'),
(2,  'Разработка платформы электронной очереди поликлиник', 2, 8, 380000000,  '2026-03-01', '2026-03-28', 'completed', 'Джизак'),
(3,  'Поставка УЗИ-аппаратов для областных клиник',         3, 8, 2750000000, '2026-02-15', '2026-03-15', 'completed', 'Джизак'),
(4,  'Закупка канцелярии для школ района',                  5, 7, 52000000,   '2026-04-05', '2026-04-25', 'completed', 'Ташкент'),
(5,  'Создание портала резидентов IT-Park',                 2, 9, 340000000,  '2026-05-10', '2026-06-05', 'completed', 'Ташкент'),
(6,  'Строительство спортзала при школе № 12',              1, 7, 1350000000, '2026-06-05', '2026-07-05', 'closed',    'Ташкент'),
(7,  'Поставка саженцев и капельного орошения',             4, 9, 210000000,  '2026-06-20', '2026-07-15', 'completed', 'Ташкент'),
(8,  'Перевозка серверного оборудования IT-Park',          6, 9, 88000000,   '2026-08-05', '2026-08-28', 'completed', 'Ташкент'),
(9,  'Закупка интерактивных досок для школ',                2, 7, 295000000,  '2026-09-05', '2026-10-18', 'open',      'Ташкент'),
(10, 'Капремонт кровли здания IT-Park',                     1, 9, 165000000,  '2026-09-12', '2026-10-22', 'open',      'Ташкент'),
(11, 'Закупка мебели для call-центра',                      5, 10, 64000000,  '2026-07-22', '2026-08-12', 'cancelled', 'Ташкент');

INSERT INTO application
  (appl_id, tender_id, company_id, offered_sum, submitted_on, appl_status) VALUES
(1,  1,  1,  875000000,  '2026-02-05', 'rejected'),
(2,  1,  12, 840000000,  '2026-02-08', 'accepted'),
(3,  2,  3,  362000000,  '2026-03-15', 'accepted'),
(4,  2,  10, 371000000,  '2026-03-17', 'rejected'),
(5,  3,  6,  2590000000, '2026-03-01', 'accepted'),
(6,  4,  4,  49500000,   '2026-04-12', 'rejected'),
(7,  4,  11, 47800000,   '2026-04-14', 'accepted'),
(8,  5,  3,  327000000,  '2026-05-22', 'rejected'),
(9,  5,  10, 315000000,  '2026-05-24', 'accepted'),
(10, 6,  1,  1290000000, '2026-06-22', 'submitted'),
(11, 6,  12, 1310000000, '2026-06-26', 'submitted'),
(12, 7,  2,  198000000,  '2026-07-03', 'accepted'),
(13, 8,  1,  84000000,   '2026-08-12', 'rejected'),
(14, 8,  4,  81500000,   '2026-08-14', 'accepted'),
(15, 9,  3,  281000000,  '2026-09-22', 'submitted'),
(16, 9,  10, 287000000,  '2026-09-24', 'submitted'),
(17, 10, 1,  158000000,  '2026-09-27', 'submitted'),
(18, 10, 12, 159500000,  '2026-09-29', 'submitted'),
(19, 7,  4,  205000000,  '2026-07-05', 'rejected');

INSERT INTO victory_protocol
  (tender_id, appl_id, protocol_no, signed_on, final_sum, commission_note) VALUES
(1, 2,  'PR-2026-001', '2026-02-25', 840000000,  'Победитель — Qoqon Green Agro, минимальная цена'),
(2, 3,  'PR-2026-002', '2026-04-02', 362000000,  'Победитель — Samarqand Soft, лучший функционал'),
(3, 5,  'PR-2026-003', '2026-03-20', 2590000000, 'Победитель — Nukus MedTech, единственный допущенный'),
(4, 7,  'PR-2026-004', '2026-04-29', 47800000,   'Победитель — Jizzakh Office Supply'),
(5, 9,  'PR-2026-005', '2026-06-10', 315000000,  'Победитель — Uzbektelecom Hudud'),
(7, 12, 'PR-2026-006', '2026-07-20', 198000000,  'Победитель — Fergana Valley Agro'),
(8, 14, 'PR-2026-007', '2026-09-02', 81500000,   'Победитель — Bukhara Cotton Trade');

-- ============================================================================
-- 4. DML: INSERT, UPDATE, DELETE (демонстрация изменения данных)
-- ============================================================================

-- добавление временной записи
INSERT INTO company
  (company_id, company_name, stir, company_role, city, email, reg_date, rating) VALUES
  (20, 'Тестовая компания', '499999999', 'supplier', 'Ташкент', 'test@temp.uz', '2026-09-30', 3.0);

-- изменение данных (условия WHERE ограничивают затрагиваемые строки)
UPDATE tender  SET deadline = '2026-10-28' WHERE tender_id = 10 AND tender_status = 'open';
UPDATE company SET phone = '+998735001113' WHERE company_id = 12;
UPDATE company SET director = 'Приёмная хокимията' WHERE company_id = 7;

-- удаление временной записи (у неё нет зависимых строк, внешние ключи не мешают)
DELETE FROM company WHERE company_id = 20;

-- ============================================================================
-- 5. DQL: запросы на выборку
-- ============================================================================

-- Запрос 1. Пять тендеров с наибольшей стартовой ценой (в миллионах сумов):
--           вычисляемое выражение, псевдоним, сортировка, LIMIT.
SELECT tender_id,
       tender_title,
       ROUND(start_price / 1000000.0, 1) AS price_mln
FROM tender
ORDER BY start_price DESC
LIMIT 5;

-- Запрос 2. Города компаний с указанным телефоном, без повторов (DISTINCT, IS NOT NULL).
SELECT DISTINCT city
FROM company
WHERE phone IS NOT NULL
ORDER BY city;

-- Запрос 3. Завершённые или закрытые тендеры на поставку/закупку
--           с ценой от 50 млн до 1,5 млрд сумов (LIKE, OR, IN, BETWEEN, AND).
SELECT tender_id, tender_title, start_price
FROM tender
WHERE (tender_title LIKE 'Поставка%' OR tender_title LIKE 'Закупка%')
  AND tender_status IN ('completed', 'closed')
  AND start_price BETWEEN 50000000 AND 1500000000;

-- Запрос 4. Заявки по статусам: количество, сумма, минимум, максимум, среднее
--           (GROUP BY, агрегатные функции; суммы в миллионах сумов).
SELECT appl_status,
       COUNT(*)                                AS appl_count,
       ROUND(SUM(offered_sum) / 1000000.0, 1) AS total_mln,
       ROUND(MIN(offered_sum) / 1000000.0, 1) AS min_mln,
       ROUND(MAX(offered_sum) / 1000000.0, 1) AS max_mln,
       ROUND(AVG(offered_sum) / 1000000.0, 1) AS avg_mln
FROM application
GROUP BY appl_status
ORDER BY appl_status;

-- Запрос 5. Тендеры, на которые после 1 апреля 2026 подано не менее двух заявок
--           (WHERE фильтрует строки, HAVING фильтрует группы).
SELECT tender_id,
       COUNT(*)         AS appl_count,
       MIN(offered_sum) AS best_offer
FROM application
WHERE submitted_on >= '2026-04-01'
GROUP BY tender_id
HAVING COUNT(*) >= 2
ORDER BY appl_count DESC, tender_id;

-- Запрос 6. Открытые тендеры с категорией и заказчиком (INNER JOIN трёх таблиц).
SELECT t.tender_id,
       t.tender_title,
       c.cat_name,
       o.company_name AS customer
FROM tender t
INNER JOIN tender_category c ON t.cat_id = c.cat_id
INNER JOIN company         o ON t.client_id = o.company_id
WHERE t.tender_status = 'open';

-- Запрос 7. Поставщики с не более чем одной заявкой, включая тех, кто не подавал заявок
--           (LEFT JOIN сохраняет компании без заявок).
SELECT o.company_name,
       COUNT(a.appl_id) AS appl_count
FROM company o
LEFT JOIN application a ON o.company_id = a.company_id
WHERE o.company_role <> 'customer'
GROUP BY o.company_id, o.company_name
HAVING COUNT(a.appl_id) <= 1
ORDER BY appl_count, o.company_name;

-- Запрос 8. Победители завершённых тендеров и экономия заказчика в процентах
--           (несколько INNER JOIN, вычисляемое выражение).
SELECT v.tender_id,
       o.company_name AS winner,
       v.final_sum,
       ROUND((t.start_price - v.final_sum) * 100.0 / t.start_price, 1) AS saving_pct
FROM victory_protocol v
INNER JOIN tender      t ON v.tender_id = t.tender_id
INNER JOIN application a ON v.appl_id   = a.appl_id
INNER JOIN company     o ON a.company_id = o.company_id
WHERE t.tender_status = 'completed'
ORDER BY v.signed_on;

-- Запрос 9. Города, где есть заказчики или поставщики, без повторов (UNION).
--           UNION удаляет дубликаты; роль 'both' учитывается в обеих выборках.
SELECT city FROM company WHERE company_role IN ('customer','both')
UNION
SELECT city FROM company WHERE company_role IN ('supplier','both')
ORDER BY city;

-- Запрос 10. Компании, подававшие заявки и на строительство (категория 1),
--            и на логистику (категория 6) — пересечение множеств (INTERSECT).
--            MySQL 8.0.31+ поддерживает INTERSECT нативно.
SELECT a.company_id
FROM application a INNER JOIN tender t ON a.tender_id = t.tender_id
WHERE t.cat_id = 1
INTERSECT
SELECT a.company_id
FROM application a INNER JOIN tender t ON a.tender_id = t.tender_id
WHERE t.cat_id = 6;

-- Запрос 11. Компании, подававшие заявки, но ни разу не победившие —
--            разность множеств (EXCEPT в MySQL 8.0.31+; в Oracle это MINUS).
SELECT DISTINCT company_id FROM application
EXCEPT
SELECT a.company_id
FROM victory_protocol v INNER JOIN application a ON v.appl_id = a.appl_id
ORDER BY company_id;
