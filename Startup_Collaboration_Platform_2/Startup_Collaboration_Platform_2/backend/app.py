# ============================================================
#   STARTUP COLLABORATION PLATFORM
#   Backend: Flask (Python)
#   Database: Oracle SQL (oracledb)
#   File: app.py
# ============================================================

from flask import Flask, request, jsonify, session
from flask_cors import CORS
import oracledb
import hashlib
import os
from datetime import date, datetime

app = Flask(__name__)
app.secret_key = 'startup_collab_secret_key_2026'
CORS(app, supports_credentials=True, origins=[
    "http://127.0.0.1:8080", "http://localhost:8080",
    "http://127.0.0.1:5500", "http://localhost:5500", "null"
])

# ============================================================
# DATABASE CONNECTION
# ============================================================

DB_USERNAME = "krissa"
DB_PASSWORD = "krissa05"
DB_DSN      = "127.0.0.1:1521/XEPDB1"

def get_db_connection():
    try:
        conn = oracledb.connect(user=DB_USERNAME, password=DB_PASSWORD, dsn=DB_DSN)
        return conn
    except oracledb.Error as e:
        print(f"Database connection error: {e}")
        return None

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

# KEY FIX: helper to safely convert any Oracle value to JSON-safe type
def safe(val):
    if val is None:
        return None
    if hasattr(val, 'read'):        # Oracle LOB (CLOB/BLOB)
        return val.read()
    if isinstance(val, (datetime, date)):
        return val.strftime('%Y-%m-%d %H:%M:%S')
    return val

# ============================================================
# HELPER: Run a stored procedure
# ============================================================

def call_procedure(proc_name, params):
    conn = get_db_connection()
    if not conn:
        return {"status": "error", "message": "Database connection failed"}
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        params.append(result_var)
        cursor.callproc(proc_name, params)
        conn.commit()
        result = result_var.getvalue()
        return {"status": "success" if result.startswith("SUCCESS") else "error", "message": result}
    except oracledb.Error as e:
        return {"status": "error", "message": str(e)}
    finally:
        cursor.close()
        conn.close()

# ============================================================
# SECTION 1: AUTH ROUTES
# ============================================================

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    full_name = data.get('full_name')
    email     = data.get('email')
    password  = hash_password(data.get('password'))
    role      = data.get('role')
    location  = data.get('location', '')
    if not all([full_name, email, password, role]):
        return jsonify({"status": "error", "message": "All fields are required"}), 400
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        cursor.callproc('sp_register_user', [full_name, email, password, role, location, result_var])
        conn.commit()
        result = result_var.getvalue()
        if result.startswith("SUCCESS"):
            return jsonify({"status": "success", "message": "Registered successfully"}), 201
        else:
            return jsonify({"status": "error", "message": result}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/login', methods=['POST'])
def login():
    data     = request.get_json()
    email    = data.get('email')
    password = hash_password(data.get('password'))
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        user_id_var = cursor.var(oracledb.NUMBER)
        role_var    = cursor.var(oracledb.STRING)
        result_var  = cursor.var(oracledb.STRING)
        cursor.callproc('sp_login_user', [email, password, user_id_var, role_var, result_var])
        result  = result_var.getvalue()
        user_id = user_id_var.getvalue()
        role    = role_var.getvalue()
        if result == "SUCCESS":
            session['user_id'] = int(user_id)
            session['role']    = role
            return jsonify({"status": "success", "user_id": int(user_id), "role": role}), 200
        else:
            return jsonify({"status": "error", "message": result}), 401
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({"status": "success", "message": "Logged out"}), 200


# ============================================================
# SECTION 2: USER / PROFILE ROUTES
# ============================================================

@app.route('/api/profile/<int:user_id>', methods=['GET'])
def get_profile(user_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT u.user_id, u.full_name, u.email, u.role, u.bio,
                   u.location, u.experience, u.created_at
            FROM users u WHERE u.user_id = :p1
        """, p1=user_id)
        row = cursor.fetchone()
        if not row:
            return jsonify({"status": "error", "message": "User not found"}), 404

        cursor.execute("""
            SELECT s.skill_name FROM skills s
            JOIN user_skills us ON s.skill_id = us.skill_id
            WHERE us.user_id = :p1
        """, p1=user_id)
        skills = [r[0] for r in cursor.fetchall()]

        cursor.execute("SELECT fn_get_avg_rating(:p1) FROM DUAL", p1=user_id)
        avg_rating = cursor.fetchone()[0]

        profile = {
            "user_id": int(row[0]),
            "full_name": safe(row[1]) or "",
            "email": safe(row[2]) or "",
            "role": safe(row[3]) or "",
            "bio": safe(row[4]) or "",
            "location": safe(row[5]) or "",
            "experience": safe(row[6]) or "",
            "created_at": safe(row[7]) or "",
            "skills": skills,
            "avg_rating": float(avg_rating) if avg_rating else 0
        }
        return jsonify({"status": "success", "profile": profile}), 200
    except Exception as e:
        print(f"Profile error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/profile/<int:user_id>', methods=['PUT'])
def update_profile(user_id):
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE users SET bio = :p1, location = :p2, experience = :p3
            WHERE user_id = :p4
        """, p1=data.get('bio'), p2=data.get('location'), p3=data.get('experience'), p4=user_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Profile updated"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/users', methods=['GET'])
def get_all_users():
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT user_id, full_name, email, role, location, is_active FROM users ORDER BY created_at DESC")
        rows = cursor.fetchall()
        users = [{"user_id": r[0], "full_name": r[1], "email": r[2], "role": r[3], "location": r[4], "is_active": r[5]} for r in rows]
        return jsonify({"status": "success", "users": users}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/users/<int:user_id>/deactivate', methods=['PUT'])
def deactivate_user(user_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET is_active = 0 WHERE user_id = :p1", p1=user_id)
        conn.commit()
        return jsonify({"status": "success", "message": "User deactivated"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 3: STARTUP IDEAS ROUTES
# ============================================================

@app.route('/api/ideas', methods=['POST'])
def post_idea():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        cursor.callproc('sp_post_idea', [
            data.get('founder_id'), data.get('title'), data.get('description'),
            data.get('domain'), data.get('required_skills'), data.get('location'), result_var
        ])
        conn.commit()
        result = result_var.getvalue()
        if result.startswith("SUCCESS"):
            return jsonify({"status": "success", "message": result}), 201
        else:
            return jsonify({"status": "error", "message": result}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/ideas', methods=['GET'])
def get_all_ideas():
    domain   = request.args.get('domain')
    location = request.args.get('location')
    skill    = request.args.get('skill')
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        query = """
            SELECT si.idea_id, si.title, si.description, si.domain,
                   si.required_skills, si.location, si.status, si.progress,
                   si.likes_count, si.created_at, u.full_name
            FROM startup_ideas si
            JOIN users u ON si.founder_id = u.user_id
            WHERE si.status != 'Inactive'
        """
        params = {}
        if domain:
            query += " AND si.domain = :p_domain"
            params['p_domain'] = domain
        if location:
            query += " AND LOWER(si.location) LIKE :p_location"
            params['p_location'] = f"%{location.lower()}%"
        if skill:
            query += " AND UPPER(si.required_skills) LIKE :p_skill"
            params['p_skill'] = f"%{skill.upper()}%"
        query += " ORDER BY si.created_at DESC"
        cursor.execute(query, params)
        rows = cursor.fetchall()
        ideas = [{
            "idea_id": r[0], "title": safe(r[1]),
            "description": safe(r[2]) or "",
            "domain": safe(r[3]), "required_skills": safe(r[4]),
            "location": safe(r[5]), "status": safe(r[6]),
            "progress": r[7], "likes_count": r[8],
            "created_at": safe(r[9]), "founder_name": safe(r[10])
        } for r in rows]
        return jsonify({"status": "success", "ideas": ideas}), 200
    except Exception as e:
        print(f"get_all_ideas error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/ideas/<int:idea_id>', methods=['GET'])
def get_idea_detail(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT si.idea_id, si.title, si.description, si.domain,
                   si.required_skills, si.location, si.status, si.progress,
                   si.likes_count, si.created_at, u.full_name, u.user_id
            FROM startup_ideas si
            JOIN users u ON si.founder_id = u.user_id
            WHERE si.idea_id = :p1
        """, p1=idea_id)
        row = cursor.fetchone()
        if not row:
            return jsonify({"status": "error", "message": "Idea not found"}), 404

        cursor.execute("""
            SELECT u.user_id, u.full_name, u.role AS user_role, tm.role AS team_role
            FROM team_members tm JOIN users u ON tm.user_id = u.user_id
            WHERE tm.idea_id = :p1
        """, p1=idea_id)
        team = [{"user_id": r[0], "full_name": r[1], "user_role": r[2], "team_role": r[3]} for r in cursor.fetchall()]

        cursor.execute("SELECT fn_get_team_size(:p1) FROM DUAL", p1=idea_id)
        team_size = cursor.fetchone()[0]

        idea = {
            "idea_id": row[0], "title": safe(row[1]),
            "description": safe(row[2]) or "",
            "domain": safe(row[3]), "required_skills": safe(row[4]),
            "location": safe(row[5]), "status": safe(row[6]),
            "progress": row[7], "likes_count": row[8],
            "created_at": safe(row[9]), "founder_name": safe(row[10]),
            "founder_id": row[11], "team": team, "team_size": int(team_size)
        }
        return jsonify({"status": "success", "idea": idea}), 200
    except Exception as e:
        print(f"get_idea_detail error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/ideas/<int:idea_id>', methods=['DELETE'])
def delete_idea(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE startup_ideas SET status = 'Inactive' WHERE idea_id = :p1", p1=idea_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Idea removed"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 4: LIKE & SAVE ROUTES
# ============================================================

@app.route('/api/ideas/<int:idea_id>/like', methods=['POST'])
def like_idea(idea_id):
    data    = request.get_json()
    user_id = data.get('user_id')
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO idea_likes (idea_id, user_id) VALUES (:p1, :p2)", p1=idea_id, p2=user_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Idea liked!"}), 200
    except oracledb.IntegrityError:
        return jsonify({"status": "error", "message": "You already liked this idea"}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/ideas/<int:idea_id>/save', methods=['POST'])
def save_idea(idea_id):
    data    = request.get_json()
    user_id = data.get('user_id')
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO saved_ideas (idea_id, user_id) VALUES (:p1, :p2)", p1=idea_id, p2=user_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Idea saved!"}), 200
    except oracledb.IntegrityError:
        return jsonify({"status": "error", "message": "You already saved this idea"}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 5: COLLABORATION ROUTES
# ============================================================

@app.route('/api/collaborate/request', methods=['POST'])
def send_collab_request():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        cursor.callproc('sp_send_collab_request', [
            data.get('idea_id'), data.get('sender_id'), data.get('message'), result_var
        ])
        conn.commit()
        result = result_var.getvalue()
        status_code = 200 if result.startswith("SUCCESS") else 400
        return jsonify({"status": "success" if result.startswith("SUCCESS") else "error", "message": result}), status_code
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/collaborate/requests/<int:idea_id>', methods=['GET'])
def get_collab_requests(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT cr.request_id, u.full_name, u.email, u.role,
                   cr.message, cr.status, cr.requested_at
            FROM collaboration_requests cr
            JOIN users u ON cr.sender_id = u.user_id
            WHERE cr.idea_id = :p1
            ORDER BY cr.requested_at DESC
        """, p1=idea_id)
        rows = cursor.fetchall()
        requests = [{
            "request_id": r[0], "full_name": r[1], "email": r[2],
            "role": r[3], "message": r[4], "status": r[5], "requested_at": safe(r[6])
        } for r in rows]
        return jsonify({"status": "success", "requests": requests}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/collaborate/handle', methods=['POST'])
def handle_collab_request():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        cursor.callproc('sp_handle_collab_request', [
            data.get('request_id'), data.get('action'), data.get('role', 'Member'), result_var
        ])
        conn.commit()
        result = result_var.getvalue()
        status_code = 200 if result.startswith("SUCCESS") else 400
        return jsonify({"status": "success" if result.startswith("SUCCESS") else "error", "message": result}), status_code
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 6: TASKS ROUTES
# ============================================================

@app.route('/api/tasks', methods=['POST'])
def assign_task():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        due_date = datetime.strptime(data.get('due_date'), '%Y-%m-%d') if data.get('due_date') else None
        cursor.callproc('sp_assign_task', [
            data.get('idea_id'), data.get('assigned_to'), data.get('assigned_by'),
            data.get('task_title'), data.get('description'), due_date, result_var
        ])
        conn.commit()
        result = result_var.getvalue()
        status_code = 201 if result.startswith("SUCCESS") else 400
        return jsonify({"status": "success" if result.startswith("SUCCESS") else "error", "message": result}), status_code
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/tasks/<int:idea_id>', methods=['GET'])
def get_tasks(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT t.task_id, t.task_title, t.description, t.status,
                   t.due_date, u.full_name AS assigned_to_name
            FROM tasks t
            LEFT JOIN users u ON t.assigned_to = u.user_id
            WHERE t.idea_id = :p1
            ORDER BY t.created_at DESC
        """, p1=idea_id)
        rows = cursor.fetchall()
        tasks = [{
            "task_id": r[0], "task_title": safe(r[1]),
            "description": safe(r[2]) or "",
            "status": r[3], "due_date": safe(r[4]),
            "assigned_to_name": r[5]
        } for r in rows]
        return jsonify({"status": "success", "tasks": tasks}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/tasks/<int:task_id>/status', methods=['PUT'])
def update_task_status(task_id):
    data       = request.get_json()
    new_status = data.get('status')
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE tasks SET status = :p1 WHERE task_id = :p2", p1=new_status, p2=task_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Task status updated"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 7: INVESTOR ROUTES
# ============================================================

@app.route('/api/investor/interest', methods=['POST'])
def investor_interest():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO investor_interests (interest_id, investor_id, idea_id, message)
            VALUES (seq_investor.NEXTVAL, :p1, :p2, :p3)
        """, p1=data.get('investor_id'), p2=data.get('idea_id'), p3=data.get('message'))
        conn.commit()
        return jsonify({"status": "success", "message": "Interest expressed!"}), 201
    except oracledb.IntegrityError:
        return jsonify({"status": "error", "message": "You already expressed interest in this idea"}), 400
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/investor/handle', methods=['POST'])
def handle_investor_interest():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE investor_interests SET status = :p1 WHERE interest_id = :p2
        """, p1=data.get('action'), p2=data.get('interest_id'))
        conn.commit()
        return jsonify({"status": "success", "message": f"Interest {data.get('action')}"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/investor/interests/<int:idea_id>', methods=['GET'])
def get_investor_interests(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT ii.interest_id, u.full_name, u.email, ii.message, ii.status, ii.expressed_at
            FROM investor_interests ii
            JOIN users u ON ii.investor_id = u.user_id
            WHERE ii.idea_id = :p1
        """, p1=idea_id)
        rows = cursor.fetchall()
        interests = [{
            "interest_id": r[0], "full_name": r[1], "email": r[2],
            "message": r[3], "status": r[4], "expressed_at": safe(r[5])
        } for r in rows]
        return jsonify({"status": "success", "interests": interests}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 8: RATINGS & FEEDBACK ROUTES
# ============================================================

@app.route('/api/ratings', methods=['POST'])
def submit_rating():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        result_var = cursor.var(oracledb.STRING)
        cursor.callproc('sp_submit_rating', [
            data.get('rated_user_id'), data.get('rated_by'),
            data.get('idea_id'), data.get('score'), result_var
        ])
        conn.commit()
        result = result_var.getvalue()
        status_code = 201 if result.startswith("SUCCESS") else 400
        return jsonify({"status": "success" if result.startswith("SUCCESS") else "error", "message": result}), status_code
    except oracledb.DatabaseError as e:
        error_msg = str(e)
        if "ORA-20002" in error_msg:
            return jsonify({"status": "error", "message": "You cannot rate yourself"}), 400
        return jsonify({"status": "error", "message": error_msg}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/feedback', methods=['POST'])
def submit_feedback():
    data = request.get_json()
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO feedback (feedback_id, from_user_id, to_user_id, idea_id, feedback_text)
            VALUES (seq_feedback.NEXTVAL, :p1, :p2, :p3, :p4)
        """, p1=data.get('from_user_id'), p2=data.get('to_user_id'),
             p3=data.get('idea_id'), p4=data.get('feedback_text'))
        conn.commit()
        return jsonify({"status": "success", "message": "Feedback submitted!"}), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 9: NOTIFICATIONS ROUTES
# ============================================================

@app.route('/api/notifications/<int:user_id>', methods=['GET'])
def get_notifications(user_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT notif_id, message, notif_type, is_read, created_at
            FROM notifications WHERE user_id = :p1
            ORDER BY created_at DESC
        """, p1=user_id)
        rows = cursor.fetchall()
        cursor.execute("SELECT fn_unread_notifications(:p1) FROM DUAL", p1=user_id)
        unread_count = cursor.fetchone()[0]
        notifications = [{
            "notif_id": r[0], "message": r[1], "notif_type": r[2],
            "is_read": r[3], "created_at": safe(r[4])
        } for r in rows]
        return jsonify({"status": "success", "notifications": notifications, "unread_count": int(unread_count)}), 200
    except Exception as e:
        print(f"Notifications error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


@app.route('/api/notifications/<int:notif_id>/read', methods=['PUT'])
def mark_notification_read(notif_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE notifications SET is_read = 1 WHERE notif_id = :p1", p1=notif_id)
        conn.commit()
        return jsonify({"status": "success", "message": "Marked as read"}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 10: SKILL MATCHING ROUTE
# ============================================================

@app.route('/api/skills/match/<int:idea_id>', methods=['GET'])
def skill_match(idea_id):
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT required_skills, founder_id FROM startup_ideas WHERE idea_id = :p1", p1=idea_id)
        row = cursor.fetchone()
        if not row:
            return jsonify({"status": "error", "message": "Idea not found"}), 404
        required_skills = row[0]
        founder_id      = row[1]
        cursor.execute("""
            SELECT DISTINCT u.user_id, u.full_name, u.role, u.location, s.skill_name
            FROM users u
            JOIN user_skills us ON u.user_id = us.user_id
            JOIN skills s ON us.skill_id = s.skill_id
            WHERE u.user_id != :p1
              AND u.is_active = 1
              AND UPPER(:p2) LIKE '%' || UPPER(s.skill_name) || '%'
            ORDER BY u.full_name
        """, p1=founder_id, p2=required_skills)
        rows = cursor.fetchall()
        matched_users = {}
        for r in rows:
            uid = r[0]
            if uid not in matched_users:
                matched_users[uid] = {"user_id": r[0], "full_name": r[1], "role": r[2], "location": r[3], "matched_skills": []}
            matched_users[uid]["matched_skills"].append(r[4])
        return jsonify({"status": "success", "matched_users": list(matched_users.values())}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 11: SEARCH ROUTE
# ============================================================

@app.route('/api/search', methods=['GET'])
def search():
    query    = request.args.get('q', '')
    domain   = request.args.get('domain', '')
    location = request.args.get('location', '')
    skill    = request.args.get('skill', '')
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        sql = """
            SELECT si.idea_id, si.title, si.description, si.domain,
                   si.required_skills, si.location, si.progress,
                   si.likes_count, u.full_name
            FROM startup_ideas si
            JOIN users u ON si.founder_id = u.user_id
            WHERE si.status = 'Active'
        """
        params = {}
        if query:
            sql += " AND (UPPER(si.title) LIKE :p_q OR UPPER(si.description) LIKE :p_q)"
            params['p_q'] = f"%{query.upper()}%"
        if domain:
            sql += " AND si.domain = :p_domain"
            params['p_domain'] = domain
        if location:
            sql += " AND LOWER(si.location) LIKE :p_location"
            params['p_location'] = f"%{location.lower()}%"
        if skill:
            sql += " AND UPPER(si.required_skills) LIKE :p_skill"
            params['p_skill'] = f"%{skill.upper()}%"
        sql += " ORDER BY si.created_at DESC"
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        results = [{
            "idea_id": r[0], "title": safe(r[1]),
            "description": safe(r[2]) or "",
            "domain": safe(r[3]), "required_skills": safe(r[4]),
            "location": safe(r[5]), "progress": r[6],
            "likes_count": r[7], "founder_name": safe(r[8])
        } for r in rows]
        return jsonify({"status": "success", "results": results}), 200
    except Exception as e:
        print(f"Search error: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# SECTION 12: ADMIN ROUTES
# ============================================================

@app.route('/api/admin/stats', methods=['GET'])
def admin_stats():
    conn = get_db_connection()
    if not conn:
        return jsonify({"status": "error", "message": "DB connection failed"}), 500
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM users WHERE is_active = 1")
        total_users = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM startup_ideas WHERE status != 'Inactive'")
        total_ideas = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM collaboration_requests WHERE status = 'Accepted'")
        total_collabs = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM tasks WHERE status = 'Completed'")
        total_tasks_done = cursor.fetchone()[0]
        return jsonify({
            "status": "success",
            "stats": {
                "total_users": int(total_users), "total_ideas": int(total_ideas),
                "total_collabs": int(total_collabs), "total_tasks_done": int(total_tasks_done)
            }
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    finally:
        cursor.close()
        conn.close()


# ============================================================
# RUN APP
# ============================================================

if __name__ == '__main__':
    app.run(debug=True, port=5000)