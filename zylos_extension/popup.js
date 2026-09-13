const DEFAULT_PORT = 7734;
let ZYLOS_PORT = DEFAULT_PORT;
let SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;

// ── Theme & Appearance ──────────────────────────────────────────────────────
const THEMES = {
  default: { bg: '#08080F', bg2: '#0F0F1A', card: '#13131F', card2: '#1C1C2E', txt: '#F1F1FF', dim: '#6B6B8A', dim2: '#9090B0', bdr: 'rgba(255,255,255,0.07)', bdr2: 'rgba(255,255,255,0.12)', p: '#8B3FD9', p2: '#A855F7', pk: '#EC4899', glowP: 'rgba(139,63,217,0.3)', glowPk: 'rgba(236,72,153,0.2)' },
  ocean: { bg: '#0B1120', bg2: '#0F172A', card: '#1E293B', card2: '#334155', txt: '#F8FAFC', dim: '#64748B', dim2: '#94A3B8', bdr: 'rgba(255,255,255,0.08)', bdr2: 'rgba(255,255,255,0.15)', p: '#3B82F6', p2: '#60A5FA', pk: '#06B6D4', glowP: 'rgba(59,130,246,0.3)', glowPk: 'rgba(6,182,212,0.2)' },
  emerald: { bg: '#022C22', bg2: '#064E3B', card: '#065F46', card2: '#047857', txt: '#ECFDF5', dim: '#6EE7B7', dim2: '#A7F3D0', bdr: 'rgba(255,255,255,0.1)', bdr2: 'rgba(255,255,255,0.2)', p: '#10B981', p2: '#34D399', pk: '#059669', glowP: 'rgba(16,185,129,0.3)', glowPk: 'rgba(5,150,105,0.2)' },
  light: { bg: '#F8FAFC', bg2: '#F1F5F9', card: '#FFFFFF', card2: '#E2E8F0', txt: '#0F172A', dim: '#64748B', dim2: '#475569', bdr: 'rgba(0,0,0,0.08)', bdr2: 'rgba(0,0,0,0.15)', p: '#6366F1', p2: '#818CF8', pk: '#EC4899', glowP: 'rgba(99,102,241,0.3)', glowPk: 'rgba(236,72,153,0.2)' },
  amoled: { bg: '#000000', bg2: '#000000', card: '#0A0A0A', card2: '#121212', txt: '#FFFFFF', dim: '#737373', dim2: '#A3A3A3', bdr: 'rgba(255,255,255,0.1)', bdr2: 'rgba(255,255,255,0.2)', p: '#F43F5E', p2: '#FB7185', pk: '#F59E0B', glowP: 'rgba(244,63,94,0.3)', glowPk: 'rgba(245,158,11,0.2)' },
  cyber: { bg: '#0A0A0A', bg2: '#121212', card: '#18181B', card2: '#27272A', txt: '#FAFAFA', dim: '#A1A1AA', dim2: '#D4D4D8', bdr: 'rgba(250,204,21,0.15)', bdr2: 'rgba(244,63,94,0.25)', p: '#FACC15', p2: '#FDE047', pk: '#F43F5E', glowP: 'rgba(250,204,21,0.3)', glowPk: 'rgba(244,63,94,0.2)' }
};

let currentTheme = 'default';
let animationsEnabled = true;

function applyTheme(name) {
  const t = THEMES[name] || THEMES.default;
  const root = document.documentElement;
  
  // Full theme CSS variables
  root.style.setProperty('--bg', t.bg);
  root.style.setProperty('--bg2', t.bg2);
  root.style.setProperty('--card', t.card);
  root.style.setProperty('--card2', t.card2);
  root.style.setProperty('--txt', t.txt);
  root.style.setProperty('--dim', t.dim);
  root.style.setProperty('--dim2', t.dim2);
  root.style.setProperty('--bdr', t.bdr);
  root.style.setProperty('--bdr2', t.bdr2);
  root.style.setProperty('--p', t.p);
  root.style.setProperty('--p2', t.p2);
  root.style.setProperty('--pk', t.pk);
  root.style.setProperty('--glow-p', t.glowP);
  root.style.setProperty('--glow-pk', t.glowPk);
  
  document.querySelectorAll('.theme-btn').forEach(btn => {
    if (btn.dataset.theme === name) btn.classList.add('active');
    else btn.classList.remove('active');
  });
}

function applyAnimations(enabled) {
  if (enabled) document.body.classList.remove('no-anim');
  else document.body.classList.add('no-anim');
}

// Load persisted settings
chrome.storage.local.get(['zylosPort', 'zylosTheme', 'zylosAnim'], (r) => {
  if (r.zylosPort && Number.isInteger(r.zylosPort) && r.zylosPort >= 1024) {
    ZYLOS_PORT = r.zylosPort;
    SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;
  }
  if (r.zylosTheme) {
    currentTheme = r.zylosTheme;
    applyTheme(currentTheme);
  }
  if (r.zylosAnim !== undefined) {
    animationsEnabled = r.zylosAnim;
    applyAnimations(animationsEnabled);
    const toggle = document.getElementById('toggle-animations');
    if (toggle) toggle.checked = animationsEnabled;
  }
});
function savePort(port) {
  const p = parseInt(port, 10);
  if (!p || p < 1024 || p > 65535) return false;
  ZYLOS_PORT = p;
  SERVER = `http://127.0.0.1:${ZYLOS_PORT}`;
  chrome.storage.local.set({ zylosPort: p });
  return true;
}

let currentMeta = null;
let currentTab = 'video';
let pollTimer = null;
let activeTaskId = null;

// Track params per taskId so we can retry failed downloads
const lastDownloadParams = {};

// ── Utilities ──────────────────────────────────────────────────────────────
function fmtBytes(b) {
  if (!b || b <= 0) return '';
  if (b >= 1073741824) return (b / 1073741824).toFixed(1) + ' GB';
  if (b >= 1048576)    return (b / 1048576).toFixed(1) + ' MB';
  if (b >= 1024)       return (b / 1024).toFixed(0) + ' KB';
  return b + ' B';
}
function fmtSpeed(bps) {
  if (!bps || bps <= 0) return '';
  if (bps >= 1048576) return (bps / 1048576).toFixed(1) + ' MB/s';
  if (bps >= 1024)    return (bps / 1024).toFixed(0) + ' KB/s';
  return bps + ' B/s';
}
function fmtEta(s) {
  if (!s || s <= 0) return '';
  if (s >= 3600) return `${Math.floor(s/3600)}h ${Math.floor((s%3600)/60)}m`;
  if (s >= 60)   return `${Math.floor(s/60)}m ${s%60}s`;
  return `${s}s remaining`;
}
function fmtDur(val) {
  if (!val) return '--:--';
  if (typeof val === 'string' && val.includes(':')) return val;
  const s = parseInt(val, 10); if (isNaN(s) || s <= 0) return '--:--';
  const h = Math.floor(s/3600), m = Math.floor((s%3600)/60), sec = s%60;
  return h > 0 ? `${h}:${String(m).padStart(2,'0')}:${String(sec).padStart(2,'0')}` : `${String(m).padStart(2,'0')}:${String(sec).padStart(2,'0')}`;
}

// ── Platform Details ────────────────────────────────────────────────────────
const PLATFORMS = {
  'youtube.com': 'YouTube', 'youtu.be': 'YouTube',
  'instagram.com': 'Instagram',
  'tiktok.com': 'TikTok', 'vm.tiktok.com': 'TikTok', 'vt.tiktok.com': 'TikTok',
  'facebook.com': 'Facebook', 'fb.watch': 'Facebook', 'm.facebook.com': 'Facebook',
  'twitter.com': 'Twitter/X', 'x.com': 'Twitter/X',
  'vimeo.com': 'Vimeo', 'dailymotion.com': 'Dailymotion', 'dai.ly': 'Dailymotion',
  'twitch.tv': 'Twitch', 'clips.twitch.tv': 'Twitch',
  'reddit.com': 'Reddit', 'bilibili.com': 'Bilibili', 'b23.tv': 'Bilibili',
  'rumble.com': 'Rumble', 'soundcloud.com': 'SoundCloud',
  'pinterest.com': 'Pinterest', 'pin.it': 'Pinterest'
};
function detectPlatform(hostname) {
  for (const [domain, name] of Object.entries(PLATFORMS)) {
    if (hostname.includes(domain)) return name;
  }
  // Return the hostname as-is for Universal fallback (1700+ sites)
  return hostname.replace('www.', '');
}
function isVideoPage(url, hostname, pathname) {
  if (hostname.includes('youtube.com')) return pathname.includes('/watch') || pathname.includes('/shorts/') || pathname.includes('/live/');
  if (hostname.includes('youtu.be')) return pathname.length > 1;
  if (hostname.includes('tiktok.com')) return pathname.includes('/video/') || pathname.includes('/v/') || hostname.includes('vm.tiktok.com') || hostname.includes('vt.tiktok.com');
  if (hostname.includes('instagram.com')) return pathname.includes('/p/') || pathname.includes('/reel/') || pathname.includes('/reels/') || pathname.includes('/tv/');
  if (hostname.includes('facebook.com') || hostname.includes('fb.watch')) return pathname.includes('/watch') || pathname.includes('/videos/') || pathname.includes('/video.php') || hostname.includes('fb.watch');
  if (hostname.includes('twitter.com') || hostname.includes('x.com')) return pathname.includes('/status/');
  const alwaysVideo = ['vimeo.com', 'dailymotion.com', 'dai.ly', 'twitch.tv', 'clips.twitch.tv', 'rumble.com', 'bilibili.com', 'b23.tv', 'soundcloud.com'];
  if (alwaysVideo.some(d => hostname.includes(d))) return true;
  if (hostname.includes('reddit.com')) return pathname.includes('/comments/');
  const exclude = ['google.', 'bing.', 'yahoo.', 'duckduckgo.', 'github.', 'stackoverflow.'];
  if (exclude.some(d => hostname.includes(d))) return false;
  
  // Default to true for any other site to allow auto-fetching by yt-dlp
  return true;
}
function cleanUrlForStorage(rawUrl, hostname) {
  try {
    const u = new URL(rawUrl);
    if (hostname.includes('youtube.com')) {
      const v = u.searchParams.get('v');
      if (v) return `https://www.youtube.com/watch?v=${v}`;
    }
    ['list', 'start_radio', 'index', 'utm_source', 'utm_medium', 'utm_campaign', 'fbclid', 'ref', 't'].forEach(p => u.searchParams.delete(p));
    return u.toString();
  } catch (_) { return rawUrl; }
}
async function getActiveTabInfo() {
  const tabs = await chrome.tabs.query({active: true, currentWindow: true});
  if (!tabs || !tabs[0] || !tabs[0].url) return null;
  const rawUrl = tabs[0].url;
  try {
    const u = new URL(rawUrl);
    const platform = detectPlatform(u.hostname);
    const isVideo = isVideoPage(rawUrl, u.hostname, u.pathname);
    const isPlaylist = u.hostname.includes('youtube.com') && u.searchParams.has('list');
    return { rawUrl, platform, isVideo, isPlaylist, hostname: u.hostname };
  } catch (e) { return null; }
}

async function getCookiesForUrl(url) {
  return new Promise((resolve) => {
    if (!chrome.cookies) return resolve('');
    chrome.cookies.getAll({ url }, (cookies) => {
      if (!cookies || cookies.length === 0) return resolve('');
      let str = '# Netscape HTTP Cookie File\n';
      for (const c of cookies) {
        let domain = c.domain;
        let includeSubdomains = domain.startsWith('.') ? 'TRUE' : 'FALSE';
        let path = c.path;
        let secure = c.secure ? 'TRUE' : 'FALSE';
        let expiry = c.expirationDate ? Math.floor(c.expirationDate) : 0;
        str += `${domain}\t${includeSubdomains}\t${path}\t${secure}\t${expiry}\t${c.name}\t${c.value}\n`;
      }
      resolve(str);
    });
  });
}

// ── Screen manager ─────────────────────────────────────────────────────────
function show(id) {
  document.querySelectorAll('.screen').forEach(el => {
    el.style.display = 'none';
  });
  const target = document.getElementById(id);
  if (target) target.style.display = id === 'screen-playlist-items' ? 'flex' : 'block';
}


let currentPlaylistItems = [];
let selectedPlaylistIds = new Set();

async function init() {
  stopPoll();
  show('screen-loading');
  setLoading('Analyzing media...', '');

  // 0. Ensure Zylos is running, if not auto-launch in background
  try {
    const ping = await fetch(`${SERVER}/ping`, { signal: AbortSignal.timeout(500) });
    if (!ping.ok) throw new Error('Not ok');
  } catch (err) {
    setLoading('Starting Zylos...', 'Launching background service...');
    // Trigger protocol launch
    const bgFrame = document.createElement('iframe');
    bgFrame.style.display = 'none'; bgFrame.src = 'zylos://background';
    document.body.appendChild(bgFrame);
    setTimeout(() => { if(document.body.contains(bgFrame)) document.body.removeChild(bgFrame); }, 200);

    // Poll a few times waiting for the server to spin up
    let isUp = false;
    for (let i = 0; i < 4; i++) {
      await new Promise(r => setTimeout(r, 1500));
      try { const p2 = await fetch(`${SERVER}/ping`, { signal: AbortSignal.timeout(800) }); if (p2.ok) { isUp = true; break; } } catch(_) {}
    }
    if (!isUp) {
      setLoading('Zylos app not running', 'Open the Zylos desktop app manually, then click Retry.');
      return;
    }
  }

  // 1. Check for active downloads quietly to populate badge
  checkBackgroundDownloads();

  // 2. Start continuous connection poller
  startConnectionPoller();

  // 3. Continually poll info for the current tab
  await loadInfo();
}

let connectionPollTimer = null;
function startConnectionPoller() {
  if (connectionPollTimer) clearInterval(connectionPollTimer);
  // Initial check
  fetch(`${SERVER}/ping?source=ext`, { signal: AbortSignal.timeout(1000) })
    .then(r => updateConnectionState(r.ok)).catch(() => updateConnectionState(false));
    
  connectionPollTimer = setInterval(async () => {
    try {
      const r = await fetch(`${SERVER}/ping?source=ext`, { signal: AbortSignal.timeout(1000) });
      updateConnectionState(r.ok);
    } catch (e) {
      updateConnectionState(false);
    }
  }, 2000);
}

function updateConnectionState(isConnected) {
  const dots = document.querySelectorAll('.ext-status-dot');
  dots.forEach(dot => {
    dot.style.background = isConnected ? '#10B981' : '#EF4444';
    dot.style.boxShadow = isConnected ? '0 0 8px rgba(16,185,129,0.5)' : '0 0 8px rgba(239,68,68,0.5)';
    dot.title = isConnected ? 'Connected to Zylos' : 'Not Connected';
  });
  
  const liveDot = document.getElementById('settings-live-dot');
  const liveText = document.getElementById('settings-live-text');
  if (liveDot && liveText) {
    liveDot.style.background = isConnected ? '#10B981' : '#EF4444';
    liveDot.style.boxShadow = isConnected ? '0 0 8px rgba(16,185,129,0.5)' : '0 0 8px rgba(239,68,68,0.5)';
    liveText.style.color = isConnected ? '#10B981' : '#EF4444';
    liveText.textContent = isConnected ? 'Live & Connected' : 'Disconnected';
  }
}

async function checkBackgroundDownloads() {
  try {
    const r = await fetch(`${SERVER}/all-tasks`, { signal: AbortSignal.timeout(2000) });
    if (r.ok) {
      const tasks = await r.json();
      const active = tasks.filter(t => ['queued','fetchingInfo','downloading','merging','retrying'].includes(t.status));
      const badge = document.getElementById('badge-dl');
      if (active.length > 0) {
        badge.style.display = 'block';
        badge.textContent = active.length > 9 ? '9+' : active.length;
      } else {
        badge.style.display = 'none';
      }
    }
  } catch (_) {}
}

function setLoading(msg, sub) {
  const m = document.getElementById('loading-msg'); if (m) m.textContent = msg;
  const s = document.getElementById('loading-sub'); if (s) s.textContent = sub;
  const retry = document.getElementById('btn-retry-load');
  if (retry) retry.style.display = sub && sub.length > 0 ? 'inline-block' : 'none';
}

async function loadInfo(forceVideo = false) {
  show('screen-loading');
  setLoading('Analyzing media...', '');

  const tabInfo = await getActiveTabInfo();

  if (!tabInfo) {
    setLoading('No video detected.', 'Navigate to a supported video first.');
    return;
  }

  // Handle YouTube Playlists
  if (tabInfo.isPlaylist && !forceVideo) {
    show('screen-playlist');
    const plVideo = document.getElementById('btn-pl-video');
    const plContinue = document.getElementById('btn-pl-continue');
    const plFull = document.getElementById('btn-pl-full');
    
    if(plVideo) plVideo.onclick = () => loadInfo(true);
    
    if(plContinue) plContinue.onclick = async () => {
      show('screen-loading');
      setLoading('Fetching playlist...', 'This may take a few seconds.');
      try {
        const cleanPUrl = cleanUrlForStorage(tabInfo.rawUrl, tabInfo.hostname);
        const r = await fetch(`${SERVER}/playlist-info?url=${encodeURIComponent(cleanPUrl)}`, { signal: AbortSignal.timeout(30000) });
        if(!r.ok) throw new Error('Could not fetch playlist info');
        const data = await r.json();
        renderPlaylistItems(data);
      } catch (err) {
        setLoading('Error fetching playlist', err.message);
      }
    };
    
    if(plFull) plFull.onclick = async () => {
      try {
        await fetch(`${SERVER}/open-playlist`, { method: 'POST', body: JSON.stringify({ url: tabInfo.rawUrl }) });
        window.close(); // close extension when app is opened
      } catch (e) { alert('Could not open playlist. Is Zylos running?'); }
    };
    return;
  }

  if (!tabInfo.isVideo) {
    const cleanHost = tabInfo.hostname.replace('www.', '');
    const capHost = cleanHost.charAt(0).toUpperCase() + cleanHost.split('.')[0].slice(1);
    setLoading(`Try ${capHost} Downloader`, `Zylos supports downloading from ${cleanHost}. Click below to attempt fetching media from this page.`);
    const retryBtn = document.getElementById('btn-retry-load');
    if (retryBtn) {
      retryBtn.textContent = `Try ${capHost} Downloader`;
      retryBtn.style.display = 'inline-block';
      retryBtn.onclick = () => { loadUniversal(tabInfo.rawUrl); };
    }
    return;
  }

  const cleanUrl = cleanUrlForStorage(tabInfo.rawUrl, tabInfo.hostname);

  try {
    const cookiesStr = await getCookiesForUrl(cleanUrl);
    // Use 60s timeout - yt-dlp may try multiple player clients sequentially
    const r = await fetch(`${SERVER}/qualities`, { 
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: cleanUrl, cookies: cookiesStr }),
      signal: AbortSignal.timeout(60000) 
    });
    if (!r.ok) throw new Error(`Server returned ${r.status}`);
    const data = await r.json();

    // Detect server-side failure: server returned error title as fallback
    if (data.error && (data.title === 'Unable to load info' || data.title === 'Unknown Title')) {
      const rawErr = data.error || '';
      let errMsg = rawErr.split('\n')[0];
      // Make DPAPI error actionable
      if (rawErr.toLowerCase().includes('dpapi') || rawErr.toLowerCase().includes('failed to decrypt')) {
        errMsg = 'Cookie decryption failed. Close Chrome and retry, or update yt-dlp in Plugin Manager.';
      } else if (rawErr.toLowerCase().includes('requested format') || rawErr.toLowerCase().includes('no video formats')) {
        errMsg = 'Format unavailable. Update yt-dlp in Plugin Manager (Plugin Manager → Update yt-dlp), then retry.';
      } else if (!errMsg) {
        errMsg = 'Could not fetch video info. Update yt-dlp in the app or try again.';
      }
      setLoading('Could not load video info', errMsg);
      return;
    }

    currentMeta = { ...data, url: cleanUrl, platform: tabInfo.platform };
    renderInfo(data, cleanUrl, tabInfo.platform || 'Unknown');
  } catch (err) {
    const msg = err.message || '';
    const isConn = msg.includes('fetch') || msg.includes('signal') || msg.includes('Failed') || msg.includes('abort') || msg.includes('network');
    const isDpapi = msg.toLowerCase().includes('dpapi') || msg.toLowerCase().includes('failed to decrypt');
    setLoading(
      isConn ? 'Zylos app not running' : (isDpapi ? 'Cookie decryption error' : 'Could not load video info'),
      isConn
        ? 'Open the Zylos desktop app, then click Retry.'
        : (isDpapi
          ? 'Close Chrome completely and retry, or update yt-dlp in Plugin Manager.'
          : (msg || 'Update yt-dlp in Plugin Manager, then retry.'))
    );
  }
}

// ── Info Screen ────────────────────────────────────────────────────────────
function renderInfo(data, url, platform) {
  const thumb = document.getElementById('thumb-img');
  const thumbPlaceholder = document.getElementById('thumb-placeholder');

  // ── Robust thumbnail loading with multiple fallbacks ──────────────────
  function tryLoadThumb(srcList) {
    if (!srcList || srcList.length === 0) {
      thumb.style.display = 'none';
      if (thumbPlaceholder) thumbPlaceholder.style.display = 'flex';
      return;
    }
    const [first, ...rest] = srcList.filter(Boolean);
    if (!first) { tryLoadThumb(rest); return; }
    thumb.src = first;
    thumb.style.display = 'block';
    if (thumbPlaceholder) thumbPlaceholder.style.display = 'none';
    thumb.onerror = () => {
      if (rest.length > 0) {
        tryLoadThumb(rest);
      } else {
        thumb.style.display = 'none';
        if (thumbPlaceholder) thumbPlaceholder.style.display = 'flex';
      }
    };
  }

  // Build a list of thumbnail candidates in priority order
  const thumbCandidates = [];
  if (data.thumbnail) thumbCandidates.push(data.thumbnail);
  if (data.thumbnails && Array.isArray(data.thumbnails)) {
    // Sort by resolution (prefer highest quality)
    const sorted = [...data.thumbnails]
      .filter(t => t && t.url)
      .sort((a, b) => ((b.width || 0) * (b.height || 0)) - ((a.width || 0) * (a.height || 0)));
    sorted.forEach(t => { if (!thumbCandidates.includes(t.url)) thumbCandidates.push(t.url); });
  }
  // YouTube fallback: construct from video ID
  try {
    const u = new URL(url);
    if (u.hostname.includes('youtube.com') || u.hostname.includes('youtu.be')) {
      const vid = u.searchParams.get('v') || u.pathname.replace('/', '');
      if (vid) {
        thumbCandidates.push(`https://img.youtube.com/vi/${vid}/maxresdefault.jpg`);
        thumbCandidates.push(`https://img.youtube.com/vi/${vid}/hqdefault.jpg`);
        thumbCandidates.push(`https://img.youtube.com/vi/${vid}/mqdefault.jpg`);
      }
    }
  } catch (_) {}

  tryLoadThumb(thumbCandidates);

  document.getElementById('video-title').textContent = data.title || 'Unknown Title';
  document.getElementById('video-duration').textContent = fmtDur(data.duration);

  const vq = data.qualities || data.video_qualities || [];
  const aq = data.audioQualities || data.audio_qualities || [];

  document.getElementById('video-grid').innerHTML = vq.map(q => {
    const ext = (q.ext||'mp4').toUpperCase();
    return `
    <button class="item-btn" data-url="${url}" data-q="${q.label} ${ext}|${q.code||''}" data-fid="${q.format_id||''}" data-type="video"
      data-title="${(data.title||'').replace(/"/g,'')}" data-thumb="${(data.thumbnail||'').replace(/"/g,'')}">
      <span class="qlabel">${q.label}</span>
      <span class="qsub">${ext} · ${q.codec||'H.264'}</span>
      ${q.file_size ? `<span class="qsize">${q.file_size}</span>` : ''}
    </button>`;
  }).join('') || '<p class="no-fmt">No video formats found.</p>';

  document.getElementById('audio-grid').innerHTML = aq.map(q => {
    const ext = (q.ext||'mp3').toUpperCase();
    return `
    <button class="item-btn audio-btn" data-url="${url}" data-q="${q.code||q.label} ${ext}" data-fid="${q.format_id||''}" data-type="audio"
      data-title="${(data.title||'').replace(/"/g,'')}" data-thumb="${(data.thumbnail||'').replace(/"/g,'')}">
      <span class="aico">🎵</span>
      <span class="qlabel">${q.label}</span>
      <span class="qsub">${ext}</span>
      ${q.file_size ? `<span class="qsize">${q.file_size}</span>` : ''}
    </button>`;
  }).join('') || '<p class="no-fmt">No audio formats found.</p>';

  show('screen-info');
}

// ── Playlist Selection Screen ────────────────────────────────────────────────
function renderPlaylistItems(data) {
  document.getElementById('pl-main-thumb').src = data.thumbnail || '';
  document.getElementById('pl-main-title').textContent = data.title || 'Unknown Playlist';
  document.getElementById('pl-main-meta').textContent = `${data.itemCount || 0} videos • ${data.channelName || ''}`;
  
  currentPlaylistItems = data.videos || [];
  selectedPlaylistIds.clear();
  
  const cont = document.getElementById('pl-items-container');
  if (currentPlaylistItems.length === 0) {
    cont.innerHTML = '<div style="text-align:center; color:var(--dim); margin-top:30px; font-size:12px;">No videos found in this playlist.</div>';
  } else {
    cont.innerHTML = currentPlaylistItems.map(v => `
      <div class="pl-item" data-vid="${v.id}">
        <div class="pl-item-cb"></div>
        <img class="pl-item-thumb" src="${v.thumbnail || ''}" onerror="this.style.display='none'">
        <div class="pl-item-info">
          <div class="pl-item-title">${v.title || 'Unknown Video'}</div>
          <div class="pl-item-dur">${v.duration || '--:--'}</div>
        </div>
      </div>
    `).join('');
  }
  
  updatePlaylistSelectionUI();
  show('screen-playlist-items');
}

function updatePlaylistSelectionUI() {
  document.getElementById('pl-selected-count').textContent = selectedPlaylistIds.size;
  const btnDown = document.getElementById('btn-pl-download-sel');
  btnDown.disabled = selectedPlaylistIds.size === 0;
  btnDown.textContent = `Download ${selectedPlaylistIds.size} Selected`;
  
  document.querySelectorAll('.pl-item').forEach(el => {
    if (selectedPlaylistIds.has(el.dataset.vid)) {
      el.classList.add('selected');
    } else {
      el.classList.remove('selected');
    }
  });
  
  const btnAll = document.getElementById('btn-pl-select-all');
  if (selectedPlaylistIds.size === currentPlaylistItems.length && currentPlaylistItems.length > 0) {
    btnAll.textContent = 'Deselect All';
  } else {
    btnAll.textContent = 'Select All';
  }
}

// ── Start Download ─────────────────────────────────────────────────────────
async function startDownload(url, quality, fid, type, title, thumb, directUrl, targetExt) {
  document.querySelectorAll('.item-btn').forEach(b => b.disabled = true);
  try {
    const isAudio = type === 'audio';
    const isImage = type === 'image';
    
    document.getElementById('badge-dl').style.display = 'block';

    const payload = { url, quality, format_id: fid, title, thumbnail: thumb, isAudioOnly: isAudio, isImage, directUrl, targetExt, conflictAction: 'keep_both' };

    const r = await fetch(`${SERVER}/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!r.ok) throw new Error(`Server error ${r.status}`);
    const d = await r.json();

    if (!d.taskId) throw new Error('No taskId returned from server');

    // Store download params for retry
    lastDownloadParams[d.taskId] = { url, quality, fid, type, title, thumb, directUrl, targetExt };

    // Remove activeTaskId locking
    checkBackgroundDownloads();
    showAllDownloads(); // Immediately switch to Downloads Manager view
  } catch (err) {
    document.querySelectorAll('.item-btn').forEach(b => b.disabled = false);
    alert(`Could not start download:\n${err.message}`);
  }
}

// ── Downloading Screen ─────────────────────────────────────────────────────
function showDownloading(taskId, quality, title, thumb) {
  activeTaskId = taskId;
  document.getElementById('dl-title').textContent = title || currentMeta?.title || 'Downloading...';
  document.getElementById('dl-badge').textContent = quality || '';
  const dlt = document.getElementById('dl-thumb');
  const t = thumb || currentMeta?.thumbnail || '';
  if (t) { dlt.src = t; dlt.style.display = 'block'; dlt.onerror = () => dlt.style.display = 'none'; }
  else dlt.style.display = 'none';
  updateBar(0); setDlMeta('Starting...', '', '', '');
  show('screen-downloading');
}

function updateRing(pct) {
  const p = Math.max(0, Math.min(1, pct));
  const el = document.getElementById('speed-ring-fill');
  const needle = document.getElementById('speed-needle-container');
  if (el) {
    // 212.05 is the length of the arc. 100% = 0 offset, 0% = 212.05 offset
    el.style.strokeDashoffset = 212.05 - (212.05 * p);
  }
  if (needle) {
    // Rotation goes from -135deg to 135deg (a sweep of 270 degrees)
    needle.style.transform = `rotate(${-135 + (270 * p)}deg)`;
  }
}

function updateBar(pct) {
  const p = Math.min(100, Math.max(0, pct));
  document.getElementById('dl-bar-fill').style.width = `${p}%`;
  document.getElementById('dl-pct').textContent = `${Math.round(p)}%`;
}
function setDlMeta(status, speed, bytes, eta) {
  const el = id => document.getElementById(id);
  if (el('dl-status')) el('dl-status').textContent = status;
  if (el('dl-speed'))  el('dl-speed').textContent  = speed;
  if (el('dl-bytes'))  el('dl-bytes').textContent  = bytes;
  if (el('dl-eta'))    el('dl-eta').textContent    = eta;
}

// ── Downloads Manager ──────────────────────────────────────────
let allTasksPollTimer = null;
function stopAllTasksPoll() {
  if (allTasksPollTimer) clearInterval(allTasksPollTimer);
  allTasksPollTimer = null;
}

async function showAllDownloads() {
  stopPoll();
  stopAllTasksPoll();
  show('screen-all-downloads');
  await renderAllTasks();
  allTasksPollTimer = setInterval(renderAllTasks, 1000);
}

async function renderAllTasks() {
  try {
    const r = await fetch(`${SERVER}/all-tasks`, { signal: AbortSignal.timeout(2000) });
    if (!r.ok) return;
    const tasks = await r.json();
    const list = document.getElementById('downloads-list');
    
    if (!tasks || tasks.length === 0) {
      list.innerHTML = '<div style="text-align:center;color:#888;margin-top:20px;font-size:11px;">No downloads yet.</div>';
      return;
    }

    list.innerHTML = tasks.map(t => {
      const isDone = t.status === 'done';
      const isFail = t.status === 'failed' || t.status === 'cancelled';
      const isActive = !isDone && !isFail;
      
      let badgeClass = 'badge-active';
      let statusTxt = 'Downloading...';
      if (isDone) { badgeClass = 'badge-done'; statusTxt = 'Completed'; }
      else if (isFail) { badgeClass = 'badge-failed'; statusTxt = t.status === 'cancelled' ? 'Cancelled' : 'Failed'; }
      else if (t.status === 'merging') statusTxt = 'Merging...';
      else if (t.status === 'queued') { badgeClass = 'badge-queued'; statusTxt = 'Queued'; }
      else if (t.status === 'fetchingInfo') statusTxt = 'Fetching info...';
      else if (t.status === 'retrying') statusTxt = 'Retrying...';
      
      const pct = Math.max(0, (t.progress || 0) * 100).toFixed(0);
      const cancelBtn = isActive ? `<button class="clear-task-btn" data-tid="${t.taskId}" title="Cancel"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg></button>` : '';
      const progressSection = isActive
        ? `<div class="task-progress-bar"><div class="task-progress-fill" style="width:${pct}%"></div></div>
           <div style="font-size:9px;color:var(--dim);display:flex;justify-content:space-between;margin-top:2px;">
             <span>${fmtSpeed(t.speed)}${t.totalBytes > 0 ? ' · ' + fmtBytes(t.downloadedBytes) + ' / ' + fmtBytes(t.totalBytes) : ''}</span>
             <span>${t.eta > 0 ? '~' + fmtEta(t.eta) : ''}</span>
           </div>`
        : isDone
          ? `<div class="task-done-actions">
               <button class="td-act-btn ply" data-path="${(t.outputPath||'').replace(/"/g,'"')}">▶ Play</button>
               <button class="td-act-btn fld" data-path="${(t.outputPath||'').replace(/"/g,'"')}">📁 Folder</button>
             </div>`
          : (isFail
            ? `<div style="font-size:9px;color:#f87171;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${t.errorMessage || 'Download failed'}</div>
               ${lastDownloadParams[t.taskId] ? `<button class="retry-task-btn" data-tid="${t.taskId}">↺ Retry</button>` : ''}`
            : '');
      
      return `
        <div class="task-item ${isDone ? 'done' : ''} ${isFail ? 'failed' : ''}" data-tid="${t.taskId}" data-path="${t.outputPath||''}">
          ${cancelBtn}
          <img src="${t.thumbnail || ''}" class="task-thumb" onerror="this.src='';this.style.background='#111'">
          <div class="task-info">
            <div class="task-title">${t.title || 'Unknown Title'}</div>
            <div class="task-status-row">
              <span class="task-status-badge ${badgeClass}">${statusTxt}</span>
              ${isActive ? `<span class="task-pct">${pct}%</span>` : ''}
            </div>
            ${progressSection}
          </div>
        </div>
      `;
    }).join('');
    
    const listEl = document.getElementById('downloads-list');
    listEl.querySelectorAll('.clear-task-btn').forEach(btn => {
      btn.onclick = (e) => {
        e.stopPropagation();
        const tid = btn.dataset.tid;
        showConfirm('Cancel Download', 'Are you sure you want to stop and clear this download?', () => {
          fetch(`${SERVER}/cancel?taskId=${tid}`, { method: 'POST' }).catch(()=>{});
          setTimeout(renderAllTasks, 200);
        });
      };
    });
    listEl.querySelectorAll('.retry-task-btn').forEach(btn => {
      btn.onclick = async (e) => {
        e.stopPropagation();
        const tid = btn.dataset.tid;
        const params = lastDownloadParams[tid];
        if (!params) return;
        delete lastDownloadParams[tid];
        await startDownload(params.url, params.quality, params.fid, params.type, params.title, params.thumb, params.directUrl, params.targetExt);
      };
    });
  } catch (e) {}
}

// ── Modal / Confirm ────────────────────────────────────────────────────────
let modalConfirmCallback = null;
let conflictResolveCallback = null;

function showConfirm(title, desc, onConfirm) {
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-desc').textContent = desc;
  modalConfirmCallback = onConfirm;
  document.getElementById('modal-overlay').style.display = 'flex';
}

function closeConfirm() {
  const d = document.getElementById('modal-overlay');
  if (d) d.style.display = 'none';
  modalConfirmCallback = null;
}

// ── Polling ────────────────────────────────────────────────────────────────
function startPoll(taskId) {
  stopPoll();
  pollTimer = setInterval(() => doPoll(taskId), 700);
}
function stopPoll() { if (pollTimer) { clearInterval(pollTimer); pollTimer = null; } }

async function doPoll(taskId) {
  try {
    const r = await fetch(`${SERVER}/status?taskId=${taskId}`, { signal: AbortSignal.timeout(3000) });
    if (!r.ok) return;
    const d = await r.json();

    const labels = { queued:'In queue...', fetchingInfo:'Fetching video info...', downloading:'Downloading...', merging:'Merging streams...', retrying:'Retrying...', paused:'Paused' };
    setDlMeta(labels[d.status] || d.status, fmtSpeed(d.speed), d.totalBytes > 0 ? `${fmtBytes(d.downloadedBytes)} / ${fmtBytes(d.totalBytes)}` : fmtBytes(d.downloadedBytes), d.eta > 0 ? `~${fmtEta(d.eta)}` : '');
    if (d.status === 'downloading') updateBar((d.progress || 0) * 100);
    if (d.status === 'merging') updateBar(98);

    if (d.status === 'done') { stopPoll(); chrome.storage.local.remove(['activeTaskId']); showDone(d); }
    if (d.status === 'failed') { stopPoll(); chrome.storage.local.remove(['activeTaskId']); showError(d.errorMessage || 'Download failed.'); }
  } catch (_) { setDlMeta('Connecting...', '', '', ''); }
}

// ── Cancel ─────────────────────────────────────────────────────────────────
async function cancelDownload() {
  stopPoll();
  if (activeTaskId) {
    try { await fetch(`${SERVER}/cancel?taskId=${activeTaskId}`, { method: 'POST' }); } catch (_) {}
  }
  chrome.storage.local.remove(['activeTaskId']);
  activeTaskId = null;
  await loadInfo();
}

// ── Done Screen ────────────────────────────────────────────────────────────
function showDone(d) {
  const path = d.outputPath || '';
  const filename = path.split(/[/\\]/).pop() || 'Download complete';
  const ext = filename.split('.').pop().toUpperCase();
  const isVideo = ['MP4','MKV','WEBM','MOV','AVI'].includes(ext);

  document.getElementById('done-thumb').src   = currentMeta?.thumbnail || '';
  document.getElementById('done-thumb').style.display = currentMeta?.thumbnail ? 'block' : 'none';
  document.getElementById('done-title').textContent   = d.title || currentMeta?.title || filename;
  document.getElementById('done-filename').textContent = filename;
  document.getElementById('done-size').textContent     = d.totalBytes ? fmtBytes(d.totalBytes) : '';
  document.getElementById('done-type').textContent     = isVideo ? '📹 Video' : '🎵 Audio';

  // Store path on action buttons
  ['btn-open','btn-folder','btn-share-file','btn-share-wa','btn-share-tg'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.dataset.path = path;
  });
  document.getElementById('done-path-val').value = path;

  show('screen-done');
}

// ── Error Screen ───────────────────────────────────────────────────────────
function showError(msg) {
  document.getElementById('error-msg').textContent = msg || 'An unknown error occurred.';
  show('screen-error');
}

// ── File actions ───────────────────────────────────────────────────────────
async function openFile(path) {
  if (!path) return;
  try { await fetch(`${SERVER}/open-file?path=${encodeURIComponent(path)}`); }
  catch (_) { alert('Could not open file. Is Zylos running?'); }
}
async function shareFile(path) {
  if (!path) return;
  try {
    const r = await fetch(`${SERVER}/share?path=${encodeURIComponent(path)}`);
    if (!r.ok) throw new Error('Server error');
  } catch (_) { alert('Could not share file. Make sure Zylos app is open.'); }
}
async function shareToApp(path, app) {
  // Try to share via Windows native share sheet, then let user pick WhatsApp/Telegram etc.
  await shareFile(path);
}
async function openFolder(path) {
  if (!path) return;
  try { await fetch(`${SERVER}/open-folder?path=${encodeURIComponent(path)}`); }
  catch (_) { alert('Could not open folder. Is Zylos running?'); }
}
async function copyPath() {
  const val = document.getElementById('done-path-val').value;
  if (!val) return;
  try {
    await navigator.clipboard.writeText(val);
    const b = document.getElementById('btn-copy');
    if (b) { b.textContent = '✓ Copied!'; setTimeout(() => b.textContent = '📋 Copy Path', 2000); }
  } catch (_) { alert('Could not copy.'); }
}
function openApp() {
  const f = document.createElement('iframe');
  f.style.display = 'none'; f.src = 'zylos://open';
  document.body.appendChild(f); setTimeout(() => document.body.removeChild(f), 150);
}

// ── Tab switching ──────────────────────────────────────────────────────────
document.querySelectorAll('.tab-item').forEach(t => {
  t.addEventListener('click', () => {
    const v = t.dataset.view; if (v === currentTab) return;
    document.querySelectorAll('.tab-item').forEach(x => x.classList.remove('active'));
    t.classList.add('active');
    document.getElementById('tab-switcher').classList.remove('audio-active');
    if (v === 'audio') document.getElementById('tab-switcher').classList.add('audio-active');
    
    document.querySelectorAll('.view-container').forEach(x => x.classList.remove('active'));
    document.getElementById(`${v}-view`).classList.add('active');
    currentTab = v;
  });
});

// ── Event delegation ───────────────────────────────────────────────────────
document.addEventListener('click', async e => {
  if (e.target.closest('#modal-btn-cancel')) { 
    closeConfirm(); 
    return; 
  }
  
  if (e.target.closest('#modal-btn-confirm')) { 
    const cb = modalConfirmCallback;
    closeConfirm();
    if (cb) await cb();
    return;
  }
  
  // Task custom actions
  const plyNode = e.target.closest('.td-act-btn.ply');
  if (plyNode) { e.stopPropagation(); openFile(plyNode.dataset.path); return; }
  const fldNode = e.target.closest('.td-act-btn.fld');
  if (fldNode) { e.stopPropagation(); openFolder(fldNode.dataset.path); return; }

  // Quality button
  const btn = e.target.closest('.item-btn:not(.act-btn)');
  if (btn && !btn.disabled) {
    const title = btn.dataset.title || 'Unknown Video';
    const qualityRaw = btn.dataset.q; // "1080p MP4|1920"
    const typeLabel = btn.dataset.type === 'image' ? 'Image' : (btn.dataset.type === 'audio' ? 'Audio' : 'Video');
    
    // Split by pipe for display string
    const displayStr = qualityRaw.split('|')[0];
    
    showConfirm('Confirm Download', `Do you want to download "${title}" as ${displayStr} ${typeLabel}?`, async () => {
      await startDownload(
        btn.dataset.url, 
        qualityRaw, 
        btn.dataset.fid || '', 
        btn.dataset.type, 
        btn.dataset.title, 
        btn.dataset.thumb,
        btn.dataset.durl || '',
        btn.dataset.ext || ''
      );
    });
    return;
  }
  
  if (e.target.closest('#btn-active-dl')) { 
    showAllDownloads();
    return; 
  }
  
  if (e.target.closest('#btn-back-mgr') || e.target.closest('#btn-back-pl')) {
    stopAllTasksPoll();
    document.querySelectorAll('.item-btn').forEach(b => b.disabled = false);
    
    if (e.target.closest('#btn-back-pl')) {
       show('screen-playlist');
    } else {
       show('screen-info');
    }
    return;
  }

  // Playlist item click
  const plItem = e.target.closest('.pl-item');
  if (plItem) {
    const vid = plItem.dataset.vid;
    if (selectedPlaylistIds.has(vid)) selectedPlaylistIds.delete(vid);
    else selectedPlaylistIds.add(vid);
    updatePlaylistSelectionUI();
    return;
  }
  
  // Playlist select all
  if (e.target.closest('#btn-pl-select-all')) {
    if (selectedPlaylistIds.size === currentPlaylistItems.length) {
      selectedPlaylistIds.clear();
    } else {
      currentPlaylistItems.forEach(v => selectedPlaylistIds.add(v.id));
    }
    updatePlaylistSelectionUI();
    return;
  }
  
  // Playlist download selected
  if (e.target.closest('#btn-pl-download-sel')) {
    const selIds = Array.from(selectedPlaylistIds);
    if (selIds.length === 0) return;
    
    const selNode = document.getElementById('pl-quality-sel');
    const sq = selNode.value;
    const isAudio = sq.includes('MP3') || sq === 'M4A' || sq === 'WAV' || sq === 'FLAC';
    const qLabel = sq;
    
    // Disable button to prevent spam
    const dlBtn = document.getElementById('btn-pl-download-sel');
    dlBtn.disabled = true;
    dlBtn.textContent = 'Starting...';
    
    for (const vid of selIds) {
       const vConf = currentPlaylistItems.find(x => x.id === vid);
       if (!vConf) continue;
       
       try {
         const payload = { 
           url: vConf.url, 
           quality: qLabel, 
           title: vConf.title, 
           thumbnail: vConf.thumbnail, 
           isAudioOnly: isAudio,
           conflictAction: 'keep_both'
         };
         
         const r = await fetch(`${SERVER}/download`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
         });
         
         await r.json();
       } catch (err) {
         console.error('Failed to start', vConf.title);
       }
    }
    
    showAllDownloads();
    return;
  }
  
  if (e.target.closest('#btn-back-dl')) {
    show('screen-info');
    return;
  }

  if (e.target.closest('#btn-clear-all')) {
    showConfirm('Clear Completed', 'Are you sure you want to clear all completed and failed downloads from the list?', async () => {
      try { await fetch(`${SERVER}/clear-history`, { method: 'POST' }); } catch (_) {}
      setTimeout(renderAllTasks, 200);
    });
    return;
  }

  if (e.target.closest('.open-app-btn'))     { openApp(); return; }
  if (e.target.closest('#btn-refresh'))      { await loadInfo(); return; }
  if (e.target.closest('#btn-theme-toggle')) {
    const keys = Object.keys(THEMES);
    let idx = keys.indexOf(currentTheme);
    idx = (idx + 1) % keys.length;
    currentTheme = keys[idx];
    applyTheme(currentTheme);
    chrome.storage.local.set({ zylosTheme: currentTheme });
    return;
  }
  if (e.target.closest('#btn-retry-load'))   { await loadInfo(); return; }
  if (e.target.closest('#btn-cancel'))       { await cancelDownload(); return; }
  if (e.target.closest('#btn-open'))         { await openFile(e.target.closest('#btn-open').dataset.path); return; }
  if (e.target.closest('#btn-folder'))       { await openFolder(e.target.closest('#btn-folder').dataset.path); return; }
  if (e.target.closest('#btn-copy'))         { await copyPath(); return; }
  if (e.target.closest('#btn-share-file'))   { await shareFile(e.target.closest('#btn-share-file').dataset.path); return; }
  if (e.target.closest('#btn-share-wa'))     { await shareFile(e.target.closest('#btn-share-wa').dataset.path); return; }
  if (e.target.closest('#btn-share-tg'))     { await shareFile(e.target.closest('#btn-share-tg').dataset.path); return; }
  if (e.target.closest('#btn-download-more')){ await loadInfo(); return; }
  if (e.target.closest('#btn-retry-dl'))     { await loadInfo(); return; }
  if (e.target.closest('.open-app-btn'))     { openApp(); return; }

  // ── Settings panel ──────────────────────────────────────────────────
  if (e.target.closest('#btn-settings')) {
    show('screen-settings-menu');
    return;
  }
  if (e.target.closest('#btn-vpn-header')) {
    initVpnScreen();
    show('screen-vpn');
    return;
  }
  if (e.target.closest('#btn-back-settings-menu')) {
    loadInfo();
    return;
  }
  if (e.target.closest('#menu-btn-vpn')) {
    initVpnScreen();
    show('screen-vpn');
    return;
  }
  if (e.target.closest('#menu-btn-speed')) {
    show('screen-speed');
    return;
  }
  if (e.target.closest('#menu-btn-port')) {
    const portInput = document.getElementById('settings-port-input');
    if (portInput) portInput.value = ZYLOS_PORT;
    show('screen-settings-port');
    return;
  }
  if (e.target.closest('#menu-btn-appearance')) {
    show('screen-settings-appearance');
    return;
  }
  if (e.target.closest('#menu-btn-about')) {
    show('screen-settings-about');
    return;
  }
  
  if (e.target.closest('#btn-back-vpn') ||
      e.target.closest('#btn-back-speed') ||
      e.target.closest('#btn-back-settings-port') || 
      e.target.closest('#btn-back-settings-appearance') || 
      e.target.closest('#btn-back-settings-about')) {
    show('screen-settings-menu');
    
    // Cleanup if leaving speed test or VPN
    if (e.target.closest('#btn-back-speed')) {
      if (speedTestController) { speedTestController.abort(); speedTestController = null; }
    }
    if (e.target.closest('#btn-back-vpn')) {
      stopVpnPoll();
    }
    return;
  }
  
  if (e.target.closest('#btn-open-desktop-vpn')) {
    fetch(`${SERVER}/open-vpn`, { method: 'POST' }).catch(()=>{});
    return;
  }
  if (e.target.closest('#btn-open-desktop-speed')) {
    fetch(`${SERVER}/open-speedtest`, { method: 'POST' }).catch(()=>{});
    return;
  }
  
  if (e.target.closest('#btn-start-speedtest')) {
    startSpeedTest();
    return;
  }
  if (e.target.closest('#btn-settings-save')) {
    const portInput = document.getElementById('settings-port-input');
    if (portInput) {
      const ok = savePort(portInput.value);
      const feedback = document.getElementById('settings-feedback');
      if (feedback) {
        feedback.textContent = ok ? `✓ Port saved as :${ZYLOS_PORT}` : '✗ Invalid port (1024–65535)';
        feedback.style.color = ok ? '#10b981' : '#ef4444';
        setTimeout(() => { feedback.textContent = ''; }, 2000);
      }
    }
    return;
  }
  if (e.target.closest('#btn-settings-reset')) {
    savePort(DEFAULT_PORT);
    const portInput = document.getElementById('settings-port-input');
    if (portInput) portInput.value = DEFAULT_PORT;
    const feedback = document.getElementById('settings-feedback');
    if (feedback) { feedback.textContent = `Port reset to :${DEFAULT_PORT}`; feedback.style.color = '#8b5cf6'; setTimeout(() => { feedback.textContent = ''; }, 2000); }
    return;
  }
  
  // ── Appearance settings ──────────────────────────────────────────────
  if (e.target.closest('.theme-btn')) {
    const btn = e.target.closest('.theme-btn');
    const t = btn.dataset.theme;
    if (t) {
      currentTheme = t;
      applyTheme(currentTheme);
      chrome.storage.local.set({ zylosTheme: currentTheme });
    }
  }
  
  if (e.target.closest('#vpn-main-btn')) {
    const btn = document.getElementById('vpn-main-btn');
    if (btn.classList.contains('connecting')) return;
    
    const isConnected = btn.classList.contains('connected');
    const newState = !isConnected;
    
    btn.classList.remove('connected');
    btn.classList.add('connecting');
    document.getElementById('vpn-status-text').textContent = newState ? 'CONNECTING...' : 'DISCONNECTING...';
    document.getElementById('vpn-status-text').style.color = '#F59E0B';
    document.getElementById('vpn-sub-text').textContent = 'Please wait...';
    document.getElementById('vpn-ripple-1').classList.remove('active');
    document.getElementById('vpn-ripple-2').classList.remove('active');
    
    const errorText = document.getElementById('vpn-error-text');
    errorText.textContent = '';
    try {
      const r = await fetch(`${SERVER}/vpn-toggle`, { method: 'POST', body: JSON.stringify({ active: newState }) });
      if (r.ok) {
        setTimeout(initVpnScreen, 500);
      } else {
        errorText.textContent = 'Failed to toggle VPN.';
        btn.classList.remove('connecting');
        if (isConnected) btn.classList.add('connected');
      }
    } catch(err) {
      errorText.textContent = 'Connection error.';
      btn.classList.remove('connecting');
      if (isConnected) btn.classList.add('connected');
    }
  }
  if (e.target.closest('.vpn-mode-item')) {
    const item = e.target.closest('.vpn-mode-item');
    document.querySelectorAll('.vpn-mode-item').forEach(el => el.classList.remove('active'));
    item.classList.add('active');
    document.getElementById('vpn-current-mode').textContent = item.textContent;
    document.getElementById('vpn-mode-dropdown').style.display = 'none';
  } else if (e.target.closest('#vpn-mode-selector')) {
    const dropdown = document.getElementById('vpn-mode-dropdown');
    dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
  } else {
    const dropdown = document.getElementById('vpn-mode-dropdown');
    if (dropdown) dropdown.style.display = 'none';
  }
});

document.addEventListener('change', async (e) => {
  if (e.target.id === 'toggle-animations') {
    animationsEnabled = e.target.checked;
    applyAnimations(animationsEnabled);
    chrome.storage.local.set({ zylosAnim: animationsEnabled });
  }
});

// ── VPN Screen Logic ────────────────────────────────────────────────────────
let vpnPollTimer = null;
function stopVpnPoll() {
  if (vpnPollTimer) clearInterval(vpnPollTimer);
  vpnPollTimer = null;
}

async function fetchVpnStatus() {
  const mainBtn = document.getElementById('vpn-main-btn');
  const ripple1 = document.getElementById('vpn-ripple-1');
  const ripple2 = document.getElementById('vpn-ripple-2');
  const statusText = document.getElementById('vpn-status-text');
  const subText = document.getElementById('vpn-sub-text');
  const origIp = document.getElementById('vpn-orig-ip');
  const origLoc = document.getElementById('vpn-orig-loc');
  const protIp = document.getElementById('vpn-prot-ip');
  const protLoc = document.getElementById('vpn-prot-loc');
  
  try {
    const r = await fetch(`${SERVER}/vpn-status`, { signal: AbortSignal.timeout(1000) });
    if (!r.ok) throw new Error();
    const data = await r.json();
    
    if (data.isActive) {
      mainBtn.classList.remove('connecting');
      mainBtn.classList.add('connected');
      ripple1.classList.add('active');
      ripple2.classList.add('active');
      statusText.textContent = 'CONNECTED';
      statusText.style.color = '#10B981';
      subText.textContent = 'Connection is secure';
      const pIp = data.protectedIp;
      if (pIp && pIp.ip) {
        protIp.textContent = pIp.ip;
        protLoc.textContent = `${pIp.city || ''}, ${pIp.country || ''}`;
      } else {
        protIp.textContent = 'Active';
        protLoc.textContent = 'Protected';
      }
    } else {
      mainBtn.classList.remove('connecting');
      mainBtn.classList.remove('connected');
      ripple1.classList.remove('active');
      ripple2.classList.remove('active');
      statusText.textContent = 'DISCONNECTED';
      statusText.style.color = 'var(--dim)';
      subText.textContent = 'Tap to connect';
      protIp.textContent = '--';
      protLoc.textContent = '--';
    }
    
    const oIp = data.originalIp;
    if (oIp && oIp.ip) {
      origIp.textContent = oIp.ip;
      origLoc.textContent = `${oIp.city || ''}, ${oIp.country || ''}`;
    } else {
      origIp.textContent = 'Unknown IP';
      origLoc.textContent = '--';
    }
    document.getElementById('vpn-error-text').textContent = '';
  } catch(err) {
    const errText = document.getElementById('vpn-error-text');
    if (errText) errText.textContent = 'Cannot reach Zylos desktop app.';
    // Do not overwrite IPs with 'Error' to maintain the last known state
  }
}

async function initVpnScreen() {
  stopVpnPoll();
  await fetchVpnStatus();
  vpnPollTimer = setInterval(fetchVpnStatus, 1500);
}

// ── Speed Test Logic ────────────────────────────────────────────────────────
let speedTestController = null;

async function startSpeedTest() {
  if (speedTestController) { speedTestController.abort(); }
  speedTestController = new AbortController();
  const signal = speedTestController.signal;
  
  const phaseLbl = document.getElementById('speed-phase');
  const valLbl = document.getElementById('speed-value');
  const btn = document.getElementById('btn-start-speedtest');
  const pingEl = document.getElementById('speed-ping');
  const downEl = document.getElementById('speed-down');
  const upEl = document.getElementById('speed-up');
  
  btn.disabled = true;
  btn.style.opacity = '0.5';
  btn.textContent = 'TESTING...';
  
  pingEl.textContent = '--';
  downEl.textContent = '--';
  upEl.textContent = '--';
  valLbl.textContent = '0';
  document.getElementById('speed-summary').style.display = 'none';
  document.getElementById('speed-glow-bg').style.opacity = '0.1';
  updateRing(0);
  
  // Convert Mbps to a 0-1 ratio based on a 200 Mbps scale (capped at 1 for the dial)
  const MAX_SCALE = 200;
  function updateSpeedDial(mbps) {
    const ratio = Math.min(1, mbps / MAX_SCALE);
    updateRing(ratio);
  }
  
  try {
    // 1. Ping test
    phaseLbl.textContent = 'PING';
    let pingTime = 0;
    for(let i=0; i<3; i++) {
      const st = performance.now();
      await fetch('https://speed.cloudflare.com/cdn-cgi/trace', { signal, cache: 'no-store' });
      const et = performance.now();
      pingTime += (et - st);
      valLbl.textContent = Math.round(pingTime / (i+1));
    }
    const finalPing = Math.round(pingTime / 3);
    pingEl.textContent = finalPing;
    
    // 2. Download test (10MB payload)
    phaseLbl.textContent = 'DOWNLOAD';
    valLbl.textContent = '0';
    const dlStart = performance.now();
    const dlRes = await fetch('https://speed.cloudflare.com/__down?bytes=10000000', { signal, cache: 'no-store' });
    
    const reader = dlRes.body.getReader();
    let loaded = 0;
    const total = 10000000;
    
    while(true) {
      const {done, value} = await reader.read();
      if (done) break;
      loaded += value.length;
      
      const now = performance.now();
      const durationSec = (now - dlStart) / 1000;
      if (durationSec > 0.1) {
        const curMbps = ((loaded * 8) / 1000000) / durationSec;
        valLbl.textContent = curMbps.toFixed(1);
        updateSpeedDial(curMbps);
      }
    }
    const dlEnd = performance.now();
    
    const dlSeconds = (dlEnd - dlStart) / 1000;
    const dlMbps = ((total * 8) / 1000000) / dlSeconds;
    
    valLbl.textContent = dlMbps.toFixed(1);
    updateSpeedDial(dlMbps);
    downEl.textContent = dlMbps.toFixed(1);
    
    // 3. Upload test (small payload)
    phaseLbl.textContent = 'UPLOAD';
    valLbl.textContent = '0';
    updateRing(0);
    const upData = new Uint8Array(2000000); // 2MB
    const upStart = performance.now();
    const upRes = await fetch('https://speed.cloudflare.com/__up', {
      method: 'POST',
      body: upData,
      signal,
      cache: 'no-store'
    });
    await upRes.text(); // Wait for response
    const upEnd = performance.now();
    
    const upSeconds = (upEnd - upStart) / 1000;
    const upMbps = ((2000000 * 8) / 1000000) / upSeconds;
    
    // Fake animate the value to the result for smooth UX
    for(let i=1; i<=10; i++) {
      const curMbps = upMbps * (i/10);
      valLbl.textContent = curMbps.toFixed(1);
      updateSpeedDial(curMbps);
      await new Promise(r => setTimeout(r, 50));
    }
    upEl.textContent = upMbps.toFixed(1);
    
    phaseLbl.textContent = 'COMPLETE';
    valLbl.textContent = dlMbps.toFixed(1); // Show DL as final
    updateSpeedDial(dlMbps);
    document.getElementById('speed-glow-bg').style.opacity = '0.4';
    
    // Fetch IP info
    try {
      const r = await fetch(`${SERVER}/vpn-status`, { signal: AbortSignal.timeout(2000) });
      if (r.ok) {
        const d = await r.json();
        const ipInfo = d.isActive ? d.protectedIp : d.originalIp;
        if (ipInfo) {
          document.getElementById('speed-sum-ip').textContent = ipInfo.ip || 'Unknown';
          document.getElementById('speed-sum-loc').textContent = `${ipInfo.city || ''}, ${ipInfo.country || ''}`;
          document.getElementById('speed-sum-isp').textContent = ipInfo.isp || 'Unknown';
        }
      }
    } catch (_) {}

    // Evaluate compatibility
    const evalCompat = (id, reqMbps) => {
      const el = document.getElementById(id);
      if (dlMbps >= reqMbps) {
        el.textContent = '✓ Supported';
        el.style.color = '#10B981';
      } else {
        el.textContent = '✗ Insufficient';
        el.style.color = '#EF4444';
      }
    };
    evalCompat('speed-compat-hd', 5);
    evalCompat('speed-compat-4k', 25);
    evalCompat('speed-compat-game', 50);

    document.getElementById('speed-summary').style.display = 'block';
    
  } catch (err) {
    if (err.name !== 'AbortError') {
      phaseLbl.textContent = 'ERROR';
      valLbl.textContent = '0';
    }
  } finally {
    btn.disabled = false;
    btn.style.opacity = '1';
    btn.textContent = 'RUN AGAIN';
    speedTestController = null;
  }
}

// ── Universal Download (1700+ sites) ─────────────────────────────────────────
async function loadUniversal(url) {
  show('screen-loading');
  setLoading('Fetching media info...', 'Detecting platform...');
  try {
    const cookiesStr = await getCookiesForUrl(url);
    const r = await fetch(`${SERVER}/qualities`, { 
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: url, cookies: cookiesStr }),
      signal: AbortSignal.timeout(60000) 
    });
    if (!r.ok) throw new Error(`Server error ${r.status}`);
    const data = await r.json();
    if (data.error && !data.title) throw new Error(data.error);
    let host = 'Universal';
    try { host = new URL(url).hostname.replace('www.', ''); } catch (_) {}
    currentMeta = { ...data, url, platform: host };
    renderInfo(data, url, host);
  } catch (err) {
    setLoading('Could not fetch media', err.message || 'Check if the URL is supported and Zylos is running.');
  }
}

init();
