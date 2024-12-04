import React from "react";

function VideoPlayer({ video, onBack }) {
  return (
    <div className="video-player">
      <button onClick={onBack}>Back</button>
      <h2>{video.title}</h2>
      <video controls width="800" src={video.url}></video>
    </div>
  );
}

export default VideoPlayer;
