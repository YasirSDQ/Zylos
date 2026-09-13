import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import '../../features/downloader/domain/entities/video_entity.dart';
import 'plugin_service.dart';

/// Uses yt-dlp --dump-json to fetch metadata for non-YouTube platforms
/// (TikTok, Facebook, Instagram, Twitter/X, Vimeo, Dailymotion, etc.)
class YtDlpMetadataService {
  final PluginService _pluginService = PluginService();

  Future<VideoEntity> fetchMetadata(String url) async {
    // Windows-only binary resolution
    final ytdlpExe = await _pluginService.getYtDlpPath();
    if (ytdlpExe == null) {
      throw Exception('yt-dlp core components not found. Please install them from Settings → Plugin Manager.');
    }

    // Strip tracking query params from TikTok URLs
    String cleanUrl = url;
    final bool isTikTok = url.contains('tiktok');
    final bool isIG = url.contains('instagram');
    final bool isYouTube = url.contains('youtube.com') || url.contains('youtu.be');
    final bool needsMobileAgent = isIG;

    if (isTikTok) {
      try {
        final uri = Uri.parse(url);
        cleanUrl = '${uri.scheme}://${uri.host}${uri.path}';
      } catch (_) {}
    }

    // Core args for all strategies
    final coreArgs = [
      '--dump-json',
      '--no-playlist',
      '--no-warnings',
      '--no-check-certificates',
      '--extractor-retries', '3',
      '--impersonate', 'Chrome',
      '--add-header', 'Accept-Language:en-US,en;q=0.9',
    ];

    if (needsMobileAgent) {
      coreArgs.addAll([
        '--user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      ]);
    }
    
    // ── WARP Proxy ────────────────────────────────────────────────────────
    try {
      final settings = Hive.box('settings');
      final useProxy = settings.get('useWarpProxy', defaultValue: false) as bool;
      if (useProxy) {
        final proxyPort = settings.get('warpProxyPort', defaultValue: 40000) as int;
        coreArgs.addAll(['--proxy', 'socks5://127.0.0.1:$proxyPort']);
      }
    } catch (_) {}
    
    // YouTube: try multiple player-client strategies.
    // tv_embedded is most reliable for bypassing bot-detection.
    // Separate clients (not comma-joined) gives cleaner retry behavior.
    final ytClientStrategies = isYouTube
        ? [null, 'tv_embedded', 'ios', 'web', 'android', 'mweb']
        : [null];

    ProcessResult? result;

    outerLoop:
    for (final clientStrategy in ytClientStrategies) {
      final strategyArgs = [...coreArgs];
      if (isYouTube && clientStrategy != null && clientStrategy.isNotEmpty) {
        strategyArgs.addAll(['--extractor-args', 'youtube:player_client=$clientStrategy']);
      }
      strategyArgs.add(cleanUrl);

      // Cookie fallback: ALWAYS start with null (no cookies) to avoid DPAPI errors.
      // Only try cookie browsers as last-resort fallback.
      final cookieBrowsers = [null, 'chrome', 'edge', 'firefox'];
      for (final browser in cookieBrowsers) {
        final args = [...strategyArgs];
        if (browser != null) {
          args.insert(args.length - 1, '--cookies-from-browser');
          args.insert(args.length - 1, browser);
        }

        result = await Process.run(ytdlpExe, args, stdoutEncoding: utf8, stderrEncoding: utf8, environment: {'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'})
            .timeout(const Duration(seconds: 60));

        if (result.exitCode == 0) break outerLoop; // ✅ Success

        final stderr = result.stderr.toString().toLowerCase();

        // DRM → give up immediately with clear message
        if (stderr.contains('drm') || stderr.contains('drm protected')) break outerLoop;

        // Cookie/DPAPI/HTTP error → try next browser
        final isCookieError = stderr.contains('dpapi') ||
            stderr.contains('failed to decrypt') ||
            stderr.contains('could not copy') ||
            stderr.contains('cookie database') ||
            stderr.contains('keyring') ||
            stderr.contains('no module named keyring') ||
            stderr.contains('http error') ||
            stderr.contains('unable to download webpage') ||
            stderr.contains('403') ||
            stderr.contains('520');
        if (isCookieError) continue;

        // Bot-detection / client limitation / format issues → try next client
        final isRetryable = stderr.contains('page needs to be reloaded') ||
            stderr.contains('requested format is not available') ||
            stderr.contains('no video formats found') ||
            stderr.contains('unable to extract') ||
            stderr.contains('sign in to confirm') ||
            stderr.contains('nsig extraction failed') ||
            stderr.contains('player response') ||
            stderr.contains('giving up');
        if (isRetryable) break; // try next client

        break outerLoop; // Non-retryable error
      }
    }

    if (result!.exitCode != 0) {
      final err = result.stderr.toString().trim();
      final errLower = err.toLowerCase();
      String cleanErr;
      if (errLower.contains('drm') || errLower.contains('drm protected')) {
        cleanErr = 'This video is DRM-protected and cannot be downloaded.';
      } else if (errLower.contains('premium')) {
        cleanErr = 'This video requires YouTube Premium.';
      } else if (errLower.contains('sign in') || errLower.contains('login') || errLower.contains('cookies')) {
        cleanErr = 'This video requires sign-in. Try a different public video.';
      } else if (errLower.contains('private') || errLower.contains('not available') || errLower.contains('unavailable')) {
        cleanErr = 'This video is private or unavailable.';
      } else if (errLower.contains('page needs to be reloaded')) {
        cleanErr = 'YouTube blocked this request. Update yt-dlp in Plugin Manager and retry.';
      } else if (errLower.contains('requested format is not available')) {
        cleanErr = 'No downloadable formats found for this video.';
      } else if (errLower.contains('unable to extract universal data for rehydration') || (errLower.contains('tiktok') && errLower.contains('unable to extract'))) {
        cleanErr = 'TikTok has updated its systems, causing a known issue in the yt-dlp engine. Please wait for an upstream fix and periodically update yt-dlp (preferably on the Nightly channel) via the Plugin Manager (Settings).';
      } else if (err.isNotEmpty) {
        cleanErr = err.split('\n').lastWhere((l) => l.trim().isNotEmpty, orElse: () => err.split('\n').first).trim();
      } else {
        cleanErr = 'Failed to fetch info. Check the URL and try again.';
      }
      throw Exception(cleanErr);
    }


    final raw = (result.stdout as String).trim();
    if (raw.isEmpty) throw Exception('No metadata returned. The URL may not be supported.');

    final Map<String, dynamic> json;
    try {
      // yt-dlp may emit warning lines before JSON — find first line starting with '{'
      final jsonLine = raw.split('\n').firstWhere(
        (l) => l.trim().startsWith('{'),
        orElse: () => raw.split('\n').first,
      );
      json = jsonDecode(jsonLine);
    } catch (e) {
      throw Exception('Failed to parse video metadata. The URL may be unsupported.');
    }

    final String title = json['title'] as String? ?? 'Unknown Title';
    final String uploader = json['uploader'] as String? ?? json['channel'] as String? ?? '';
    final String thumbnail = json['thumbnail'] as String? ?? '';
    final int durationSecs = (json['duration'] as num?)?.toInt() ?? 0;
    final int viewCount = (json['view_count'] as num?)?.toInt() ?? 0;
    // Store original URL as the videoId for non-YouTube platforms
    final String videoId = url;

    // Build quality options from yt-dlp format list
    final List<VideoQuality> videoQualities = [];
    final List<AudioQuality> audioQualities = [];
    final List<ImageQuality> imageQualities = [];

    final formats = json['formats'] as List<dynamic>? ?? [];
    final thumbnails = json['thumbnails'] as List<dynamic>? ?? [];

    // 1. Process explicit images
    final Set<String> addedUrls = {};
    for (final f in formats) {
      final vcodec = (f['vcodec'] as String? ?? 'none').toLowerCase();
      final acodec = (f['acodec'] as String? ?? 'none').toLowerCase();
      final ext = (f['ext'] as String?)?.toLowerCase() ?? '';
      final fUrl = (f['url'] as String?) ?? '';

      if ((vcodec == 'none' || vcodec == 'mjpeg') && acodec == 'none' && ['jpg', 'jpeg', 'png', 'webp'].contains(ext) && fUrl.isNotEmpty) {
        if (!addedUrls.contains(fUrl)) {
          addedUrls.add(fUrl);
          final h = (f['height'] as num?)?.toInt() ?? 0;
          final w = (f['width'] as num?)?.toInt() ?? 0;
          final label = h > 0 ? '${w}x$h' : 'Original Image';
          
          int sizeBytes = (f['filesize'] as num?)?.toInt() ?? (f['filesize_approx'] as num?)?.toInt() ?? 0;
          
          imageQualities.add(ImageQuality(
            label: label,
            code: 'IMG_$w',
            ext: ext,
            directUrl: fUrl,
            fileSize: sizeBytes > 0 ? '${(sizeBytes / 1024).toStringAsFixed(0)} KB' : 'Unknown',
          ));
        }
      }
    }

    // 2. Add best thumbnail
    if (thumbnails.isNotEmpty) {
      final bestThumb = thumbnails.last;
      final tUrl = (bestThumb['url'] as String?) ?? '';
      if (tUrl.isNotEmpty && !addedUrls.contains(tUrl)) {
        addedUrls.add(tUrl);
        final h = (bestThumb['height'] as num?)?.toInt() ?? 0;
        final w = (bestThumb['width'] as num?)?.toInt() ?? 0;
        final label = h > 0 ? 'Thumbnail ${w}x$h' : 'Cover Thumbnail';
        String ext = 'jpg';
        if (tUrl.contains('.png')) ext = 'png';
        if (tUrl.contains('.webp')) ext = 'webp';

        imageQualities.add(ImageQuality(
          label: label,
          code: 'THUMB_MAX',
          ext: ext,
          directUrl: tUrl,
          fileSize: 'Unknown',
        ));
      }
    }

    // Collect unique heights for video
    final seen = <int>{};
    for (final f in formats.reversed) {
      final height = (f['height'] as num?)?.toInt();
      final width = (f['width'] as num?)?.toInt();
      final vcodec = (f['vcodec'] as String? ?? 'none').toLowerCase();
      final acodec = (f['acodec'] as String? ?? 'none').toLowerCase();
      
      // Ignore image streams here
      if (['jpg', 'jpeg', 'png', 'webp'].contains((f['ext'] as String?)?.toLowerCase())) continue;
      
      if (height != null && height > 0 && vcodec != 'none' && !seen.contains(height)) {
        seen.add(height);
        int sizeBytes = (f['filesize'] as num?)?.toInt()
            ?? (f['filesize_approx'] as num?)?.toInt()
            ?? 0;
            
        if (sizeBytes == 0) {
            final tbr = (f['tbr'] as num?)?.toDouble() ?? (f['vbr'] as num?)?.toDouble();
            if (tbr != null && tbr > 0 && durationSecs > 0) {
                sizeBytes = ((tbr * 1024) * durationSecs / 8).round();
            }
        }
        
        final shortEdge = (width != null && width > 0 && width < height) ? width : height;
            
        videoQualities.add(VideoQuality(
          label: '${shortEdge}p',
          height: height,
          fps: (f['fps'] as num?)?.toInt() ?? 30,
          isMuxed: true,
          fileSizeBytes: sizeBytes > 0 ? sizeBytes : null,
        ));
      }
    }

    // Sort highest → lowest
    videoQualities.sort((a, b) => b.height.compareTo(a.height));

    // If no formats detected AND no images detected, provide sensible defaults
    if (videoQualities.isEmpty && imageQualities.isEmpty) {
      videoQualities.addAll([
        VideoQuality(label: '1080p', height: 1080, fps: 30, isMuxed: true, fileSizeBytes: durationSecs > 0 ? (4000000 * durationSecs) ~/ 8 : null),
        VideoQuality(label: '720p',  height: 720,  fps: 30, isMuxed: true, fileSizeBytes: durationSecs > 0 ? (2500000 * durationSecs) ~/ 8 : null),
        VideoQuality(label: '480p',  height: 480,  fps: 30, isMuxed: true, fileSizeBytes: durationSecs > 0 ? (1000000 * durationSecs) ~/ 8 : null),
        VideoQuality(label: '360p',  height: 360,  fps: 30, isMuxed: true, fileSizeBytes: durationSecs > 0 ? (500000 * durationSecs) ~/ 8 : null),
      ]);
    }

    audioQualities.addAll([
      AudioQuality(label: 'High (256kbps)', bitrate: 256000, format: 'm4a', fileSizeBytes: durationSecs > 0 ? (256000 * durationSecs) ~/ 8 : null),
      AudioQuality(label: 'Standard (128kbps)', bitrate: 128000, format: 'm4a', fileSizeBytes: durationSecs > 0 ? (128000 * durationSecs) ~/ 8 : null),
      AudioQuality(label: 'MP3', bitrate: 192000, format: 'mp3', fileSizeBytes: durationSecs > 0 ? (192000 * durationSecs) ~/ 8 : null),
    ]);

    return VideoEntity(
      id: videoId,  // store original URL so downloader can use it directly
      title: title,
      channelName: uploader,
      thumbnailUrl: thumbnail,
      duration: Duration(seconds: durationSecs),
      viewCount: viewCount,
      uploadDate: DateTime.now(),
      availableQualities: videoQualities,
      availableAudioQualities: audioQualities,
      availableImageQualities: imageQualities,
    );
  }
}

