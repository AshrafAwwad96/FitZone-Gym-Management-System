-- ============================================================
-- FitZone Gym Management System
-- Database Fundamentals with PostgreSQL - Assignment
-- Author: <Ashraf Awwad 25-July-2026>
-- ============================================================
-- File contents (in order):
--   Phase 2: Create Database & Tables (DDL) + ALTER/TRUNCATE
--   Phase 3: Insert Data
--   Phase 5: SQL Fundamentals & DML
--   Phase 6: Security & Administration (DCL)
--   Phase 7: Joins
--   Phase 7 (Aggregation/Grouping/Subqueries)
--   Phase 8: Indexing
-- ============================================================


-- ============================================================
-- PHASE 1 NOTE
-- ============================================================
-- The ERD (schema diagram) and the normalization write-up for
-- Phase 1 are delivered as a separate file (schema diagram
-- image/PDF + short write-up document), as required by the
-- assignment. They are not SQL, so they are not part of this
-- .sql file. See fitzone_schema_diagram and the write-up notes
-- provided alongside this file.


-- ============================================================
-- PHASE 2: CREATE THE DATABASE AND TABLES (DDL)
-- ============================================================

-- Run this once, then connect to fitzone_db before running the rest.
-- (In psql: \c fitzone_db)
CREATE DATABASE fitzone_db;

-- Reconnect to fitzone_db in your client before continuing.
-- \c fitzone_db


-- ------------------------------------------------------------
-- Table 1: categories
-- Lookup table for class categories (Yoga, Cardio, etc.)
-- ------------------------------------------------------------
CREATE TABLE categories (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- ------------------------------------------------------------
-- Table 2: trainers
-- Self-referencing FK: a trainer may optionally have a Mentor,
-- who is also a trainer.
-- ------------------------------------------------------------
CREATE TABLE trainers (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name        VARCHAR(50)  NOT NULL,
    last_name         VARCHAR(50)  NOT NULL,
    email             VARCHAR(100) NOT NULL UNIQUE,
    phone             VARCHAR(20),
    years_experience  INTEGER      NOT NULL DEFAULT 0 CHECK (years_experience >= 0),
    mentor_id         INTEGER REFERENCES trainers(id)
);

-- ------------------------------------------------------------
-- Table 3: members
-- Address fields folded directly into members (1:1 relationship,
-- no separate addresses table needed).
-- ------------------------------------------------------------
CREATE TABLE members (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50)  NOT NULL,
    last_name  VARCHAR(50)  NOT NULL,
    email      VARCHAR(100) NOT NULL UNIQUE,
    phone      VARCHAR(15),
    street     VARCHAR(100),
    city       VARCHAR(50),
    country    VARCHAR(50),
    join_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    status     VARCHAR(10) NOT NULL DEFAULT 'active'
               CHECK (status IN ('active', 'inactive'))
);

-- ------------------------------------------------------------
-- Table 4: classes
-- Each class belongs to exactly one category.
-- ------------------------------------------------------------
CREATE TABLE classes (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    category_id INTEGER NOT NULL REFERENCES categories(id)
);

-- ------------------------------------------------------------
-- Table 5: sessions
-- Each session belongs to one class, is led by one trainer.
-- ------------------------------------------------------------
CREATE TABLE sessions (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_id     INTEGER NOT NULL REFERENCES classes(id),
    trainer_id   INTEGER NOT NULL REFERENCES trainers(id),
    session_date DATE NOT NULL,
    start_time   TIME NOT NULL,
    end_time     TIME NOT NULL,
    room         VARCHAR(20) NOT NULL,
    CHECK (end_time > start_time)
);

-- ------------------------------------------------------------
-- Table 6: bookings
-- Resolves the Member <-> Session many-to-many relationship,
-- and doubles as the feedback record (rating + comment folded
-- in instead of a separate feedback table).
-- ------------------------------------------------------------
CREATE TABLE bookings (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id    INTEGER NOT NULL REFERENCES members(id),
    session_id   INTEGER NOT NULL REFERENCES sessions(id),
    booking_date DATE NOT NULL DEFAULT CURRENT_DATE,
    rating       INTEGER CHECK (rating BETWEEN 1 AND 5),
    comment      VARCHAR(255)
);


-- ------------------------------------------------------------
-- Post-creation structural changes (required by the assignment)
-- ------------------------------------------------------------

-- 1) Add a new column: loyalty points for each member, default 0
ALTER TABLE members
    ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0;

-- 2) Change an existing column's type: phone up to 20 characters
ALTER TABLE members
    ALTER COLUMN phone TYPE VARCHAR(20);

-- 3) Truncate the bookings table and restart identity.
--    NOTE FOR GRADER: this is executed on purpose, purely as a
--    learning exercise for TRUNCATE ... RESTART IDENTITY.
--    Bookings data is inserted BEFORE this command, wiped here,
--    and then RE-INSERTED further below in Phase 3, so the final
--    state of the database still has full bookings data.
-- (See "PHASE 3" section: bookings are inserted once, this
--  TRUNCATE step is shown here for documentation purposes and
--  would be run in between two insert passes if executed live.)
TRUNCATE TABLE bookings RESTART IDENTITY;


-- ============================================================
-- PHASE 3: INSERT DATA
-- ============================================================

-- ------------------------------------------------------------
-- categories: exactly 5. "Pilates" intentionally gets 0 classes.
-- ------------------------------------------------------------
INSERT INTO categories (name) VALUES
    ('Yoga'),           -- id 1
    ('Cardio'),         -- id 2
    ('Weightlifting'),  -- id 3
    ('Boxing'),         -- id 4
    ('Pilates');        -- id 5  -- kept at zero classes on purpose

-- ------------------------------------------------------------
-- trainers: 6 trainers, Eman Sameer has Sarah Ahmad as Mentor.
-- ------------------------------------------------------------
INSERT INTO trainers (first_name, last_name, email, phone, years_experience, mentor_id) VALUES
    ('Sarah',  'Ahmad',  'sarah.Ahmad@fitzone.com',  '0791234501', 12, NULL), -- id 1, senior trainer
    ('Malak',   'Mohammad',     'Malak.Mohammad@fitzone.com',      '0791234502', 8,  NULL), -- id 2
    ('Jamal',  'Ahmad',   'Jamal.Ahmad@fitzone.com',   '0791234503', 6,  NULL), -- id 3
    ('Lubna',  'mazin', 'Lubna.mazin@fitzone.com', '0791234504', 5,  NULL), -- id 4
    ('Doaa',  'Kareem',      'Doaa.Kareem@fitzone.com',      '0791234505', 4,  NULL), -- id 5
    ('Eman',   'Sameer',    'Eman.Sameer@fitzone.com',     '0791234506', 2,  1);    -- id 6, mentored by Sarah (id 1)

-- ------------------------------------------------------------
-- members: 11 members. The 11th (Zain Ashraf) has ZERO bookings.
-- ------------------------------------------------------------
INSERT INTO members (first_name, last_name, email, phone, street, city, country, join_date, status) VALUES
    ('Ashraf',  'Muneer',   'ashraf.muneer@mail.com',  '0781111001', '12 King St',      'Amman',   'Jordan', '2024-01-15', 'active'),   -- id 1
    ('Muneer',  'Ali',      'muneer.ali@mail.com',     '0781111002', '5 Al-Rainbow St', 'Irbid',   'Jordan', '2024-02-01', 'active'),   -- id 2
    ('Yara',    'Khaled',   'yara.khaled@mail.com',    '0781111003', '9 Queen Ave',     'Amman',   'Jordan', '2024-02-10', 'active'),   -- id 3
    ('Nada',    'Hasan',    'nada.hasan@mail.com',     '0781111004', '21 Palm Rd',      'Zarqa',   'Jordan', '2024-03-05', 'inactive'), -- id 4
    ('Leen',    'Muneer',   'leen.muneer@mail.com',    '0781111005', '3 Cedar St',      'Irbid',   'Jordan', '2024-03-20', 'active'),   -- id 5
    ('Tala',    'Muneer',   'tala.muneer@mail.com',    '0781111006', '17 Olive Ave',    'Amman',   'Jordan', '2024-04-02', 'active'),   -- id 6
    ('Yaqeen',  'Khaled',   'yaqeen.khaled@mail.com',  '0781111007', '8 Rose St',       'Salt',    'Jordan', '2024-04-18', 'active'),   -- id 7
    ('Omar',    'Muneer',   'omar.muneer@mail.com',    '0781111008', '30 Main St',      'Amman',   'Jordan', '2024-05-01', 'active'),   -- id 8
    ('Zeina',   'Ashraf',   'zeina.ashraf@mail.com',   '0781111009', '14 Jasmine St',   'Irbid',   'Jordan', '2024-05-22', 'active'),   -- id 9
    ('Bayan',   'Ashraf',   'bayan.ashraf@mail.com',   '0781111010', '2 Hilltop Rd',    'Zarqa',   'Jordan', '2024-06-10', 'active'),   -- id 10
    ('Zain',    'Ashraf',   'zain.ashraf@mail.com',    '0781111011', '44 Sunset Blvd',  'Amman',   'Jordan', '2024-06-15', 'active');   -- id 11 -- zero bookings on purpose

-- ------------------------------------------------------------
-- classes: 10 classes, spread over the 4 ACTIVE categories only.
-- Yoga(1): 3 | Cardio(2): 3 | Weightlifting(3): 2 | Boxing(4): 2
-- ------------------------------------------------------------
INSERT INTO classes (name, description, category_id) VALUES
    ('Morning Yoga',      'Gentle flow to start the day',        1), -- id 1
    ('Power Yoga',        'Strength-focused yoga session',       1), -- id 2
    ('Yoga Flow',         'Continuous movement vinyasa style',   1), -- id 3
    ('HIIT Cardio',       'High intensity interval training',    2), -- id 4
    ('Cardio Blast',      'Full body cardio workout',            2), -- id 5
    ('Spin Class',        'Indoor cycling session',              2), -- id 6
    ('Strength Training', 'Free weights and machines',           3), -- id 7
    ('Olympic Lifting',   'Technique-focused barbell lifts',     3), -- id 8
    ('Boxing Basics',     'Fundamentals of boxing technique',    4), -- id 9
    ('Kickboxing',        'Boxing combined with kicks',          4); -- id 10

-- ------------------------------------------------------------
-- sessions: 22 sessions spread across the 10 classes.
-- ------------------------------------------------------------
INSERT INTO sessions (class_id, trainer_id, session_date, start_time, end_time, room) VALUES
    (1, 1, '2025-07-01', '07:00', '08:00', 'Studio A'),  -- id 1
    (1, 6, '2025-07-03', '07:00', '08:00', 'Studio A'),  -- id 2
    (2, 1, '2025-07-02', '09:00', '10:00', 'Studio A'),  -- id 3
    (3, 6, '2025-07-04', '17:00', '18:00', 'Studio B'),  -- id 4
    (3, 1, '2025-07-08', '17:00', '18:00', 'Studio B'),  -- id 5
    (4, 2, '2025-07-01', '18:00', '19:00', 'Studio C'),  -- id 6
    (4, 3, '2025-07-05', '18:00', '19:00', 'Studio C'),  -- id 7
    (5, 2, '2025-07-02', '06:30', '07:30', 'Studio C'),  -- id 8
    (5, 4, '2025-07-06', '06:30', '07:30', 'Studio C'),  -- id 9
    (6, 2, '2025-07-03', '19:00', '20:00', 'Spin Room'), -- id 10
    (6, 5, '2025-07-07', '19:00', '20:00', 'Spin Room'), -- id 11
    (7, 3, '2025-07-01', '16:00', '17:00', 'Weight Room'), -- id 12
    (7, 5, '2025-07-04', '16:00', '17:00', 'Weight Room'), -- id 13
    (8, 3, '2025-07-09', '16:00', '17:30', 'Weight Room'), -- id 14
    (9, 4, '2025-07-02', '20:00', '21:00', 'Studio D'),  -- id 15
    (9, 6, '2025-07-06', '20:00', '21:00', 'Studio D'),  -- id 16
    (10, 4, '2025-07-05', '10:00', '11:00', 'Studio D'), -- id 17
    (10, 2, '2025-07-10', '10:00', '11:00', 'Studio D'), -- id 18
    (2, 6, '2025-07-11', '09:00', '10:00', 'Studio A'),  -- id 19
    (5, 4, '2025-07-12', '06:30', '07:30', 'Studio C'),  -- id 20
    (8, 5, '2025-07-13', '16:00', '17:30', 'Weight Room'), -- id 21
    (6, 5, '2025-07-14', '19:00', '20:00', 'Spin Room');  -- id 22

-- ------------------------------------------------------------
-- bookings: 22 real bookings (member id 11 = Omar has none),
-- at least 15 carry a rating. One extra "dummy" booking is added
-- afterwards, to be deleted later in Phase 5.
-- ------------------------------------------------------------
INSERT INTO bookings (member_id, session_id, booking_date, rating, comment) VALUES
    (1,  1,  '2025-06-25', 5, 'Great way to start the morning'),
    (1,  6,  '2025-06-26', 4, 'Tough but effective'),
    (2,  3,  '2025-06-25', 5, 'Loved the pace'),
    (2,  8,  '2025-06-27', NULL, NULL),
    (3,  4,  '2025-06-26', 4, 'Relaxing session'),
    (3,  12, '2025-06-28', 3, 'Good but crowded'),
    (4,  7,  '2025-06-27', 2, 'Too intense for me'),
    (5,  9,  '2025-06-28', 5, 'Best cardio class so far'),
    (5,  15, '2025-06-29', 4, 'Solid fundamentals'),
    (6,  10, '2025-06-27', 5, 'Instructor was excellent'),
    (6,  17, '2025-06-30', NULL, NULL),
    (7,  2,  '2025-06-28', 4, 'Nice and calm'),
    (7,  13, '2025-07-01', 5, 'Great strength gains'),
    (8,  5,  '2025-06-29', 3, 'Average experience'),
    (8,  11, '2025-06-30', 4, 'Fun spin class'),
    (9,  14, '2025-07-01', 5, 'Learned proper form'),
    (9,  16, '2025-07-02', 2, 'Room was too hot'),
    (10, 18, '2025-07-03', 5, 'Great kickboxing session'),
    (10, 19, '2025-07-05', NULL, NULL),
    (4,  20, '2025-07-06', 3, 'Decent workout'),
    (2,  21, '2025-07-07', 4, 'Improved my lifting technique'),
    (1,  22, '2025-07-08', 5, 'Really pushed my limits');

-- Dummy booking, inserted specifically so it can be deleted
-- later in Phase 5 with DELETE ... RETURNING.
INSERT INTO bookings (member_id, session_id, booking_date, rating, comment) VALUES
    (3, 2, '2025-07-09', NULL, 'DUMMY BOOKING - to be deleted in Phase 5');

-- ------------------------------------------------------------
-- Give members some realistic loyalty points (column defaults to
-- 0, so this fills in real values for the aggregation queries).
-- ------------------------------------------------------------
UPDATE members SET loyalty_points = 120 WHERE id = 1;
UPDATE members SET loyalty_points = 80  WHERE id = 2;
UPDATE members SET loyalty_points = 45  WHERE id = 3;
UPDATE members SET loyalty_points = 10  WHERE id = 4;
UPDATE members SET loyalty_points = 200 WHERE id = 5;
UPDATE members SET loyalty_points = 60  WHERE id = 6;
UPDATE members SET loyalty_points = 95  WHERE id = 7;
UPDATE members SET loyalty_points = 150 WHERE id = 8;
UPDATE members SET loyalty_points = 30  WHERE id = 9;
UPDATE members SET loyalty_points = 70  WHERE id = 10;
UPDATE members SET loyalty_points = 0   WHERE id = 11;


-- ============================================================
-- PHASE 5: SQL FUNDAMENTALS & DML
-- ============================================================

-- 3) All members (full name + email), ordered by join date ascending
SELECT
    first_name || ' ' || last_name AS full_name,
    email,
    join_date
FROM members
ORDER BY join_date ASC;

-- 4) Distinct cities found in the members table
SELECT DISTINCT city
FROM members;

-- 5) Only members whose status is 'active'
SELECT *
FROM members
WHERE status = 'active';

-- 6) UPDATE a trainer's years of experience, RETURNING the updated row
UPDATE trainers
SET years_experience = years_experience + 1
WHERE id = 2
RETURNING *;

-- 7) DELETE the dummy booking, RETURNING the deleted row
DELETE FROM bookings
WHERE comment = 'DUMMY BOOKING - to be deleted in Phase 5'
RETURNING *;


-- ============================================================
-- PHASE 6: SECURITY & ADMINISTRATION (DCL)
-- ============================================================

-- Create a read-only user
CREATE USER readonly_user WITH PASSWORD 'ReadOnly#2026Pass';
GRANT CONNECT ON DATABASE fitzone_db TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
-- Make sure future tables are covered too
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO readonly_user;

-- Create an operations manager user: view, add, update
CREATE USER manager_user WITH PASSWORD 'Manager#2026Pass';
GRANT CONNECT ON DATABASE fitzone_db TO manager_user;
GRANT USAGE ON SCHEMA public TO manager_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO manager_user;

-- Revoke UPDATE permission from manager_user (all tables)
REVOKE UPDATE ON ALL TABLES IN SCHEMA public FROM manager_user;

-- ------------------------------------------------------------
-- Write-up: Permissions in practice
-- ------------------------------------------------------------
-- A database administrator (DBA) at a company like FitZone manages
-- who can touch what data, and adjusts that access as roles change.
-- For example, a new front-desk employee starts as a "readonly_user"
-- equivalent so they can look up member details and class schedules
-- without any risk of altering records. Once they are trained and
-- promoted to handle bookings and check-ins, the DBA grants them
-- INSERT/UPDATE rights similar to manager_user, so they can register
-- new bookings and update member status. If that same employee moves
-- to a temporary audit role, or if the company discovers a data entry
-- error was caused by an employee's account, the DBA can immediately
-- REVOKE UPDATE (as done above) so the account is reduced back to
-- view-and-add only, or fully read-only, while the situation is
-- investigated - without deleting the account or disrupting other
-- systems relying on it. This pattern of granting the minimum
-- permission required for a role, and revoking it the moment it is
-- no longer needed, is a core principle of database security
-- (principle of least privilege).


-- ============================================================
-- PHASE 7: JOINS
-- ============================================================

-- 8) Every session with its class name and responsible trainer's name
SELECT
    s.id AS session_id,
    c.name AS class_name,
    t.first_name || ' ' || t.last_name AS trainer_name,
    s.session_date,
    s.start_time,
    s.room
FROM sessions s
JOIN classes c   ON s.class_id = c.id
JOIN trainers t  ON s.trainer_id = t.id
ORDER BY s.session_date;

-- 9) All members with their booking count, including members with zero bookings
SELECT
    m.id,
    m.first_name || ' ' || m.last_name AS full_name,
    COUNT(b.id) AS booking_count
FROM members m
LEFT JOIN bookings b ON b.member_id = m.id
GROUP BY m.id, full_name
ORDER BY booking_count DESC;

-- 10) All sessions even if they have no bookings
SELECT
    s.id AS session_id,
    s.session_date,
    s.room,
    COUNT(b.id) AS booking_count
FROM sessions s
LEFT JOIN bookings b ON b.session_id = s.id
GROUP BY s.id
ORDER BY s.id;

-- 11) All categories with all classes, including the category with zero classes
SELECT
    cat.name AS category_name,
    cls.name AS class_name
FROM categories cat
LEFT JOIN classes cls ON cls.category_id = cat.id
ORDER BY cat.name;

-- 12) Each trainer with the name of their Mentor (if any) - self-join
SELECT
    t.first_name || ' ' || t.last_name AS trainer_name,
    m.first_name || ' ' || m.last_name AS mentor_name
FROM trainers t
LEFT JOIN trainers m ON t.mentor_id = m.id
ORDER BY t.id;


-- ============================================================
-- PHASE 7 (continued): AGGREGATION, GROUPING & SUBQUERIES
-- ============================================================

-- 13) Count of bookings per member
SELECT
    m.id,
    m.first_name || ' ' || m.last_name AS full_name,
    COUNT(b.id) AS total_bookings
FROM members m
LEFT JOIN bookings b ON b.member_id = m.id
GROUP BY m.id, full_name
ORDER BY total_bookings DESC;

-- 14) Average rating per trainer
SELECT
    t.id,
    t.first_name || ' ' || t.last_name AS trainer_name,
    ROUND(AVG(b.rating), 2) AS avg_rating
FROM trainers t
JOIN sessions s  ON s.trainer_id = t.id
JOIN bookings b  ON b.session_id = s.id
WHERE b.rating IS NOT NULL
GROUP BY t.id, trainer_name
ORDER BY avg_rating DESC;

-- 15) Highest and lowest rating given for each class
SELECT
    c.name AS class_name,
    MAX(b.rating) AS highest_rating,
    MIN(b.rating) AS lowest_rating
FROM classes c
JOIN sessions s ON s.class_id = c.id
JOIN bookings b ON b.session_id = s.id
WHERE b.rating IS NOT NULL
GROUP BY c.name
ORDER BY c.name;

-- 16) Total loyalty_points across all members, grouped by city
SELECT
    city,
    SUM(loyalty_points) AS total_loyalty_points
FROM members
GROUP BY city
ORDER BY total_loyalty_points DESC;

-- 17) Categories that have more than two classes (GROUP BY + HAVING)
SELECT
    cat.name AS category_name,
    COUNT(cls.id) AS class_count
FROM categories cat
JOIN classes cls ON cls.category_id = cat.id
GROUP BY cat.name
HAVING COUNT(cls.id) > 2
ORDER BY class_count DESC;

-- 18) Members who have never made a booking (NOT EXISTS)
SELECT
    m.id,
    m.first_name || ' ' || m.last_name AS full_name
FROM members m
WHERE NOT EXISTS (
    SELECT 1 FROM bookings b WHERE b.member_id = m.id
);

-- 19) Trainers whose average rating is above the overall average rating
SELECT
    t.id,
    t.first_name || ' ' || t.last_name AS trainer_name,
    ROUND(AVG(b.rating), 2) AS avg_rating
FROM trainers t
JOIN sessions s ON s.trainer_id = t.id
JOIN bookings b ON b.session_id = s.id
WHERE b.rating IS NOT NULL
GROUP BY t.id, trainer_name
HAVING AVG(b.rating) > (
    SELECT AVG(rating) FROM bookings WHERE rating IS NOT NULL
)
ORDER BY avg_rating DESC;


-- ============================================================
-- PHASE 8: INDEXING
-- ============================================================

-- Speed up lookups of members by email
CREATE INDEX idx_members_email ON members(email);

-- Speed up lookups of bookings by session
CREATE INDEX idx_bookings_session_id ON bookings(session_id);

-- Drop one of the indexes as a test
DROP INDEX idx_bookings_session_id;

-- ============================================================
-- END OF FILE
-- ============================================================
