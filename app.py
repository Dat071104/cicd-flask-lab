from flask import Flask, jsonify
import os


app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        {
            "message": "CI/CD Lab Jenkins + Docker is running",
            "branch": os.getenv("APP_BRANCH", "unknown"),
            "build": os.getenv("BUILD_NUMBER", "local"),
        }
    )


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
