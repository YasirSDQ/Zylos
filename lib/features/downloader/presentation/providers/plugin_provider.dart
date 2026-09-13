import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/plugin_service.dart';

enum PluginSetupStatus { checking, ready, downloading, error }

class PluginProvider extends ChangeNotifier {
  final PluginService _service;
  PluginService get service => _service;

  PluginSetupStatus _status = PluginSetupStatus.checking;
  PluginSetupStatus get status => _status;

  // Per-plugin state
  bool _ffmpegInstalled = false;
  bool _ytDlpInstalled = false;
  bool _warpInstalled = false;

  bool get ffmpegInstalled => _ffmpegInstalled;
  bool get ytDlpInstalled => _ytDlpInstalled;
  bool get warpInstalled => _warpInstalled;
  bool get allPluginsReady => _ffmpegInstalled && _ytDlpInstalled;

  // Version info
  String? _ffmpegVersion;
  String? _ytDlpVersion;
  String? get ffmpegVersion => _ffmpegVersion;
  String? get ytDlpVersion => _ytDlpVersion;

  bool _ffmpegUpdateAvailable = false;
  bool _ytDlpUpdateAvailable = false;
  bool get ffmpegUpdateAvailable => _ffmpegUpdateAvailable;
  bool get ytDlpUpdateAvailable => _ytDlpUpdateAvailable;

  // Progress while downloading
  String _currentMessage = '';
  String get currentMessage => _currentMessage;

  double _ffmpegProgress = 0;
  double _ytDlpProgress  = 0;
  double _warpProgress   = 0;

  double get ffmpegProgress => _ffmpegProgress;
  double get ytDlpProgress  => _ytDlpProgress;
  double get warpProgress   => _warpProgress;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Throttle: last time we called notifyListeners() during a stream
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _notifyThrottle = Duration(milliseconds: 120);

  PluginProvider(this._service) {
    _checkPlugins().then((_) {
      if (!allPluginsReady && _status != PluginSetupStatus.downloading) {
        downloadMissingPlugins();
      } else if (allPluginsReady) {
        // Silently update yt-dlp in background after check completes
        _service.autoUpdateYtDlp().then((_) {
          // Re-read version after update
          _service.getLocalVersion(PluginType.ytDlp).then((v) {
            if (v != null && v != _ytDlpVersion) {
              _ytDlpVersion = v;
              notifyListeners();
            }
          });
        });
      }
    });
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Checks if both plugins are installed. If not, starts download automatically.
  Future<void> checkAndEnsurePlugins() async {
    if (_status == PluginSetupStatus.downloading) return;
    await _checkPlugins();
    if (!allPluginsReady) {
      await downloadMissingPlugins();
    }
  }

  /// Checks the current status without downloading.
  Future<void> refreshStatus() async {
    if (_status == PluginSetupStatus.downloading) return;
    await _checkPlugins();
    await checkForUpdates();
  }

  /// Checks for remote updates.
  Future<void> checkForUpdates() async {
    if (_status == PluginSetupStatus.downloading) return;

    // Always clear remote version cache so we fetch fresh data from GitHub
    _service.clearRemoteVersionCache();

    final remoteFfmpeg = await _service.getLatestRemoteVersion(PluginType.ffmpeg);
    final remoteYtDlp = await _service.getLatestRemoteVersion(PluginType.ytDlp);

    debugPrint('[UpdateCheck] Local FFmpeg: $_ffmpegVersion  Remote: $remoteFfmpeg');
    debugPrint('[UpdateCheck] Local yt-dlp: $_ytDlpVersion  Remote: $remoteYtDlp');

    if (remoteFfmpeg != null && _ffmpegVersion != null) {
      // Extract 8-digit date from both strings for comparison
      final localDate  = _extractBuildDate(_ffmpegVersion!);
      final remoteDate = _extractBuildDate(remoteFfmpeg);
      if (localDate != null && remoteDate != null) {
        _ffmpegUpdateAvailable = remoteDate.compareTo(localDate) > 0;
      } else {
        _ffmpegUpdateAvailable = !_ffmpegVersion!.contains(remoteFfmpeg);
      }
    }

    if (remoteYtDlp != null && _ytDlpVersion != null) {
      // yt-dlp local: "2026.08.29.232305", remote tag: "2026.08.30.232305" etc.
      _ytDlpUpdateAvailable = remoteYtDlp.trim() != _ytDlpVersion!.trim();
    }

    debugPrint('[UpdateCheck] ffmpegUpdate=$_ffmpegUpdateAvailable  ytDlpUpdate=$_ytDlpUpdateAvailable');
    notifyListeners();
  }

  /// Extracts an 8-digit build date (YYYYMMDD) from a version string.
  /// Works for both "N-128262-g...-20260824" and "20260824" formats.
  String? _extractBuildDate(String version) {
    final match = RegExp(r'(\d{8})').firstMatch(version);
    return match?.group(1);
  }

  /// Immediately downloads any missing plugins.
  Future<void> downloadMissingPlugins() async {
    if (_status == PluginSetupStatus.downloading) return;
    _status = PluginSetupStatus.downloading;
    _errorMessage = null;
    _currentMessage = 'Preparing plugins…';
    _ffmpegProgress = 0;
    _ytDlpProgress = 0;
    notifyListeners();

    try {
      await for (final event in _service.ensurePlugins()) {
        if (_status != PluginSetupStatus.downloading) break; // User cancelled
        
        _currentMessage = event.message;
        if (event.plugin == PluginType.ffmpeg) {
          // Monotonic guard: only update if progress is higher
          if (event.progress > _ffmpegProgress) _ffmpegProgress = event.progress;
          if (event.progress >= 1.0) _ffmpegInstalled = true;
        } else {
          if (event.progress > _ytDlpProgress) _ytDlpProgress = event.progress;
          if (event.progress >= 1.0) _ytDlpInstalled = true;
        }
        _throttledNotify();
      }

      await _finalSync();
    } catch (e) {
      if (_status == PluginSetupStatus.downloading) {
        _status = PluginSetupStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    }
    notifyListeners();
  }

  /// Force re-download of a single plugin.
  Future<void> reinstallPlugin(PluginType plugin) async {
    if (_status == PluginSetupStatus.downloading) return;
    _status = PluginSetupStatus.downloading;
    _errorMessage = null;
    if (plugin == PluginType.ffmpeg) {
      _ffmpegProgress = 0;
    } else {
      _ytDlpProgress = 0;
    }
    _currentMessage = 'Downloading ${plugin == PluginType.ffmpeg ? 'FFmpeg' : 'yt-dlp'}…';
    notifyListeners();

    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', 'yt-dlp.exe']);
      }
      await for (final event in _service.redownloadPlugin(plugin)) {
        if (_status != PluginSetupStatus.downloading) break;
        
        _currentMessage = event.message;
        if (event.plugin == PluginType.ffmpeg) {
          if (event.progress > _ffmpegProgress) _ffmpegProgress = event.progress;
          if (event.progress >= 1.0) _ffmpegInstalled = true;
        } else {
          if (event.progress > _ytDlpProgress) _ytDlpProgress = event.progress;
          if (event.progress >= 1.0) _ytDlpInstalled = true;
        }
        _throttledNotify();
      }
      await _finalSync();
    } catch (e) {
      if (_status == PluginSetupStatus.downloading) {
        _status = PluginSetupStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    }
    notifyListeners();
  }

  /// Download all 3 yt-dlp channels (stable, master, nightly) sequentially
  Future<void> downloadAllYtDlpChannels() async {
    if (_status == PluginSetupStatus.downloading) return;
    _status = PluginSetupStatus.downloading;
    _errorMessage = null;
    _ytDlpProgress = 0;
    _currentMessage = 'Downloading all yt-dlp versions…';
    notifyListeners();

    try {
      await for (final event in _service.downloadAllYtDlpChannels()) {
        if (_status != PluginSetupStatus.downloading) break;
        
        _currentMessage = event.message;
        if (event.progress > _ytDlpProgress) _ytDlpProgress = event.progress;
        if (event.progress >= 1.0) _ytDlpInstalled = true;
        _throttledNotify();
      }
      await _finalSync();
    } catch (e) {
      if (_status == PluginSetupStatus.downloading) {
        _status = PluginSetupStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    }
    notifyListeners();
  }

  /// Download and run the Cloudflare WARP installer.
  Future<void> installWarp() async {
    if (_status == PluginSetupStatus.downloading) return;
    _status = PluginSetupStatus.downloading;
    _errorMessage = null;
    _warpProgress = 0;
    _currentMessage = 'Downloading Cloudflare WARP…';
    notifyListeners();

    try {
      await for (final event in _service.downloadWarp()) {
        if (_status != PluginSetupStatus.downloading) break;
        
        _currentMessage = event.message;
        if (event.progress > _warpProgress) _warpProgress = event.progress;
        _throttledNotify();
      }
      await _finalSync();
    } catch (e) {
      if (_status == PluginSetupStatus.downloading) {
        _status = PluginSetupStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
    }
    notifyListeners();
  }

  /// Stop any active download.
  void stopDownload() {
    if (_status == PluginSetupStatus.downloading) {
      _service.cancelDownload();
      _status = PluginSetupStatus.error;
      _errorMessage = 'Download stopped by user.';
      notifyListeners();
    }
  }

  /// Set a manually-chosen executable path for a plugin.
  Future<bool> setManualPluginPath(PluginType plugin, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      _errorMessage = 'File not found: $sourcePath';
      notifyListeners();
      return false;
    }

    final target = plugin == PluginType.ffmpeg
        ? File(PluginService.ffmpegExePath)
        : File(PluginService.ytDlpExePath);

    try {
      final dir = Directory(PluginService.binDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      await source.copy(target.path);
      _errorMessage = null;
      // Clear BOTH path and version cache so the new binary is fully re-read
      _service.clearCache(plugin);
      if (plugin == PluginType.ffmpeg) {
        _ffmpegVersion = null;
      } else {
        _ytDlpVersion = null;
      }
      await _checkPlugins(); // Re-reads installed status + versions
      return true;
    } catch (e) {
      _errorMessage = 'Failed to import: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) >= _notifyThrottle) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  Future<void> _finalSync() async {
    final statuses = await _service.checkAllPlugins();
    _ffmpegInstalled = statuses[PluginType.ffmpeg] ?? false;
    _ytDlpInstalled  = statuses[PluginType.ytDlp]  ?? false;
    _warpInstalled = await File(r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe').exists();
    _status = allPluginsReady ? PluginSetupStatus.ready : PluginSetupStatus.error;
  }

  Future<void> _checkPlugins() async {
    if (_status == PluginSetupStatus.downloading) return;
    _status = PluginSetupStatus.checking;
    notifyListeners();

    final statuses = await _service.checkAllPlugins();
    _ffmpegInstalled = statuses[PluginType.ffmpeg] ?? false;
    _ytDlpInstalled  = statuses[PluginType.ytDlp]  ?? false;
    _warpInstalled = await File(r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe').exists();

    // Fetch local versions
    if (_ffmpegInstalled) _ffmpegVersion = await _service.getLocalVersion(PluginType.ffmpeg);
    if (_ytDlpInstalled) _ytDlpVersion = await _service.getLocalVersion(PluginType.ytDlp);

    _status = allPluginsReady ? PluginSetupStatus.ready : PluginSetupStatus.error;
    notifyListeners();
  }
}
