import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../../../core/services/queue_manager.dart';
import '../../../../core/services/local_server.dart';


class IpInfo {
  final String ip;
  final String country;
  final String countryCode;
  final String city;
  final String isp;

  const IpInfo({required this.ip, required this.country, required this.countryCode, required this.city, required this.isp});

  factory IpInfo.fromJson(Map<String, dynamic> json) {
    return IpInfo(
      ip: json['ip'] ?? '',
      country: json['country'] ?? '',
      countryCode: json['countryCode'] ?? '',
      city: json['city'] ?? '',
      isp: json['isp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'country': country,
      'countryCode': countryCode,
      'city': city,
      'isp': isp,
    };
  }

  String get flagEmoji {
    if (countryCode.length != 2) return '🌐';
    final base = 0x1F1E6 - 0x41;
    final chars = countryCode.toUpperCase().codeUnits;
    return String.fromCharCodes(chars.map((c) => base + c));
  }
}

class SpeedTestResult {
  final double pingMs;
  final double downloadMbps;
  final DateTime timestamp;

  const SpeedTestResult({
    required this.pingMs,
    required this.downloadMbps,
    required this.timestamp,
  });

  String get quality {
    if (downloadMbps >= 100) return 'Excellent';
    if (downloadMbps >= 25) return 'Very Good';
    if (downloadMbps >= 10) return 'Good';
    if (downloadMbps >= 5) return 'Fair';
    return 'Poor';
  }

  Color get qualityColor {
    if (downloadMbps >= 100) return const Color(0xFF10B981);
    if (downloadMbps >= 25) return const Color(0xFF3B82F6);
    if (downloadMbps >= 10) return const Color(0xFF8B5CF6);
    if (downloadMbps >= 5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class SettingsProvider extends ChangeNotifier {
  final Box _box;
  final QueueManager _queueManager;

  SettingsProvider(this._box, this._queueManager) {
    _isDarkTheme = _box.get('darkTheme', defaultValue: true);
    
    final maxConcurrent = _box.get('maxConcurrentTasks', defaultValue: 3);
    _queueManager.maxConcurrentTasks = maxConcurrent;
    _converterMaxConcurrent = _box.get('converterMaxConcurrent', defaultValue: 2);

    _animationScale = _box.get('animationScale', defaultValue: 0.6);
    timeDilation = _animationScale == 0.0 ? 0.001 : _animationScale;
    _serverPort = _box.get('serverPort', defaultValue: 7734);
    
    _ytdlpReleaseChannel = _box.get('ytdlpReleaseChannel', defaultValue: 'master');
    
    _useWarpProxy = _box.get('useWarpProxy', defaultValue: false);
    _warpMode = _box.get('warpMode', defaultValue: 'proxy');
    
    final savedOriginalIp = _box.get('originalIpInfo');
    if (savedOriginalIp != null) {
      try {
        _originalIpInfo = IpInfo.fromJson(Map<String, dynamic>.from(jsonDecode(savedOriginalIp)));
      } catch (_) {}
    }
    
    SchedulerBinding.instance.addPostFrameCallback((_) => fetchIpInfo());
  }

  late bool _isDarkTheme;
  bool get isDarkTheme => _isDarkTheme;

  late double _animationScale;
  double get animationScale => _animationScale;

  int get maxConcurrentTasks => _queueManager.maxConcurrentTasks;

  late int _converterMaxConcurrent;
  int get converterMaxConcurrent => _converterMaxConcurrent;

  String? get currentDownloadPath => _box.get('downloadPath') as String?;

  void setDownloadPath(String path) {
    _box.put('downloadPath', path);
    notifyListeners();
  }

  void toggleTheme(bool value) {
    _isDarkTheme = value;
    _box.put('darkTheme', value);
    notifyListeners();
  }

  void setMaxConcurrentTasks(int value) {
    _queueManager.maxConcurrentTasks = value;
    _box.put('maxConcurrentTasks', value);
    notifyListeners();
  }

  void setConverterMaxConcurrent(int value) {
    _converterMaxConcurrent = value;
    _box.put('converterMaxConcurrent', value);
    notifyListeners();
  }

  void setAnimationScale(double value) {
    _animationScale = value;
    _box.put('animationScale', value);
    timeDilation = value == 0.0 ? 0.001 : value;
    notifyListeners();
  }

  // ── yt-dlp Channel ────────────────────────────────────────────────────────
  late String _ytdlpReleaseChannel;
  String get ytdlpReleaseChannel => _ytdlpReleaseChannel;

  void setYtdlpReleaseChannel(String channel) {
    _ytdlpReleaseChannel = channel;
    _box.put('ytdlpReleaseChannel', channel);
    notifyListeners();
  }

  // ── Server Port ──────────────────────────────────────────────────────────────
  late int _serverPort;
  int get serverPort => _serverPort;

  void setServerPort(int port) {
    _serverPort = port;
    _box.put('serverPort', port);
    LocalServer.restart(port);
    notifyListeners();
  }

  // ── WARP Proxy ──────────────────────────────────────────────────────────────
  late bool _useWarpProxy;
  bool get useWarpProxy => _useWarpProxy;

  late String _warpMode;
  String get warpMode => _warpMode;

  bool _isConfiguringWarp = false;
  bool get isConfiguringWarp => _isConfiguringWarp;

  Future<void> setUseWarpProxy(bool value) async {
    if (_useWarpProxy == value) return;
    _isConfiguringWarp = true;
    notifyListeners();

    try {
      final warpCliPath = r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe';
      if (await File(warpCliPath).exists()) {
        if (value) {
          // Enable selected mode and connect
          await Process.run(warpCliPath, ['mode', _warpMode], runInShell: true);
          await Process.run(warpCliPath, ['connect'], runInShell: true);
        } else {
          // Disable and revert to warp mode
          await Process.run(warpCliPath, ['disconnect'], runInShell: true);
          await Process.run(warpCliPath, ['mode', 'warp'], runInShell: true);
        }
      }
    } catch (_) {
      // Silently ignore errors (e.g. warp-cli not installed or requires elevation)
    }

    _useWarpProxy = value;
    _box.put('useWarpProxy', value);
    _isConfiguringWarp = false;
    notifyListeners();
  }

  Future<void> setWarpMode(String mode) async {
    if (_warpMode == mode) return;
    _warpMode = mode;
    _box.put('warpMode', mode);
    notifyListeners();
    
    // If currently enabled, re-apply the mode
    if (_useWarpProxy) {
      _isConfiguringWarp = true;
      notifyListeners();
      try {
        final warpCliPath = r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe';
        if (await File(warpCliPath).exists()) {
          await Process.run(warpCliPath, ['mode', _warpMode], runInShell: true);
        }
      } catch (_) {}
      _isConfiguringWarp = false;
      notifyListeners();
    }
  }

  // ── IP Info ─────────────────────────────────────────────────────────────────
  IpInfo? _ipInfo;
  IpInfo? get ipInfo => _ipInfo;

  IpInfo? _originalIpInfo;
  IpInfo? get originalIpInfo => _originalIpInfo;

  IpInfo? _protectedIpInfo;
  IpInfo? get protectedIpInfo => _protectedIpInfo;

  bool _isFetchingIp = false;
  bool get isFetchingIp => _isFetchingIp;

  Future<void> fetchIpInfo() async {
    if (_isFetchingIp) return;
    _isFetchingIp = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json/?fields=status,message,country,countryCode,city,isp,query&_t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          _ipInfo = IpInfo(
            ip: data['query'] ?? '',
            country: data['country'] ?? '',
            countryCode: data['countryCode'] ?? '',
            city: data['city'] ?? '',
            isp: data['isp'] ?? '',
          );
          
          if (_useWarpProxy) {
            _protectedIpInfo = _ipInfo;
          } else {
            _originalIpInfo = _ipInfo;
            _box.put('originalIpInfo', jsonEncode(_originalIpInfo!.toJson()));
          }
        }
      }
    } catch (_) {
      _ipInfo = null;
    } finally {
      _isFetchingIp = false;
      notifyListeners();
    }
  }

  // ── Speed Test Logic ─────────────────────────────────────────────────────────
  SpeedTestResult? _lastResult;
  SpeedTestResult? get lastResult => _lastResult;

  SpeedTestPhase _testPhase = SpeedTestPhase.idle;
  SpeedTestPhase get testPhase => _testPhase;

  double _liveSpeedMbps = 0.0;
  double get liveSpeedMbps => _liveSpeedMbps;

  double _testProgress = 0.0;
  double get testProgress => _testProgress;

  bool get isTestingSpeed => _testPhase != SpeedTestPhase.idle && _testPhase != SpeedTestPhase.done;

  Future<void> testConnectionSpeed() async {
    if (isTestingSpeed) return;

    _lastResult = null;
    _liveSpeedMbps = 0.0;
    _testProgress = 0.0;
    notifyListeners();

    try {
      // Phase 1: Ping / Latency
      _testPhase = SpeedTestPhase.ping;
      notifyListeners();

      final pingMs = await _measurePing();

      // Phase 2: Download Speed — stream 5MB file with live updates
      _testPhase = SpeedTestPhase.download;
      _testProgress = 0.0;
      notifyListeners();

      final downloadMbps = await _measureDownloadSpeed();

      _lastResult = SpeedTestResult(
        pingMs: pingMs,
        downloadMbps: downloadMbps,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      _lastResult = null;
    } finally {
      _testPhase = SpeedTestPhase.done;
      _testProgress = 1.0;
      notifyListeners();
    }
  }

  Future<double> _measurePing() async {
    final List<double> pings = [];
    for (int i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      try {
        await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1'))
            .timeout(const Duration(seconds: 5));
        sw.stop();
        pings.add(sw.elapsedMilliseconds.toDouble());
      } catch (_) {
        pings.add(999);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    pings.sort();
    return pings.first; // Best (lowest) ping
  }

  Future<double> _measureDownloadSpeed() async {
    // Download 5MB in chunks, tracking live speed
    const totalBytes = 5 * 1024 * 1024; // 5 MB
    final url = Uri.parse('https://speed.cloudflare.com/__down?bytes=$totalBytes');

    int receivedBytes = 0;
    final overallStopwatch = Stopwatch()..start();

    try {
      final request = http.Request('GET', url);
      final streamedResponse = await http.Client().send(request).timeout(const Duration(seconds: 30));

      await for (final chunk in streamedResponse.stream) {
        receivedBytes += chunk.length;
        final seconds = overallStopwatch.elapsedMilliseconds / 1000.0;
        if (seconds > 0) {
          _liveSpeedMbps = (receivedBytes * 8) / (seconds * 1024 * 1024);
          _testProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          notifyListeners();
        }
      }
    } catch (_) {}

    overallStopwatch.stop();
    final seconds = overallStopwatch.elapsedMilliseconds / 1000.0;
    if (seconds <= 0 || receivedBytes == 0) return 0.0;
    return (receivedBytes * 8) / (seconds * 1024 * 1024);
  }

  void resetSpeedTest() {
    _lastResult = null;
    _testPhase = SpeedTestPhase.idle;
    _liveSpeedMbps = 0.0;
    _testProgress = 0.0;
    notifyListeners();
  }
}

enum SpeedTestPhase { idle, ping, download, done }
