import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';
import 'platform_downloader_screen.dart';
import 'universal_downloader_screen.dart';
import 'supported_sites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();



  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleUrlInput(String url) {
    if (url.isEmpty) return;

    // First try to match known platforms
    String? matchedPlatform;
    for (final entry in platformRegistry.entries) {
      if (entry.value.isValidUrl(url)) {
        matchedPlatform = entry.key;
        break;
      }
    }

    // Check if it looks like any valid URL (http/https)
    final isUrl = url.startsWith('http://') || url.startsWith('https://');

    if (matchedPlatform != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => PlatformDownloaderScreen(
            platformName: matchedPlatform!,
            initialUrl: url,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 320),
        ),
      ).then((_) => _urlController.clear());
    } else if (isUrl) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        String host = uri.host;
        if (host.startsWith('www.')) host = host.substring(4);
        final parts = host.split('.');
        final platformName = parts.length >= 2 ? parts[parts.length - 2] : host;
        final capitalized = platformName.isNotEmpty ? platformName.substring(0, 1).toUpperCase() + platformName.substring(1) : 'Unknown';

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => PlatformDownloaderScreen(
              platformName: capitalized,
              initialUrl: url,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
              position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 320),
          ),
        ).then((_) => _urlController.clear());
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid URL (starting with http:// or https://)', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const SizedBox(height: 20),
              
              // ── Hero Logo & Title ─────────────────────────────────────
              // Pulsing glow ring behind the logo
              _ZylosHero().animate().scale(delay: 100.ms, begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
              
              const SizedBox(height: 16),
              
              Text('Paste any video link below — we auto-detect the platform for you.', 
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6, fontSize: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

              const SizedBox(height: 48),

              // ── Input Field ────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder), 
                    width: _focusNode.hasFocus ? 2 : 1.5
                  ),
                  boxShadow: _focusNode.hasFocus 
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6))] 
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(children: [
                      const SizedBox(width: 20),
                      Icon(Icons.link_rounded, color: _focusNode.hasFocus ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          focusNode: _focusNode,
                          onSubmitted: _handleUrlInput,
                          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Paste video link here...',
                            hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontSize: 15),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                        ),
                      ),
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          onPressed: () => setState(() => _urlController.clear()),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          hoverColor: AppColors.primary.withValues(alpha: 0.15),
                          splashRadius: 20,
                          tooltip: 'Clear input',
                        )
                      else
                        IconButton(
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              setState(() {
                                _urlController.text = data.text!;
                              });
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded, size: 20),
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          hoverColor: AppColors.primary.withValues(alpha: 0.15),
                          splashRadius: 20,
                          tooltip: 'Paste link',
                        ),
                      const SizedBox(width: 8),
                    ]),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 16),

              // ── Detect Button (full width, no Paste Link) ─────────────
              GestureDetector(
                onTap: () => _handleUrlInput(_urlController.text.trim()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Detect & Download', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),


              const SizedBox(height: 60),

              // ── Supported Platforms ──────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SUPPORTED PLATFORMS', 
                        style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportedSitesScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('1700+ sites →', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 10,
                    children: platformRegistry.entries.map((e) {
                      final meta = e.value;
                      return GestureDetector(
                        onTap: () => Navigator.push(context, PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => PlatformDownloaderScreen(platformName: meta.name),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
                            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                          transitionDuration: const Duration(milliseconds: 320),
                        )),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: meta.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: meta.color.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(meta.icon, size: 14, color: meta.color),
                              const SizedBox(width: 6),
                              Text(meta.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: meta.color)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportedSitesScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          const Text('View all 1700+ supported sites', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 600.ms),

            ],
          ),
        ),
      ),
    );
  }
}


/// Zylos Hero: animated pulsing glow ring + logo
class _ZylosHero extends StatefulWidget {
  const _ZylosHero();

  @override
  State<_ZylosHero> createState() => _ZylosHeroState();
}

class _ZylosHeroState extends State<_ZylosHero> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.12).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.2, end: 0.55).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing glow
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: _opacity.value),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Zylos logo container (rounded rect with glowing shadow and perfectly fitted new logo)
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 36,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
