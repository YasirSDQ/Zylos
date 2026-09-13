import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/plugin_service.dart';
import '../providers/plugin_provider.dart';
import '../providers/settings_provider.dart';

class PluginManagerScreen extends StatefulWidget {
  const PluginManagerScreen({super.key});

  @override
  State<PluginManagerScreen> createState() => _PluginManagerScreenState();
}

class _PluginManagerScreenState extends State<PluginManagerScreen> {
  bool _isCheckingUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);

    final provider = context.read<PluginProvider>();
    await provider.refreshStatus();

    if (!mounted) return;
    setState(() => _isCheckingUpdates = false);

    final hasUpdates = provider.ffmpegUpdateAvailable || provider.ytDlpUpdateAvailable;
    final updatesFor = [
      if (provider.ytDlpUpdateAvailable) 'yt-dlp',
      if (provider.ffmpegUpdateAvailable) 'FFmpeg',
    ].join(' & ');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              hasUpdates ? Icons.system_update_alt_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasUpdates
                    ? 'Update available for $updatesFor'
                    : 'All plugins are up to date!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: hasUpdates ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentChannel = context.watch<SettingsProvider>().ytdlpReleaseChannel;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plugin Manager',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (_isCheckingUpdates)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Check for updates',
            ),
        ],
      ),
      body: Consumer<PluginProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info header
                _InfoBanner(isDark: isDark),
                const SizedBox(height: 24),

                Text(
                  'REQUIRED PLUGINS',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 12),
                
                // Download All / Switchable Action
                if (!provider.allPluginsReady || provider.ytDlpUpdateAvailable || provider.ffmpegUpdateAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary, 
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: provider.status == PluginSetupStatus.downloading 
                            ? null 
                            : () => _showDownloadAllDialog(context, provider, isDark),
                        icon: const Icon(Icons.cloud_download_rounded),
                        label: const Text('Download / Update Plugins', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ),

                // yt-dlp card
                _PluginCard(
                  name: 'yt-dlp',
                  version: provider.ytDlpVersion ?? 'Not Installed',
                  hasUpdate: provider.ytDlpUpdateAvailable,
                  description: 'Powers all video/audio downloads from YouTube, TikTok, Instagram, and 1000+ sites.',
                  icon: Icons.download_for_offline_rounded,
                  iconColor: const Color(0xFF06B6D4),
                  isInstalled: provider.ytDlpInstalled,
                  progress: provider.ytDlpProgress,
                  isDownloading: provider.status == PluginSetupStatus.downloading,
                  isDark: isDark,
                  exePath: PluginService.ytDlpExePath,
                  downloadUrl: currentChannel == 'stable' 
                      ? 'https://github.com/yt-dlp/yt-dlp'
                      : currentChannel == 'nightly' 
                          ? 'https://github.com/yt-dlp/yt-dlp-nightly-builds' 
                          : 'https://github.com/yt-dlp/yt-dlp-master-builds',
                  directDownloadUrl: currentChannel == 'stable' 
                      ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
                      : currentChannel == 'nightly'
                          ? 'https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp.exe'
                          : 'https://github.com/yt-dlp/yt-dlp-master-builds/releases/latest/download/yt-dlp.exe',
                  onReinstall: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Update yt-dlp?', style: TextStyle(fontWeight: FontWeight.w800)),
                        content: const Text('Are you sure you want to re-download and install yt-dlp?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) provider.reinstallPlugin(PluginType.ytDlp);
                  },
                  onImportPath: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['exe'],
                      dialogTitle: 'Select yt-dlp.exe',
                    );
                    if (result != null && result.files.single.path != null && context.mounted) {
                      final ok = await context.read<PluginProvider>()
                          .setManualPluginPath(PluginType.ytDlp, result.files.single.path!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'yt-dlp imported successfully!' : 'Import failed. Check the file.'),
                          backgroundColor: ok ? const Color(0xFF10B981) : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                        ));
                      }
                    }
                  },
                  delay: 100,
                ),

                const SizedBox(height: 8),
                _YtDlpChannelSelector(isDark: isDark),

                const SizedBox(height: 16),

                // FFmpeg card
                _PluginCard(
                  name: 'FFmpeg',
                  version: provider.ffmpegVersion ?? 'Not Installed',
                  hasUpdate: provider.ffmpegUpdateAvailable,
                  description: 'Handles audio/video merging, format conversion, and quality processing.',
                  icon: Icons.settings_suggest_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  isInstalled: provider.ffmpegInstalled,
                  progress: provider.ffmpegProgress,
                  isDownloading: provider.status == PluginSetupStatus.downloading,
                  isDark: isDark,
                  exePath: PluginService.ffmpegExePath,
                  downloadUrl: 'https://ffmpeg.org/download.html',
                  directDownloadUrl: 'https://github.com/yt-dlp/FFmpeg-Builds/releases/latest',
                  onReinstall: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Update FFmpeg?', style: TextStyle(fontWeight: FontWeight.w800)),
                        content: const Text('Are you sure you want to re-download and install FFmpeg?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) provider.reinstallPlugin(PluginType.ffmpeg);
                  },
                  onImportPath: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['exe'],
                      dialogTitle: 'Select ffmpeg.exe',
                    );
                    if (result != null && result.files.single.path != null && context.mounted) {
                      final ok = await context.read<PluginProvider>()
                          .setManualPluginPath(PluginType.ffmpeg, result.files.single.path!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'FFmpeg imported successfully!' : 'Import failed. Check the file.'),
                          backgroundColor: ok ? const Color(0xFF10B981) : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(16),
                        ));
                      }
                    }
                  },
                  delay: 200,
                ),

                const SizedBox(height: 24),

                Text(
                  'OPTIONAL PLUGINS',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 12),

                _WarpPluginCard(provider: provider, isDark: isDark),

                const SizedBox(height: 28),

                // Status banner (Only show Error or Success, hide during active download to avoid overlap with cards)
                if (provider.status == PluginSetupStatus.error && provider.errorMessage != null)
                  Column(children: [
                    _StatusBanner(message: provider.errorMessage!, sub: null, color: const Color(0xFFEF4444), icon: Icons.error_outline_rounded, isDark: isDark),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => provider.downloadMissingPlugins(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Auto-Install', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ])
                else if (provider.allPluginsReady)
                  _StatusBanner(
                    message: 'All plugins installed and ready!',
                    sub: 'Downloads are fully operational.',
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline_rounded,
                    isDark: isDark,
                  ),

                const SizedBox(height: 24),

                // Storage location
                _StorageLocationCard(isDark: isDark),

                const SizedBox(height: 24),

                // ── Troubleshoot Section ───────────────────────────────────
                _TroubleshootSection(isDark: isDark),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDownloadAllDialog(BuildContext context, PluginProvider provider, bool isDark) {
    bool downloadYtDlpAll = !provider.ytDlpInstalled || provider.ytDlpUpdateAvailable;
    bool downloadFfmpeg = !provider.ffmpegInstalled || provider.ffmpegUpdateAvailable;
    
    if (provider.allPluginsReady && !provider.ytDlpUpdateAvailable && !provider.ffmpegUpdateAvailable) {
      downloadYtDlpAll = true;
      downloadFfmpeg = true;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Download Plugins', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select the plugins you want to download or update:', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('yt-dlp (All Versions)', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Download Stable, Master, and Nightly simultaneously', style: TextStyle(fontSize: 11)),
                  value: downloadYtDlpAll,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => downloadYtDlpAll = val),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('FFmpeg', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(provider.ffmpegInstalled ? 'Update / Reinstall' : 'Install (Required)', style: const TextStyle(fontSize: 11)),
                  value: downloadFfmpeg,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => downloadFfmpeg = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: (!downloadYtDlpAll && !downloadFfmpeg) ? null : () {
                  Navigator.pop(ctx);
                  if (downloadYtDlpAll && downloadFfmpeg) {
                    provider.downloadAllYtDlpChannels().then((_) {
                      provider.reinstallPlugin(PluginType.ffmpeg);
                    });
                  } else if (downloadYtDlpAll) {
                    provider.downloadAllYtDlpChannels();
                  } else if (downloadFfmpeg) {
                    provider.reinstallPlugin(PluginType.ffmpeg);
                  }
                },
                child: const Text('Download Selected'),
              ),
            ],
          );
        }
      ),
    );
  }
}

// ── YtDlp Channel Selector ───────────────────────────────────────────────────

class _YtDlpChannelSelector extends StatelessWidget {
  final bool isDark;
  const _YtDlpChannelSelector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final currentChannel = settingsProvider.ytdlpReleaseChannel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes_rounded, size: 18, color: Color(0xFF06B6D4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Release Channel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text('Change where updates come from', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ],
            ),
          ),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentChannel,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF06B6D4), size: 18),
                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4)),
                items: const [
                  DropdownMenuItem(value: 'stable', child: Text('Stable')),
                  DropdownMenuItem(value: 'master', child: Text('Master')),
                  DropdownMenuItem(value: 'nightly', child: Text('Nightly')),
                ],
                onChanged: (v) {
                  if (v != null && v != currentChannel) {
                    settingsProvider.setYtdlpReleaseChannel(v);
                    context.read<PluginProvider>().refreshStatus();
                    
                    if (!File(PluginService.ytDlpExePathForChannel(v)).existsSync()) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Download Required', style: TextStyle(fontWeight: FontWeight.w800)),
                          content: Text('You switched the yt-dlp release channel to "$v". This version is not downloaded yet. Please trigger an update to fetch it.',
                              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          actions: [
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Got it'),
                            ),
                          ],
                        )
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms);
  }
}

// ── Info Banner ─────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Zylos requires FFmpeg and yt-dlp. They are auto-detected from your system PATH, or auto-downloaded to your app folder. You can also manually import them or download externally.',
              style: TextStyle(
                fontSize: 13, height: 1.5, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

// ── Plugin Card ─────────────────────────────────────────────────────────────

class _PluginCard extends StatelessWidget {
  final String name;
  final String version;
  final bool hasUpdate;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isInstalled;
  final double progress;
  final bool isDownloading;
  final bool isDark;
  final String exePath;
  final String downloadUrl;
  final String directDownloadUrl;
  final VoidCallback onReinstall;
  final VoidCallback onImportPath;
  final int delay;

  const _PluginCard({
    required this.name, required this.version, this.hasUpdate = false, required this.description,
    required this.icon, required this.iconColor, required this.isInstalled,
    required this.progress, required this.isDownloading, required this.isDark,
    required this.exePath, required this.downloadUrl, required this.directDownloadUrl,
    required this.onReinstall, required this.onImportPath, required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, borderRadius: BorderRadius.circular(6)),
                      child: Text(version, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    ),
                    if (hasUpdate) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                        child: const Row(
                          children: [
                            Icon(Icons.upgrade_rounded, size: 10, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('UPDATE AVAILABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isInstalled ? 'Installed' : 'Not Installed',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                  ]),
                ]),
              ),
              if (!isDownloading)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: isDark ? AppColors.darkCard : Colors.white,
                  elevation: 6,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'update', child: Row(children: [Icon(Icons.refresh_rounded, size: 18), SizedBox(width: 10), Text('Update / Reinstall')])),
                    const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.folder_open_rounded, size: 18), SizedBox(width: 10), Text('Import from path…')])),
                    const PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.open_in_browser_rounded, size: 18), SizedBox(width: 10), Text('Download externally…')])),
                    const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 10), Text('Copy download link')])),
                  ],
                  onSelected: (val) async {
                    switch (val) {
                      case 'update': onReinstall(); break;
                      case 'import': onImportPath(); break;
                      case 'download':
                        final uri = Uri.parse(downloadUrl);
                        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                        break;
                      case 'copy':
                        await Clipboard.setData(ClipboardData(text: directDownloadUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Download link copied!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ));
                        }
                        break;
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(fontSize: 13, height: 1.4,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),

          // Progress bar when downloading this plugin
          if (isDownloading && progress > 0 && progress < 1) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const SizedBox(width: 4, height: 4, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Downloading…', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ]),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.01, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [iconColor, iconColor.withValues(alpha: 0.6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.read<PluginProvider>().stopDownload(),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Stop Download', style: TextStyle(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: AppColors.error, backgroundColor: AppColors.error.withValues(alpha: 0.08)),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: isInstalled ? Icons.refresh_rounded : Icons.download_rounded,
                  label: isInstalled ? 'Update' : 'Auto Install',
                  color: iconColor.withValues(alpha: 0.12),
                  textColor: iconColor,
                  onTap: isDownloading ? null : onReinstall,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.open_in_browser_rounded,
                  label: 'Direct Link',
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  textColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onTap: () async {
                    final uri = Uri.parse(directDownloadUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.folder_open_rounded,
                  label: 'Import .exe',
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  textColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onTap: isDownloading ? null : onImportPath,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.15);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon, required this.label, required this.color,
    required this.textColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ── Cloudflare WARP Card ────────────────────────────────────────────────────

class _WarpPluginCard extends StatelessWidget {
  final PluginProvider provider;
  final bool isDark;

  const _WarpPluginCard({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isInstalled = provider.warpInstalled;
    final isDownloading = provider.status == PluginSetupStatus.downloading && provider.warpProgress > 0;
    final progress = provider.warpProgress;
    final statusColor = isInstalled ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final iconColor = const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.security_rounded, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cloudflare WARP', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isInstalled ? 'Installed' : 'Not Installed',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                  ]),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('A local proxy client to bypass geo-restrictions and download rate limits.', style: TextStyle(fontSize: 13, height: 1.4,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          
          if (isDownloading && progress > 0 && progress < 1) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const SizedBox(width: 4, height: 4, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Downloading Installer…', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ]),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.01, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [iconColor, iconColor.withValues(alpha: 0.6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: isInstalled ? Icons.refresh_rounded : Icons.download_rounded,
                  label: isInstalled ? 'Update WARP' : 'Auto Install',
                  color: iconColor.withValues(alpha: 0.12),
                  textColor: iconColor,
                  onTap: provider.status == PluginSetupStatus.downloading ? null : () => provider.installWarp(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.open_in_browser_rounded,
                  label: 'Direct Link',
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  textColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onTap: () async {
                    final uri = Uri.parse('https://1111-releases.cloudflareclient.com/windows/Cloudflare_WARP_Release-x64.msi');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Website',
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  textColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onTap: () async {
                    final uri = Uri.parse('https://1.1.1.1/');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15);
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String message;
  final String? sub;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatusBanner({required this.message, required this.sub, required this.color, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.25), width: 1)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
          ],
        ])),
      ]),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

// ── Storage Location Card ───────────────────────────────────────────────────

class _StorageLocationCard extends StatelessWidget {
  final bool isDark;
  const _StorageLocationCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.folder_outlined, size: 18, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
            const SizedBox(width: 8),
            Text('Plugin Storage Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Process.run('explorer.exe', [PluginService.binDir]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.folder_open_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Open Folder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: PluginService.binDir));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Path copied!'),
                    backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
                  ));
                }
              },
              child: Icon(Icons.copy_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
            ),
          ]),
          const SizedBox(height: 8),
          Text(PluginService.binDir,
              style: TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.4,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _FileExistsIndicator(path: PluginService.ytDlpExePath, label: 'yt-dlp.exe', isDark: isDark),
              _FileExistsIndicator(path: PluginService.ffmpegExePath, label: 'ffmpeg.exe', isDark: isDark),
              _FileExistsIndicator(path: r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe', label: 'warp-cli.exe', isDark: isDark),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _FileExistsIndicator extends StatelessWidget {
  final String path;
  final String label;
  final bool isDark;
  const _FileExistsIndicator({required this.path, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final exists = File(path).existsSync();
    final color = exists ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
    ]);
  }
}

// ── Troubleshoot Section ───────────────────────────────────────────────────────

class _TroubleshootSection extends StatelessWidget {
  final bool isDark;
  const _TroubleshootSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.build_rounded, size: 16, color: AppColors.error),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Troubleshoot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text('Diagnostics & repair tools', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              _TroubleshootButton(
                icon: Icons.system_update_alt_rounded,
                label: 'Re-download All Plugins',
                subtitle: 'Force reinstall yt-dlp & FFmpeg',
                color: AppColors.primary,
                isDark: isDark,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Re-download Plugins?', style: TextStyle(fontWeight: FontWeight.w800)),
                      content: const Text('This will force a fresh download of both yt-dlp and FFmpeg. Are you sure you want to proceed?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          child: const Text('Re-download'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    final p = context.read<PluginProvider>();
                    p.reinstallPlugin(PluginType.ytDlp);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (context.mounted) p.reinstallPlugin(PluginType.ffmpeg);
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _TroubleshootButton(
                icon: Icons.folder_special_rounded,
                label: 'Check Plugin Paths',
                subtitle: 'View where binaries are expected',
                color: const Color(0xFF06B6D4),
                isDark: isDark,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Plugin Paths', style: TextStyle(fontWeight: FontWeight.w800)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('yt-dlp:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated, borderRadius: BorderRadius.circular(8)),
                            child: SelectableText(PluginService.ytDlpExePath, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          ),
                          const SizedBox(height: 12),
                          Text('FFmpeg:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated, borderRadius: BorderRadius.circular(8)),
                            child: SelectableText(PluginService.ffmpegExePath, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          ),
                          const SizedBox(height: 12),
                          Text('Cloudflare WARP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated, borderRadius: BorderRadius.circular(8)),
                            child: SelectableText(r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          ),
                          const SizedBox(height: 12),
                          Wrap(spacing: 16, runSpacing: 8, children: [
                            _FileExistsIndicator(path: PluginService.ytDlpExePath, label: File(PluginService.ytDlpExePath).existsSync() ? 'yt-dlp found' : 'yt-dlp missing', isDark: isDark),
                            _FileExistsIndicator(path: PluginService.ffmpegExePath, label: File(PluginService.ffmpegExePath).existsSync() ? 'FFmpeg found' : 'FFmpeg missing', isDark: isDark),
                            _FileExistsIndicator(path: r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe', label: File(r'C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe').existsSync() ? 'WARP found' : 'WARP missing', isDark: isDark),
                          ]),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: 'yt-dlp: ${PluginService.ytDlpExePath}\nFFmpeg: ${PluginService.ffmpegExePath}\nWARP: C:\\Program Files\\Cloudflare\\Cloudflare WARP\\warp-cli.exe'));
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paths copied to clipboard')));
                            }
                          },
                          child: const Text('Copy'),
                        ),
                      ],
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 300.ms);
  }
}

class _TroubleshootButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _TroubleshootButton({required this.icon, required this.label, required this.subtitle, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
