// Zylos content script — detects supported video pages and stores metadata
(function () {
  const PLATFORMS = {
    'youtube.com': 'YouTube',
    'youtu.be': 'YouTube',
    'instagram.com': 'Instagram',
    'tiktok.com': 'TikTok',
    'vm.tiktok.com': 'TikTok',
    'vt.tiktok.com': 'TikTok',
    'facebook.com': 'Facebook',
    'fb.watch': 'Facebook',
    'm.facebook.com': 'Facebook',
    'twitter.com': 'Twitter/X',
    'x.com': 'Twitter/X',
    'vimeo.com': 'Vimeo',
    'dailymotion.com': 'Dailymotion',
    'dai.ly': 'Dailymotion',
    'twitch.tv': 'Twitch',
    'clips.twitch.tv': 'Twitch',
    'reddit.com': 'Reddit',
    'bilibili.com': 'Bilibili',
    'b23.tv': 'Bilibili',
    'rumble.com': 'Rumble',
    'soundcloud.com': 'SoundCloud',
    'pinterest.com': 'Pinterest',
    'pin.it': 'Pinterest',
  };

  function detectPlatform(hostname) {
    for (const [domain, name] of Object.entries(PLATFORMS)) {
      if (hostname.includes(domain)) return name;
    }
    return 'Unknown';
  }

  function isVideoPage(url, hostname, pathname) {
    // YouTube
    if (hostname.includes('youtube.com')) {
      return pathname.includes('/watch') || pathname.includes('/shorts/') || pathname.includes('/live/');
    }
    if (hostname.includes('youtu.be')) return pathname.length > 1;

    // TikTok — all variants
    if (hostname.includes('tiktok.com')) {
      return pathname.includes('/video/') || pathname.includes('/v/') || hostname.includes('vm.tiktok.com') || hostname.includes('vt.tiktok.com');
    }

    // Instagram
    if (hostname.includes('instagram.com')) {
      return pathname.includes('/p/') || pathname.includes('/reel/') || pathname.includes('/reels/') || pathname.includes('/tv/');
    }

    // Facebook
    if (hostname.includes('facebook.com') || hostname.includes('fb.watch')) {
      return pathname.includes('/watch') || pathname.includes('/videos/') || pathname.includes('/video.php') || hostname.includes('fb.watch');
    }

    // Twitter/X
    if (hostname.includes('twitter.com') || hostname.includes('x.com')) {
      return pathname.includes('/status/');
    }

    // Platforms where essentially all pages are videos
    const alwaysVideo = ['vimeo.com', 'dailymotion.com', 'dai.ly', 'twitch.tv', 'clips.twitch.tv', 'rumble.com', 'bilibili.com', 'b23.tv', 'soundcloud.com'];
    if (alwaysVideo.some(d => hostname.includes(d))) return true;

    // Reddit — only video posts
    if (hostname.includes('reddit.com')) {
      return pathname.includes('/comments/');
    }

    return false;
  }

  function cleanUrlForStorage(rawUrl, hostname) {
    try {
      const u = new URL(rawUrl);
      // YouTube: keep only v= param
      if (hostname.includes('youtube.com')) {
        const v = u.searchParams.get('v');
        if (v) return `https://www.youtube.com/watch?v=${v}`;
      }
      // Strip common noise params
      ['list', 'start_radio', 'index', 'utm_source', 'utm_medium', 'utm_campaign', 'fbclid', 'ref', 't'].forEach(p => u.searchParams.delete(p));
      return u.toString();
    } catch (_) {
      return rawUrl;
    }
  }

  function detect() {
    const rawUrl = window.location.href;
    const hostname = window.location.hostname;
    const pathname = window.location.pathname;

    const platform = detectPlatform(hostname);
    const isVideo = isVideoPage(rawUrl, hostname, pathname);
    const cleanUrl = cleanUrlForStorage(rawUrl, hostname);

    try {
      if (chrome.runtime && chrome.runtime.id) {
        chrome.storage.local.set({
          currentUrl: cleanUrl,
          currentRawUrl: rawUrl,
          currentPlatform: platform,
          isVideoPage: isVideo,
          lastUpdated: Date.now(),
        });
      }
    } catch (e) {
      console.warn('[Zylos] Extension context invalidated (extension was updated/reloaded). Refresh the page.');
    }

    console.log(`[Zylos] ${platform} | video=${isVideo} | ${cleanUrl}`);
  }

  // Run immediately
  detect();

  // SPA navigation (YouTube, TikTok, etc.)
  let lastUrl = location.href;
  new MutationObserver(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      // Small delay so SPA has time to update DOM/URL
      setTimeout(detect, 300);
    }
  }).observe(document, { subtree: true, childList: true });

  // Also re-detect on popstate (back/forward)
  window.addEventListener('popstate', () => setTimeout(detect, 300));
})();
