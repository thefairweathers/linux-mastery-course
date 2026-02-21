"""
Three-Tier Flask API — Week 13
================================
This is the Week 12 API evolved to connect to PostgreSQL.
It provides CRUD endpoints for a 'tasks' table.

In Week 16, you'll containerize this with a Dockerfile.
In Week 17, you'll orchestrate it with Docker Compose.

Setup:
    pip install -r requirements.txt

    # Set database connection environment variables:
    export DB_HOST=localhost
    export DB_NAME=taskdb
    export DB_USER=taskapp
    export DB_PASS=your_password

    python3 lab_02_app.py
"""

from flask import Flask, jsonify, request
import psycopg2
import psycopg2.extras
import os
import sys

app = Flask(__name__)


def get_db_connection():
    """Create a database connection using environment variables."""
    try:
        conn = psycopg2.connect(
            host=os.environ.get("DB_HOST", "localhost"),
            database=os.environ.get("DB_NAME", "taskdb"),
            user=os.environ.get("DB_USER", "taskapp"),
            password=os.environ.get("DB_PASS", ""),
            port=os.environ.get("DB_PORT", "5432")
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"Database connection failed: {e}", file=sys.stderr)
        return None


@app.route("/")
def index():
    """Root endpoint — API information."""
    return jsonify({
        "application": "Linux Mastery Task API",
        "version": "2.0",
        "endpoints": [
            "GET    /",
            "GET    /healthz",
            "GET    /api/tasks",
            "POST   /api/tasks",
            "PUT    /api/tasks/<id>",
            "DELETE /api/tasks/<id>"
        ]
    })


@app.route("/healthz")
def health():
    """Health check — verifies database connectivity."""
    conn = get_db_connection()
    if conn is None:
        return jsonify({"status": "unhealthy", "reason": "database unreachable"}), 503
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "reason": str(e)}), 503


@app.route("/api/tasks", methods=["GET"])
def get_tasks():
    """List all tasks."""
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 503

    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # -------------------------------------------------------------------------
    # TODO 1: Write a SELECT query to fetch all tasks, ordered by created_at
    # HINT: SELECT id, title, status, created_at FROM tasks ORDER BY ...
    # -------------------------------------------------------------------------
    cur.execute("SELECT 1")  # Replace this line with your query

    tasks = cur.fetchall()
    cur.close()
    conn.close()

    # Convert datetime objects to strings for JSON serialization
    for task in tasks:
        if "created_at" in task and task["created_at"]:
            task["created_at"] = task["created_at"].isoformat()

    return jsonify({"tasks": tasks})


@app.route("/api/tasks", methods=["POST"])
def create_task():
    """Create a new task."""
    data = request.get_json(silent=True)
    if not data or "title" not in data:
        return jsonify({"error": "Missing 'title' in request body"}), 400

    title = data["title"]
    status = data.get("status", "pending")

    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 503

    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # -------------------------------------------------------------------------
    # TODO 2: Write an INSERT query to create a new task and return it
    # HINT: INSERT INTO tasks (title, status) VALUES (%s, %s) RETURNING ...
    # Use parameterized queries (%s) to prevent SQL injection!
    # -------------------------------------------------------------------------
    cur.execute("SELECT 1")  # Replace this line with your query

    new_task = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    if new_task and "created_at" in new_task and new_task["created_at"]:
        new_task["created_at"] = new_task["created_at"].isoformat()

    return jsonify({"task": new_task}), 201


@app.route("/api/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    """Update a task's title or status."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 503

    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # -------------------------------------------------------------------------
    # TODO 3: Write an UPDATE query to modify a task's title and/or status
    # HINT: UPDATE tasks SET title = %s, status = %s WHERE id = %s RETURNING ...
    # Handle the case where only title OR status is provided in the request
    # -------------------------------------------------------------------------
    title = data.get("title")
    status = data.get("status")

    cur.execute("SELECT 1")  # Replace this line with your query

    updated_task = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    if updated_task is None:
        return jsonify({"error": f"Task {task_id} not found"}), 404

    if "created_at" in updated_task and updated_task["created_at"]:
        updated_task["created_at"] = updated_task["created_at"].isoformat()

    return jsonify({"task": updated_task})


@app.route("/api/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    """Delete a task."""
    conn = get_db_connection()
    if conn is None:
        return jsonify({"error": "Database connection failed"}), 503

    cur = conn.cursor()

    # -------------------------------------------------------------------------
    # TODO 4: Write a DELETE query to remove a task by id
    # HINT: DELETE FROM tasks WHERE id = %s
    # Check cur.rowcount to see if a row was actually deleted
    # -------------------------------------------------------------------------
    cur.execute("SELECT 1")  # Replace this line with your query

    deleted = cur.rowcount > 0
    conn.commit()
    cur.close()
    conn.close()

    if not deleted:
        return jsonify({"error": f"Task {task_id} not found"}), 404

    return jsonify({"message": f"Task {task_id} deleted"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"Starting Task API on port {port}...")
    print(f"Database: {os.environ.get('DB_HOST', 'localhost')}:{os.environ.get('DB_PORT', '5432')}/{os.environ.get('DB_NAME', 'taskdb')}")
    app.run(host="0.0.0.0", port=port)
