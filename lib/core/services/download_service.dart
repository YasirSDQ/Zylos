import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import '../../features/downloader/domain/entities/download_task.dart';
import '../utils/platform_utils.dart';
import 'notification_service.dart';
import 'ffmpeg_service.dart';
import 'plugin_service.dart';

class DownloadService {
  final NotificationService _notificationService;
  final FFmpegService _ffmpegService;
  final PluginService _pluginService;

  final Map<String, bool> _cancelFlags = {};
  final Map<String, bool> _pauseFlags = {};

  DownloadService(this._notificationService, this._ffmpegService, this._pluginService);

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getUniquePath(String dir, String title, String ext) {
    bool fileExistsFuzzy(String testTitle) {
      final asciiTestTitle = testTitle.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
      final targetDir = Directory(dir);
      if (!targetDir.existsSync()) return false;
      
      final files = targetDir.listSync().whereType<File>();
      for (var file in files) {
        final baseName = p.basenameWithoutExtension(file.path);
        final asciiBaseName = baseName.replaceAll(RegExp(r'[^\x00-\x7F]'), '').replaceAll('?', '').trim();
        
        if (asciiBaseName.isNotEmpty && asciiBaseName == asciiTestTitle) {
          return true;
        } else if (baseName == testTitle) {
          return true;
        }
      }
      return false;
    }

    String currentTitle = title;
    String path = p.join(dir, '$currentTitle.$ext');
    int counter = 1;
    while (fileExistsFuzzy(currentTitle)) {
      currentTitle = '$title ($counter)';
      path = p.join(dir, '$currentTitle.$ext');
      counter++;
    }
    return path;
  }

  void cancelDownload(String taskId) {
    _cancelFlags[taskId] = true;
  }

  void pauseDownload(String taskId) {
    _pauseFlags[taskId] = true;
  }

  bool _isCancelled(String taskId) => _cancelFlags[taskId] == true;
  bool _isPaused(String taskId) => _pauseFlags[taskId] == true;

  // ── Public download entry-point ──────────────────────────────────────────

  Future<void> downloadVideo(
    DownloadTask task, {
    required Function(
      double progress,
      double speed,
      Duration? eta,
      int? downloadedBytes,
      int? totalBytes,
      DownloadStatus? status,
    ) onProgress,
    required Function(String finalPath) onComplete,
    required Function(String error) onError,
    Function(String retryMessage)? onRetry,
  }) async {
    _cancelFlags[task.taskId] = false;

    final platform = task.platform ?? _detectPlatform(task.videoId);

    onProgress(0.0, 0.0, null, 0, 0, DownloadStatus.fetchingInfo);

    // Multi-client retry strategy — same as metadata fetch:
    // Outer loop: YouTube player client strategies (tv_embedded is best for bot bypass)
    // Inner loop: cookie fallback per client (no-cookies first to ALWAYS avoid DPAPI)
    final ytClientStrategies = platform == 'YouTube'
        ? [null, 'tv_embedded', 'ios', 'web', 'android', 'mweb']
        : [null];

    String? lastError;

    outerLoop:
    for (final clientStrategy in ytClientStrategies) {
      // Cookie fallback: ALWAYS start with null (no cookies) to avoid DPAPI errors.
      // Only try cookie browsers as last resort if no-cookie attempts fail.
      final cookieBrowsers = [null, 'chrome', 'edge', 'firefox'];

      for (final cookieBrowser in cookieBrowsers) {
        if (_isCancelled(task.taskId)) {
          _cancelFlags.remove(task.taskId);
          onError('Cancelled');
          return;
        }

        try {
          final finalPath = await _performDownload(
            task,
            onProgress: onProgress,
            cookieBrowser: cookieBrowser,
            ytPlayerClient: clientStrategy,
          );
          _cancelFlags.remove(task.taskId);
          _notificationService.showDownloadComplete(task.title);
          onComplete(finalPath);
          return; // ✅ Success
        } catch (e) {
          if (_isCancelled(task.taskId)) {
            _cancelFlags.remove(task.taskId);
            onError('Cancelled');
            return;
          }

          final errorStr = e.toString();
          final errorLower = errorStr.toLowerCase();
          lastError = errorStr;

          // Fatal errors — no retry will help
          final isFatal = errorStr.contains('FFmpeg not found') ||
              errorStr.contains('Sign in') ||
              errorStr.contains('This video is') ||
              errorStr.contains('Video unavailable') ||
              errorStr.contains('No video streams') ||
              errorStr.contains('Private video') ||
              errorStr.contains('members-only') ||
              errorLower.contains('drm') ||
              errorLower.contains('premium');
          if (isFatal) {
            _cancelFlags.remove(task.taskId);
            onError(_cleanError(errorStr));
            return;
          }

          // Cookie/DPAPI error — try next cookie browser (same client)
          final isCookieError = errorLower.contains('could not copy') ||
              errorLower.contains('cookie database') ||
              errorLower.contains('cookies-from-browser') ||
              errorLower.contains('dpapi') ||
              errorLower.contains('failed to decrypt') ||
              errorLower.contains('chrome_cookies') ||
              errorLower.contains('keyring') ||
              errorLower.contains('http error') ||
              errorLower.contains('unable to download webpage') ||
              errorLower.contains('403') ||
              errorLower.contains('520');
          if (isCookieError) {
            onRetry?.call('Cookie error, trying next...');
            onProgress(0.0, 0.0, null, 0, 0, DownloadStatus.retrying);
            continue; // try next cookie browser
          }

          // Bot-detection / client limitation — try next player client
          final isClientError = errorLower.contains('page needs to be reloaded') ||
              errorLower.contains('requested format is not available') ||
              errorLower.contains('no video formats found') ||
              errorLower.contains('nsig extraction failed') ||
              errorLower.contains('unable to extract') ||
              errorLower.contains('giving up') ||
              errorLower.contains('403');
          if (isClientError) {
            onRetry?.call('Retrying with different client...');
            onProgress(0.0, 0.0, null, 0, 0, DownloadStatus.retrying);
            break; // break inner cookie loop → try next player client
          }

          // Unknown error — no point retrying
          break outerLoop;
        }
      }
    }

    // All strategies exhausted
    _cancelFlags.remove(task.taskId);
    onError(_cleanError(lastError ?? 'Download failed. Please try again.'));
  }

  String _cleanError(String raw) {
    if (raw.contains('SocketException') || raw.contains('HandshakeException')) {
      return 'Network error – check your internet connection.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'Download timed out – the connection is too slow or YouTube is throttling.';
    }
    if (raw.toLowerCase().contains('drm') || raw.toLowerCase().contains('drm protected')) {
      return 'This video is DRM-protected and cannot be downloaded.';
    }
    if (raw.toLowerCase().contains('premium')) {
      return 'This video requires YouTube Premium and cannot be downloaded.';
    }
    if (raw.contains('page needs to be reloaded')) {
      return 'YouTube blocked this request. Please update yt-dlp in Plugin Manager, then retry.';
    }
    if (raw.contains('403')) return 'YouTube blocked this download (403). Update yt-dlp in Plugin Manager, open Chrome and log into YouTube, then retry.';
    if (raw.contains('404')) return 'Stream not found (404). The video may have been removed.';
    if (raw.contains('FFmpeg')) return 'FFmpeg not found. Please install FFmpeg.';
    if (raw.contains('No video streams')) return 'No downloadable streams for this video.';
    return raw.split('\n').first;
  }

  // ── Core download logic using yt-dlp ──────────────────────────────────────

  /// Forces a fresh download of yt-dlp and ffmpeg by resetting via PluginService
  Future<void> resetBinaries() async {
    await _pluginService.resetAll();
  }

  Future<String> _performDownload(
    DownloadTask task, {
    required Function(
      double progress,
      double speed,
      Duration? eta,
      int? downloadedBytes,
      int? totalBytes,
      DownloadStatus? status,
    ) onProgress,
    String? cookieBrowser, // 'chrome', 'edge', or null (no cookies)
    String? ytPlayerClient, // YouTube player client strategy to use
  }) async {
    // Windows-only: removing Android/iOS checks
    
    final outputDir = (task.outputPath?.isNotEmpty ?? false)
        ? task.outputPath!
        : _defaultDownloadDir();

    final platform = task.platform ?? _detectPlatform(task.videoId);
    final isDirectImage = task.videoQualityLabel?.contains('|http') ?? false;
    
    final category = task.isAudioOnly ? 'Audios' : (isDirectImage ? 'Images' : 'Videos');
    final categoryDir = p.join(outputDir, 'Downloader', platform, category);
    if (!Directory(categoryDir).existsSync()) Directory(categoryDir).createSync(recursive: true);
    final actualOutputDir = categoryDir;

    // Sanitize title for filename
    final safeTitle = task.title
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim()
        .replaceAll(RegExp(r'_+'), '_');

    final ytdlpExe = await _pluginService.getYtDlpPath();
    final ffmpegExe = await _ffmpegService.ensureFfmpegExists();

    if (ytdlpExe == null) {
      throw Exception('yt-dlp is not installed. Please go to Tools → Plugin Manager and install it.');
    }
    if (ffmpegExe == null) {
      throw Exception('FFmpeg is not installed. Please go to Tools → Plugin Manager and install it.');
    }

    if (isDirectImage) {
      final parts = task.videoQualityLabel!.split('|');
      String directUrl = '';
      String targetFormat = '';

      // MODIFIED: Robust URL extraction by looking for the start of the URL (http)
      int urlIndex = parts.indexWhere((p) => p.toLowerCase().startsWith('http'));
      if (urlIndex != -1) {
        directUrl = parts.sublist(urlIndex).join('|');
        // If there's a part between the code and the URL, it's the target extension
        if (urlIndex > 1 && parts[1].isNotEmpty) {
          targetFormat = parts[1].toLowerCase();
        }
      } else {
        throw Exception('Invalid image URL in quality label: ${task.videoQualityLabel}');
      }
      
      // Determine extension from url
      String directExt = 'jpg';
      final uLower = directUrl.toLowerCase();
      if (uLower.contains('.png')) directExt = 'png';
      else if (uLower.contains('.webp')) directExt = 'webp';
      else if (uLower.contains('.gif')) directExt = 'gif';

      if (targetFormat.isEmpty || !['jpg','png','webp','gif'].contains(targetFormat)) {
        targetFormat = directExt;
      }

      String finalPath = p.join(actualOutputDir, '$safeTitle.$directExt');
      if (!task.overwriteFile) {
        finalPath = _getUniquePath(actualOutputDir, safeTitle, directExt);
      }

      onProgress(0.1, 0.0, null, 0, 0, DownloadStatus.downloading);

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final request = await client.getUrl(Uri.parse(directUrl));
      
      // Always use a generic desktop user agent to prevent 403s on images
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      request.headers.set('Accept', 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8');
      request.headers.set('Accept-Language', 'en-US,en;q=0.9');
      
      // Platform-specific Referers are CRITICAL to avoid 403 Forbidden
      if (platform == 'YouTube') {
          request.headers.set('Referer', 'https://www.youtube.com/');
      } else if (platform == 'TikTok') {
          request.headers.set('Referer', 'https://www.tiktok.com/');
      } else if (platform == 'Pinterest') {
          request.headers.set('Referer', 'https://www.pinterest.com/');
      } else if (platform == 'Instagram') {
          request.headers.set('Referer', 'https://www.instagram.com/');
      } else if (platform == 'Facebook') {
          request.headers.set('Referer', 'https://www.facebook.com/');
      } else if (platform == 'Twitter/X' || platform == 'Twitter') {
          request.headers.set('Referer', 'https://twitter.com/');
      }

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode} while fetching image. (Referer: $platform)');
      }

      final total = response.contentLength;
      final file = File(finalPath);
      final sink = file.openWrite();
      
      int downloadedBytes = 0;
      final startTime = DateTime.now();
      int lastReport = startTime.millisecondsSinceEpoch;

      await for (final chunk in response) {
        if (_cancelFlags.containsKey(task.taskId)) {
          await sink.close();
          if (file.existsSync()) file.deleteSync();
          throw Exception('Cancelled');
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastReport > 200 || downloadedBytes == total) {
          lastReport = now;
          final elapsed = now - startTime.millisecondsSinceEpoch;
          double speed = 0.0;
          if (elapsed > 0) speed = (downloadedBytes / elapsed) * 1000;
          
          double progress = 0.0;
          Duration? eta;
          if (total > 0) {
            progress = (downloadedBytes / total) * 100;
            if (speed > 0) {
                final remainingBytes = total - downloadedBytes;
                eta = Duration(seconds: (remainingBytes / speed).round());
            }
          } else {
            progress = -1; // Unknown total
          }

          onProgress(progress, speed, eta, downloadedBytes, total > 0 ? total : downloadedBytes, DownloadStatus.downloading);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Transcode if user requested PNG or JPG but file is different
      if (targetFormat != directExt && ffmpegExe != null) {
        onProgress(100.0, 0.0, null, total > 0 ? total : downloadedBytes, total > 0 ? total : downloadedBytes, DownloadStatus.merging);
        
        final convertedPath = _getUniquePath(actualOutputDir, safeTitle, targetFormat);
        final result = await Process.run(ffmpegExe, ['-i', finalPath, convertedPath], runInShell: true);
        
        if (result.exitCode == 0) {
           if (File(finalPath).existsSync()) File(finalPath).deleteSync();
           finalPath = convertedPath;
        } else {
           print('[FFmpeg] Failed to convert image to $targetFormat. Keeping original. ${result.stderr}');
        }
      }

      return finalPath;
    }

    final ext = task.isAudioOnly ? (task.audioQualityLabel?.toUpperCase().contains('MP3') == true ? 'mp3' : 'm4a') : 'mp4';

    String finalPath = p.join(actualOutputDir, '$safeTitle.$ext');

    // If videoId already starts with http, it is the full original URL (non-YouTube platforms).
    // Otherwise, if it's YouTube, reconstruct the watch URL.
    String downloadUrl;
    if (task.videoId.startsWith('http')) {
      downloadUrl = task.videoId;
    } else if (platform == 'YouTube') {
      downloadUrl = 'https://www.youtube.com/watch?v=${task.videoId}';
    } else {
      // Fallback for bare domains
      downloadUrl = 'https://${task.videoId}';
    }

    if (platform == 'TikTok') {
      try {
        final uri = Uri.parse(downloadUrl);
        downloadUrl = '${uri.scheme}://${uri.host}${uri.path}';
      } catch (_) {}
    }

    if (!task.overwriteFile) {
      finalPath = _getUniquePath(actualOutputDir, safeTitle, ext);
    }

    final List<String> args = [
      '--no-playlist',
      '--newline',
      '--no-config',
      '--no-warnings',
      '--http-chunk-size', '10M',
      '--no-check-certificates',
      '--geo-bypass',
      '--progress',
      '--ffmpeg-location', ffmpegExe,
      '--impersonate', 'Chrome',
      '--add-header', 'Accept-Language:en-US,en;q=0.9',
      // Retry failed extractions up to 3 times before giving up
      '--extractor-retries', '3',
      // Abort partial fragments rather than re-downloading entire file
      '--abort-on-unavailable-fragments',
      // Windows-safe filenames
      '--windows-filenames',
    ];

    // ── Cookie Support ─────────────────────────────────────────────────────
    // First try a cookies.txt file in the yt-dlp directory (manual override)
    final exeDir = p.dirname(ytdlpExe);
    final cookiesFile = File(p.join(exeDir, 'cookies.txt'));
    if (await cookiesFile.exists()) {
      args.addAll(['--cookies', cookiesFile.path]);
    } else if (cookieBrowser != null) {
      // Only use --cookies-from-browser when explicitly requested as fallback.
      // This prevents DPAPI errors when Chrome is open.
      args.addAll(['--cookies-from-browser', cookieBrowser]);
    }
    // Note: no --cookies-from-browser by default → avoids DPAPI decryption errors

    // ── YouTube-specific extractor args ───────────────────────────────────
    if (platform == 'YouTube') {
      final client = ytPlayerClient ?? 'tv_embedded';
      if (client.isNotEmpty) {
        args.addAll([
          '--extractor-args', 'youtube:player_client=$client',
        ]);
      }
    }

    // ── WARP Proxy ────────────────────────────────────────────────────────
    try {
      final settings = Hive.box('settings');
      final useProxy = settings.get('useWarpProxy', defaultValue: false) as bool;
      if (useProxy) {
        final proxyPort = settings.get('warpProxyPort', defaultValue: 40000) as int;
        args.addAll(['--proxy', 'socks5://127.0.0.1:$proxyPort']);
      }
    } catch (_) {}

    args.addAll(['-o', finalPath]);
    if (task.overwriteFile) args.add('--force-overwrites');

    // ── Platform-specific flags ────────────────────────────────────────────
    if (platform == 'Instagram') {
      args.addAll([
        '--user-agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        '--add-header', 'Accept-Language:en-US,en;q=0.9',
        '--add-header', 'Accept:text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      ]);
    }
    if (platform == 'TikTok') {
      args.addAll([
        '--add-header', 'Referer:https://www.tiktok.com/',
      ]);
    }

    if (task.isAudioOnly) {
      args.addAll(['-f', 'bestaudio/best']);
      args.addAll(['--extract-audio', '--audio-format', ext, '--audio-quality', '0']);
    } else {
      final int requestedHeight = _parseHeight(task.videoQualityLabel);

      if (requestedHeight >= 4320) {
         args.addAll(['-f', 'bestvideo*+bestaudio*/best']);
      } else {
        // Resolution-accurate format selection with permissive fallback chain:
        // 1. Try exact requested height with best containers
        // 2. Try up to requested height with best containers  
        // 3. Permissive fallback: bestvideo* allows any container (webm, mp4, etc.)
        // 4. Final safety net: just get anything downloadable
        // NOTE: The * suffix on bestvideo*/bestaudio* makes yt-dlp more permissive
        //       about which containers it accepts — critical for format availability.
        args.addAll([
          '--format-sort', 'res:$requestedHeight,fps,+codec,quality',
          '-f',
          'bestvideo[height=$requestedHeight][ext=mp4]+bestaudio[ext=m4a]'
          '/bestvideo[height=$requestedHeight]+bestaudio'
          '/bestvideo[height<=$requestedHeight][ext=mp4]+bestaudio[ext=m4a]'
          '/bestvideo[height<=$requestedHeight]+bestaudio'
          '/bestvideo*[height<=$requestedHeight]+bestaudio*'
          '/bestvideo*+bestaudio*'
          '/best*',
        ]);
      }
      args.addAll(['--merge-output-format', 'mp4']);
    }

    // ── Final Url at the end ──────────────────────────────────────────────
    args.add(downloadUrl);

    // ── Speed Optimizations ────────────────────────────────────────────────
    args.addAll(['--concurrent-fragments', '4']);
    args.addAll(['--buffer-size', '16K']);
    // Prevent rate limiting
    args.addAll(['--sleep-interval', '0']);
    args.addAll(['--max-sleep-interval', '0']);

    if (!await File(ytdlpExe).exists()) {
      throw Exception('yt-dlp executable not found. Please reinstall it from Tools → Plugin Manager.');
    }

    // Run yt-dlp as a subprocess and parse its progress
    final process = await Process.start(ytdlpExe, args, mode: ProcessStartMode.normal, environment: {'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'});

    final RegExp progressRegex = RegExp(r'\[download\]\s+([\d\.]+)%\s+of\s+~?\s*([\d\.]+[KMG]i?B).*at\s+([\d\.]+[KMG]i?B/s).*ETA\s+([\d:]+)');
    
    // Listen to stdout line by line — use allowMalformed to prevent UTF-8 crashes
    // from non-ASCII chars in video titles (emojis, Arabic, etc.)
    // Listen to stdout line by line
    const decoder = Utf8Decoder(allowMalformed: true);
    
    // Track if we've received ANY progress
    bool receivedProgress = false;
    int? maxTotalBytes;
    bool isSecondStream = false;
    
    final sub = process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (_isCancelled(task.taskId) || _isPaused(task.taskId)) {
        process.kill();
        return;
      }

      debugPrint('yt-dlp stdout: $line'); // DEBUG LOG
      
      final match = progressRegex.firstMatch(line);
      if (match != null) {
        receivedProgress = true;
        final percentStr = match.group(1);
        final totalSizeStr = match.group(2);
        final speedStr = match.group(3);
        final etaStr = match.group(4);

        if (percentStr != null) {
          double progress = (double.tryParse(percentStr) ?? 0) / 100.0;
          
          double speedBytes = 0.0;
          if (speedStr != null) speedBytes = _parseSpeed(speedStr);

          Duration? eta;
          if (etaStr != null && etaStr != 'Unknown') eta = _parseEta(etaStr);

          int? totalBytes;
          int? downloadedBytes;
          if (totalSizeStr != null) {
            totalBytes = _parseSizeToBytes(totalSizeStr);
            if (totalBytes != null) {
              if (maxTotalBytes == null || totalBytes > maxTotalBytes!) {
                maxTotalBytes = totalBytes;
              } else if (totalBytes < maxTotalBytes! * 0.5) {
                isSecondStream = true;
              }
            }
          }

          if (isSecondStream) {
            progress = 0.99;
            totalBytes = maxTotalBytes;
            if (totalBytes != null) downloadedBytes = totalBytes;
          } else {
            if (totalBytes != null) {
              downloadedBytes = (totalBytes * progress).toInt();
            }
          }

          onProgress(progress, speedBytes, eta, downloadedBytes, totalBytes, DownloadStatus.downloading);
        }
      } else if (line.contains('[Merger]') || line.contains('[ExtractAudio]')) {
        receivedProgress = true;
        onProgress(0.99, 0.0, null, null, null, DownloadStatus.merging); 
      }
    });

    // Capture stderr for better error messages
    final List<String> errorLines = [];
    process.stderr
        .transform(decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;

      debugPrint('yt-dlp stderr: $trimmed');
      
      // Prioritize actual error messages
      if (trimmed.toLowerCase().contains('error:') || trimmed.toLowerCase().contains('fatal:')) {
        errorLines.add(trimmed);
      } else {
        // Keep a buffer of context if no explicit error found
        if (errorLines.length > 10) errorLines.removeAt(0);
        errorLines.add(trimmed);
      }
    });

    // Use a safety timeout for the entire process if it keeps hanging
    int exitCode = -1;
    try {
      // If we haven't even started downloading (fetching info) for 30s, fail it
      exitCode = await process.exitCode.timeout(const Duration(minutes: 10), onTimeout: () {
        if (!receivedProgress) {
          throw Exception('Timed out waiting for yt-dlp to start. Check your internet/VPN.');
        }
        return -1; // Continue waiting if we have progress
      });
    } catch (e) {
      debugPrint('Error or timeout waiting for process: $e');
      process.kill();
      if (e is! Exception) throw Exception('Download timed out or failed to start.');
      rethrow;
    }
    await sub.cancel();

    if (_isCancelled(task.taskId)) {
      if (File(finalPath).existsSync()) File(finalPath).deleteSync();
      // yt-dlp parts cleanup
      try {
        final dirList = Directory(actualOutputDir).listSync();
        for (var f in dirList) {
          if (f.path.contains(safeTitle) && f.path.endsWith('.part')) f.deleteSync();
          if (f.path.contains(safeTitle) && f.path.endsWith('.ytdl')) f.deleteSync();
        }
      } catch (_) {}
      throw Exception('Cancelled');
    }

    if (_isPaused(task.taskId)) {
      _pauseFlags.remove(task.taskId);
      throw Exception('Paused');
    }

    if (exitCode != 0) {
      final errorMsg = errorLines.isNotEmpty ? errorLines.join('\n') : 'Unknown error (code $exitCode)';
      throw Exception(errorMsg);
    }
    
    if (!receivedProgress && exitCode == 0) {
       // Check if file exists anyway, maybe it was super fast or already done
       if (!File(finalPath).existsSync()) {
         throw Exception('yt-dlp finished but no file was created.');
       }
    }

    onProgress(1.0, 0.0, Duration.zero, null, null, DownloadStatus.done);
    return finalPath;
  }

  // ── Platform detection ───────────────────────────────────────────────────
  String _detectPlatform(String videoIdOrUrl) {
    final url = videoIdOrUrl.toLowerCase();
    if (url.contains('tiktok')) return 'TikTok';
    if (url.contains('facebook') || url.contains('fb.watch')) return 'Facebook';
    if (url.contains('instagram')) return 'Instagram';
    if (url.contains('twitter') || url.contains('x.com')) return 'Twitter';
    if (url.contains('vimeo')) return 'Vimeo';
    if (url.contains('dailymotion') || url.contains('dai.ly')) return 'Dailymotion';
    if (url.contains('bilibili')) return 'Bilibili';
    if (url.contains('reddit')) return 'Reddit';
    if (url.contains('pinterest') || url.contains('pin.it')) return 'Pinterest';
    if (url.contains('twitch')) return 'Twitch';
    if (url.contains('soundcloud')) return 'SoundCloud';
    if (url.contains('linkedin')) return 'LinkedIn';
    
    // Bare YouTube ID (11 chars) or YouTube domain
    if (videoIdOrUrl.length == 11 && !videoIdOrUrl.contains('/') || url.contains('youtube') || url.contains('youtu.be')) {
      return 'YouTube';
    }
    
    try {
      final uri = Uri.parse(videoIdOrUrl);
      String host = uri.host.toLowerCase().replaceFirst('www.', '');
      if (host.isNotEmpty) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          String domain = parts[parts.length - 2];
          return domain[0].toUpperCase() + domain.substring(1);
        } else {
          return host[0].toUpperCase() + host.substring(1);
        }
      }
    } catch (_) {}
    
    return 'Other'; 
  }

  // ── yt-dlp binary resolved via PluginService ──────────────────────────────

  int? _parseSizeToBytes(String sizeStr) {
    try {
      final clean = sizeStr.replaceAll('~', '').trim();
      final numStr = clean.replaceAll(RegExp(r'[a-zA-Z]'), '');
      final unit = clean.replaceAll(RegExp(r'[0-9\.]'), '').toUpperCase();
      final value = double.tryParse(numStr) ?? 0.0;
      
      if (unit.contains('G')) return (value * 1024 * 1024 * 1024).toInt();
      if (unit.contains('M')) return (value * 1024 * 1024).toInt();
      if (unit.contains('K')) return (value * 1024).toInt();
      if (unit.contains('B')) return value.toInt();
      return value.toInt();
    } catch (_) {
      return null;
    }
  }

  double _parseSpeed(String speedStr) {
    if (speedStr.contains('KiB/s')) return (double.tryParse(speedStr.replaceAll('KiB/s', '')) ?? 0) * 1024;
    if (speedStr.contains('MiB/s')) return (double.tryParse(speedStr.replaceAll('MiB/s', '')) ?? 0) * 1024 * 1024;
    if (speedStr.contains('GiB/s')) return (double.tryParse(speedStr.replaceAll('GiB/s', '')) ?? 0) * 1024 * 1024 * 1024;
    return 0.0;
  }

  Duration _parseEta(String etaStr) {
    final parts = etaStr.split(':').reversed.toList();
    int seconds = 0;
    if (parts.isNotEmpty) seconds += int.tryParse(parts[0]) ?? 0;
    if (parts.length > 1) seconds += (int.tryParse(parts[1]) ?? 0) * 60;
    if (parts.length > 2) seconds += (int.tryParse(parts[2]) ?? 0) * 3600;
    return Duration(seconds: seconds);
  }

  // Native Mobile Downloader (Android / iOS) - REMOVED

  // ── Utilities ────────────────────────────────────────────────────────────

  int _parseHeight(String? label) {
    if (label == null || label.toLowerCase().contains('best')) return 4320; // 8K max
    if (label.contains('|')) {
      final parts = label.split('|');
      if (parts.length > 1) {
        return int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 720;
      }
    }
    final firstPart = label.split(' ').first;
    return int.tryParse(firstPart.replaceAll(RegExp(r'[^0-9]'), '')) ?? 720;
  }

  String _defaultDownloadDir() {
    return PlatformUtils.getActiveDownloadPath();
  }
}
