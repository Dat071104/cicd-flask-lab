import os

from flask import Flask, jsonify


app = Flask(__name__)


@app.get("/")
def index():
    return jsonify(
        service=os.getenv("SERVICE_NAME", "vihire-backend"),
        branch=os.getenv("APP_BRANCH", "unknown"),
        build=os.getenv("BUILD_NUMBER", "local"),
        status="running",
    )


@app.get("/health")
def health():
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
