import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../../../../app/theme/app_colors.dart';

class _IpInfo {
  final String ip, country, countryCode, city, isp;
  const _IpInfo({required this.ip, required this.country, required this.countryCode, required this.city, required this.isp});
  String get flag {
    if (countryCode.length != 2) return '🌐';
    final b = 0x1F1E6 - 0x41;
    return String.fromCharCodes(countryCode.toUpperCase().codeUnits.map((c) => b + c));
  }
}

enum _Phase { idle, ping, download, upload, done }

class _TestResult {
  final double pingMs, downloadMbps, uploadMbps;
  const _TestResult({required this.pingMs, required this.downloadMbps, required this.uploadMbps});
  String get quality {
    final avg = (downloadMbps + uploadMbps) / 2;
    if (avg >= 100) return 'Excellent';
    if (avg >= 50)  return 'Very Good';
    if (avg >= 25)  return 'Good';
    if (avg >= 10)  return 'Fair';
    if (avg >= 5)   return 'Weak';
    return 'Poor';
  }
  Color get qColor {
    final avg = (downloadMbps + uploadMbps) / 2;
    if (avg >= 100) return const Color(0xFF10B981);
    if (avg >= 50)  return const Color(0xFF3B82F6);
    if (avg >= 25)  return const Color(0xFF8B5CF6);
    if (avg >= 10)  return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
  int get qualityScore {
    final avg = (downloadMbps + uploadMbps) / 2;
    if (avg >= 100) return 98;
    if (avg >= 50)  return 82;
    if (avg >= 25)  return 65;
    if (avg >= 10)  return 48;
    if (avg >= 5)   return 30;
    return 15;
  }
}

Color _speedColor(double mbps) {
  if (mbps >= 100) return const Color(0xFF10B981);
  if (mbps >= 50)  return const Color(0xFF3B82F6);
  if (mbps >= 25)  return const Color(0xFF8B5CF6);
  if (mbps >= 10)  return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

Color _pingColor(double ms) {
  if (ms <= 20)  return const Color(0xFF10B981);
  if (ms <= 50)  return const Color(0xFF3B82F6);
  if (ms <= 100) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}
class SpeedTesterScreen extends StatefulWidget {
  const SpeedTesterScreen({super.key});
  @override
  State<SpeedTesterScreen> createState() => _SpeedTesterScreenState();
}

class _SpeedTesterScreenState extends State<SpeedTesterScreen> with TickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  _TestResult? _result;
  _IpInfo? _ipInfo;
  bool _fetchingIp = false;
  double _liveSpeed = 0, _progress = 0, _pingMs = 0, _downloadMbps = 0, _uploadMbps = 0;
  bool _showingDownload = true;
  late AnimationController _pulseCtrl, _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIp());
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _rotateCtrl.dispose(); super.dispose(); }

  Future<void> _fetchIp() async {
    if (!mounted) return;
    setState(() => _fetchingIp = true);
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json/?fields=status,country,countryCode,city,isp,query')).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        if (d['status'] == 'success') setState(() { _ipInfo = _IpInfo(ip: d['query'] ?? '', country: d['country'] ?? '', countryCode: d['countryCode'] ?? '', city: d['city'] ?? '', isp: d['isp'] ?? ''); });
      }
    } catch (_) {}
    if (mounted) setState(() => _fetchingIp = false);
  }

  Future<void> _startTest() async {
    if (_phase == _Phase.ping || _phase == _Phase.download || _phase == _Phase.upload) return;
    setState(() { _phase = _Phase.ping; _result = null; _liveSpeed = 0; _progress = 0; _pingMs = 0; _downloadMbps = 0; _uploadMbps = 0; _showingDownload = true; });
    _fetchIp();

    // Ping
    double best = 9999;
    for (int i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      try { await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=1')).timeout(const Duration(seconds: 5)); sw.stop(); if (sw.elapsedMilliseconds < best) best = sw.elapsedMilliseconds.toDouble(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    setState(() { _pingMs = best == 9999 ? 0 : best; _phase = _Phase.download; _liveSpeed = 0; _progress = 0; });

    // Download 10 MB
    const dlTotal = 10 * 1024 * 1024;
    int dlReceived = 0;
    final dlSw = Stopwatch()..start();
    try {
      final req = http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=$dlTotal'));
      final streamed = await http.Client().send(req).timeout(const Duration(seconds: 40));
      await for (final chunk in streamed.stream) {
        dlReceived += chunk.length;
        final secs = dlSw.elapsedMilliseconds / 1000.0;
        if (secs > 0 && mounted) setState(() { _liveSpeed = (dlReceived * 8) / (secs * 1024 * 1024); _progress = (dlReceived / dlTotal).clamp(0.0, 1.0); });
      }
    } catch (_) {}
    dlSw.stop();
    final dlSecs = dlSw.elapsedMilliseconds / 1000.0;
    final dlMbps = dlSecs > 0 && dlReceived > 0 ? (dlReceived * 8) / (dlSecs * 1024 * 1024) : 0.0;
    if (!mounted) return;
    setState(() { _downloadMbps = dlMbps; _phase = _Phase.upload; _liveSpeed = 0; _progress = 0; _showingDownload = false; });

    // Upload 5 MB
    const ulTotal = 5 * 1024 * 1024;
    final ulData = List<int>.generate(ulTotal, (i) => i & 0xFF);
    int ulSent = 0;
    final ulSw = Stopwatch()..start();
    try {
      final req = http.MultipartRequest('POST', Uri.parse('https://speed.cloudflare.com/__up'));
      req.files.add(http.MultipartFile.fromBytes('file', ulData, filename: 'test.bin'));
      final streamed = await req.send().timeout(const Duration(seconds: 40));
      ulSent = ulTotal;
      await streamed.stream.drain();
    } catch (_) {}
    ulSw.stop();
    final ulSecs = ulSw.elapsedMilliseconds / 1000.0;
    final ulMbps = ulSecs > 0 && ulSent > 0 ? (ulSent * 8) / (ulSecs * 1024 * 1024) : 0.0;

    if (mounted) {
      for (int i = 0; i <= 100; i++) {
        if (!mounted) break;
        setState(() { _progress = i / 100.0; _liveSpeed = ulMbps * (i / 100.0); });
        await Future.delayed(const Duration(milliseconds: 8));
      }
      setState(() { _uploadMbps = ulMbps; _result = _TestResult(pingMs: _pingMs, downloadMbps: dlMbps, uploadMbps: ulMbps); _phase = _Phase.done; _progress = 1; _liveSpeed = dlMbps; _showingDownload = true; });
    }
  }

  void _reset() => setState(() { _phase = _Phase.idle; _result = null; _liveSpeed = 0; _progress = 0; _downloadMbps = 0; _uploadMbps = 0; _showingDownload = true; });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(isDark),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: Column(children: [
          _buildIpCard(isDark), const SizedBox(height: 16),
          _buildGauge(isDark),  const SizedBox(height: 16),
          _buildMetrics(isDark),const SizedBox(height: 16),
          _buildSteps(isDark),  const SizedBox(height: 16),
          _buildButton(isDark),
          if (_result != null) ...[const SizedBox(height: 20), _buildScore(isDark), const SizedBox(height: 16), _buildSummary(isDark)],
        ]),
      )),
    );
  }

  AppBar _buildAppBar(bool isDark) => AppBar(
    backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg, elevation: 0,
    leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), onPressed: () => Navigator.of(context).pop()),
    title: Row(children: [
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: const Icon(Icons.speed_rounded, color: Colors.white, size: 18)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ShaderMask(shaderCallback: (b) => AppColors.brandGradient.createShader(b), child: const Text('Internet Speed Test', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white))),
        Text('Ping · Download · Upload', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
      ]),
    ]),
  );

  Widget _buildIpCard(bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
    child: _fetchingIp
        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)), const SizedBox(width: 10), Text('Detecting IP…', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))])
        : _ipInfo == null
            ? Row(children: [Icon(Icons.wifi_off_rounded, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, size: 16), const SizedBox(width: 8), Expanded(child: Text('Could not detect IP', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))), GestureDetector(onTap: _fetchIp, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(8)), child: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))))])
            : Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.15))), child: Center(child: Text(_ipInfo!.flag, style: const TextStyle(fontSize: 20)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Flexible(child: Text(_ipInfo!.ip, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)), const SizedBox(width: 6), GestureDetector(onTap: _fetchIp, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.refresh_rounded, size: 12, color: AppColors.primary)))]),
                  const SizedBox(height: 2),
                  Text('${_ipInfo!.city}, ${_ipInfo!.country}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)), child: Text(_ipInfo!.isp.length > 20 ? '${_ipInfo!.isp.substring(0, 18)}…' : _ipInfo!.isp, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  const SizedBox(height: 4),
                  Text(_ipInfo!.countryCode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ]),
              ]),
  ).animate().fadeIn(delay: 80.ms);
  Widget _buildGauge(bool isDark) {
    final isRunning = _phase == _Phase.ping || _phase == _Phase.download || _phase == _Phase.upload;
    final displaySpeed = _phase == _Phase.done ? (_showingDownload ? _downloadMbps : _uploadMbps) : _liveSpeed;
    final displayColor = _speedColor(displaySpeed);
    final gaugeValue = (displaySpeed / 200.0).clamp(0.0, 1.0);
    final phaseLabel = _phase == _Phase.ping ? 'PING' : _phase == _Phase.download ? 'DOWNLOAD' : _phase == _Phase.upload ? 'UPLOAD' : _phase == _Phase.done ? (_showingDownload ? 'DOWNLOAD' : 'UPLOAD') : 'READY';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: BorderRadius.circular(28), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(color: isRunning ? AppColors.primary.withValues(alpha: 0.12) : (isDark ? AppColors.darkBorder : AppColors.lightBorder), borderRadius: BorderRadius.circular(20), border: Border.all(color: isRunning ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isRunning) ...[AnimatedBuilder(animation: _pulseCtrl, builder: (context, child) => Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value), shape: BoxShape.circle))), const SizedBox(width: 6)],
            Text(phaseLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: isRunning ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(width: 260, height: 260, child: Stack(alignment: Alignment.center, children: [
          // Speed-reactive pulsating background rings
          if (isRunning && _phase != _Phase.ping) AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final scale = 1.0 + (_pulseCtrl.value * 0.2 * gaugeValue); // Pulse intensity based on speed
              final opacity = (1.0 - _pulseCtrl.value) * 0.4 * gaugeValue;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: displayColor.withValues(alpha: opacity), blurRadius: 40, spreadRadius: 10),
                      BoxShadow(color: displayColor.withValues(alpha: opacity * 0.5), blurRadius: 80, spreadRadius: 30),
                    ]
                  )
                ),
              );
            }
          ),
          
          CustomPaint(size: const Size(240, 240), painter: _ModernGaugePainter(value: gaugeValue, color: displayColor, isDark: isDark)),
          if (isRunning) AnimatedBuilder(animation: _rotateCtrl, builder: (context, child) => Transform.rotate(angle: _rotateCtrl.value * 2 * math.pi, child: CustomPaint(size: const Size(240, 240), painter: _SpinRingPainter(color: displayColor)))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            if (_phase == _Phase.ping)
              const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.info))
            else
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                tween: Tween<double>(begin: 0, end: displaySpeed),
                builder: (context, val, child) {
                  final formattedNum = val > 0 ? (val < 10 ? val.toStringAsFixed(2) : val.toStringAsFixed(1)) : '0';
                  return Text(formattedNum, style: TextStyle(fontSize: val > 0 ? 46 : 32, fontWeight: FontWeight.w900, color: _phase == _Phase.idle ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary) : displayColor, height: 1.0, letterSpacing: -1));
                }
              ),
            const SizedBox(height: 4),
            Text('Mbps', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, letterSpacing: 1.2)),
            if (_phase == _Phase.done && _result != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(color: _result!.qColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _result!.qColor.withValues(alpha: 0.3))), child: Text(_result!.quality, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _result!.qColor, letterSpacing: 0.5))),
            ],
          ]),
        ])),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['0', '50', '100', '150', '200+'].map((e) => Text(e, style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))).toList())),
        Text('Scale in Mbps', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        if (_phase == _Phase.done && _result != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _toggleBtn(isDark, true,  Icons.download_rounded, 'Download', '${_downloadMbps.toStringAsFixed(1)} Mbps'),
              _toggleBtn(isDark, false, Icons.upload_rounded,   'Upload',   '${_uploadMbps.toStringAsFixed(1)} Mbps'),
            ]),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: 120.ms).scale(begin: const Offset(0.97, 0.97));
  }

  Widget _toggleBtn(bool isDark, bool isDownload, IconData icon, String label, String value) {
    final active = _showingDownload == isDownload;
    final color = isDownload ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _showingDownload = isDownload),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: active ? (isDark ? AppColors.darkCard : AppColors.lightCard) : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? color : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: active ? color : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: active ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary) : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))),
          ]),
        ]),
      ),
    ));
  }

  Widget _buildMetrics(bool isDark) {
    final pingVal = _pingMs > 0 ? '${_pingMs.toStringAsFixed(0)} ms' : '--';
    final dlVal   = _downloadMbps > 0 ? _downloadMbps.toStringAsFixed(1) : (_liveSpeed > 0 && _phase == _Phase.download ? _liveSpeed.toStringAsFixed(1) : '--');
    final ulVal   = _uploadMbps > 0 ? _uploadMbps.toStringAsFixed(1) : (_liveSpeed > 0 && _phase == _Phase.upload ? _liveSpeed.toStringAsFixed(1) : '--');
    return Row(children: [
      Expanded(child: _MetricCard(icon: Icons.wifi_tethering_rounded, label: 'Ping',     value: pingVal, unit: '',     color: _pingMs > 0 ? _pingColor(_pingMs) : AppColors.info, isDark: isDark, delay: 0,   active: _phase == _Phase.ping)),
      const SizedBox(width: 10),
      Expanded(child: _MetricCard(icon: Icons.download_rounded,       label: 'Download', value: dlVal,   unit: 'Mbps', color: _speedColor(_downloadMbps > 0 ? _downloadMbps : _liveSpeed), isDark: isDark, delay: 60,  active: _phase == _Phase.download)),
      const SizedBox(width: 10),
      Expanded(child: _MetricCard(icon: Icons.upload_rounded,         label: 'Upload',   value: ulVal,   unit: 'Mbps', color: _speedColor(_uploadMbps > 0 ? _uploadMbps : (_phase == _Phase.upload ? _liveSpeed : 0)), isDark: isDark, delay: 120, active: _phase == _Phase.upload)),
    ]);
  }
  Widget _buildSteps(bool isDark) {
    final steps = [(_Phase.ping, Icons.network_ping_rounded, 'Ping'), (_Phase.download, Icons.download_rounded, 'Download'), (_Phase.upload, Icons.upload_rounded, 'Upload')];
    return Row(children: steps.asMap().entries.map((e) {
      final idx = e.key; final step = e.value;
      final isDone = _phase == _Phase.done || (_phase == _Phase.download && step.$1 == _Phase.ping) || (_phase == _Phase.upload && (step.$1 == _Phase.ping || step.$1 == _Phase.download));
      final isCurrent = _phase == step.$1;
      final col = isCurrent ? AppColors.primary : (isDone ? AppColors.success : (isDark ? AppColors.darkBorder : AppColors.lightBorder));
      return Expanded(child: Row(children: [
        Expanded(child: Column(children: [
          AnimatedContainer(duration: 300.ms, width: 36, height: 36, decoration: BoxDecoration(color: isCurrent ? AppColors.primary.withValues(alpha: 0.15) : (isDone ? AppColors.success.withValues(alpha: 0.12) : (isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder)), shape: BoxShape.circle, border: Border.all(color: col, width: isCurrent ? 2 : 1)), child: Center(child: isDone && !isCurrent ? const Icon(Icons.check_rounded, size: 16, color: AppColors.success) : Icon(step.$2, size: 16, color: isCurrent ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)))),
          const SizedBox(height: 6),
          Text(step.$3, style: TextStyle(fontSize: 10, fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500, color: isCurrent ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))),
        ])),
        if (idx < steps.length - 1) Container(height: 1.5, width: 30, color: isDone ? AppColors.success.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ]));
    }).toList());
  }

  Widget _buildButton(bool isDark) {
    final running = _phase == _Phase.ping || _phase == _Phase.download || _phase == _Phase.upload;
    return Column(children: [
      if (running && (_phase == _Phase.download || _phase == _Phase.upload)) ...[
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: _progress, minHeight: 5, backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder, valueColor: AlwaysStoppedAnimation(_phase == _Phase.download ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6))))),
          const SizedBox(width: 10),
          Text('${(_progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _phase == _Phase.download ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6))),
        ]),
        const SizedBox(height: 12),
      ],
      GestureDetector(
        onTap: running ? null : (_phase == _Phase.done ? _reset : _startTest),
        child: AnimatedContainer(
          duration: 250.ms, height: 56,
          decoration: BoxDecoration(gradient: running ? null : AppColors.brandGradient, color: running ? (isDark ? AppColors.darkBorder : AppColors.lightBorder.withValues(alpha: 0.6)) : null, borderRadius: BorderRadius.circular(16), boxShadow: running ? null : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)), BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 16))]),
          alignment: Alignment.center,
          child: running
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)), const SizedBox(width: 12), Text(_phase == _Phase.ping ? 'Measuring Latency…' : _phase == _Phase.download ? 'Testing Download…' : 'Testing Upload…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))])
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_phase == _Phase.done ? Icons.refresh_rounded : Icons.speed_rounded, color: Colors.white, size: 20), const SizedBox(width: 10), Text(_phase == _Phase.done ? 'Run Again' : 'Start Speed Test', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3))]),
        ),
      ),
    ]);
  }

  Widget _buildScore(bool isDark) {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [r.qColor.withValues(alpha: isDark ? 0.15 : 0.08), r.qColor.withValues(alpha: isDark ? 0.05 : 0.02)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: r.qColor.withValues(alpha: 0.25)), boxShadow: [BoxShadow(color: r.qColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Row(children: [
        SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(80, 80), painter: _ScoreRingPainter(score: r.qualityScore / 100.0, color: r.qColor)),
          Column(mainAxisSize: MainAxisSize.min, children: [Text('${r.qualityScore}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: r.qColor, height: 1)), Text('/ 100', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))]),
        ])),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Connection Quality', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(r.quality, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: r.qColor)),
          const SizedBox(height: 8),
          Row(children: [
            _mini(Icons.download_rounded,     r.downloadMbps.toStringAsFixed(1), 'DN', const Color(0xFF3B82F6), isDark),
            const SizedBox(width: 12),
            _mini(Icons.upload_rounded,       r.uploadMbps.toStringAsFixed(1),   'UP', const Color(0xFF8B5CF6), isDark),
            const SizedBox(width: 12),
            _mini(Icons.network_ping_rounded, r.pingMs.toStringAsFixed(0),       'ms', _pingColor(r.pingMs),    isDark),
          ]),
        ])),
      ]),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06);
  }

  Widget _mini(IconData icon, String val, String unit, Color color, bool isDark) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color), const SizedBox(width: 3),
    Text('$val ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
    Text(unit, style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
  ]);
  Widget _buildSummary(bool isDark) {
    final r = _result!;
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 14)), const SizedBox(width: 10), const Text('Test Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const Spacer(), Text('${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))]),
        const SizedBox(height: 16),
        _sh('SPEED', isDark), const SizedBox(height: 8),
        _sr(isDark, icon: Icons.download_rounded,       label: 'Download Speed', value: '${r.downloadMbps.toStringAsFixed(2)} Mbps', color: const Color(0xFF3B82F6)),
        _sr(isDark, icon: Icons.upload_rounded,         label: 'Upload Speed',   value: '${r.uploadMbps.toStringAsFixed(2)} Mbps',   color: const Color(0xFF8B5CF6)),
        _sr(isDark, icon: Icons.wifi_tethering_rounded, label: 'Latency (Ping)', value: '${r.pingMs.toStringAsFixed(0)} ms',          color: _pingColor(r.pingMs)),
        const SizedBox(height: 14),
        _sh('CONNECTION', isDark), const SizedBox(height: 8),
        if (_ipInfo != null) ...[
          _sr(isDark, icon: Icons.fingerprint_rounded, label: 'IP Address',   value: _ipInfo!.ip,                              color: AppColors.accent),
          _sr(isDark, icon: Icons.location_on_rounded, label: 'Location',     value: '${_ipInfo!.city}, ${_ipInfo!.country}',  color: AppColors.info),
          _sr(isDark, icon: Icons.business_rounded,    label: 'ISP / Network',value: _ipInfo!.isp,                             color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ],
        const SizedBox(height: 14),
        _sh('COMPATIBILITY', isDark), const SizedBox(height: 8),
        _compat(isDark, 'HD Video Streaming', 5,  r.downloadMbps),
        _compat(isDark, '4K / HDR Streaming', 25, r.downloadMbps),
        _compat(isDark, 'HD Video Calls',     10, r.downloadMbps),
        _compat(isDark, 'Cloud Gaming',       50, r.downloadMbps),
        _compat(isDark, 'Fast File Upload',   10, r.uploadMbps, upload: true),
      ]),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.06);
  }

  Widget _sh(String t, bool isDark) => Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary));

  Widget _sr(bool isDark, {required IconData icon, required String label, required String value, required Color color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 13, color: color)), const SizedBox(width: 10), Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))]),
  );

  Widget _compat(bool isDark, String label, double req, double actual, {bool upload = false}) {
    final ok = actual >= req;
    final okColor = ok ? AppColors.success : AppColors.error;
    final icon = upload ? Icons.upload_rounded : Icons.download_rounded;
    final iconColor = upload ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 13, color: iconColor)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)), Text('Requires ${req.toStringAsFixed(0)} Mbps', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: okColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 11, color: okColor), const SizedBox(width: 4), Text(ok ? 'Supported' : 'Insufficient', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: okColor))])),
      ]),
    );
  }
}
class _MetricCard extends StatelessWidget {
  final IconData icon; final String label, value, unit; final Color color; final bool isDark, active; final int delay;
  const _MetricCard({required this.icon, required this.label, required this.value, required this.unit, required this.color, required this.isDark, required this.active, required this.delay});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color.withValues(alpha: active ? (isDark ? 0.22 : 0.12) : (isDark ? 0.10 : 0.05)), color.withValues(alpha: active ? (isDark ? 0.08 : 0.04) : (isDark ? 0.02 : 0.01))], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: active ? 0.45 : 0.2), width: active ? 1.5 : 1),
      boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))] : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 13)), const SizedBox(width: 6), Flexible(child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary), overflow: TextOverflow.ellipsis))]),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    ]),
  ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.1);
}

class _ModernGaugePainter extends CustomPainter {
  final double value; final Color color; final bool isDark;
  _ModernGaugePainter({required this.value, required this.color, required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 20;
    const sa = math.pi * 0.75, sw = math.pi * 1.5;
    
    // Tick marks (inside the track)
    for (int i = 0; i <= 30; i++) {
      final a = sa + sw * (i / 30);
      final long = i % 5 == 0;
      final tickColor = (isDark ? Colors.white : Colors.black).withValues(alpha: long ? 0.15 : 0.05);
      
      canvas.drawLine(
        Offset(c.dx + (r - 28) * math.cos(a), c.dy + (r - 28) * math.sin(a)), 
        Offset(c.dx + (r - (long ? 38 : 34)) * math.cos(a), c.dy + (r - (long ? 38 : 34)) * math.sin(a)), 
        Paint()
          ..color = tickColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
      );
    }
    
    // Draw background track
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r), sa, sw, false, 
      Paint()
        ..color = isDark ? const Color(0xFF2A2146) : Colors.black.withValues(alpha: 0.05)
        ..strokeWidth = 24
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
    );

    // Dynamic sweeping gradient based on current speed value
    final gradientColors = const [Color(0xFF3B82F6), Color(0xFF8B3FD9), Color(0xFFEC4899)];
    final activeShader = SweepGradient(
      startAngle: sa, endAngle: sa + sw, 
      colors: gradientColors, 
      stops: const [0.0, 0.5, 1.0]
    ).createShader(Rect.fromCircle(center: c, radius: r));

    if (value > 0) {
      final activeSw = sw * value;
      
      // Outer glow for the neon effect
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), sa, activeSw, false, 
        Paint()
          ..shader = activeShader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
      );
      
      // The sharp main bar
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), sa, activeSw, false, 
        Paint()
          ..shader = activeShader
          ..strokeWidth = 24
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
      );

      // Needle at the end
      final ta = sa + activeSw;
      final tp = Offset(c.dx + r * math.cos(ta), c.dy + r * math.sin(ta));
      
      // Glow behind needle
      final glowColor = const Color(0xFF8B3FD9); // Purple-ish glow matches extension
      canvas.drawCircle(tp, 24, Paint()..color = glowColor.withValues(alpha: 0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
      
      // Needle body
      canvas.drawCircle(tp, 8, Paint()..color = Colors.white);
      canvas.drawCircle(tp, 3, Paint()..color = glowColor);
    }
  }
  @override bool shouldRepaint(_ModernGaugePainter o) => o.value != value || o.color != color || o.isDark != isDark;
}

class _SpinRingPainter extends CustomPainter {
  final Color color;
  _SpinRingPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final glowColor = const Color(0xFFEC4899);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r), 
      0, math.pi * 0.4, false, 
      Paint()
        ..shader = SweepGradient(colors: [glowColor.withValues(alpha: 0.0), glowColor.withValues(alpha: 0.5)]).createShader(Rect.fromCircle(center: c, radius: r))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
    );
  }
  @override bool shouldRepaint(_SpinRingPainter o) => false;
}

class _ScoreRingPainter extends CustomPainter {
  final double score; final Color color;
  _ScoreRingPainter({required this.score, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 7);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * score, false, Paint()..color = color..strokeWidth = 7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_ScoreRingPainter o) => o.score != score || o.color != color;
}
