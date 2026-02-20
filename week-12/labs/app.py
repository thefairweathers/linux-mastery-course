"""
Minimal Flask API — Week 12
============================
This is a simple API that serves JSON responses through an nginx reverse proxy.
In Week 13, we'll add a PostgreSQL database to store and retrieve data.

Run with:
    pip install -r requirements.txt
    python3 app.py

The API listens on port 8080 by default.
"""

from flask import Flask, jsonify, request
import os

app = Flask(__name__)


@app.route("/")
def index():
    """Root endpoint — basic API information."""
    return jsonify({
        "application": "Linux Mastery API",
        "version": "1.0",
        "endpoints": ["/", "/healthz", "/api/hello", "/api/echo"]
    })


@app.route("/healthz")
def health():
    """Health check endpoint.

    Every production service needs this. Load balancers, reverse proxies,
    and container orchestrators use it to know if the service is alive.
    """
    return jsonify({"status": "healthy"}), 200


@app.route("/api/hello")
def hello():
    """Simple greeting endpoint."""
    name = request.args.get("name", "World")
    return jsonify({"message": f"Hello, {name}!"})


@app.route("/api/echo", methods=["POST"])
def echo():
    """Echo back whatever JSON is posted."""
    data = request.get_json(silent=True)
    if data is None:
        return jsonify({"error": "Request body must be JSON"}), 400
    return jsonify({"echoed": data})


@app.route("/api/headers")
def headers():
    """Show request headers — useful for verifying reverse proxy configuration."""
    header_dict = {key: value for key, value in request.headers}
    return jsonify({"headers": header_dict})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
