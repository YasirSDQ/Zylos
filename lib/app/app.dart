import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import '../features/downloader/presentation/screens/home_screen.dart';
import '../features/downloader/presentation/screens/download_screen.dart';
import '../features/downloader/presentation/screens/history_screen.dart';
import '../features/downloader/presentation/screens/speed_tester_screen.dart';
import '../features/downloader/presentation/screens/converter_manager_screen.dart';
import '../features/downloader/presentation/screens/plugin_manager_screen.dart';
import '../features/downloader/presentation/screens/supported_sites_screen.dart';
import '../features/downloader/presentation/screens/settings_screen.dart';
import '../features/vpn/presentation/screens/vpn_screen.dart';
import '../features/downloader/presentation/providers/settings_provider.dart';
import '../features/downloader/presentation/providers/navigation_provider.dart';
import '../features/downloader/presentation/providers/plugin_provider.dart';
import '../core/services/app_update_service.dart';
import '../main.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class YTDownloaderApp extends StatefulWidget {
  final bool isBackground;
  const YTDownloaderApp({super.key, this.isBackground = false});

  @override
  State<YTDownloaderApp> createState() => _YTDownloaderAppState();
}

class _YTDownloaderAppState extends State<YTDownloaderApp> with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      // Prevent default close — we intercept in onWindowClose
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  // ── WindowListener ────────────────────────────────────────────────────
  @override
  void onWindowClose() async {
    // Minimize to tray instead of quitting
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  // ── TrayListener ──────────────────────────────────────────────────────
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
    windowManager.setSkipTaskbar(false);
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') {
      windowManager.show();
      windowManager.focus();
      windowManager.setSkipTaskbar(false);
    } else if (menuItem.key == 'exit_app') {
      windowManager.setPreventClose(false);
      windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Zylos',
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getLightTheme(context),
          darkTheme: AppTheme.getDarkTheme(context),
          themeMode: settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
            if (!isDesktop || child == null) return child ?? const SizedBox();
            
            final isDark = settings.isDarkTheme;
            return Scaffold(
              backgroundColor: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    windowManager.startDragging();
                  },
                  child: WindowCaption(
                    brightness: isDark ? Brightness.dark : Brightness.light,
                    backgroundColor: Colors.transparent,
                    title: Row(
                      children: [
                        Image.asset('assets/images/logo.png', width: 18, height: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Zylos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'v3.0',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: child,
            );
          },
          home: const MainLayout(),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const DownloadScreen(),
    const HistoryScreen(),
    const SpeedTesterScreen(),
    const ConverterManagerScreen(),
    const VpnScreen(),
  ];

  bool _pluginCheckStarted = false;
  final _appUpdateService = AppUpdateService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pluginCheckStarted) {
      _pluginCheckStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runStartupFlow();
      });
    }
  }

  Future<void> _runStartupFlow() async {
    final settingsBox = Hive.box('settings');
    bool isFirstLaunch = settingsBox.get('isFirstLaunch', defaultValue: true);
    final pluginProvider = context.read<PluginProvider>();

    if (isFirstLaunch) {
      // 1. Plugins Check & Download Modal
      bool pluginsReady = pluginProvider.allPluginsReady;
      if (!pluginsReady) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildPluginSetupModal(),
        );
        await pluginProvider.checkAndEnsurePlugins();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); // Close plugin modal
        }
      }

      // 2. Extension Setup Modal
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildExtensionSetupModal(),
        );
      }
      
      await settingsBox.put('isFirstLaunch', false);
    } else {
      pluginProvider.checkAndEnsurePlugins();
    }
    
    _checkForAppUpdates();
  }

  Widget _buildPluginSetupModal() {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.downloading, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Downloading Required Plugins', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Zylos needs yt-dlp and ffmpeg to function properly. Please wait...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Consumer<PluginProvider>(
                builder: (context, provider, _) {
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: (provider.ffmpegProgress + provider.ytDlpProgress) / 200, // 0 to 1
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        color: AppColors.primary,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 12),
                      Text(provider.currentMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtensionSetupModal() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.extension, size: 32, color: AppColors.primary),
                SizedBox(width: 12),
                Text('Install Zylos Browser Extension', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('To seamlessly download videos from your browser, install the Zylos extension:'),
            const SizedBox(height: 12),
            const Text('1. Click "Open Extension Folder" below to open the directory.'),
            const Text('2. Go to chrome://extensions in your Chrome/Edge browser.'),
            const Text('3. Enable "Developer mode" in the top right corner.'),
            const Text('4. Drag and drop the "zylos_extension" folder into the browser window.'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final String exeDir = p.dirname(Platform.resolvedExecutable);
                      final String extDir = p.join(exeDir, 'zylos_extension');
                      if (Platform.isWindows) {
                         await Process.start('explorer.exe', [extDir]);
                      }
                    } catch (e) {
                      debugPrint('Error opening directory: $e');
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Extension Folder'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForAppUpdates() async {
    final newVersion = await _appUpdateService.checkForUpdates();
    if (newVersion != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('A new version of Zylos (v$newVersion) is available!'),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () {
            launchUrl(Uri.parse('https://github.com/Yasir/Zylos/releases/latest'));
          },
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final pluginProvider = context.watch<PluginProvider>();
    final currentIndex = navProvider.currentIndex;
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final useRail = isDesktop || screenWidth >= 720;

    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final showPluginBanner = pluginProvider.status == PluginSetupStatus.downloading ||
        pluginProvider.status == PluginSetupStatus.error;

    Widget mainContent;
    if (useRail) {
      mainContent = _DesktopLayout(
        currentIndex: currentIndex,
        isDark: isDark,
        screens: _screens,
        onTabChanged: navProvider.setTab,
      );
    } else {
      mainContent = _MobileLayout(
        currentIndex: currentIndex,
        isDark: isDark,
        screens: _screens,
        onTabChanged: navProvider.setTab,
      );
    }

    return Stack(
      children: [
        mainContent,
        if (showPluginBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PluginWarningBanner(isDark: isDark),
          ),
      ],
    );
  }
}

// ── Plugin Warning Banner ─────────────────────────────────────────────────────

class _PluginWarningBanner extends StatelessWidget {
  final bool isDark;
  const _PluginWarningBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PluginProvider>();
    final isDownloading = provider.status == PluginSetupStatus.downloading;
    final color = isDownloading ? AppColors.primary : const Color(0xFFEF4444);
    final message = isDownloading
        ? provider.currentMessage
        : 'Required plugins missing. Tap to install.';

    // Combined progress: average of both plugins' progress (0=missing, 1=done)
    final combinedProgress = ((provider.ytDlpProgress + provider.ffmpegProgress) / 2).clamp(0.0, 1.0);
    final percentStr = isDownloading ? ' ${(combinedProgress * 100).toInt()}%' : '';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PluginManagerScreen()),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: color,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: isDownloading ? 8 : 10,
                left: 20,
                right: 20,
              ),
              child: Row(
                children: [
                  Icon(
                    isDownloading ? Icons.downloading_rounded : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$message$percentStr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (!isDownloading)
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
                ],
              ),
            ),
            if (isDownloading)
              LinearProgressIndicator(
                value: combinedProgress > 0 ? combinedProgress : null,
                minHeight: 3,
                backgroundColor: color.withValues(alpha: 0.4),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
          ],
        ),
      ),
    ).animate().slideY(begin: -1.0, duration: 500.ms, curve: Curves.easeOut);
  }
}



// ── Mobile Layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final List<Widget> screens;
  final Function(int) onTabChanged;

  const _MobileLayout({
    required this.currentIndex,
    required this.isDark,
    required this.screens,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _GlassyBottomNav(
        currentIndex: currentIndex,
        isDark: isDark,
        onTabChanged: onTabChanged,
      ),
    );
  }
}

class _GlassyBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final Function(int) onTabChanged;

  const _GlassyBottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkNavBar.withValues(alpha: 0.75)
                  : AppColors.lightNavBar.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                    : AppColors.lightBorder.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'HOME'),
                _buildNavItem(1, Icons.download_rounded, Icons.download_outlined, 'LIBRARY'),
                _buildNavItem(2, Icons.video_library_rounded, Icons.video_library_outlined, 'LIBRARY'),
                _buildNavItem(3, Icons.speed_rounded, Icons.speed_outlined, 'SPEED'),
                _buildNavItem(4, Icons.transform_rounded, Icons.transform_rounded, 'CONVERT'),
                _buildNavItem(5, Icons.vpn_key_rounded, Icons.vpn_key_outlined, 'VPN'),

              ],
            ),
          ),
        ),
      ).animate().slideY(begin: 1.5, duration: const Duration(milliseconds: 800), curve: Curves.easeOutExpo),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Desktop/Tablet Layout ─────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final List<Widget> screens;
  final Function(int) onTabChanged;

  const _DesktopLayout({
    required this.currentIndex,
    required this.isDark,
    required this.screens,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
      body: Row(
        children: [
          _SideRail(
            currentIndex: currentIndex,
            isDark: isDark,
            onTap: onTabChanged,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 8, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: IndexedStack(
                        index: currentIndex,
                        children: screens,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final Function(int) onTap;

  const _SideRail({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  static const _navItems = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'HOME'),
    (icon: Icons.download_outlined, activeIcon: Icons.download_rounded, label: 'LIBRARY'),
    (icon: Icons.video_library_outlined, activeIcon: Icons.video_library_rounded, label: 'MEDIA'),
    (icon: Icons.speed_outlined, activeIcon: Icons.speed_rounded, label: 'SPEED'),
    (icon: Icons.transform_rounded, activeIcon: Icons.transform_rounded, label: 'CONVERT'),
    (icon: Icons.vpn_key_outlined, activeIcon: Icons.vpn_key_rounded, label: 'VPN'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.4),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      // ── Logo + v2.0 badge ──────────────────────────
                      Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 50, height: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary, AppColors.accent],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // v2.0 badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'v3.0',
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ).animate().scale(delay: const Duration(milliseconds: 200), curve: Curves.easeOutBack),
                      const SizedBox(height: 24),
                      ...List.generate(6, (i) => _buildNavItem(context, i)),
                      const Spacer(),
                      // ── Settings button at bottom ──────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Tooltip(
                          message: 'SETTINGS',
                          preferBelow: false,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const _SettingsScreenProxy()),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            hoverColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.settings_outlined, size: 24,
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                                  const SizedBox(height: 5),
                                  Text('SETTINGS',
                                    style: TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final item = _navItems[index];
    final isSelected = index == currentIndex;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: item.label,
        preferBelow: false,
        verticalOffset: 24,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(18),
          hoverColor: activeColor.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.accent.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(18),
              border: isSelected
                  ? Border.all(color: activeColor.withValues(alpha: 0.35), width: 1)
                  : Border.all(color: Colors.transparent),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: isSelected
                      ? ShaderMask(
                          key: const ValueKey(true),
                          shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
                          child: Icon(item.activeIcon, size: 26, color: Colors.white),
                        )
                      : Icon(
                          item.icon,
                          key: const ValueKey(false),
                          color: inactiveColor,
                          size: 24,
                        ),
                ),
                const SizedBox(height: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 80 * index)).slideX(begin: -0.15);
  }
}

// Proxy to push SettingsScreen from sidebar
class _SettingsScreenProxy extends StatelessWidget {
  const _SettingsScreenProxy();
  @override
  Widget build(BuildContext context) => const SettingsScreen();
}


