-- ============================================================
--   STARTUP COLLABORATION PLATFORM
--   Database: Oracle SQL (SQL*Plus)
--   File: project.sql
-- ============================================================

-- ============================================================
-- SECTION 1: DROP EXISTING TABLES (Clean Start)
-- ============================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE notifications CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE feedback CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ratings CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE tasks CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE investor_interests CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE collaboration_requests CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE team_members CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE saved_ideas CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE idea_likes CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE startup_ideas CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE user_skills CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE skills CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- SECTION 2: DROP SEQUENCES
-- ============================================================

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_users'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_skills'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ideas'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_collab'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_tasks'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_notifications'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_ratings'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_feedback'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_investor'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- SECTION 3: CREATE SEQUENCES
-- ============================================================

CREATE SEQUENCE seq_users START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_skills START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_ideas START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_collab START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_tasks START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_notifications START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_ratings START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_feedback START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_investor START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================
-- SECTION 4: CREATE TABLES
-- ============================================================

-- 4.1 USERS TABLE
CREATE TABLE users (
    user_id         NUMBER PRIMARY KEY,
    full_name       VARCHAR2(100) NOT NULL,
    email           VARCHAR2(150) UNIQUE NOT NULL,
    password_hash   VARCHAR2(255) NOT NULL,
    role            VARCHAR2(20) CHECK (role IN ('Founder', 'Developer', 'Investor')) NOT NULL,
    bio             VARCHAR2(500),
    location        VARCHAR2(100),
    experience      VARCHAR2(50),
    is_admin        NUMBER(1) DEFAULT 0,
    is_active       NUMBER(1) DEFAULT 1,
    created_at      DATE DEFAULT SYSDATE
);

-- 4.2 SKILLS TABLE (Master List)
CREATE TABLE skills (
    skill_id    NUMBER PRIMARY KEY,
    skill_name  VARCHAR2(100) UNIQUE NOT NULL
);

-- 4.3 USER SKILLS TABLE
CREATE TABLE user_skills (
    user_id     NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    skill_id    NUMBER REFERENCES skills(skill_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, skill_id)
);

-- 4.4 STARTUP IDEAS TABLE
CREATE TABLE startup_ideas (
    idea_id         NUMBER PRIMARY KEY,
    founder_id      NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    title           VARCHAR2(200) NOT NULL,
    description     CLOB,
    domain          VARCHAR2(50) CHECK (domain IN ('AI', 'FinTech', 'HealthTech', 'EdTech', 'E-Commerce', 'SaaS', 'Other')),
    required_skills VARCHAR2(500),
    location        VARCHAR2(100),
    status          VARCHAR2(20) DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Completed')),
    progress        NUMBER(3) DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
    likes_count     NUMBER DEFAULT 0,
    created_at      DATE DEFAULT SYSDATE
);

-- 4.5 IDEA LIKES TABLE
CREATE TABLE idea_likes (
    like_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idea_id     NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    user_id     NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    liked_at    DATE DEFAULT SYSDATE,
    UNIQUE (idea_id, user_id)
);

-- 4.6 SAVED IDEAS TABLE
CREATE TABLE saved_ideas (
    save_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idea_id     NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    user_id     NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    saved_at    DATE DEFAULT SYSDATE,
    UNIQUE (idea_id, user_id)
);

-- 4.7 TEAM MEMBERS TABLE
CREATE TABLE team_members (
    team_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idea_id     NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    user_id     NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    role        VARCHAR2(100),
    joined_at   DATE DEFAULT SYSDATE,
    UNIQUE (idea_id, user_id)
);

-- 4.8 COLLABORATION REQUESTS TABLE
CREATE TABLE collaboration_requests (
    request_id  NUMBER PRIMARY KEY,
    idea_id     NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    sender_id   NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    message     VARCHAR2(500),
    status      VARCHAR2(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Accepted', 'Rejected')),
    requested_at DATE DEFAULT SYSDATE
);

-- 4.9 TASKS TABLE
CREATE TABLE tasks (
    task_id         NUMBER PRIMARY KEY,
    idea_id         NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    assigned_to     NUMBER REFERENCES users(user_id) ON DELETE SET NULL,
    assigned_by     NUMBER REFERENCES users(user_id) ON DELETE SET NULL,
    task_title      VARCHAR2(200) NOT NULL,
    description     VARCHAR2(500),
    status          VARCHAR2(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed')),
    due_date        DATE,
    created_at      DATE DEFAULT SYSDATE
);

-- 4.10 INVESTOR INTERESTS TABLE
CREATE TABLE investor_interests (
    interest_id     NUMBER PRIMARY KEY,
    investor_id     NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    idea_id         NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    message         VARCHAR2(500),
    status          VARCHAR2(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Accepted', 'Rejected')),
    expressed_at    DATE DEFAULT SYSDATE,
    UNIQUE (investor_id, idea_id)
);

-- 4.11 RATINGS TABLE
CREATE TABLE ratings (
    rating_id       NUMBER PRIMARY KEY,
    rated_user_id   NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    rated_by        NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    idea_id         NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    score           NUMBER(2) CHECK (score BETWEEN 1 AND 5),
    rated_at        DATE DEFAULT SYSDATE,
    UNIQUE (rated_user_id, rated_by, idea_id)
);

-- 4.12 FEEDBACK TABLE
CREATE TABLE feedback (
    feedback_id     NUMBER PRIMARY KEY,
    from_user_id    NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    to_user_id      NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    idea_id         NUMBER REFERENCES startup_ideas(idea_id) ON DELETE CASCADE,
    feedback_text   VARCHAR2(1000),
    created_at      DATE DEFAULT SYSDATE
);

-- 4.13 NOTIFICATIONS TABLE
CREATE TABLE notifications (
    notif_id        NUMBER PRIMARY KEY,
    user_id         NUMBER REFERENCES users(user_id) ON DELETE CASCADE,
    message         VARCHAR2(500),
    notif_type      VARCHAR2(50) CHECK (notif_type IN ('Join Request', 'Task Assigned', 'Idea Liked', 'Request Accepted', 'Request Rejected', 'Investor Interest', 'General')),
    is_read         NUMBER(1) DEFAULT 0,
    created_at      DATE DEFAULT SYSDATE
);

-- ============================================================
-- SECTION 5: INSERT SAMPLE DATA
-- ============================================================

-- Users
INSERT INTO users VALUES (seq_users.NEXTVAL, 'Aarav Shah', 'aarav@email.com', 'hash1', 'Founder', 'Building next-gen startups', 'Ahmedabad', '3 years', 0, 1, SYSDATE);
INSERT INTO users VALUES (seq_users.NEXTVAL, 'Priya Mehta', 'priya@email.com', 'hash2', 'Developer', 'Full stack developer', 'Mumbai', '2 years', 0, 1, SYSDATE);
INSERT INTO users VALUES (seq_users.NEXTVAL, 'Rohan Patel', 'rohan@email.com', 'hash3', 'Investor', 'Angel investor in FinTech', 'Delhi', '5 years', 0, 1, SYSDATE);
INSERT INTO users VALUES (seq_users.NEXTVAL, 'Sneha Joshi', 'sneha@email.com', 'hash4', 'Developer', 'AI/ML enthusiast', 'Pune', '1 year', 0, 1, SYSDATE);
INSERT INTO users VALUES (seq_users.NEXTVAL, 'Admin User', 'admin@email.com', 'adminhash', 'Founder', 'Platform admin', 'Ahmedabad', '10 years', 1, 1, SYSDATE);

-- Skills
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'Python');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'JavaScript');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'React');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'Machine Learning');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'UI/UX Design');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'Finance');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'Marketing');
INSERT INTO skills VALUES (seq_skills.NEXTVAL, 'Node.js');

-- User Skills
INSERT INTO user_skills VALUES (1, 1);
INSERT INTO user_skills VALUES (1, 7);
INSERT INTO user_skills VALUES (2, 1);
INSERT INTO user_skills VALUES (2, 2);
INSERT INTO user_skills VALUES (2, 3);
INSERT INTO user_skills VALUES (4, 1);
INSERT INTO user_skills VALUES (4, 4);

-- Startup Ideas
INSERT INTO startup_ideas VALUES (seq_ideas.NEXTVAL, 1, 'AI Study Buddy', 'An AI-powered platform to help students study smarter using personalized recommendations.', 'AI', 'Python,Machine Learning,React', 'Ahmedabad', 'Active', 20, 0, SYSDATE);
INSERT INTO startup_ideas VALUES (seq_ideas.NEXTVAL, 1, 'FinTrack', 'A personal finance tracker for college students with budgeting and investment tips.', 'FinTech', 'React,Node.js,Finance', 'Mumbai', 'Active', 10, 0, SYSDATE);

-- Team Members
INSERT INTO team_members (idea_id, user_id, role) VALUES (1, 1, 'Founder');
INSERT INTO team_members (idea_id, user_id, role) VALUES (1, 2, 'Lead Developer');

-- Collaboration Requests
INSERT INTO collaboration_requests VALUES (seq_collab.NEXTVAL, 2, 4, 'I would love to contribute my ML skills!', 'Pending', SYSDATE);

-- Tasks
INSERT INTO tasks VALUES (seq_tasks.NEXTVAL, 1, 2, 1, 'Build Login Page', 'Create login and register UI', 'Pending', SYSDATE + 7, SYSDATE);
INSERT INTO tasks VALUES (seq_tasks.NEXTVAL, 1, 4, 1, 'Train ML Model', 'Train recommendation model on dataset', 'In Progress', SYSDATE + 14, SYSDATE);

-- Investor Interests
INSERT INTO investor_interests VALUES (seq_investor.NEXTVAL, 3, 1, 'Interested in funding this AI project!', 'Pending', SYSDATE);

-- Notifications
INSERT INTO notifications VALUES (seq_notifications.NEXTVAL, 1, 'Sneha Joshi requested to join your startup FinTrack', 'Join Request', 0, SYSDATE);
INSERT INTO notifications VALUES (seq_notifications.NEXTVAL, 2, 'You have been assigned a new task: Build Login Page', 'Task Assigned', 0, SYSDATE);

COMMIT;

-- ============================================================
-- SECTION 6: STORED PROCEDURES
-- ============================================================

-- 6.1 REGISTER USER
CREATE OR REPLACE PROCEDURE sp_register_user (
    p_full_name     IN VARCHAR2,
    p_email         IN VARCHAR2,
    p_password_hash IN VARCHAR2,
    p_role          IN VARCHAR2,
    p_location      IN VARCHAR2,
    p_result        OUT VARCHAR2
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM users WHERE email = p_email;
    IF v_count > 0 THEN
        p_result := 'ERROR: Email already registered.';
    ELSE
        INSERT INTO users (user_id, full_name, email, password_hash, role, location)
        VALUES (seq_users.NEXTVAL, p_full_name, p_email, p_password_hash, p_role, p_location);
        COMMIT;
        p_result := 'SUCCESS: User registered successfully.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.2 LOGIN USER
CREATE OR REPLACE PROCEDURE sp_login_user (
    p_email         IN VARCHAR2,
    p_password_hash IN VARCHAR2,
    p_user_id       OUT NUMBER,
    p_role          OUT VARCHAR2,
    p_result        OUT VARCHAR2
) AS
BEGIN
    SELECT user_id, role INTO p_user_id, p_role
    FROM users
    WHERE email = p_email AND password_hash = p_password_hash AND is_active = 1;
    p_result := 'SUCCESS';
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_user_id := NULL;
        p_role := NULL;
        p_result := 'ERROR: Invalid email or password.';
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.3 POST STARTUP IDEA
CREATE OR REPLACE PROCEDURE sp_post_idea (
    p_founder_id        IN NUMBER,
    p_title             IN VARCHAR2,
    p_description       IN VARCHAR2,
    p_domain            IN VARCHAR2,
    p_required_skills   IN VARCHAR2,
    p_location          IN VARCHAR2,
    p_result            OUT VARCHAR2
) AS
    v_idea_id NUMBER;
BEGIN
    v_idea_id := seq_ideas.NEXTVAL;
    INSERT INTO startup_ideas (idea_id, founder_id, title, description, domain, required_skills, location)
    VALUES (v_idea_id, p_founder_id, p_title, p_description, p_domain, p_required_skills, p_location);

    -- Auto add founder as team member
    INSERT INTO team_members (idea_id, user_id, role)
    VALUES (v_idea_id, p_founder_id, 'Founder');

    COMMIT;
    p_result := 'SUCCESS: Idea posted with ID ' || v_idea_id;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.4 SEND COLLABORATION REQUEST
CREATE OR REPLACE PROCEDURE sp_send_collab_request (
    p_idea_id   IN NUMBER,
    p_sender_id IN NUMBER,
    p_message   IN VARCHAR2,
    p_result    OUT VARCHAR2
) AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM collaboration_requests
    WHERE idea_id = p_idea_id AND sender_id = p_sender_id;

    IF v_count > 0 THEN
        p_result := 'ERROR: You have already sent a request for this idea.';
    ELSE
        INSERT INTO collaboration_requests (request_id, idea_id, sender_id, message)
        VALUES (seq_collab.NEXTVAL, p_idea_id, p_sender_id, p_message);
        COMMIT;
        p_result := 'SUCCESS: Collaboration request sent.';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.5 ACCEPT OR REJECT COLLABORATION REQUEST
CREATE OR REPLACE PROCEDURE sp_handle_collab_request (
    p_request_id    IN NUMBER,
    p_action        IN VARCHAR2,
    p_role          IN VARCHAR2,
    p_result        OUT VARCHAR2
) AS
    v_idea_id   NUMBER;
    v_sender_id NUMBER;
BEGIN
    SELECT idea_id, sender_id INTO v_idea_id, v_sender_id
    FROM collaboration_requests WHERE request_id = p_request_id;

    UPDATE collaboration_requests
    SET status = p_action
    WHERE request_id = p_request_id;

    IF p_action = 'Accepted' THEN
        INSERT INTO team_members (idea_id, user_id, role)
        VALUES (v_idea_id, v_sender_id, p_role);

        INSERT INTO notifications (notif_id, user_id, message, notif_type)
        VALUES (seq_notifications.NEXTVAL, v_sender_id, 'Your collaboration request has been accepted!', 'Request Accepted');
    ELSE
        INSERT INTO notifications (notif_id, user_id, message, notif_type)
        VALUES (seq_notifications.NEXTVAL, v_sender_id, 'Your collaboration request was rejected.', 'Request Rejected');
    END IF;

    COMMIT;
    p_result := 'SUCCESS: Request ' || p_action;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.6 ASSIGN TASK
CREATE OR REPLACE PROCEDURE sp_assign_task (
    p_idea_id       IN NUMBER,
    p_assigned_to   IN NUMBER,
    p_assigned_by   IN NUMBER,
    p_title         IN VARCHAR2,
    p_description   IN VARCHAR2,
    p_due_date      IN DATE,
    p_result        OUT VARCHAR2
) AS
BEGIN
    INSERT INTO tasks (task_id, idea_id, assigned_to, assigned_by, task_title, description, due_date)
    VALUES (seq_tasks.NEXTVAL, p_idea_id, p_assigned_to, p_assigned_by, p_title, p_description, p_due_date);
    COMMIT;
    p_result := 'SUCCESS: Task assigned successfully.';
EXCEPTION
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- 6.7 SUBMIT RATING
CREATE OR REPLACE PROCEDURE sp_submit_rating (
    p_rated_user_id IN NUMBER,
    p_rated_by      IN NUMBER,
    p_idea_id       IN NUMBER,
    p_score         IN NUMBER,
    p_result        OUT VARCHAR2
) AS
BEGIN
    IF p_rated_user_id = p_rated_by THEN
        p_result := 'ERROR: You cannot rate yourself.';
        RETURN;
    END IF;

    INSERT INTO ratings (rating_id, rated_user_id, rated_by, idea_id, score)
    VALUES (seq_ratings.NEXTVAL, p_rated_user_id, p_rated_by, p_idea_id, p_score);
    COMMIT;
    p_result := 'SUCCESS: Rating submitted.';
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        p_result := 'ERROR: You have already rated this user for this idea.';
    WHEN OTHERS THEN
        p_result := 'ERROR: ' || SQLERRM;
END;
/

-- ============================================================
-- SECTION 7: FUNCTIONS
-- ============================================================

-- 7.1 GET AVERAGE RATING OF A USER
CREATE OR REPLACE FUNCTION fn_get_avg_rating (
    p_user_id IN NUMBER
) RETURN NUMBER AS
    v_avg NUMBER;
BEGIN
    SELECT ROUND(AVG(score), 2) INTO v_avg
    FROM ratings WHERE rated_user_id = p_user_id;
    RETURN NVL(v_avg, 0);
END;
/

-- 7.2 GET TOTAL LIKES OF AN IDEA
CREATE OR REPLACE FUNCTION fn_get_idea_likes (
    p_idea_id IN NUMBER
) RETURN NUMBER AS
    v_likes NUMBER;
BEGIN
    SELECT likes_count INTO v_likes
    FROM startup_ideas WHERE idea_id = p_idea_id;
    RETURN NVL(v_likes, 0);
END;
/

-- 7.3 GET TEAM SIZE OF A STARTUP
CREATE OR REPLACE FUNCTION fn_get_team_size (
    p_idea_id IN NUMBER
) RETURN NUMBER AS
    v_size NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_size
    FROM team_members WHERE idea_id = p_idea_id;
    RETURN v_size;
END;
/

-- 7.4 GET UNREAD NOTIFICATION COUNT
CREATE OR REPLACE FUNCTION fn_unread_notifications (
    p_user_id IN NUMBER
) RETURN NUMBER AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM notifications WHERE user_id = p_user_id AND is_read = 0;
    RETURN v_count;
END;
/

-- 7.5 SKILL MATCH FUNCTION (returns count of matched skills)
CREATE OR REPLACE FUNCTION fn_skill_match_count (
    p_user_id   IN NUMBER,
    p_idea_id   IN NUMBER
) RETURN NUMBER AS
    v_required  VARCHAR2(500);
    v_count     NUMBER := 0;
    v_skill     VARCHAR2(100);
    v_pos       NUMBER := 1;
    v_next      NUMBER;
BEGIN
    SELECT required_skills INTO v_required FROM startup_ideas WHERE idea_id = p_idea_id;

    LOOP
        v_next := INSTR(v_required, ',', v_pos);
        IF v_next = 0 THEN
            v_skill := TRIM(SUBSTR(v_required, v_pos));
        ELSE
            v_skill := TRIM(SUBSTR(v_required, v_pos, v_next - v_pos));
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM user_skills us JOIN skills s ON us.skill_id = s.skill_id
        WHERE us.user_id = p_user_id AND UPPER(s.skill_name) = UPPER(v_skill);

        EXIT WHEN v_next = 0;
        v_pos := v_next + 1;
    END LOOP;

    RETURN v_count;
EXCEPTION
    WHEN OTHERS THEN RETURN 0;
END;
/

-- ============================================================
-- SECTION 8: TRIGGERS
-- ============================================================

-- 8.1 TRIGGER: Auto-create notification when collaboration request is sent
CREATE OR REPLACE TRIGGER trg_collab_request_notify
AFTER INSERT ON collaboration_requests
FOR EACH ROW
DECLARE
    v_founder_id NUMBER;
    v_sender_name VARCHAR2(100);
BEGIN
    SELECT founder_id INTO v_founder_id
    FROM startup_ideas WHERE idea_id = :NEW.idea_id;

    SELECT full_name INTO v_sender_name
    FROM users WHERE user_id = :NEW.sender_id;

    INSERT INTO notifications (notif_id, user_id, message, notif_type)
    VALUES (seq_notifications.NEXTVAL, v_founder_id,
            v_sender_name || ' requested to join your startup idea.',
            'Join Request');
END;
/

-- 8.2 TRIGGER: Auto-create notification when task is assigned
CREATE OR REPLACE TRIGGER trg_task_assigned_notify
AFTER INSERT ON tasks
FOR EACH ROW
BEGIN
    IF :NEW.assigned_to IS NOT NULL THEN
        INSERT INTO notifications (notif_id, user_id, message, notif_type)
        VALUES (seq_notifications.NEXTVAL, :NEW.assigned_to,
                'You have been assigned a new task: ' || :NEW.task_title,
                'Task Assigned');
    END IF;
END;
/

-- 8.3 TRIGGER: Auto-update likes_count when a like is inserted
CREATE OR REPLACE TRIGGER trg_update_likes_count
AFTER INSERT ON idea_likes
FOR EACH ROW
BEGIN
    UPDATE startup_ideas
    SET likes_count = likes_count + 1
    WHERE idea_id = :NEW.idea_id;
END;
/

-- 8.4 TRIGGER: Auto-update project progress when task is completed
CREATE OR REPLACE TRIGGER trg_update_project_progress
AFTER UPDATE OF status ON tasks
FOR EACH ROW
WHEN (NEW.status = 'Completed')
DECLARE
    v_total     NUMBER;
    v_completed NUMBER;
    v_progress  NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM tasks WHERE idea_id = :NEW.idea_id;
    SELECT COUNT(*) INTO v_completed FROM tasks WHERE idea_id = :NEW.idea_id AND status = 'Completed';

    IF v_total > 0 THEN
        v_progress := ROUND((v_completed / v_total) * 100);
        UPDATE startup_ideas SET progress = v_progress WHERE idea_id = :NEW.idea_id;
    END IF;
END;
/

-- 8.5 TRIGGER: Prevent duplicate team member
CREATE OR REPLACE TRIGGER trg_prevent_duplicate_team
BEFORE INSERT ON team_members
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM team_members WHERE idea_id = :NEW.idea_id AND user_id = :NEW.user_id;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: This user is already a member of the team.');
    END IF;
END;
/

-- 8.6 TRIGGER: Prevent self-rating
CREATE OR REPLACE TRIGGER trg_prevent_self_rating
BEFORE INSERT ON ratings
FOR EACH ROW
BEGIN
    IF :NEW.rated_user_id = :NEW.rated_by THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR: A user cannot rate themselves.');
    END IF;
END;
/

-- 8.7 TRIGGER: Notify investor when founder accepts/rejects interest
CREATE OR REPLACE TRIGGER trg_investor_response_notify
AFTER UPDATE OF status ON investor_interests
FOR EACH ROW
WHEN (NEW.status IN ('Accepted', 'Rejected'))
DECLARE
    v_idea_title VARCHAR2(200);
BEGIN
    SELECT title INTO v_idea_title FROM startup_ideas WHERE idea_id = :NEW.idea_id;

    INSERT INTO notifications (notif_id, user_id, message, notif_type)
    VALUES (seq_notifications.NEXTVAL, :NEW.investor_id,
            'Your investment interest in "' || v_idea_title || '" was ' || :NEW.status || '.',
            'Investor Interest');
END;
/

-- 8.8 TRIGGER: Notify idea owner when someone likes their idea
CREATE OR REPLACE TRIGGER trg_idea_liked_notify
AFTER INSERT ON idea_likes
FOR EACH ROW
DECLARE
    v_founder_id    NUMBER;
    v_liker_name    VARCHAR2(100);
    v_idea_title    VARCHAR2(200);
BEGIN
    SELECT founder_id, title INTO v_founder_id, v_idea_title
    FROM startup_ideas WHERE idea_id = :NEW.idea_id;

    SELECT full_name INTO v_liker_name FROM users WHERE user_id = :NEW.user_id;

    IF v_founder_id != :NEW.user_id THEN
        INSERT INTO notifications (notif_id, user_id, message, notif_type)
        VALUES (seq_notifications.NEXTVAL, v_founder_id,
                v_liker_name || ' liked your idea: ' || v_idea_title,
                'Idea Liked');
    END IF;
END;
/

-- ============================================================
-- SECTION 9: USEFUL QUERIES (for reference/testing)
-- ============================================================

-- View all users
-- SELECT user_id, full_name, email, role FROM users;

-- View all startup ideas
-- SELECT idea_id, title, domain, status, progress FROM startup_ideas;

-- Skill Matching: Find users matching required skills of idea 1
-- SELECT DISTINCT u.user_id, u.full_name, u.role, s.skill_name
-- FROM users u
-- JOIN user_skills us ON u.user_id = us.user_id
-- JOIN skills s ON us.skill_id = s.skill_id
-- JOIN startup_ideas si ON INSTR(UPPER(si.required_skills), UPPER(s.skill_name)) > 0
-- WHERE si.idea_id = 1 AND u.user_id != si.founder_id;

-- Search by domain
-- SELECT * FROM startup_ideas WHERE domain = 'AI';

-- Search by location
-- SELECT * FROM startup_ideas WHERE LOWER(location) LIKE '%ahmedabad%';

-- Get average rating of user 2
-- SELECT fn_get_avg_rating(2) AS avg_rating FROM DUAL;

-- Get team size of idea 1
-- SELECT fn_get_team_size(1) AS team_size FROM DUAL;

-- Get unread notifications for user 1
-- SELECT fn_unread_notifications(1) AS unread FROM DUAL;

-- Get total likes of idea 1
-- SELECT fn_get_idea_likes(1) AS total_likes FROM DUAL;

-- ============================================================
-- SECTION 10: CALL PROCEDURES (for testing in SQL*Plus)
-- ============================================================

-- Test Register User
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_register_user('Test User', 'test@email.com', 'testhash', 'Developer', 'Surat', v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Login User
-- DECLARE v_id NUMBER; v_role VARCHAR2(20); v_result VARCHAR2(200);
-- BEGIN
--     sp_login_user('aarav@email.com', 'hash1', v_id, v_role, v_result);
--     DBMS_OUTPUT.PUT_LINE('Result: ' || v_result || ' | User ID: ' || v_id || ' | Role: ' || v_role);
-- END;
-- /

-- Test Post Idea
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_post_idea(1, 'EcoTrack', 'Track your carbon footprint daily.', 'SaaS', 'Python,React', 'Ahmedabad', v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Send Collaboration Request (also fires trg_collab_request_notify)
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_send_collab_request(2, 4, 'I want to help with ML!', v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Handle Collab Request
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_handle_collab_request(1, 'Accepted', 'ML Engineer', v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Assign Task (also fires trg_task_assigned_notify)
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_assign_task(1, 2, 1, 'Design Homepage', 'Create the homepage UI', SYSDATE+5, v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Submit Rating (fires trg_prevent_self_rating if same user)
-- DECLARE v_result VARCHAR2(200);
-- BEGIN
--     sp_submit_rating(2, 1, 1, 5, v_result);
--     DBMS_OUTPUT.PUT_LINE(v_result);
-- END;
-- /

-- Test Duplicate Team Member Trigger (should throw error)
-- INSERT INTO team_members (idea_id, user_id, role) VALUES (1, 1, 'Founder');

-- Test Like Idea (fires trg_update_likes_count and trg_idea_liked_notify)
-- INSERT INTO idea_likes (idea_id, user_id) VALUES (1, 4);

-- Test Progress Trigger (fires trg_update_project_progress)
-- UPDATE tasks SET status = 'Completed' WHERE task_id = 1;

-- ============================================================
-- END OF project.sql
-- ============================================================