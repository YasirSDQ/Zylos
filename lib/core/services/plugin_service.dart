import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Represents one binary plugin managed by the app.
enum PluginType { ffmpeg, ytDlp, warp }

/// Emitted during a plugin download to report progress.
class PluginDownloadEvent {
  final PluginType plugin;
  final double progress; // 0.0 – 1.0
  final String message;
  const PluginDownloadEvent({required this.plugin, required this.progress, required this.message});
}

/// Centralized service that locates, verifies, and (if necessary) downloads
/// the required local binaries (ffmpeg.exe, yt-dlp.exe) into a private
/// app folder so we never depend on the system PATH.
class PluginService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final PluginService _instance = PluginService._internal();
  factory PluginService() => _instance;
  PluginService._internal();

  // ── Cache ─────────────────────────────────────────────────────────────────
  String? _ffmpegPath;
  String? _ytDlpPath;

  // Cancellation support
  CancelToken? _cancelToken;

  // ── Version Cache ────────────────────────────────────────────────────────
  String? _localFfmpegVersion;
  String? _localYtDlpVersion;
  String? _remoteFfmpegVersion;
  String? _remoteYtDlpVersion;

  /// Folder where internal binaries are stored: %LOCALAPPDATA%\Zylos\bin
  static String get binDir {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    return p.join(localAppData, 'Zylos', 'bin');
  }

  static String get ffmpegExePath => p.join(binDir, 'ffmpeg.exe');

  static String ytDlpExePathForChannel(String channel) {
    if (channel == 'nightly') return p.join(binDir, 'yt-dlp-nightly.exe');
    if (channel == 'stable') return p.join(binDir, 'yt-dlp-stable.exe');
    return p.join(binDir, 'yt-dlp.exe'); // master
  }

  static String get ytDlpExePath {
    String channel = 'master';
    if (Hive.isBoxOpen('settings')) channel = Hive.box('settings').get('ytdlpReleaseChannel', defaultValue: 'master');
    return ytDlpExePathForChannel(channel);
  }

  static String get _ffmpegExePath => ffmpegExePath;
  String get _ytDlpExePath => ytDlpExePath;

  // ─────────────────────────────────────────────────────────────────────────
  // Public: resolve paths (returning null if missing)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the resolved path to ffmpeg.exe, or null if not installed.
  Future<String?> getFfmpegPath() async {
    if (_ffmpegPath != null && await File(_ffmpegPath!).exists()) return _ffmpegPath;
    _ffmpegPath = await _findFfmpeg();
    return _ffmpegPath;
  }

  /// Returns the resolved path to yt-dlp.exe, or null if not installed.
  Future<String?> getYtDlpPath() async {
    if (_ytDlpPath != null && await File(_ytDlpPath!).exists()) return _ytDlpPath;
    _ytDlpPath = await _findYtDlp();
    return _ytDlpPath;
  }

  /// Returns true if ffmpeg.exe is present and usable.
  Future<bool> isFfmpegInstalled() async => (await getFfmpegPath()) != null;

  /// Returns true if yt-dlp.exe is present and usable.
  Future<bool> isYtDlpInstalled() async => (await getYtDlpPath()) != null;

  /// Returns a map of which plugins are installed.
  Future<Map<PluginType, bool>> checkAllPlugins() async {
    final ffmpeg = await isFfmpegInstalled();
    final ytdlp  = await isYtDlpInstalled();
    return {
      PluginType.ffmpeg: ffmpeg,
      PluginType.ytDlp:  ytdlp,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public: Download missing plugins with progress
  // ─────────────────────────────────────────────────────────────────────────

  /// Download yt-dlp and ffmpeg if they are missing.
  /// Yields [PluginDownloadEvent]s with real-time progress.
  Stream<PluginDownloadEvent> ensurePlugins() async* {
    await _ensureBinDir();
    _cancelToken = CancelToken();

    final ffmpegMissing = !(await isFfmpegInstalled());
    final ytDlpMissing  = !(await isYtDlpInstalled());

    if (ytDlpMissing) {
      yield* _downloadYtDlp();
    }
    if (ffmpegMissing) {
      yield* _downloadFfmpeg();
    }

    // Refresh cache
    _ffmpegPath = await _findFfmpeg();
    _ytDlpPath  = await _findYtDlp();
    _cancelToken = null;
  }

  /// Force re-download of a specific plugin.
  Stream<PluginDownloadEvent> redownloadPlugin(PluginType plugin) async* {
    await _ensureBinDir();
    _cancelToken = CancelToken();
    if (plugin == PluginType.ytDlp) {
      _ytDlpPath = null;
      yield* _downloadYtDlp(force: true);
      _ytDlpPath = await _findYtDlp();
    } else {
      _ffmpegPath = null;
      yield* _downloadFfmpeg(force: true);
      _ffmpegPath = await _findFfmpeg();
    }
    _cancelToken = null;
    // Clear version cache after successful download
    _localFfmpegVersion = null;
    _localYtDlpVersion = null;
  }

  /// Clear cache for a specific plugin (useful after manual import)
  void clearCache(PluginType plugin) {
    if (plugin == PluginType.ffmpeg) {
      _localFfmpegVersion = null;
      _ffmpegPath = null;
    } else {
      _localYtDlpVersion = null;
      _ytDlpPath = null;
    }
  }

  /// Clears the remote version cache so the next call fetches fresh data.
  void clearRemoteVersionCache() {
    _remoteFfmpegVersion = null;
    _remoteYtDlpVersion = null;
  }

  Stream<PluginDownloadEvent> downloadAllYtDlpChannels() async* {
    await _ensureBinDir();
    _cancelToken = CancelToken();
    final channels = ['stable', 'master', 'nightly'];
    for (final channel in channels) {
      yield* _downloadYtDlp(force: true, explicitChannel: channel);
    }
    _ytDlpPath = await _findYtDlp();
    _cancelToken = null;
    _localYtDlpVersion = null;
  }

  /// Silently runs yt-dlp --update-to <channel> to get the latest build.
  /// Call on app startup for seamless updates.
  Future<void> autoUpdateYtDlp() async {
    final path = await getYtDlpPath();
    if (path == null) return;
    try {
      String channel = 'master';
      if (Hive.isBoxOpen('settings')) {
        channel = Hive.box('settings').get('ytdlpReleaseChannel', defaultValue: 'master');
      }
      
      debugPrint('[PluginService] Auto-updating yt-dlp to $channel build...');
      final result = await Process.run(
        path,
        ['--update-to', channel],
        runInShell: true,
      ).timeout(const Duration(seconds: 90));
      debugPrint('[PluginService] yt-dlp update result: ${result.stdout}');
      // Clear version cache so it re-reads the new version
      _localYtDlpVersion = null;
    } catch (e) {
      debugPrint('[PluginService] yt-dlp auto-update skipped: $e');
    }
  }

  // ── Versioning logic ─────────────────────────────────────────────────────

  /// Fetches the local version of a plugin by running it with --version.
  Future<String?> getLocalVersion(PluginType plugin) async {
    if (plugin == PluginType.ffmpeg && _localFfmpegVersion != null) return _localFfmpegVersion;
    if (plugin == PluginType.ytDlp && _localYtDlpVersion != null) return _localYtDlpVersion;

    final path = plugin == PluginType.ffmpeg ? await getFfmpegPath() : await getYtDlpPath();
    if (path == null) return null;

    try {
      final String? version;
      if (plugin == PluginType.ytDlp) {
        final r = await Process.run(path, ['--version']);
        version = r.stdout.toString().trim();
      } else {
        // ffmpeg -version output is verbose: "ffmpeg version N-114324-g9a9301297e..."
        final r = await Process.run(path, ['-version']);
        final out = r.stdout.toString();
        final match = RegExp(r'version ([\w\.-]+)').firstMatch(out);
        version = match?.group(1);
      }
      if (plugin == PluginType.ffmpeg) _localFfmpegVersion = version;
      else _localYtDlpVersion = version;
      return version;
    } catch (_) { return null; }
  }

  /// Fetches the latest version available on GitHub.
  Future<String?> getLatestRemoteVersion(PluginType plugin) async {
    if (plugin == PluginType.ffmpeg && _remoteFfmpegVersion != null) return _remoteFfmpegVersion;
    if (plugin == PluginType.ytDlp && _remoteYtDlpVersion != null) return _remoteYtDlpVersion;

    String url;
    if (plugin == PluginType.ytDlp) {
      String channel = 'master';
      if (Hive.isBoxOpen('settings')) {
        channel = Hive.box('settings').get('ytdlpReleaseChannel', defaultValue: 'master');
      }
      if (channel == 'stable') {
        url = 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest';
      } else if (channel == 'nightly') {
        url = 'https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest';
      } else {
        url = 'https://api.github.com/repos/yt-dlp/yt-dlp-master-builds/releases/latest';
      }
    } else {
      url = 'https://api.github.com/repos/yt-dlp/FFmpeg-Builds/releases/latest';
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse(url));
      // GitHub API requires a User-Agent header, otherwise it returns 403
      request.headers.set('User-Agent', 'Zylos-App/1.0');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 15));

      final body = await response.transform(const Utf8Decoder()).join();
      debugPrint('[PluginService] GitHub API status: ${response.statusCode} for $url');

      if (response.statusCode != 200) {
        debugPrint('[PluginService] GitHub API error body: ${body.length > 300 ? body.substring(0, 300) : body}');
        client.close();
        return null;
      }
      client.close();

      final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
      String? version;

      if (plugin == PluginType.ffmpeg) {
        // FFmpeg-Builds: tag_name is "latest". Extract YYYYMMDD from asset filenames.
        final releaseName = data['name']?.toString() ?? '';
        final tagName = data['tag_name']?.toString() ?? '';

        // 1. Try release name / tag
        final dateMatch = RegExp(r'(\d{8})').firstMatch(releaseName) ??
                          RegExp(r'(\d{8})').firstMatch(tagName);
        if (dateMatch != null) {
          version = dateMatch.group(1);
        } else {
          // 2. Scan asset filenames for YYYYMMDD
          final assets = data['assets'] as List? ?? [];
          for (final asset in assets) {
            final name = asset['name']?.toString() ?? '';
            final m = RegExp(r'(\d{8})').firstMatch(name);
            if (m != null) { version = m.group(1); break; }
          }
        }
        // 3. Last resort: published_at date
        if (version == null) {
          final published = data['published_at']?.toString() ?? '';
          final m = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(published);
          if (m != null) version = '${m.group(1)}${m.group(2)}${m.group(3)}';
        }
        _remoteFfmpegVersion = version;
        debugPrint('[PluginService] Remote FFmpeg version: $version  (release: "$releaseName", tag: "$tagName")');
      } else {
        version = data['tag_name']?.toString() ?? data['name']?.toString();
        _remoteYtDlpVersion = version;
        debugPrint('[PluginService] Remote yt-dlp version: $version');
      }
      return version;
    } catch (e, st) {
      debugPrint('[PluginService] Error fetching remote version for $plugin: $e');
      debugPrint(st.toString());
      return null;
    }
  }

  /// Cancels any active plugin download.
  void cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
    _cancelToken = null;
  }

  /// Delete all binaries so they are re-downloaded from scratch.
  Future<void> resetAll() async {
    _ffmpegPath = null;
    _ytDlpPath  = null;
    final dir = Directory(binDir);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private: Find logic
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _findFfmpeg() async {
    // 1. Private Zylos bin dir (preferred)
    if (await File(_ffmpegExePath).exists()) return _ffmpegExePath;

    // 2. Alongside the .exe (bundled in release)
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = p.join(exeDir, 'bin', 'ffmpeg.exe');
    if (await File(bundled).exists()) return bundled;

    // 3. System PATH
    try {
      final r = await Process.run('where', ['ffmpeg'], runInShell: true);
      if (r.exitCode == 0) {
        for (final line in r.stdout.toString().trim().split('\n')) {
          final path = line.trim();
          if (path.isNotEmpty && await File(path).exists()) return path;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _findYtDlp() async {
    // 1. Private Zylos bin dir (preferred)
    if (await File(_ytDlpExePath).exists()) return _ytDlpExePath;

    // 2. Alongside the .exe (bundled in release)
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = p.join(exeDir, 'bin', 'yt-dlp.exe');
    if (await File(bundled).exists()) return bundled;

    // 3. System PATH
    try {
      final r = await Process.run('where', ['yt-dlp'], runInShell: true);
      if (r.exitCode == 0) {
        final path = r.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } catch (_) {}

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private: Download logic (StreamController-based for real-time progress)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _ensureBinDir() async {
    final dir = Directory(binDir);
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  /// Downloads yt-dlp.exe with per-byte progress reporting.
  Stream<PluginDownloadEvent> _downloadYtDlp({bool force = false, String? explicitChannel}) {
    final controller = StreamController<PluginDownloadEvent>();

    Future.microtask(() async {
      String channel = explicitChannel ?? 'master';
      if (explicitChannel == null && Hive.isBoxOpen('settings')) {
        channel = Hive.box('settings').get('ytdlpReleaseChannel', defaultValue: 'master');
      }
      
      final targetPath = ytDlpExePathForChannel(channel);
      final file = File(targetPath);
      final tempPath = '$targetPath.part';
      
      try {
        if (!force && await file.exists() && (await file.length()) > 0) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ytDlp, progress: 1.0, message: 'yt-dlp ($channel) already installed'));
          return;
        }

        controller.add(PluginDownloadEvent(plugin: PluginType.ytDlp, progress: 0.0, message: 'Connecting to GitHub ($channel build)…'));

        String url;
        if (channel == 'stable') {
          url = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
        } else if (channel == 'nightly') {
          url = 'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe';
        } else {
          url = 'https://github.com/yt-dlp/yt-dlp-master-builds/releases/latest/download/yt-dlp.exe';
        }

        final dio = Dio();

        await dio.download(
          url,
          tempPath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (controller.isClosed) return;
            final progress = total > 0 ? (received / total).clamp(0.0, 0.99) : 0.0;
            final receivedMb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = total > 0 ? ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB' : '';
            controller.add(PluginDownloadEvent(
              plugin: PluginType.ytDlp,
              progress: progress,
              message: 'Downloading yt-dlp $channel… $receivedMb MB$totalMb',
            ));
          },
          options: Options(receiveTimeout: const Duration(minutes: 5)),
        );

        // Rename temp to final
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          if (await file.exists()) await file.delete();
          await tempFile.rename(targetPath);
        }

        if (await file.exists() && (await file.length()) > (1 * 1024 * 1024)) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ytDlp, progress: 1.0, message: 'yt-dlp ($channel) installed ✓'));
        } else {
          throw Exception('yt-dlp download incomplete or corrupt.');
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ytDlp, progress: 0.0, message: 'Download stopped'));
        } else {
          if (await file.exists() && (await file.length()) > 1024 * 1024) {
             controller.add(PluginDownloadEvent(plugin: PluginType.ytDlp, progress: 1.0, message: 'Using existing yt-dlp'));
          } else {
            controller.addError(e);
          }
        }
      } finally {
        try { if (await File(tempPath).exists()) await File(tempPath).delete(); } catch (_) {}
        await controller.close();
      }
    });

    return controller.stream;
  }

  /// Downloads ffmpeg (zip) with per-byte progress reporting, then extracts the exe.
  Stream<PluginDownloadEvent> _downloadFfmpeg({bool force = false}) {
    final controller = StreamController<PluginDownloadEvent>();

    Future.microtask(() async {
      final file = File(_ffmpegExePath);
      final zipPath = p.join(binDir, '_ffmpeg_dl.zip');
      try {
        if (!force && await file.exists() && (await file.length()) > 0) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 1.0, message: 'FFmpeg already installed'));
          return;
        }

        controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 0.0, message: 'Connecting to GitHub…'));

        const zipUrl = 'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip';
        final dio = Dio();

        // FFmpeg zip is ~90 MB — download maps to 0.0–0.90, extraction to 0.90–1.0
        await dio.download(
          zipUrl,
          zipPath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (controller.isClosed) return;
            final downloadProgress = total > 0 ? (received / total).clamp(0.0, 1.0) * 0.90 : 0.0;
            final receivedMb = (received / 1024 / 1024).toStringAsFixed(0);
            final totalMb = total > 0 ? ' / ${(total / 1024 / 1024).toStringAsFixed(0)} MB' : '';
            controller.add(PluginDownloadEvent(
              plugin: PluginType.ffmpeg,
              progress: downloadProgress,
              message: 'Downloading FFmpeg… $receivedMb MB$totalMb',
            ));
          },
          options: Options(receiveTimeout: const Duration(minutes: 10)),
        );

        if (_cancelToken?.isCancelled ?? false) return;

        controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 0.92, message: 'Extracting FFmpeg…'));

        // Extract using Windows built-in tar (Win 10+)
        final result = await Process.run(
          'tar',
          ['-xf', zipPath, '--strip-components', '2', '-C', binDir, '*/bin/ffmpeg.exe'],
          runInShell: true,
        );

        if (result.exitCode != 0 || !await file.exists()) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 0.95, message: 'Fallback extraction…'));
          await _extractFfmpegFallback(zipPath, file);
        }

        if (await file.exists() && (await file.length()) > (1 * 1024 * 1024)) {
          controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 1.0, message: 'FFmpeg installed ✓'));
        } else {
          throw Exception('FFmpeg extraction failed.');
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
           controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 0.0, message: 'Download stopped'));
        } else {
          if (await file.exists() && (await file.length()) > 1024 * 1024) {
            controller.add(PluginDownloadEvent(plugin: PluginType.ffmpeg, progress: 1.0, message: 'Using existing FFmpeg'));
          } else {
            controller.addError(e);
          }
        }
      } finally {
        try { if (await File(zipPath).exists()) await File(zipPath).delete(); } catch (_) {}
        await controller.close();
      }
    });

    return controller.stream;
  }

  /// Downloads the Cloudflare WARP MSI and launches the installer.
  Stream<PluginDownloadEvent> downloadWarp() {
    final controller = StreamController<PluginDownloadEvent>();

    Future.microtask(() async {
      final msiPath = p.join(binDir, 'Cloudflare_WARP.msi');
      try {
        controller.add(const PluginDownloadEvent(plugin: PluginType.warp, progress: 0.0, message: 'Connecting to Cloudflare…'));

        const msiUrl = 'https://1111-releases.cloudflareclient.com/windows/Cloudflare_WARP_Release-x64.msi';
        final dio = Dio();

        await dio.download(
          msiUrl,
          msiPath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (controller.isClosed) return;
            final downloadProgress = total > 0 ? (received / total).clamp(0.0, 1.0) * 0.95 : 0.0;
            final receivedMb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = total > 0 ? ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB' : '';
            controller.add(PluginDownloadEvent(
              plugin: PluginType.warp,
              progress: downloadProgress,
              message: 'Downloading WARP Installer… $receivedMb MB$totalMb',
            ));
          },
          options: Options(receiveTimeout: const Duration(minutes: 5)),
        );

        controller.add(const PluginDownloadEvent(plugin: PluginType.warp, progress: 0.95, message: 'Launching Installer… Please accept UAC prompt.'));

        // Launch the MSI
        final result = await Process.start('msiexec', ['/i', msiPath], runInShell: true);
        
        // We do not wait for exit code because MSI installer handles itself asynchronously in some cases,
        // and we don't want to block the UI forever if the user leaves it open.
        // We'll mark it as 1.0 (done) so the UI can prompt the user to restart or check status.
        await Future.delayed(const Duration(seconds: 3));
        controller.add(const PluginDownloadEvent(plugin: PluginType.warp, progress: 1.0, message: 'Installer launched!'));
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          controller.add(const PluginDownloadEvent(plugin: PluginType.warp, progress: 0.0, message: 'Download stopped'));
        } else {
          controller.addError(e);
        }
      } finally {
        await controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _extractFfmpegFallback(String zipPath, File targetFile) async {
    final extractDir = p.join(binDir, '_ffmpeg_extract');
    try {
      await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Force -Path "$zipPath" -DestinationPath "$extractDir"'
      ], runInShell: true);

      final extracted = Directory(extractDir);
      if (await extracted.exists()) {
        await for (final entity in extracted.list(recursive: true)) {
          if (entity is File && entity.path.toLowerCase().endsWith('ffmpeg.exe')) {
            await entity.copy(targetFile.path);
            break;
          }
        }
        await extracted.delete(recursive: true);
      }
    } catch (_) {}
  }
}
