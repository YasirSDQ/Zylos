import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../features/downloader/presentation/providers/settings_provider.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> with TickerProviderStateMixin {
  String _warpStatus = 'Checking status...';
  String _networkName = '--';
  Timer? _statusTimer;
  
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    
    _checkStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await Process.run('warp-cli', ['status']);
      final out = res.stdout.toString().trim();
      
      if (!mounted) return;

      if (out.contains('Status update: Connected')) {
        if (_warpStatus != 'Protected') {
          setState(() {
            _warpStatus = 'Protected';
            _networkName = 'Cloudflare WARP';
          });
          if (mounted) context.read<SettingsProvider>().fetchIpInfo();
        }
      } else if (out.contains('Status update: Connecting')) {
        if (_warpStatus != 'Connecting...') {
          setState(() {
            _warpStatus = 'Connecting...';
          });
        }
      } else {
        if (_warpStatus != 'Unprotected' && _warpStatus != 'Checking status...') {
          setState(() {
            _warpStatus = 'Unprotected';
            _networkName = '--';
          });
          if (mounted) context.read<SettingsProvider>().fetchIpInfo();
        } else if (_warpStatus == 'Checking status...') {
          setState(() {
            _warpStatus = 'Unprotected';
            _networkName = '--';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _warpStatus = 'warp-cli not found';
        });
      }
    }
  }

  Color _getStatusColor(bool isConnected, bool isWorking) {
    if (_warpStatus == 'warp-cli not found') return AppColors.error;
    if (isWorking || _warpStatus == 'Connecting...') return AppColors.warning;
    if (isConnected || _warpStatus == 'Protected') return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final isWorking = provider.isConfiguringWarp;
    final isConnected = provider.useWarpProxy;
    final statusColor = _getStatusColor(isConnected, isWorking);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(isDark, statusColor),
              const SizedBox(height: 32),
              
              // IPs Section
              _buildIpSection(isDark, provider),
              
              const SizedBox(height: 32),
              _buildMainSwitch(isDark, isConnected, isWorking, provider, statusColor),
              
              const SizedBox(height: 40),
              
              // Mode Selector
              _buildModeSelector(isDark, provider),
              
              const SizedBox(height: 24),
              _buildInfoGrid(isDark, isConnected),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.brandGradient.createShader(b),
              child: const Text('VPN Proxy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 4),
            Text('Powered by Cloudflare WARP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          ],
        ).animate().fadeIn(delay: 50.ms).slideX(begin: -0.05),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6)])),
              const SizedBox(width: 8),
              Text(_warpStatus.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 1.2)),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
  
  Widget _buildIpSection(bool isDark, SettingsProvider provider) {
    final originalIp = provider.originalIpInfo;
    final protectedIp = provider.protectedIpInfo;
    
    return Row(
      children: [
        Expanded(
          child: _buildIpCard(
            isDark: isDark,
            title: 'Original IP',
            ip: (provider.isFetchingIp && !provider.useWarpProxy) ? 'Fetching...' : (originalIp?.ip ?? 'Unknown'),
            location: (provider.isFetchingIp && !provider.useWarpProxy) ? '--' : (originalIp != null ? '${originalIp.city}, ${originalIp.countryCode}' : '--'),
            icon: Icons.public_off_rounded,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildIpCard(
            isDark: isDark,
            title: 'Protected IP',
            ip: (provider.isFetchingIp && provider.useWarpProxy) ? 'Fetching...' : (protectedIp?.ip ?? (provider.useWarpProxy ? 'Waiting...' : '--')),
            location: (provider.isFetchingIp && provider.useWarpProxy) ? '--' : (protectedIp != null ? '${protectedIp.city}, ${protectedIp.countryCode}' : '--'),
            icon: Icons.shield_rounded,
            color: AppColors.success,
            isActive: provider.useWarpProxy,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1);
  }
  
  Widget _buildIpCard({
    required bool isDark,
    required String title,
    required String ip,
    required String location,
    required IconData icon,
    required Color color,
    bool isActive = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2)
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isActive ? color : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ip,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isActive ? color : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSwitch(bool isDark, bool isConnected, bool isWorking, SettingsProvider provider, Color statusColor) {
    return Center(
      child: GestureDetector(
        onTap: isWorking ? null : () {
          provider.setUseWarpProxy(!provider.useWarpProxy);
        },
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rings
              if (isConnected || isWorking)
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(260, 260),
                    painter: _PulsePainter(
                      color: statusColor,
                      progress: _pulseCtrl.value,
                    ),
                  ),
                ),
                
              if (isConnected || isWorking)
                AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, __) => Transform.rotate(
                    angle: _rotateCtrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(220, 220),
                      painter: _DashRingPainter(color: statusColor),
                    ),
                  ),
                ),

              // Main Button Body
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isConnected 
                        ? [AppColors.success, const Color(0xFF059669)]
                        : (isWorking 
                            ? [AppColors.warning, const Color(0xFFD97706)]
                            : (isDark ? [const Color(0xFF2A2A3C), const Color(0xFF1C1C28)] : [const Color(0xFFE5E7EB), const Color(0xFFD1D5DB)])),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    if (isConnected || isWorking)
                      BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10),
                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                  border: Border.all(
                    color: isConnected || isWorking 
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isWorking
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      : Icon(
                          Icons.power_settings_new_rounded,
                          size: 64,
                          color: isConnected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(delay: 200.ms, begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
    );
  }
  
  Widget _buildModeSelector(bool isDark, SettingsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connection Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                const SizedBox(height: 2),
                Text('Select how traffic is routed', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ],
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.warpMode,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, size: 20),
                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                items: const [
                  DropdownMenuItem(value: 'proxy', child: Text('Local proxy')),
                  DropdownMenuItem(value: 'warp', child: Text('Traffic and DNS (UDP)')),
                  DropdownMenuItem(value: 'doh', child: Text('DNS only (HTTPS)')),
                  DropdownMenuItem(value: 'dot', child: Text('DNS only (TLS)')),
                  DropdownMenuItem(value: 'warp+doh', child: Text('Traffic and DNS (HTTPS)')),
                  DropdownMenuItem(value: 'warp+dot', child: Text('Traffic and DNS (TLS)')),
                  DropdownMenuItem(value: 'tunnel_only', child: Text('Traffic only')),
                ],
                onChanged: provider.isConfiguringWarp ? null : (v) {
                  if (v != null) provider.setWarpMode(v);
                },
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1);
  }

  Widget _buildInfoGrid(bool isDark, bool isConnected) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoTile(
            isDark,
            icon: Icons.router_rounded,
            title: 'Protocol',
            value: isConnected ? 'WireGuard' : '--',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoTile(
            isDark,
            icon: Icons.public_rounded,
            title: 'Network',
            value: _networkName,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildInfoTile(bool isDark, {required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  final Color color;
  final double progress;
  _PulsePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    
    final p1 = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.15)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(c, 80 + (maxR - 80) * progress, p1);
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => progress != oldDelegate.progress || color != oldDelegate.color;
}

class _DashRingPainter extends CustomPainter {
  final Color color;
  _DashRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashCount = 24;
    const dashLength = math.pi * 2 / dashCount * 0.5;
    const gapLength = math.pi * 2 / dashCount * 0.5;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashLength + gapLength);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashRingPainter oldDelegate) => color != oldDelegate.color;
}
