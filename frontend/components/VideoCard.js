import React from "react";

function VideoCard({ video, onSelect }) {
  return (
    <div className="video-card" onClick={() => onSelect(video)}>
      <img src={video.thumbnail} alt={video.title} />
      <h3>{video.title}</h3>
    </div>
  );
}

export default VideoCard;
