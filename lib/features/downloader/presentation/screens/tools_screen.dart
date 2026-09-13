import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'converter_screen.dart';
import 'speed_tester_screen.dart';
import 'plugin_manager_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Power Tools',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 8),
              Text(
                'Everything you need to manage and optimize your media.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
              
              const SizedBox(height: 40),

              // Video Downloader Card (Redirects to Home tab)
              _ToolCard(
                title: 'Video Downloader',
                description: 'Download videos and audio from dozens of platforms in native high quality.',
                icon: Icons.download_rounded,
                color: AppColors.primary,
                isDark: isDark,
                onTap: () {
                  context.read<NavigationProvider>().setTab(0);
                },
                delayMs: 200,
              ),

              const SizedBox(height: 20),

              // Converter Card
              _ToolCard(
                title: 'Format Converter',
                description: 'Convert local videos to audio, compress files, and change formats instantly.',
                icon: Icons.transform_rounded,
                color: const Color(0xFFE56A54),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ConverterScreen()));
                },
                delayMs: 300,
              ),

              const SizedBox(height: 20),

              // Speed Tester Card
              _ToolCard(
                title: 'Speed Tester',
                description: 'Check your real-time internet connection to ensure the fastest downloads.',
                icon: Icons.speed_rounded,
                color: const Color(0xFF19B7EA),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedTesterScreen()));
                },
                delayMs: 400,
              ),

              const SizedBox(height: 20),

              // Plugin Manager Card
              _ToolCard(
                title: 'Plugin Manager',
                description: 'Install, update, or repair FFmpeg and yt-dlp — the engines that power Zylos.',
                icon: Icons.extension_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginManagerScreen()));
                },
                delayMs: 500,
              ),

            ],
          ),
        ),
      ),
    );
  }
}


class _ToolCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final int delayMs;

  const _ToolCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    required this.delayMs,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isHovered ? widget.color.withOpacity(0.5) : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: widget.color.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 12))]
                : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 28, color: widget.color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isHovered ? widget.color : widget.color.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: _isHovered ? Colors.white : widget.color,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: widget.delayMs)).slideY(begin: 0.2),
    );
  }
}
