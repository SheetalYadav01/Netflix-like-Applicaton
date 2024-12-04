from flask import Flask, jsonify, send_file
import os

app = Flask(__name__)

VIDEOS = [
    {"id": 1, "title": "Nature Documentary", "thumbnail": "/static/nature.jpg", "url": "/videos/video1.mp4"},
    {"id": 2, "title": "Space Exploration", "thumbnail": "/static/space.jpg", "url": "/videos/video2.mp4"},
]

@app.route("/videos", methods=["GET"])
def get_videos():
    return jsonify(VIDEOS)

@app.route("/videos/<path:filename>", methods=["GET"])
def stream_video(filename):
    return send_file(os.path.join("videos", filename))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
