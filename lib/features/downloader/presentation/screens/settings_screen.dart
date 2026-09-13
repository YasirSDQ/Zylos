import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/platform_utils.dart';
import '../providers/settings_provider.dart';
import '../providers/download_provider.dart';
import '../providers/plugin_provider.dart';
import 'plugin_manager_screen.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/local_server.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN — Modern Redesign
// ═══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: _buildAppBar(isDark),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ── Downloads ──────────────────────────────────────────────────
            _SettingsGroup(
              isDark: isDark,
              icon: Icons.folder_rounded,
              iconColor: AppColors.primary,
              title: 'Downloads',
              delay: 0,
              children: [
                _SettingsTile(
                  icon: Icons.folder_open_rounded,
                  iconColor: AppColors.primary,
                  title: 'Save Location',
                  subtitle: settingsProvider.currentDownloadPath ?? PlatformUtils.getDefaultDownloadPath(),
                  trailing: _PillButton(
                    label: 'Change',
                    color: AppColors.primary,
                  ),
                  onTap: () async {
                    final result = await FilePicker.platform.getDirectoryPath();
                    if (result != null) settingsProvider.setDownloadPath(result);
                  },
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Performance & Concurrency ──────────────────────────────────
            _SettingsGroup(
              isDark: isDark,
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Performance',
              delay: 30,
              children: [
                _ConcurrentTasksSetting(provider: settingsProvider, isDark: isDark),
                _SettingsDivider(isDark: isDark),
                _ConverterConcurrentTasksSetting(provider: settingsProvider, isDark: isDark),
              ],
            ),

            const SizedBox(height: 16),

            // ── Appearance ─────────────────────────────────────────────────
            _SettingsGroup(
              isDark: isDark,
              icon: Icons.palette_rounded,
              iconColor: AppColors.accent,
              title: 'Appearance',
              delay: 60,
              children: [
                _SwitchTile(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  iconColor: AppColors.accent,
                  title: 'Dark Mode',
                  subtitle: 'Switch between light and dark',
                  value: settingsProvider.isDarkTheme,
                  onChanged: (val) => settingsProvider.toggleTheme(val),
                  isDark: isDark,
                ),
                _SettingsDivider(isDark: isDark),
                _AnimationScaleSetting(provider: settingsProvider, isDark: isDark),
              ],
            ),

            const SizedBox(height: 16),



            // ── Plugins ────────────────────────────────────────────────────
            _SettingsGroup(
              isDark: isDark,
              icon: Icons.extension_rounded,
              iconColor: AppColors.primary,
              title: 'Plugins & Tools',
              delay: 120,
              children: [
                _SettingsTile(
                  icon: Icons.manage_search_rounded,
                  iconColor: AppColors.primary,
                  title: 'Plugin Manager',
                  subtitle: 'Install, update or reinstall yt-dlp & FFmpeg',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PluginManagerScreen()),
                  ),
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 8),
            _PluginsStatusCard(isDark: isDark),

            const SizedBox(height: 16),

            // ── Integrations ───────────────────────────────────────────────
            _SettingsGroup(
              isDark: isDark,
              icon: Icons.cable_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Integrations',
              delay: 180,
              children: [
                _WarpProxySettingTile(provider: settingsProvider, isDark: isDark),
                _SettingsDivider(isDark: isDark),
                _PortConfigTile(provider: settingsProvider, isDark: isDark),
                _SettingsDivider(isDark: isDark),
                _ConnectionStatusTile(isDark: isDark),
                _SettingsDivider(isDark: isDark),
                _ChromeExtensionStatusTile(isDark: isDark),
              ],
            ),

            const SizedBox(height: 16),

            const SizedBox(height: 40),

            // ── App info ───────────────────────────────────────────────────
            _AppInfoFooter(isDark: isDark),
          ].animate(interval: 30.ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Z',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Download Tooling?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This will delete and re-download the core components (yt-dlp and FFmpeg). Use this if your downloads are consistently stuck at 0%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<DownloadProvider>().resetBinaries();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tooling reset. It will re-download on next task.')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS GROUP — Section card with gradient header
// ═══════════════════════════════════════════════════════════════════════════
class _SettingsGroup extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final int delay;

  const _SettingsGroup({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
        // Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsDivider extends StatelessWidget {
  final bool isDark;
  const _SettingsDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 60),
      height: 0.5,
      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  const _PillButton({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDark;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? customSubtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final bool isLoading;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.customSubtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (customSubtitle != null) customSubtitle!
                else if (subtitle != null) Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
        ],
      ),
    );
  }
}

Future<int?> _showCustomTasksDialog(BuildContext context, bool isDark, String title) {
  final controller = TextEditingController();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Enter a number',
          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _ConcurrentTasksSetting extends StatelessWidget {
  final SettingsProvider provider;
  final bool isDark;
  const _ConcurrentTasksSetting({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final valStr = provider.maxConcurrentTasks >= 999 ? 'All' : provider.maxConcurrentTasks.toString();
    final hasCustom = !['All', '1', '2', '3', '4', '5'].contains(valStr);
    final items = ['All', '1', '2', '3', '4', '5'];
    if (hasCustom) items.add(valStr);
    items.add('Custom...');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Concurrent Downloads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Max parallel downloads',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: valStr,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                items: items.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(hasCustom && s == valStr ? 'Custom ($s)' : s),
                )).toList(),
                onChanged: (v) async {
                  if (v == 'All') {
                    provider.setMaxConcurrentTasks(999);
                  } else if (v == 'Custom...') {
                    final val = await _showCustomTasksDialog(context, isDark, 'Max Downloads');
                    if (val != null && val > 0) provider.setMaxConcurrentTasks(val);
                  } else if (v != null) {
                    provider.setMaxConcurrentTasks(int.parse(v));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimationScaleSetting extends StatelessWidget {
  final SettingsProvider provider;
  final bool isDark;
  const _AnimationScaleSetting({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final labels = ['Off', '25%', '50%', '75%', 'Full'];
    final idx = (provider.animationScale * 4).round().clamp(0, 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.animation_rounded, color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Animation Speed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'UI motion intensity',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[idx],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.info,
              thumbColor: AppColors.info,
              overlayColor: AppColors.info.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: provider.animationScale,
              min: 0.0,
              max: 1.0,
              divisions: 4,
              onChanged: (val) => provider.setAnimationScale(val),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.asMap().entries.map((e) => Text(
              e.value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: idx == e.key ? FontWeight.w800 : FontWeight.w500,
                color: idx == e.key
                    ? AppColors.info
                    : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLUGINS STATUS CARD
// ═══════════════════════════════════════════════════════════════════════════
class _PluginsStatusCard extends StatelessWidget {
  final bool isDark;
  const _PluginsStatusCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Consumer<PluginProvider>(
      builder: (context, provider, _) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            _PluginStatusRow(
              name: 'yt-dlp',
              subtitle: 'Video & audio downloader',
              isInstalled: provider.ytDlpInstalled,
              icon: Icons.download_for_offline_rounded,
              iconColor: const Color(0xFF06B6D4),
              isDark: isDark,
              onDownload: () async {
                final uri = Uri.parse('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe');
                if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            Container(
              margin: const EdgeInsets.only(left: 60),
              height: 0.5,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            _PluginStatusRow(
              name: 'FFmpeg',
              subtitle: 'Media conversion engine',
              isInstalled: provider.ffmpegInstalled,
              icon: Icons.settings_suggest_rounded,
              iconColor: const Color(0xFF8B5CF6),
              isDark: isDark,
              onDownload: () async {
                final uri = Uri.parse('https://github.com/yt-dlp/FFmpeg-Builds/releases/latest');
                if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            Container(
              margin: const EdgeInsets.only(left: 60),
              height: 0.5,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            _PluginStatusRow(
              name: 'Cloudflare WARP',
              subtitle: 'Local proxy & VPN',
              isInstalled: provider.warpInstalled,
              icon: Icons.security_rounded,
              iconColor: const Color(0xFFF59E0B),
              isDark: isDark,
              onDownload: () async {
                final uri = Uri.parse('https://1.1.1.1/');
                if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ]),
        );
      },
    );
  }
}

class _PluginStatusRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isInstalled;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onDownload;

  const _PluginStatusRow({
    required this.name,
    required this.subtitle,
    required this.isInstalled,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isInstalled ? const Color(0xFF10B981) : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(
                isInstalled ? 'Installed' : 'Missing',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ]),
          ),
          if (!isInstalled) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.open_in_browser_rounded, size: 14),
              label: const Text('Get', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHROME EXTENSION STATUS TILE
// ═══════════════════════════════════════════════════════════════════════════
class _ChromeExtensionStatusTile extends StatefulWidget {
  final bool isDark;
  const _ChromeExtensionStatusTile({required this.isDark});

  @override
  State<_ChromeExtensionStatusTile> createState() => _ChromeExtensionStatusTileState();
}

class _ChromeExtensionStatusTileState extends State<_ChromeExtensionStatusTile> {
  bool _connected = false;
  bool _checking = true;
  bool _installing = false;
  bool _showManual = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkConnection());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (!mounted) return;
    try {
      final lastPing = LocalServer.lastExtensionPing;
      final bool isConnected = lastPing != null && DateTime.now().difference(lastPing).inSeconds < 5;
      if (mounted) setState(() { _connected = isConnected; _checking = false; });
    } catch (_) {
      if (mounted) setState(() { _connected = false; _checking = false; });
    }
  }

  Future<void> _runAutoInstall() async {
    setState(() => _installing = true);
    try {
      final String exeDir = Platform.resolvedExecutable
          .substring(0, Platform.resolvedExecutable.lastIndexOf('\\'));
      final String extDir = '$exeDir\\zylos_extension';
      final String psScript = '$extDir\\install_extension.ps1';

      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', psScript, '-ExtensionDir', extDir],
        runInShell: true,
      );

      if (!mounted) return;
      if (result.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extension setup complete! Restart Chrome to apply.'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup note: ${result.stderr.toString().split('\n').first}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _installing = false);
      _checkConnection();
    }
  }

  Future<void> _openExtensionFolder() async {
    try {
      final String exeDir = Platform.resolvedExecutable
          .substring(0, Platform.resolvedExecutable.lastIndexOf('\\'));
      final String extDir = '$exeDir\\zylos_extension';
      await PlatformUtils.openFolder(extDir);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open folder: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final statusColor = _checking
        ? AppColors.warning
        : (_connected ? const Color(0xFF25D366) : AppColors.error);
    final port = context.read<SettingsProvider>().serverPort;
    final statusText = _checking
        ? 'Checking...'
        : (_connected ? 'Connected — port $port' : 'Not connected');

    return Column(
      children: [
        // ── Status row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: _checking
                  ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                  : Icon(
                      _connected ? Icons.extension_rounded : Icons.extension_off_rounded,
                      color: statusColor, size: 18,
                    ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chrome Extension',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      )),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(statusText,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                onPressed: _checkConnection,
                tooltip: 'Re-check connection',
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Action buttons ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _ActionButton(
                  isDark: isDark,
                  icon: Icons.install_desktop_rounded,
                  label: _installing ? 'Installing...' : 'Auto Install',
                  color: AppColors.primary,
                  onTap: _installing ? null : _runAutoInstall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  isDark: isDark,
                  icon: Icons.folder_open_rounded,
                  label: 'Open Ext Folder',
                  color: const Color(0xFF8B5CF6),
                  onTap: _openExtensionFolder,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Manual steps toggle ──
        InkWell(
          onTap: () => setState(() => _showManual = !_showManual),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                Icon(
                  _showManual ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _showManual ? 'Hide manual steps' : 'Manual install steps',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_showManual) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Manual Extension Setup',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    )),
                ]),
                const SizedBox(height: 10),
                ...[
                  '1. Open Chrome and go to chrome://extensions',
                  '2. Enable "Developer mode" (top-right toggle)',
                  '3. Click "Load unpacked"',
                  '4. Browse to your Zylos install folder',
                  '5. Select the zylos_extension folder',
                  '6. Click OK — the Zylos icon will appear in Chrome',
                ].map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(step,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          )),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color,
              )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP INFO FOOTER
// ═══════════════════════════════════════════════════════════════════════════
class _AppInfoFooter extends StatelessWidget {
  final bool isDark;
  const _AppInfoFooter({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B4FDE), Color(0xFFE8336D)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2FBE).withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Text(
                    'Z',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: const Text(
              'Zylos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Version 3.0.0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ♥ by Yasir Siddiqui',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Port Configuration Tile ────────────────────────────────────────────────────

class _PortConfigTile extends StatefulWidget {
  final SettingsProvider provider;
  final bool isDark;
  const _PortConfigTile({required this.provider, required this.isDark});

  @override
  State<_PortConfigTile> createState() => _PortConfigTileState();
}

class _PortConfigTileState extends State<_PortConfigTile> {
  late TextEditingController _portController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: widget.provider.serverPort.toString());
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1024 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invalid port. Must be between 1024–65535.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    widget.provider.setServerPort(port);
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Port updated to $port. Restart the app to apply.'),
      backgroundColor: const Color(0xFF10B981),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.router_rounded, size: 18, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Server Port', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text('Port used for browser extension communication', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_editing)
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: const Color(0xFF06B6D4))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    _portController.text = '7734';
                    _save();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: isDark ? AppColors.darkCardElevated : AppColors.lightCardElevated, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder), borderRadius: BorderRadius.circular(8)),
                    child: Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _editing = false),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                ),
                child: Text(':${widget.provider.serverPort}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4))),
              ),
            ),
        ],
      ),
    );
  }
}

// ── WARP Proxy Setting Tile ──────────────────────────────────────────────────

class _WarpProxySettingTile extends StatefulWidget {
  final SettingsProvider provider;
  final bool isDark;
  const _WarpProxySettingTile({required this.provider, required this.isDark});

  @override
  State<_WarpProxySettingTile> createState() => _WarpProxySettingTileState();
}

class _WarpProxySettingTileState extends State<_WarpProxySettingTile> {
  Timer? _timer;
  String _warpStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkWarpStatus();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _checkWarpStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkWarpStatus() async {
    if (!mounted || !widget.provider.useWarpProxy) return;
    
    final warpCliPath = r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe';
    if (!await File(warpCliPath).exists()) {
      if (mounted) setState(() => _warpStatus = 'Not Installed');
      return;
    }
    
    try {
      final res = await Process.run(warpCliPath, ['status'], runInShell: true);
      final out = res.stdout.toString().trim();
      String newStatus = 'Unknown';
      if (out.contains('Connected')) {
        newStatus = 'Live (Traffic Mode)';
      } else if (out.contains('Connecting')) {
        newStatus = 'Connecting...';
      } else if (out.contains('Disconnected')) {
        newStatus = 'Disconnected';
      } else {
        newStatus = out.split('\n').first;
      }
      if (mounted && _warpStatus != newStatus) {
        setState(() => _warpStatus = newStatus);
      }
    } catch (_) {
      if (mounted) setState(() => _warpStatus = 'Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Column(
      children: [
        _SwitchTile(
          icon: Icons.security_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'Cloudflare WARP Proxy',
          customSubtitle: widget.provider.useWarpProxy
              ? Row(
                  children: [
                    Text('Status: ', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    if (_warpStatus.contains('Live')) ...[
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_warpStatus, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ] else ...[
                      Text(_warpStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _warpStatus.contains('Error') || _warpStatus.contains('Disconnected') || _warpStatus.contains('Not Installed') ? AppColors.error : AppColors.warning)),
                    ],
                  ],
                )
              : null,
          subtitle: widget.provider.useWarpProxy ? null : 'Route downloads through local proxy',
          value: widget.provider.useWarpProxy,
          onChanged: widget.provider.isConfiguringWarp ? (_) {} : (val) => widget.provider.setUseWarpProxy(val),
          isDark: isDark,
          isLoading: widget.provider.isConfiguringWarp,
        ),
        if (widget.provider.useWarpProxy)
          Padding(
            padding: const EdgeInsets.only(left: 68, right: 16, bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Connection Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBg : AppColors.lightBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.provider.warpMode,
                            isExpanded: true,
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
                            onChanged: widget.provider.isConfiguringWarp ? null : (v) {
                              if (v != null) widget.provider.setWarpMode(v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Connection Status Tile ─────────────────────────────────────────────────────

class _ConnectionStatusTile extends StatefulWidget {
  final bool isDark;
  const _ConnectionStatusTile({required this.isDark});

  @override
  State<_ConnectionStatusTile> createState() => _ConnectionStatusTileState();
}

class _ConnectionStatusTileState extends State<_ConnectionStatusTile> {
  bool _isConnected = false;
  bool _checking = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _testConnection();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _testConnection());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!mounted) return;
    final port = context.read<SettingsProvider>().serverPort;
    try {
      final resp = await http.get(Uri.parse('http://localhost:$port/ping')).timeout(const Duration(seconds: 2));
      if (mounted) setState(() { _isConnected = resp.statusCode < 400; _checking = false; });
    } catch (_) {
      if (mounted) setState(() { _isConnected = false; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final statusColor = _checking
        ? AppColors.warning
        : _isConnected
            ? const Color(0xFF10B981)
            : AppColors.error;
    final statusText = _checking ? 'Checking...' : _isConnected ? 'Live & Active' : 'Not reachable';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: _checking 
                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                : Icon(Icons.wifi_tethering_rounded, size: 18, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connection Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(_isConnected ? 'Live' : 'Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConverterConcurrentTasksSetting extends StatelessWidget {
  final SettingsProvider provider;
  final bool isDark;
  const _ConverterConcurrentTasksSetting({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final valStr = provider.converterMaxConcurrent >= 999 ? 'All' : provider.converterMaxConcurrent.toString();
    final hasCustom = !['All', '1', '2', '3', '4', '5'].contains(valStr);
    final items = ['All', '1', '2', '3', '4', '5'];
    if (hasCustom) items.add(valStr);
    items.add('Custom...');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.compare_arrows_rounded, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Concurrent Conversions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Max parallel conversions',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: valStr,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 20),
                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                items: items.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(hasCustom && s == valStr ? 'Custom ($s)' : s),
                )).toList(),
                onChanged: (v) async {
                  if (v == 'All') {
                    provider.setConverterMaxConcurrent(999);
                  } else if (v == 'Custom...') {
                    final val = await _showCustomTasksDialog(context, isDark, 'Max Conversions');
                    if (val != null && val > 0) provider.setConverterMaxConcurrent(val);
                  } else if (v != null) {
                    provider.setConverterMaxConcurrent(int.parse(v));
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
