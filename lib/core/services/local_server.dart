import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' hide Router;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/downloader/presentation/providers/download_provider.dart';
import '../../features/downloader/presentation/providers/navigation_provider.dart';
import '../../features/downloader/presentation/screens/platform_downloader_screen.dart';
import '../../features/downloader/data/datasources/youtube_datasource.dart';
import '../utils/platform_utils.dart';
import '../../features/downloader/presentation/providers/settings_provider.dart';
import 'plugin_service.dart';
import 'package:path/path.dart' as p;

class LocalServer {
  static HttpServer? _server;
  static int port = 7734;
  static DateTime? lastExtensionPing;
  static late PluginService _pluginService;
  static late DownloadProvider _downloadProvider;
  static late NavigationProvider _navigationProvider;
  static late GlobalKey<NavigatorState> _navigatorKey;
  static late SettingsProvider _settingsProvider;
  
  static final Map<String, dynamic> _qualitiesCache = {};
  static final Map<String, DateTime> _qualitiesCacheTime = {};

  static Future<void> start(DownloadProvider downloadProvider, NavigationProvider navigationProvider, GlobalKey<NavigatorState> navigatorKey, PluginService pluginService, SettingsProvider settingsProvider, {int serverPort = 7734}) async {
    port = serverPort;
    _pluginService = pluginService;
    _downloadProvider = downloadProvider;
    _navigationProvider = navigationProvider;
    _navigatorKey = navigatorKey;
    _settingsProvider = settingsProvider;
    final router = Router();

    // ── CORS preflight ────────────────────────────────────────────────────
    router.options('/<path|.*>', (Request request) {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Max-Age': '86400',
      });
    });

    // ── /qualities — returns video + audio options with file sizes ────────
    router.all('/qualities', (Request request) async {
      String url = '';
      String cookiesStr = '';
      if (request.method == 'POST') {
        try {
          final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
          url = (body['url'] as String?) ?? '';
          cookiesStr = (body['cookies'] as String?) ?? '';
        } catch (_) {}
      } else {
        url = request.url.queryParameters['url'] ?? '';
      }
      
      if (url.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'No URL provided'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Check cache first
      if (_qualitiesCache.containsKey(url)) {
        final cacheTime = _qualitiesCacheTime[url];
        if (cacheTime != null && DateTime.now().difference(cacheTime).inMinutes < 15) {
          print('[Zylos] Returning cached qualities for: $url');
          return Response.ok(
            jsonEncode(_qualitiesCache[url]),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      print('[Zylos] /qualities requested for: $url');

      try {
        final ytDlpExe = await PluginService().getYtDlpPath();

        if (ytDlpExe == null) {
          // yt-dlp not installed — return defaults
          return Response.ok(
            jsonEncode({
              'title': 'Zylos Downloader',
              'thumbnail': '',
              'duration': '--:--',
              'qualities': _getDefaultVideoQualities(),
              'audioQualities': _getDefaultAudioQualities(),
              'url': url,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        File? cookieFile;
        Directory? cookieDir;
        if (cookiesStr.isNotEmpty) {
          cookieDir = await Directory.systemTemp.createTemp('zylos_cookies_');
          cookieFile = File(p.join(cookieDir.path, 'cookies.txt'));
          await cookieFile.writeAsString(cookiesStr);
        }

        // Core args shared across all retry strategies
        final coreArgs = [
          '--dump-json',
          '--no-warnings',
          '--no-playlist',
          '--skip-download',
          '--no-check-certificates',
          '--extractor-retries', '3',
          '--add-header', 'Accept-Language:en-US,en;q=0.9',
        ];

        if (cookieFile != null) {
          coreArgs.addAll(['--cookies', cookieFile.path]);
        }

        // TikTok/Instagram specific headers
        if (url.contains('tiktok.com') || url.contains('instagram.com')) {
          coreArgs.addAll([
            '--impersonate', 'Chrome',
            '--user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            '--add-header', 'Accept:text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            '--add-header', 'Referer:https://www.tiktok.com/',
          ]);
          // Note: NOT adding --cookies-from-browser for Instagram by default
          // to avoid DPAPI errors. Will be tried in cookie fallback loop if needed.
        }

        String cleanUrl = url;
        if (url.contains('tiktok.com')) {
          try {
            final uri = Uri.parse(url);
            cleanUrl = '${uri.scheme}://${uri.host}${uri.path}';
          } catch (_) {}
        }

        final isYouTube = url.contains('youtube.com') || url.contains('youtu.be');

        if (isYouTube) {
          try {
            final ytDatasource = YoutubeDatasource(PluginService());
            final videoEntity = await ytDatasource.fetchVideo(url).timeout(const Duration(seconds: 20));

            final videoQualities = videoEntity.availableQualities.map((q) => {
              'label': q.label,
              'code': '${q.height}',
              'format_id': '', // Not strictly needed by download_service for YT
              'ext': 'mp4',
              'codec': 'H.264',
              'file_size': _formatFileSize(q.fileSizeBytes),
            }).toList();

            final audioQualities = videoEntity.availableAudioQualities.map((q) => {
              'label': q.label,
              'code': '${(q.bitrate / 1000).round()}k',
              'ext': 'mp3',
              'file_size': _formatFileSize(q.fileSizeBytes),
              '_bitrate': (q.bitrate / 1000).round(),
            }).toList();

            return Response.ok(
              jsonEncode({
                'title': videoEntity.title,
                'thumbnail': videoEntity.thumbnailUrl,
                'duration': _formatDuration(videoEntity.duration.inSeconds),
                'qualities': videoQualities.isNotEmpty ? videoQualities : _getDefaultVideoQualities(),
                'audioQualities': audioQualities.isNotEmpty ? audioQualities : _getDefaultAudioQualities(),
                'imageQualities': [],
                'url': url,
              }),
              headers: {'Content-Type': 'application/json'},
            );
          } catch (e) {
            print('[Zylos] youtube_explode failed, falling back to yt-dlp: $e');
          }
        }

        // YouTube fallback & other platforms: try multiple player-client strategies
        final ytClientStrategies = isYouTube
            ? [null, 'tv_embedded', 'ios', 'web', 'android', 'mweb']
            : [null];

        ProcessResult? result;

        outerLoop:
        for (final clientStrategy in ytClientStrategies) {
          // Build args for this client strategy
          final strategyArgs = [...coreArgs];
          if (isYouTube && clientStrategy != null && clientStrategy.isNotEmpty) {
            strategyArgs.addAll(['--extractor-args', 'youtube:player_client=$clientStrategy']);
          }
          strategyArgs.add(cleanUrl);

          // Inner loop: cookie fallback (ALWAYS no-cookies first to avoid DPAPI errors)
          final cookieBrowsers = cookieFile != null ? [null] : [null, 'chrome', 'edge', 'firefox'];
          for (final browser in cookieBrowsers) {
            final args = [...strategyArgs];
            if (browser != null) {
              args.insert(args.length - 1, '--cookies-from-browser');
              args.insert(args.length - 1, browser);
            }

            result = await Process.run(ytDlpExe, args, runInShell: true, stdoutEncoding: utf8, stderrEncoding: utf8, environment: {'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'});
            if (result.exitCode == 0) break outerLoop; // ✅ Success

            final stderr = result.stderr.toString().toLowerCase();

            // DRM-protected → cannot be fixed by any client/cookie combo, give up immediately
            final isDrm = stderr.contains('drm') || stderr.contains('premium') ||
                stderr.contains('drm protected');
            if (isDrm) break outerLoop;

            // Cookie/DPAPI/HTTP error → try next cookie browser
            final isCookieError = stderr.contains('could not copy') ||
                stderr.contains('cookie database') ||
                stderr.contains('cookies-from-browser') ||
                stderr.contains('dpapi') ||
                stderr.contains('failed to decrypt') ||
                stderr.contains('chrome_cookies') ||
                stderr.contains('keyring') ||
                stderr.contains('http error') ||
                stderr.contains('unable to download webpage') ||
                stderr.contains('403') ||
                stderr.contains('520');
            if (isCookieError) {
              print('[Zylos] Cookie/DPAPI error with $browser, trying next...');
              continue; // Try next cookie browser
            }

            // YouTube bot-detection, client limitation, or format unavailability → try next client
            final isYtBotError = stderr.contains('page needs to be reloaded') ||
                stderr.contains('could not find js player') ||
                stderr.contains('unable to extract') ||
                stderr.contains('sign in to confirm') ||
                stderr.contains('confirm you') ||
                stderr.contains('player response') ||
                stderr.contains('requested format is not available') ||
                stderr.contains('no video formats found') ||
                stderr.contains('giving up') ||
                stderr.contains('nsig extraction failed');
            if (isYtBotError) {
              print('[Zylos] Bot/format error with client "$clientStrategy", trying next...');
              break; // Break inner cookie loop, try next client strategy
            }

            // Non-retryable error → no point trying other cookies or clients
            break outerLoop;
          }
        }

        if (result!.exitCode != 0) {
          final stderr = result.stderr.toString();
          print('[Zylos] yt-dlp final error: $stderr');
          // Build a user-friendly error message
          final stderrLower = stderr.toLowerCase();
          final String friendlyError;
          if (stderrLower.contains('drm') || stderrLower.contains('premium')) {
            friendlyError = 'This video is DRM-protected or requires a YouTube Premium subscription and cannot be downloaded.';
          } else if (stderrLower.contains('sign in') || stderrLower.contains('age-restrict') || stderrLower.contains('age restrict')) {
            friendlyError = 'This video requires sign-in or is age-restricted. Open the app, update yt-dlp in Plugin Manager, then retry.';
          } else if (stderrLower.contains('private') || stderrLower.contains('unavailable')) {
            friendlyError = 'This video is private or unavailable.';
          } else if (stderrLower.contains('page needs to be reloaded')) {
            friendlyError = 'YouTube blocked this request. Please update yt-dlp in Plugin Manager, then retry.';
          } else {
            friendlyError = stderr.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Unknown error');
          }

          // Pure HTML Fallback for Instagram/Pinterest
          if (url.contains('instagram.com') || url.contains('pinterest.com') || url.contains('pin.it')) {
            final fallbackImgUrl = await _fetchHtmlOgImage(url);
            if (fallbackImgUrl != null && fallbackImgUrl.isNotEmpty) {
              return Response.ok(
                jsonEncode({
                  'title': 'Image Post',
                  'thumbnail': fallbackImgUrl,
                  'duration': '--:--',
                  'qualities': _getDefaultVideoQualities(),
                  'audioQualities': _getDefaultAudioQualities(),
                  'imageQualities': [{
                    'label': 'IMG_ORIGINAL',
                    'code': 'Max',
                    'ext': 'jpg',
                    'file_size': 'Unknown',
                    '_direct_url': fallbackImgUrl
                  }],
                  'url': url,
                }),
                headers: {'Content-Type': 'application/json'},
              );
            }
          }

          // Still return defaults so extension shows something
          return Response.ok(
            jsonEncode({
              'title': 'Unable to load info',
              'thumbnail': '',
              'duration': '--:--',
              'error': friendlyError,
              'qualities': _getDefaultVideoQualities(),
              'audioQualities': _getDefaultAudioQualities(),
              'imageQualities': [],
              'url': url,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // yt-dlp may output multiple JSON lines — find first valid JSON object
        final stdout = result.stdout.toString().trim();
        Map<String, dynamic>? meta;
        for (final line in stdout.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('{')) {
            try {
              meta = jsonDecode(trimmed) as Map<String, dynamic>;
              if (meta['title'] != null) break; // prefer the first line with a real title
            } catch (_) {
              continue;
            }
          }
        }
        if (meta == null) throw Exception('Could not parse video metadata from yt-dlp output.');

        // Extract title robustly from multiple fields
        String title = ((meta['title'] as String?) ?? '').trim();
        if (title.isEmpty || title == 'NA') {
          title = ((meta['fulltitle'] as String?) ?? '').trim();
        }
        if (title.isEmpty || title == 'NA') {
          title = ((meta['alt_title'] as String?) ?? '').trim();
        }
        if (title.isEmpty) title = 'Unknown Title';

        var infoThumbnail = (meta['thumbnail'] as String?) ?? '';
        final durationSecs = (meta['duration'] as num?)?.toInt() ?? 0;
        final durationStr = _formatDuration(durationSecs);

        final videoQualities = _parseVideoQualities(meta);
        final audioQualities = _parseAudioQualities(meta);
        var imageQualities = _parseImageQualities(meta);

        // Fallback for Instagram/Pinterest if yt-dlp found zero formats
        if (imageQualities.isEmpty && (url.contains('instagram.com') || url.contains('pinterest.com') || url.contains('pin.it'))) {
          final fallbackImgUrl = await _fetchHtmlOgImage(url);
          if (fallbackImgUrl != null && fallbackImgUrl.isNotEmpty) {
            imageQualities = [{
              'label': 'IMG_ORIGINAL',
              'code': 'Max',
              'ext': 'jpg',
              'file_size': 'Unknown',
              '_direct_url': fallbackImgUrl
            }];
            if (infoThumbnail.isEmpty) infoThumbnail = fallbackImgUrl;
          }
        }

        print('[Zylos] Parsed ${videoQualities.length} video, ${audioQualities.length} audio, ${imageQualities.length} image formats');

        if (cookieDir != null && cookieDir.existsSync()) {
          try { cookieDir.deleteSync(recursive: true); } catch (_) {}
        }

        final responseMap = {
          'title': title,
          'thumbnail': infoThumbnail,
          'duration': durationStr,
          'qualities': videoQualities,
          'audioQualities': audioQualities,
          'imageQualities': imageQualities,
          'url': url,
        };

        // Save to cache
        _qualitiesCache[url] = responseMap;
        _qualitiesCacheTime[url] = DateTime.now();

        return Response.ok(
          jsonEncode(responseMap),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e, st) {
        print('[Zylos] /qualities exception: $e\n$st');
        return Response.ok(
          jsonEncode({
            'title': 'Unknown Title',
            'thumbnail': '',
            'duration': '--:--',
            'error': e.toString(),
            'qualities': _getDefaultVideoQualities(),
            'audioQualities': _getDefaultAudioQualities(),
            'imageQualities': [],
            'url': url,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ── /open-library — switch app to Library tab ─────────────────────────
    router.get('/open-library', (Request request) async {
      print('[Zylos] Extension requesting Library tab');
      navigationProvider.setTab(1); // 1 = LIBRARY
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'zylos://open']);
      }
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'});
    });

    // ── /open-playlist — switch app to Downloader and fetch playlist ──────
    router.post('/open-playlist', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        final url = (body['url'] as String?) ?? '';
        if (url.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'URL required'}));

        // Bring app to front
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', 'zylos://open']);
        }
        
        // Push PlatformDownloaderScreen on top with the playlist URL
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => PlatformDownloaderScreen(platformName: 'YouTube', initialUrl: url),
            ),
          );
        }
        return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // ── /playlist-info — return playlist metadata and videos ──────────────
    router.get('/playlist-info', (Request request) async {
      final url = request.url.queryParameters['url'] ?? '';
      if (url.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'URL required'}));

      try {
        // Instantiate YoutubeDatasource directly to fetch playlist details quickly
        final ytDatasource = YoutubeDatasource(_pluginService);
        if (ytDatasource.isPlaylist(url)) {
          final playlist = await ytDatasource.fetchPlaylist(url);
          final videos = playlist.videos.map((v) => {
            'id': v.id,
            'title': v.title,
            'thumbnail': v.thumbnailUrl,
            'duration': _formatDuration(v.duration.inSeconds),
            'channelName': v.channelName,
            'url': 'https://www.youtube.com/watch?v=${v.id}',
          }).toList();

          return Response.ok(
            jsonEncode({
              'id': playlist.id,
              'title': playlist.title,
              'channelName': playlist.channelName,
              'thumbnail': playlist.thumbnailUrl,
              'videos': videos,
              'itemCount': videos.length,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response.badRequest(body: jsonEncode({'error': 'Not a YouTube playlist'}));
        }
      } catch (e) {
        print('[Zylos] /playlist-info exception: $e');
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ── /download — start a download from extension ───────────────────────
    router.post('/download', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        final url = (body['url'] as String?) ?? '';
        final quality = (body['quality'] as String?) ?? '1080p';
        final title = (body['title'] as String?) ?? 'Fetching details...';
        final thumbnail = (body['thumbnail'] as String?) ?? '';
        final isAudioOnly = (body['isAudioOnly'] as bool?) ?? false;
        final isImage = (body['isImage'] as bool?) ?? false;
        final directUrl = (body['directUrl'] as String?) ?? '';
        final targetExt = (body['targetExt'] as String?) ?? '';

        if (url.isEmpty) {
          return Response.badRequest(
            body: jsonEncode({'error': 'URL required'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        String finalQuality = quality;
        if (isImage && directUrl.isNotEmpty) {
          finalQuality = targetExt.isNotEmpty ? '$quality|$targetExt|$directUrl' : '$quality|$directUrl';
        }

        final conflictAction = body['conflictAction'] as String?; // null, 'overwrite', 'keep_both'

        if (conflictAction == null) {
          // Determine expected output path
          final safeTitle = title
              .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
              .trim()
              .replaceAll(RegExp(r'_+'), '_');

          String platformFolder = DownloadProvider.detectPlatformFromUrl(url);
          final category = isAudioOnly ? 'Audios' : (isImage ? 'Images' : 'Videos');
          final activeDir = PlatformUtils.getActiveDownloadPath();
          final targetDir = Directory(p.join(activeDir, 'Downloader', platformFolder, category));

          bool conflictFound = false;
          if (targetDir.existsSync()) {
            final ext = isAudioOnly ? (quality.toUpperCase().contains('MP3') ? 'mp3' : 'm4a') : (isImage ? 'jpg' : 'mp4');
            final exactPath = p.join(targetDir.path, '$safeTitle.$ext');
            if (File(exactPath).existsSync()) {
              conflictFound = true;
            } else {
              // Strip non-ASCII (emojis, etc) for a robust fuzzy match
              // because yt-dlp sometimes replaces them with '?' on Windows.
              final asciiSafeTitle = safeTitle.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
              
              final files = targetDir.listSync().whereType<File>();
              for (var file in files) {
                final baseName = p.basenameWithoutExtension(file.path);
                final asciiBaseName = baseName.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
              
                if (asciiBaseName.isNotEmpty && asciiBaseName == asciiSafeTitle) {
                  conflictFound = true;
                  break;
                } else if (baseName == safeTitle) { // Exact match fallback
                  conflictFound = true;
                  break;
                }
              }
            }
          }

          if (conflictFound) {
            return Response.ok(
              jsonEncode({'status': 'conflict', 'title': title}),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        print('[Zylos] Extension download: $url ($quality, audio: $isAudioOnly, image: $isImage, ext: $targetExt)');

        final taskId = downloadProvider.startDownload(
          url,
          qualityLabel: finalQuality,
          title: title.isNotEmpty ? title : 'Fetching details...',
          thumbnailUrl: thumbnail,
          isAudioOnly: isAudioOnly,
          overwriteFile: conflictAction == 'overwrite',
        );

        return Response.ok(
          jsonEncode({'status': 'started', 'taskId': taskId, 'title': title}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('[Zylos] /download exception: $e');
        return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ── /status — poll download progress ─────────────────────────────────
    router.get('/status', (Request request) {
      final taskId = request.url.queryParameters['taskId'] ?? '';
      if (taskId.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'taskId required'}),
            headers: {'Content-Type': 'application/json'});
      }
      try {
        final task = downloadProvider.tasks.firstWhere((t) => t.taskId == taskId);
        return Response.ok(
          jsonEncode({
            'taskId': task.taskId,
            'status': task.status.name,
            'progress': task.progress,
            'speed': task.speedBytesPerSecond,
            'downloadedBytes': task.downloadedBytes,
            'totalBytes': task.totalBytes,
            'outputPath': task.outputPath ?? '',
            'eta': task.eta?.inSeconds ?? 0,
            'errorMessage': task.errorMessage ?? '',
            'title': task.title,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (_) {
        return Response.notFound(
          jsonEncode({'error': 'Task not found', 'status': 'done'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    // ── /all-tasks — return all current and past downloads ────────────────
    router.get('/all-tasks', (Request request) {
      final list = downloadProvider.tasks.map((task) => {
        'taskId': task.taskId,
        'status': task.status.name,
        'progress': task.progress,
        'speed': task.speedBytesPerSecond,
        'downloadedBytes': task.downloadedBytes,
        'totalBytes': task.totalBytes,
        'outputPath': task.outputPath ?? '',
        'eta': task.eta?.inSeconds ?? 0,
        'errorMessage': task.errorMessage ?? '',
        'title': task.title,
        'thumbnail': task.thumbnailUrl ?? '',
      }).toList();
      return Response.ok(
        jsonEncode(list),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ── /cancel — cancel a download ───────────────────────────────────────
    router.post('/cancel', (Request request) async {
      final taskId = request.url.queryParameters['taskId'] ?? '';
      if (taskId.isNotEmpty) downloadProvider.cancelTask(taskId);
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'});
    });

    // ── /clear-history — clear completed/failed downloads ─────────────────
    router.post('/clear-history', (Request request) async {
      final toRemove = downloadProvider.tasks.where((t) => 
        t.status.name == 'done' || 
        t.status.name == 'failed' || 
        t.status.name == 'cancelled'
      ).map((t) => t.taskId).toList();
      
      for (final id in toRemove) {
        downloadProvider.cancelTask(id);
      }
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'});
    });

    // ── /open-file — open downloaded file ────────────────────────────────
    router.get('/open-file', (Request request) async {
      final path = request.url.queryParameters['path'] ?? '';
      if (path.isEmpty) return Response.badRequest(body: 'path required');
      try {
        await Process.run('explorer.exe', [path]);
      } catch (e) {
        try {
          await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
        } catch (_) {}
      }
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'});
    });

    // ── /open-folder — open file location in Explorer ────────────────────
    router.get('/open-folder', (Request request) async {
      final path = request.url.queryParameters['path'] ?? '';
      if (path.isEmpty) return Response.badRequest(body: 'path required');
      try {
        // /select highlights the file in Explorer
        await Process.run('explorer.exe', ['/select,', path]);
      } catch (e) {
        final folder = path.contains('\\') ? path.substring(0, path.lastIndexOf('\\')) : path;
        await Process.run('explorer.exe', [folder]);
      }
      return Response.ok(jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json'});
    });

    // ── /share — share the actual file via Windows native share sheet ──────
    router.get('/share', (Request request) async {
      final path = request.url.queryParameters['path'] ?? '';
      if (path.isEmpty) return Response.badRequest(body: jsonEncode({'error': 'path required'}), headers: {'Content-Type': 'application/json'});
      try {
        final xFile = XFile(path);
        await SharePlus.instance.share(ShareParams(files: [xFile], text: 'Shared from Zylos'));
        return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        print('[Zylos] /share error: $e');
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
      }
    });

    // ── /ping — health check ──────────────────────────────────────────────
    router.get('/ping', (Request request) {
      final source = request.url.queryParameters['source'] ?? request.requestedUri.queryParameters['source'];
      if (source == 'ext') {
        lastExtensionPing = DateTime.now();
      }
      return Response.ok('pong', headers: {'Content-Type': 'text/plain'});
    });

    // ── /vpn-status — get current VPN/Proxy state ─────────────────────────
    router.get('/vpn-status', (Request request) {
      final isWarpActive = settingsProvider.useWarpProxy;
      final warpMode = settingsProvider.warpMode;
      final originalIp = settingsProvider.originalIpInfo;
      final protectedIp = settingsProvider.protectedIpInfo;
      
      return Response.ok(
        jsonEncode({
          'isActive': isWarpActive,
          'warpMode': warpMode,
          'originalIp': originalIp?.toJson(),
          'protectedIp': protectedIp?.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // ── /vpn-toggle — toggle the VPN/Proxy state ──────────────────────────
    router.post('/vpn-toggle', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        final turnOn = body['active'] as bool?;
        
        if (turnOn != null) {
          settingsProvider.setUseWarpProxy(turnOn);
        } else {
          settingsProvider.setUseWarpProxy(!settingsProvider.useWarpProxy);
        }
        
        return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // ── /vpn-set-mode — change the VPN mode ───────────────────────────────
    router.post('/vpn-set-mode', (Request request) async {
      try {
        final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        final mode = body['mode'] as String?;
        if (mode != null && mode.isNotEmpty) {
          settingsProvider.setWarpMode(mode);
        }
        return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
      }
    });

    // ── /open-vpn — switch app to VPN tab ─────────────────────────────────
    router.post('/open-vpn', (Request request) async {
      navigationProvider.setTab(5); // 5 = VPN
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'zylos://open']);
      }
      return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
    });

    // ── /open-speedtest — switch app to Speed Tester tab ──────────────────
    router.post('/open-speedtest', (Request request) async {
      navigationProvider.setTab(3); // 3 = Speed Tester
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', 'zylos://open']);
      }
      return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
    });

    // ── Apply CORS middleware then start server ────────────────────────────
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port, shared: true);
      print('[Zylos] LocalServer running on port $port');
    } catch (e) {
      print('[Zylos] Failed to start local server: $e');
    }
  }

  static Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        final response = await handler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      };
    };
  }

  // ── Duration formatter ────────────────────────────────────────────────────
  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── File size formatter ───────────────────────────────────────────────────
  static String _formatFileSize(num? bytes) {
    if (bytes == null || bytes <= 0) return '';
    final b = bytes.toDouble();
    if (b >= 1024 * 1024 * 1024) return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${b.toInt()} B';
  }

  // ── Video quality parser ──────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseVideoQualities(Map<String, dynamic> meta) {
    final formats = meta['formats'] as List<dynamic>? ?? [];
    final Map<String, Map<String, dynamic>> bestByRes = {};
    final durationSecs = (meta['duration'] as num?)?.toDouble() ?? 0.0;

    // Pre-compute best audio stream size (to add to video-only stream estimates)
    double bestAudioBitrateKbps = 0.0;
    int bestAudioBytes = 0;
    for (final fmt in formats) {
      final vcodec = (fmt['vcodec'] as String?) ?? 'none';
      final acodec = (fmt['acodec'] as String?) ?? 'none';
      if (vcodec != 'none' || acodec == 'none' || acodec.isEmpty) continue;
      final abr = (fmt['abr'] as num?)?.toDouble() ?? 0.0;
      if (abr > bestAudioBitrateKbps) {
        bestAudioBitrateKbps = abr;
        final fb = (fmt['filesize'] ?? fmt['filesize_approx'] as num?);
        if (fb != null && (fb as num) > 0) {
          bestAudioBytes = (fb as num).toInt();
        } else if (abr > 0 && durationSecs > 0) {
          bestAudioBytes = ((abr * 1000 / 8) * durationSecs).round();
        }
      }
    }

    for (final fmt in formats) {
      final vcodec = (fmt['vcodec'] as String?) ?? 'none';
      final acodec = (fmt['acodec'] as String?) ?? 'none';
      final height = (fmt['height'] as num?)?.toInt() ?? 0;
      final width = (fmt['width'] as num?)?.toInt() ?? 0;
      final ext = (fmt['ext'] as String?) ?? '';
      final formatId = (fmt['format_id'] as String?) ?? '';

      // Skip audio-only or video-less formats
      if (vcodec == 'none' || height == 0) continue;

      final shortEdge = (width > 0 && width < height) ? width : height;

      // Determine resolution label
      String label;
      if (shortEdge >= 2160) label = '4K';
      else if (shortEdge >= 1440) label = '1440p';
      else if (shortEdge >= 1080) label = '1080p';
      else if (shortEdge >= 720)  label = '720p';
      else if (shortEdge >= 480)  label = '480p';
      else if (shortEdge >= 360)  label = '360p';
      else if (shortEdge >= 240)  label = '240p';
      else continue;

      // isVideoOnly: no audio in this format stream (common for high-quality YouTube streams)
      final isVideoOnly = acodec == 'none' || acodec.isEmpty;

      // Compute format bitrate fields once — used for both size estimation and quality ranking
      final fmtTbr = (fmt['tbr'] as num?)?.toDouble() ?? 0.0;
      final fmtVbr = (fmt['vbr'] as num?)?.toDouble() ?? 0.0;
      final effectiveBitrate = fmtTbr > 0 ? fmtTbr : fmtVbr;

      // Get file size: prefer exact filesize, then approx, then estimate from bitrate × duration
      num? fileBytes = fmt['filesize'] ?? fmt['filesize_approx'];
      if ((fileBytes == null || (fileBytes as num) <= 0) && durationSecs > 0) {
        // tbr = total bitrate in kbps (video+audio combined for muxed; video-only for video streams)
        if (effectiveBitrate > 0) {
          // Convert kbps → bytes: kbps * 1000 bits/sec / 8 bits/byte * duration_sec
          fileBytes = ((effectiveBitrate * 1000 / 8) * durationSecs).round();
          // For video-only streams, add the best audio stream size
          if (isVideoOnly && bestAudioBytes > 0) {
            fileBytes = (fileBytes as num) + bestAudioBytes;
          }
        }
      } else if (fileBytes != null && isVideoOnly && bestAudioBytes > 0) {
        // Even if we have the exact video file size, add audio size for total estimate
        fileBytes = (fileBytes as num) + bestAudioBytes;
      }
      final fileSize = _formatFileSize(fileBytes as num?);

      // Pick best format per resolution: prefer mp4 muxed, then by bitrate descending
      final existing = bestByRes[label];
      final existingBitrate = (existing?['_bitrate'] as double?) ?? 0.0;
      final existingExt = (existing?['_ext'] as String?) ?? '';
      final existingIsVideoOnly = (existing?['_videoOnly'] as bool?) ?? false;

      // Prefer: muxed over video-only, mp4 over others, then higher bitrate
      final isBetter = existing == null ||
          (existingIsVideoOnly && !isVideoOnly) ||
          (!existingIsVideoOnly == !isVideoOnly && ext == 'mp4' && existingExt != 'mp4') ||
          (!existingIsVideoOnly == !isVideoOnly && ext == existingExt && effectiveBitrate > existingBitrate);

      if (isBetter) {
        bestByRes[label] = {
          'label': label,
          'code': '${height}',
          'format_id': formatId,
          'ext': 'mp4',
          'codec': _detectVideoCodec(vcodec),
          'file_size': fileSize,
          '_bitrate': effectiveBitrate,
          '_ext': ext,
          '_videoOnly': isVideoOnly,
        };
      }
    }

    // Sort by resolution descending
    const order = ['4K', '1440p', '1080p', '720p', '480p', '360p', '240p'];
    final result = bestByRes.values.toList();
    result.sort((a, b) {
      final ai = order.indexOf(a['label'] as String);
      final bi = order.indexOf(b['label'] as String);
      return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
    });

    // Remove internal tracking fields
    for (final r in result) { r.remove('_bitrate'); r.remove('_ext'); r.remove('_videoOnly'); }

    if (result.isEmpty) return _getDefaultVideoQualities();
    return result;
  }

  static String _detectVideoCodec(String vcodec) {
    if (vcodec.contains('avc') || vcodec.contains('h264')) return 'H.264';
    if (vcodec.contains('hevc') || vcodec.contains('h265')) return 'H.265';
    if (vcodec.contains('vp9')) return 'VP9';
    if (vcodec.contains('av01') || vcodec.contains('av1')) return 'AV1';
    return 'H.264';
  }

  // ── Audio quality parser ──────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseAudioQualities(Map<String, dynamic> meta) {
    final formats = meta['formats'] as List<dynamic>? ?? [];
    final Map<String, Map<String, dynamic>> bestByBitrate = {};
    final durationSecs = (meta['duration'] as num?)?.toDouble() ?? 0.0;

    for (final fmt in formats) {
      final vcodec = (fmt['vcodec'] as String?) ?? 'none';
      final acodec = (fmt['acodec'] as String?) ?? 'none';
      final ext = (fmt['ext'] as String?) ?? '';

      // Must be audio-only: vcodec is 'none' AND acodec is not 'none'
      if (vcodec != 'none') continue;
      if (acodec == 'none' || acodec.isEmpty) continue;

      final abr = (fmt['abr'] as num?)?.toDouble() ?? 0.0;
      final formatId = (fmt['format_id'] as String?) ?? '';
      num? fileBytes = fmt['filesize'] ?? fmt['filesize_approx'];
      // Estimate size from abr × duration when filesize fields are missing
      if ((fileBytes == null || (fileBytes as num) <= 0) && abr > 0 && durationSecs > 0) {
        fileBytes = ((abr * 1000 / 8) * durationSecs).round();
      }
      final fileSize = _formatFileSize(fileBytes as num?);

      // Bucket by bitrate range
      String label;
      if (abr >= 256)      label = '320kbps';
      else if (abr >= 192) label = '256kbps';
      else if (abr >= 128) label = '192kbps';
      else if (abr >= 64)  label = '128kbps';
      else if (abr > 0)    label = '${abr.toInt()}kbps';
      else                 label = 'Best';

      // Output ext: prefer m4a/mp3/opus
      String outExt = 'mp3';
      if (ext == 'm4a') outExt = 'm4a';
      else if (ext == 'opus') outExt = 'opus';

      final existing = bestByBitrate[label];
      final existingAbr = (existing?['_abr'] as double?) ?? 0.0;

      if (existing == null || abr > existingAbr) {
        bestByBitrate[label] = {
          'label': label,
          'code': label,
          'format_id': formatId,
          'ext': outExt,
          'file_size': fileSize,
          '_abr': abr,
        };
      }
    }

    // Sort bitrate descending (Best first)
    const bitrateOrder = ['320kbps', '256kbps', '192kbps', '128kbps', 'Best'];
    final result = bestByBitrate.values.toList();
    result.sort((a, b) {
      final la = a['label'] as String;
      final lb = b['label'] as String;
      final ai = bitrateOrder.indexOf(la);
      final bi = bitrateOrder.indexOf(lb);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      // Unknown labels: sort by numeric value descending
      final an = double.tryParse(la.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final bn = double.tryParse(lb.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      return bn.compareTo(an);
    });

    for (final r in result) r.remove('_abr');

    if (result.isEmpty) return _getDefaultAudioQualities();
    return result;
  }

  // ── Image quality parser ──────────────────────────────────────────────────
  static List<Map<String, dynamic>> _parseImageQualities(Map<String, dynamic> meta) {
    final List<Map<String, dynamic>> result = [];
    final Set<String> addedUrls = {};

    // 1. Process explicit formats (e.g. Instagram pictures, Pinterest)
    final formats = meta['formats'] as List<dynamic>? ?? [];
    for (final fmt in formats) {
      final vcodec = (fmt['vcodec'] as String?) ?? 'none';
      final acodec = (fmt['acodec'] as String?) ?? 'none';
      final ext = (fmt['ext'] as String?)?.toLowerCase() ?? '';
      final url = (fmt['url'] as String?) ?? '';

      // Extractor returns pure images (vcodec is none/mjpeg, acodec is none, ext is jpg/png/webp)
      if ((vcodec == 'none' || vcodec == 'mjpeg') && acodec == 'none' && ['jpg', 'jpeg', 'png', 'webp'].contains(ext) && url.isNotEmpty) {
        if (addedUrls.contains(url)) continue;
        addedUrls.add(url);
        
        final height = (fmt['height'] as num?)?.toInt() ?? 0;
        final width = (fmt['width'] as num?)?.toInt() ?? 0;
        final label = height > 0 ? '${width}x${height}' : 'Original Image';
        final fileSize = _formatFileSize(fmt['filesize'] ?? fmt['filesize_approx']);
        
        result.add({
          'label': label,
          'code': 'IMG_$width',
          'format_id': (fmt['format_id'] as String?) ?? 'image',
          'ext': ext,
          'codec': ext.toUpperCase(),
          'file_size': fileSize,
          '_direct_url': url, // So we can download it directly
        });
      }
    }

    // 2. Process thumbnails (e.g. YouTube maxres thumbnail)
    final thumbnails = meta['thumbnails'] as List<dynamic>? ?? [];
    // We take the best (last) thumbnail to avoid clutter
    if (thumbnails.isNotEmpty) {
      final bestThumb = thumbnails.last;
      final url = (bestThumb['url'] as String?) ?? '';
      
      if (url.isNotEmpty && !addedUrls.contains(url)) {
        addedUrls.add(url);
        final height = (bestThumb['height'] as num?)?.toInt() ?? 0;
        final width = (bestThumb['width'] as num?)?.toInt() ?? 0;
        final label = height > 0 ? 'Thumbnail ${width}x${height}' : 'Cover Thumbnail';
        
        String ext = 'jpg';
        if (url.contains('.png')) ext = 'png';
        if (url.contains('.webp')) ext = 'webp';

        result.add({
          'label': label,
          'code': 'THUMB_MAX',
          'format_id': (bestThumb['id'] as String?) ?? 'thumb',
          'ext': ext,
          'codec': ext.toUpperCase(),
          'file_size': 'Unknown',
          '_direct_url': url,
        });
      }
    }

    return result;
  }

  // ── HTML DOM OG:IMAGE Scraper ────────────────────────────────────────────────
  static Future<String?> _fetchHtmlOgImage(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      if (url.contains('pinterest.com') || url.contains('pin.it')) {
        request.headers.set('Accept', 'text/html,application/xhtml+xml');
      }
      
      final response = await request.close();
      if (response.statusCode != 200) return null;
      
      String body = '';
      await for (final chunk in response) {
        body += utf8.decode(chunk, allowMalformed: true);
        if (body.length > 100000) { client.close(); break; }
      }
      
      final RegExp ogRegExp = RegExp(r'<meta[^>]*property="og:image"[^>]*content="([^"]+)"', caseSensitive: false);
      final match = ogRegExp.firstMatch(body);
      if (match != null && match.groupCount >= 1) return match.group(1)?.replaceAll('&amp;', '&');
      
      final RegExp propRegExp = RegExp(r'<meta[^>]*content="([^"]+)"[^>]*property="og:image"', caseSensitive: false);
      final match2 = propRegExp.firstMatch(body);
      if (match2 != null && match2.groupCount >= 1) return match2.group(1)?.replaceAll('&amp;', '&');

    } catch (_) {}
    return null;
  }

  // ── Fallback quality lists ────────────────────────────────────────────────
  static List<Map<String, dynamic>> _getDefaultVideoQualities() {
    return [
      {'label': '1080p', 'code': '1080p', 'ext': 'mp4', 'codec': 'H.264', 'file_size': ''},
      {'label': '720p',  'code': '720p',  'ext': 'mp4', 'codec': 'H.264', 'file_size': ''},
      {'label': '480p',  'code': '480p',  'ext': 'mp4', 'codec': 'H.264', 'file_size': ''},
      {'label': '360p',  'code': '360p',  'ext': 'mp4', 'codec': 'H.264', 'file_size': ''},
    ];
  }

  static List<Map<String, dynamic>> _getDefaultAudioQualities() {
    return [
      {'label': 'Best',   'code': 'Best',   'ext': 'mp3', 'file_size': ''},
      {'label': '128kbps','code': '128kbps','ext': 'mp3', 'file_size': ''},
    ];
  }

  static Future<void> stop() async {
    await _server?.close();
  }

  static Future<void> restart(int newPort) async {
    await stop();
    await start(_downloadProvider, _navigationProvider, _navigatorKey, _pluginService, _settingsProvider, serverPort: newPort);
  }
}
