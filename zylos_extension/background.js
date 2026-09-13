let ZYLOS_PORT = 7734;
let SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;

// Load port
chrome.storage.local.get(['zylosPort'], (r) => {
  if (r.zylosPort) {
    ZYLOS_PORT = r.zylosPort;
    SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;
  }
});

chrome.storage.onChanged.addListener((changes, namespace) => {
  if (namespace === 'local' && changes.zylosPort) {
    ZYLOS_PORT = changes.zylosPort.newValue;
    SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;
  }

  if (namespace === 'local' && changes.currentUrl && changes.currentUrl.newValue) {
    const newUrl = changes.currentUrl.newValue;
    const isVideo = changes.isVideoPage ? changes.isVideoPage.newValue : null;
    
    // If we just detected a video page, ping the backend to cache the qualities
    if (isVideo !== false && newUrl) {
      console.log('[Zylos Background] Pre-fetching info for:', newUrl);
      fetch(`${SERVER}/qualities?url=${encodeURIComponent(newUrl)}`)
        .then(res => {
          if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
          console.log('[Zylos Background] Pre-fetch successful');
        })
        .catch(err => console.log('[Zylos Background] Pre-fetch failed:', err));
    }
  }
});
