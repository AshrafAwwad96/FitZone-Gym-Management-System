-- ============================================================
-- FitZone Gym Management System
-- PL/pgSQL Programming - Follow-up Assignment
-- Author: <Ashraf Awwad>
-- ============================================================
-- This file builds directly on fitzone_db from the previous
-- assignment. The original 6 tables (members, trainers,
-- categories, classes, sessions, bookings) and their data are
-- kept exactly as they were - nothing here redesigns the schema.
--
-- Two things are added on top of the original schema, each with
-- a short comment at the point they're introduced:
--   1) members.loyalty_level  - a small 1-5 capped tier used by
--      Phase 6 (#16) and Phase 11 (#23). This is a different
--      concept from the existing members.loyalty_points column
--      from Assignment 1 (which is an open-ended reward-points
--      total) - the new column is a capped "level", so it is
--      kept separate rather than overloading loyalty_points.
--   2) audit_log table         - required by Phase 10 (#22) to
--      record INSERT/UPDATE/DELETE activity on bookings.
--
-- A handful of extra sessions/bookings are also inserted (clearly
-- marked below) purely so that later demos (e.g. "a member with
-- more than 3 bookings") have real rows to act on - the original
-- 22 bookings from Assignment 1 are untouched.
-- ============================================================


-- ============================================================
-- PHASE 0: SCHEMA ADDITIONS REQUIRED FOR THIS ASSIGNMENT
-- ============================================================

-- New column: capped loyalty tier (1-5), separate from the
-- existing open-ended loyalty_points column. Used by
-- apply_loyalty_bonus() (#16) and the ratings trigger (#23).
ALTER TABLE members
    ADD COLUMN loyalty_level INTEGER NOT NULL DEFAULT 1
    CHECK (loyalty_level BETWEEN 1 AND 5);


-- ============================================================
-- SUPPLEMENTARY TEST DATA
-- (extra sessions/bookings so "member with >3 bookings" scenarios
--  in Phase 6 and Phase 11 have real data to work with; original
--  Assignment 1 rows are untouched)
-- ============================================================
INSERT INTO sessions (class_id, trainer_id, session_date, start_time, end_time, room) VALUES
    (1, 1, '2025-07-15', '07:00', '08:00', 'Studio A'),  -- extra Morning Yoga session
    (4, 2, '2025-07-16', '18:00', '19:00', 'Studio C');  -- extra HIIT Cardio session

-- member 1 (Ashraf Muneer) picks up 2 more bookings -> total 5
-- member 2 (Muneer Ali) picks up 1 more booking   -> total 4
INSERT INTO bookings (member_id, session_id, booking_date, rating, comment) VALUES
    (1, (SELECT id FROM sessions WHERE room = 'Studio A' AND session_date = '2025-07-15'), '2025-07-10', 5, 'Loved it'),
    (1, (SELECT id FROM sessions WHERE room = 'Studio C' AND session_date = '2025-07-16'), '2025-07-11', 4, 'Great session'),
    (2, (SELECT id FROM sessions WHERE room = 'Studio A' AND session_date = '2025-07-15'), '2025-07-10', 5, 'Nice class');


-- ============================================================
-- PART A - PL/pgSQL BASICS
-- ============================================================

-- ============================================================
-- PHASE 1: BLOCKS & VARIABLES
-- ============================================================

-- (1) + (2) Anonymous block: %TYPE variable, SELECT INTO,
-- a second plain variable for booking count, RAISE NOTICE,
-- full DECLARE / BEGIN / EXCEPTION / END structure.
DO $$
DECLARE
    v_email           members.email%TYPE;
    v_lowest_id       INTEGER;
    v_total_bookings  INTEGER;
BEGIN
    SELECT id, email
      INTO v_lowest_id, v_email
      FROM members
     ORDER BY id ASC
     LIMIT 1;

    SELECT COUNT(*)
      INTO v_total_bookings
      FROM bookings
     WHERE member_id = v_lowest_id;

    RAISE NOTICE 'Member with lowest id (%) -> email: %, total bookings: %',
        v_lowest_id, v_email, v_total_bookings;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE NOTICE 'No members found in the members table.';
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error while looking up the member: %', SQLERRM;
END;
$$;

-- (3) Note: plain SQL SELECT vs PL/pgSQL block
-- A plain "SELECT email, ... FROM members ORDER BY id LIMIT 1" can only
-- return a result set to the client - it cannot store that value in a
-- variable, run a second dependent query using it, branch on it, or
-- decide what to print. Wrapping it in a PL/pgSQL block gives us
-- procedural capability: we can capture the result with SELECT INTO,
-- reuse it immediately in the next query (the booking count), and
-- control what happens next (including catching errors), all inside
-- the database itself instead of round-tripping values back to the client.


-- ============================================================
-- PHASE 2: CONTROL FLOW & LOOPS
-- ============================================================

-- (4) IF / ELSIF / ELSE on a specific member's status
DO $$
DECLARE
    v_member_id INTEGER := 4; -- Nada Hasan, currently 'inactive'
    v_status    members.status%TYPE;
BEGIN
    SELECT status INTO v_status FROM members WHERE id = v_member_id;

    IF v_status = 'active' THEN
        RAISE NOTICE 'Member % is active and can book classes.', v_member_id;
    ELSIF v_status = 'inactive' THEN
        RAISE NOTICE 'Member % is inactive; please reactivate before booking.', v_member_id;
    ELSE
        RAISE NOTICE 'Member % has an unrecognized status: %', v_member_id, v_status;
    END IF;
END;
$$;

-- (5) FOR loop over all classes in one category (Yoga, category_id = 1)
DO $$
DECLARE
    r_class RECORD;
BEGIN
    FOR r_class IN
        SELECT name FROM classes WHERE category_id = 1 ORDER BY id
    LOOP
        RAISE NOTICE 'Yoga class: %', r_class.name;
    END LOOP;
END;
$$;

-- (6) WHILE loop counting a trainer's sessions without using COUNT() directly
DO $$
DECLARE
    v_trainer_id   INTEGER := 1; -- Sarah jameel
    v_session_ids  INTEGER[];
    v_index        INTEGER := 1;
    v_counter      INTEGER := 0;
BEGIN
    SELECT ARRAY_AGG(id ORDER BY id)
      INTO v_session_ids
      FROM sessions
     WHERE trainer_id = v_trainer_id;

    WHILE v_index <= COALESCE(array_length(v_session_ids, 1), 0) LOOP
        v_counter := v_counter + 1;
        v_index   := v_index + 1;
    END LOOP;

    RAISE NOTICE 'Trainer % has led % session(s) (counted via WHILE loop).', v_trainer_id, v_counter;
END;
$$;


-- ============================================================
-- PHASE 3: FUNCTIONS
-- ============================================================

-- (7) get_member_full_name
CREATE OR REPLACE FUNCTION get_member_full_name(p_member_id INT)
RETURNS TEXT AS $$
DECLARE
    v_full_name TEXT;
BEGIN
    SELECT first_name || ' ' || last_name
      INTO v_full_name
      FROM members
     WHERE id = p_member_id;

    IF v_full_name IS NULL THEN
        RETURN 'Member not found';
    END IF;

    RETURN v_full_name;
END;
$$ LANGUAGE plpgsql;

-- Sample call:
SELECT get_member_full_name(1) AS full_name;

-- (8) get_average_rating_by_trainer
CREATE OR REPLACE FUNCTION get_average_rating_by_trainer(p_trainer_id INT)
RETURNS NUMERIC AS $$
DECLARE
    v_avg_rating NUMERIC;
BEGIN
    SELECT ROUND(AVG(b.rating), 2)
      INTO v_avg_rating
      FROM bookings b
      JOIN sessions s ON s.id = b.session_id
     WHERE s.trainer_id = p_trainer_id
       AND b.rating IS NOT NULL;

    RETURN COALESCE(v_avg_rating, 0);
END;
$$ LANGUAGE plpgsql;

-- Sample call:
SELECT get_average_rating_by_trainer(1) AS avg_rating;

-- (9) calculate_loyalty_points
-- NOTE / ASSUMPTION: the assignment text describing the exact formula
-- was cut off in the PDF ("... a rating 5 ."). This implementation
-- assumes: 10 points for every booking the member rated 4 or 5.
-- Adjust the multiplier/threshold below if your instructor specified
-- a different rule.
CREATE OR REPLACE FUNCTION calculate_loyalty_points(p_member_id INT)
RETURNS INT AS $$
DECLARE
    v_points INT;
BEGIN
    SELECT COUNT(*) * 10
      INTO v_points
      FROM bookings
     WHERE member_id = p_member_id
       AND rating >= 4;

    RETURN COALESCE(v_points, 0);
END;
$$ LANGUAGE plpgsql;

-- Sample call:
SELECT calculate_loyalty_points(1) AS loyalty_points;


-- ============================================================
-- PHASE 4: PROCEDURES
-- ============================================================

-- (10) add_new_booking
CREATE OR REPLACE PROCEDURE add_new_booking(p_member_id INT, p_session_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO bookings (member_id, session_id, rating, comment)
    VALUES (p_member_id, p_session_id, NULL, NULL);

    RAISE NOTICE 'Booking added for member % on session %.', p_member_id, p_session_id;
END;
$$;

-- Sample call: member 5 books session 6 (a session they have not booked before)
CALL add_new_booking(5, 6);

-- (11) update_member_status
CREATE OR REPLACE PROCEDURE update_member_status(p_member_id INT, p_new_status VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE members
       SET status = p_new_status
     WHERE id = p_member_id;

    RAISE NOTICE 'Member % status updated to %.', p_member_id, p_new_status;
END;
$$;

-- Sample call: reactivate Nada Hasan (id 4)
CALL update_member_status(4, 'active');


-- ============================================================
-- PHASE 5: ERROR HANDLING & RECORD VARIABLES
-- ============================================================

-- (12) RECORD variable inside a FOR loop, over every session of one class
DO $$
DECLARE
    r_session RECORD;
BEGIN
    FOR r_session IN
        SELECT session_date, room, trainer_id
          FROM sessions
         WHERE class_id = 1 -- Morning Yoga
         ORDER BY id
    LOOP
        RAISE NOTICE 'Session date: %, Room: %, Trainer id: %',
            r_session.session_date, r_session.room, r_session.trainer_id;
    END LOOP;
END;
$$;

-- (13) add_new_booking wrapped in BEGIN/EXCEPTION - deliberately trigger an error
CREATE OR REPLACE PROCEDURE add_new_booking_safe(p_member_id INT, p_session_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        INSERT INTO bookings (member_id, session_id, rating, comment)
        VALUES (p_member_id, p_session_id, NULL, NULL);

        RAISE NOTICE 'Booking added for member % on session %.', p_member_id, p_session_id;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Could not add booking: member % or session % does not exist.',
                p_member_id, p_session_id;
        WHEN OTHERS THEN
            RAISE NOTICE 'Unexpected error while adding booking: %', SQLERRM;
    END;
END;
$$;

-- Sample call: session 9999 does not exist - this is deliberate, to
-- prove the EXCEPTION block catches it instead of crashing.
CALL add_new_booking_safe(1, 9999);


-- ============================================================
-- PHASE 6: PRACTICAL APPLICATIONS OF PL/pgSQL
-- ============================================================

-- (14) get_member_by_email using OUT parameters
CREATE OR REPLACE FUNCTION get_member_by_email(
    p_email     VARCHAR,
    OUT o_id        INT,
    OUT o_full_name TEXT,
    OUT o_status    VARCHAR,
    OUT o_message   TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT id, first_name || ' ' || last_name, status
      INTO o_id, o_full_name, o_status
      FROM members
     WHERE email = p_email;

    IF o_id IS NULL THEN
        o_message := 'No member found with email ' || p_email;
    ELSE
        o_message := 'Member found.';
    END IF;
END;
$$;

-- Sample calls: one that matches, one that does not
SELECT * FROM get_member_by_email('ashraf.muneer@mail.com');
SELECT * FROM get_member_by_email('nobody@nowhere.com');

-- (15) is_valid_rating
CREATE OR REPLACE FUNCTION is_valid_rating(p_rating INT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN p_rating IS NOT NULL AND p_rating BETWEEN 1 AND 5;
END;
$$ LANGUAGE plpgsql;

-- Sample calls:
SELECT is_valid_rating(4) AS should_be_true;
SELECT is_valid_rating(9) AS should_be_false;

-- (16) apply_loyalty_bonus - every member with more than 3 bookings
-- gets loyalty_level + 1, capped at 5.
CREATE OR REPLACE PROCEDURE apply_loyalty_bonus()
LANGUAGE plpgsql AS $$
DECLARE
    r_member RECORD;
BEGIN
    FOR r_member IN
        SELECT m.id, COUNT(b.id) AS total_bookings
          FROM members m
          JOIN bookings b ON b.member_id = m.id
         GROUP BY m.id
        HAVING COUNT(b.id) > 3
    LOOP
        UPDATE members
           SET loyalty_level = LEAST(loyalty_level + 1, 5)
         WHERE id = r_member.id;

        RAISE NOTICE 'Member % (% bookings) loyalty level increased.',
            r_member.id, r_member.total_bookings;
    END LOOP;
END;
$$;

-- Sample call (member 1 has 5 bookings, member 2 has 4, from the
-- supplementary data inserted above - both qualify):
CALL apply_loyalty_bonus();
SELECT id, first_name, last_name, loyalty_level FROM members ORDER BY id;

-- (17) get_available_seats - fixed room capacity constant inside the function
CREATE OR REPLACE FUNCTION get_available_seats(p_session_id INT)
RETURNS INT AS $$
DECLARE
    c_room_capacity CONSTANT INT := 15;
    v_booked_seats  INT;
BEGIN
    SELECT COUNT(*)
      INTO v_booked_seats
      FROM bookings
     WHERE session_id = p_session_id;

    RETURN c_room_capacity - v_booked_seats;
END;
$$ LANGUAGE plpgsql;

-- Sample call:
SELECT get_available_seats(1) AS available_seats;


-- ============================================================
-- PART B - ADVANCED PL/pgSQL
-- ============================================================

-- ============================================================
-- PHASE 7: NAMED EXCEPTION HANDLING
-- ============================================================

-- (18) Insert a trainer with a duplicate email, caught via unique_violation
DO $$
BEGIN
    BEGIN
        INSERT INTO trainers (first_name, last_name, email, years_experience)
        VALUES ('Test', 'Trainer', 'sarah.jameel@fitzone.com', 1); -- email already exists

        RAISE NOTICE 'Trainer inserted successfully.';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Insert failed: a trainer with this email already exists.';
    END;
END;
$$;

-- (19) Insert a booking with a nonexistent session_id, caught via foreign_key_violation
DO $$
BEGIN
    BEGIN
        INSERT INTO bookings (member_id, session_id)
        VALUES (1, 9999); -- session 9999 does not exist

        RAISE NOTICE 'Booking inserted successfully.';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Insert failed: session id 9999 does not exist.';
    END;
END;
$$;


-- ============================================================
-- PHASE 8: ADDITIONAL PL/pgSQL PRACTICE
-- ============================================================

-- (20) Total number of members, via SELECT INTO + RAISE NOTICE
DO $$
DECLARE
    v_total_members INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_members FROM members;
    RAISE NOTICE 'Total members in FitZone: %', v_total_members;
END;
$$;


-- ============================================================
-- PHASE 9: TRIGGERS - VALIDATION & BUSINESS RULES
-- ============================================================

-- (21-A) Validation trigger - "prevent duplicate booking" was chosen
-- over "rating 1-5", because rating validity is already enforced by
-- the CHECK (rating BETWEEN 1 AND 5) constraint on bookings from
-- Assignment 1; a trigger here would be redundant. Preventing a
-- member from booking the exact same session twice is not covered
-- by any existing constraint, so it adds real value.
CREATE OR REPLACE FUNCTION trg_prevent_duplicate_booking()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM bookings
         WHERE member_id = NEW.member_id
           AND session_id = NEW.session_id
    ) THEN
        RAISE EXCEPTION 'Member % has already booked session %.',
            NEW.member_id, NEW.session_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_duplicate_booking
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trg_prevent_duplicate_booking();

-- Test: member 1 already booked session 1 in Assignment 1 data.
DO $$
BEGIN
    BEGIN
        INSERT INTO bookings (member_id, session_id) VALUES (1, 1);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Trigger correctly blocked duplicate booking: %', SQLERRM;
    END;
END;
$$;

-- (21-B) Business rule trigger - prevent updating rating twice
-- (once a booking has a non-null rating, it cannot be changed again).
CREATE OR REPLACE FUNCTION trg_prevent_rating_double_update()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.rating IS NOT NULL AND NEW.rating IS DISTINCT FROM OLD.rating THEN
        RAISE EXCEPTION 'Rating for booking % has already been submitted and cannot be changed.',
            OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_rating_update
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trg_prevent_rating_double_update();

-- Test: booking id 1 (member 1 / session 1) already has rating 5.
DO $$
BEGIN
    BEGIN
        UPDATE bookings SET rating = 1 WHERE id = 1;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Trigger correctly blocked rating change: %', SQLERRM;
    END;
END;
$$;


-- ============================================================
-- PHASE 10: AUDIT LOGGING
-- ============================================================

-- Supporting table: records every INSERT/UPDATE/DELETE on bookings.
CREATE TABLE audit_log (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR(50) NOT NULL,
    operation   VARCHAR(10) NOT NULL,
    row_id      INTEGER,
    changed_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    old_data    JSONB,
    new_data    JSONB
);

CREATE OR REPLACE FUNCTION trg_audit_bookings()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, row_id, new_data)
        VALUES ('bookings', 'INSERT', NEW.id, to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data)
        VALUES ('bookings', 'UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, row_id, old_data)
        VALUES ('bookings', 'DELETE', OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bookings_audit
    AFTER INSERT OR UPDATE OR DELETE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trg_audit_bookings();

-- Test: insert, update, then delete a booking, and confirm each
-- action was logged.
CALL add_new_booking(3, 6); -- member 3 has not booked session 6 before

UPDATE bookings
   SET comment = 'Updated comment for audit test'
 WHERE member_id = 3 AND session_id = 6;

DELETE FROM bookings
 WHERE member_id = 3 AND session_id = 6;

SELECT id, table_name, operation, row_id, changed_at
  FROM audit_log
 ORDER BY id DESC
 LIMIT 5;


-- ============================================================
-- PHASE 11: BUSINESS RULES IN THE DATABASE
-- ============================================================

-- AFTER UPDATE trigger: when a booking's rating changes from NULL
-- to a real value for the first time, bump the member's
-- loyalty_level by 1 (never exceeding 5).
CREATE OR REPLACE FUNCTION trg_award_loyalty_on_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.rating IS NULL AND NEW.rating IS NOT NULL THEN
        UPDATE members
           SET loyalty_level = LEAST(loyalty_level + 1, 5)
         WHERE id = NEW.member_id;

        RAISE NOTICE 'Loyalty level increased for member % (rating submitted for booking %).',
            NEW.member_id, NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bookings_loyalty_on_rating
    AFTER UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION trg_award_loyalty_on_rating();

-- Test: booking for member 2 / session 8 was inserted with a NULL
-- rating in Assignment 1 - filling it in for the first time here.
UPDATE bookings
   SET rating = 4
 WHERE member_id = 2 AND session_id = 8;

SELECT id, first_name, last_name, loyalty_level
  FROM members
 WHERE id = 2;

-- ============================================================
-- END OF FILE
-- ============================================================
