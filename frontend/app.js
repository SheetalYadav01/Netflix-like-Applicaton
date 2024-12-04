import React, { useState, useEffect } from "react";
import VideoCard from "./components/VideoCard";
import VideoPlayer from "./components/VideoPlayer";

function App() {
  const [videos, setVideos] = useState([]);
  const [selectedVideo, setSelectedVideo] = useState(null);

  useEffect(() => {
    fetch("http://<API_GATEWAY_URL>/videos")
      .then((response) => response.json())
      .then((data) => setVideos(data));
  }, []);

  return (
    <div className="App">
      <h1>Streaming Service</h1>
      {selectedVideo ? (
        <VideoPlayer video={selectedVideo} onBack={() => setSelectedVideo(null)} />
      ) : (
        <div className="video-grid">
          {videos.map((video) => (
            <VideoCard key={video.id} video={video} onSelect={setSelectedVideo} />
          ))}
        </div>
      )}
    </div>
  );
}

export default App;
