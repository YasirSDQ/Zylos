import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../data/datasources/youtube_datasource.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/video_entity.dart';
import '../providers/download_provider.dart';
import '../providers/plugin_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/video_info_card.dart';
import '../widgets/quality_selector_sheet.dart';
import '../../../../core/utils/app_notifications.dart';

// ══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL DOWNLOADER SCREEN
// Accepts any URL that yt-dlp supports (1700+ sites)
// ══════════════════════════════════════════════════════════════════════════════

class UniversalDownloaderScreen extends StatefulWidget {
  final String? initialUrl;
  const UniversalDownloaderScreen({super.key, this.initialUrl});

  @override
  State<UniversalDownloaderScreen> createState() => _UniversalDownloaderScreenState();
}

class _UniversalDownloaderScreenState extends State<UniversalDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  VideoEntity? _singleVideo;
  String? _localOutputPath;
  String get _outputPath => _localOutputPath ?? context.read<SettingsProvider>().currentDownloadPath ?? PlatformUtils.getDefaultDownloadPath();

  VideoQuality? _selectedVideoQuality;
  AudioQuality? _selectedAudioQuality;
  ImageQuality? _selectedImageQuality;
  bool _isAudioOnly = false;
  bool _isImageOnly = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));

    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaylistProvider>().clear();
      if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
        _fetchUrl();
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() { _isLoading = true; _errorMessage = null; _singleVideo = null; });
    context.read<PlaylistProvider>().clear();

    try {
      final repo = context.read<DownloadRepositoryImpl>();
      final pluginService = context.read<PluginProvider>().service;
      final isPlaylist = YoutubeDatasource(pluginService).isPlaylist(url);
      if (isPlaylist) {
        final playlist = await repo.fetchPlaylistInfo(url);
        if (!mounted) return;
        context.read<PlaylistProvider>().setPlaylist(playlist);
      } else {
        final video = await repo.fetchVideoInfo(url);
        if (!mounted) return;
        setState(() {
          _singleVideo = video;
          _selectedVideoQuality = video.availableQualities.firstOrNull;
          _selectedAudioQuality = video.availableAudioQualities.firstOrNull;
          _selectedImageQuality = video.availableImageQualities.firstOrNull;
          _isAudioOnly = false;
          _isImageOnly = video.availableQualities.isEmpty && video.availableImageQualities.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not fetch info. Check the URL or try a different link.\n\nError: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _localOutputPath = result);
  }

  void _showQualitySheet() {
    if (_singleVideo == null) return;

    final Map<String, VideoQuality> vMap = {};
    for (final q in _singleVideo!.availableQualities) {
      if (!vMap.containsKey(q.label) || q.fps > vMap[q.label]!.fps) vMap[q.label] = q;
    }
    final dedupedVideo = vMap.values.toList()..sort((a, b) => b.height.compareTo(a.height));

    final Map<String, AudioQuality> aMap = {};
    for (final q in _singleVideo!.availableAudioQualities) { aMap.putIfAbsent(q.label, () => q); }
    final dedupedAudio = aMap.values.toList()..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    QualitySelectorSheet.show(context,
      videoQualities: dedupedVideo,
      audioQualities: dedupedAudio,
      imageQualities: _singleVideo!.availableImageQualities,
      selectedVideoQuality: _selectedVideoQuality,
      selectedAudioQuality: _selectedAudioQuality,
      selectedImageQuality: _selectedImageQuality,
      isAudioOnly: _isAudioOnly,
      isImageOnly: _isImageOnly,
      onVideoSelected: (v) => setState(() { _selectedVideoQuality = v; _isAudioOnly = false; _isImageOnly = false; }),
      onAudioSelected: (a) => setState(() { _selectedAudioQuality = a; _isAudioOnly = true; _isImageOnly = false; }),
      onImageSelected: (i) => setState(() { _selectedImageQuality = i; _isImageOnly = true; _isAudioOnly = false; }),
    );
  }

  Future<List<DownloadTask>?> _resolveConflicts(List<DownloadTask> tasks) async {
    final conflicting = <DownloadTask>[];
    for (var task in tasks) {
      final safeTitle = task.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim().replaceAll(RegExp(r'_+'), '_');
      final ext = task.isAudioOnly ? (task.audioQualityLabel?.toUpperCase().contains('MP3') == true ? 'mp3' : 'm4a') : (task.videoQualityLabel?.contains('IMG') == true ? 'jpg' : 'mp4');
      final platform = task.platform ?? _detectPlatform(task.videoId);
      final category = task.isAudioOnly ? 'Audios' : (ext == 'jpg' ? 'Images' : 'Videos');
      final path = p.join(task.outputPath ?? _outputPath, 'Downloader', platform, category, '$safeTitle.$ext');
      if (await File(path).exists()) conflicting.add(task);
    }
    if (conflicting.isEmpty) return tasks;
    if (!mounted) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Files Already Exist', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('${conflicting.length == 1 ? "This file" : "${conflicting.length} files"} already exist. What to do?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('Skip Existing')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'rename'), child: const Text('Keep Both')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Overwrite')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return null;
    if (choice == 'skip') {
      final ids = conflicting.map((t) => t.taskId).toSet();
      return tasks.where((t) => !ids.contains(t.taskId)).toList();
    }
    if (choice == 'overwrite') for (var t in tasks) { t.overwriteFile = true; }
    return tasks;
  }

  void _downloadSingle() async {
    if (_singleVideo == null) return;
    final platform = _detectPlatform(_urlController.text);
    final task = DownloadTask(
      taskId: const Uuid().v4(),
      videoId: _singleVideo!.id,
      title: _singleVideo!.title,
      thumbnailUrl: _singleVideo!.thumbnailUrl,
      videoQualityLabel: _isImageOnly 
          ? _selectedImageQuality?.directUrl 
          : (_selectedVideoQuality != null ? '${_selectedVideoQuality!.label}|${_selectedVideoQuality!.height}' : null),
      audioQualityLabel: _selectedAudioQuality?.label,
      isAudioOnly: _isAudioOnly,
      sourceUrl: _isImageOnly ? _selectedImageQuality?.directUrl : null,
      outputPath: _outputPath,
      createdAt: DateTime.now(),
      platform: platform,
    );
    final resolved = await _resolveConflicts([task]);
    if (resolved == null || resolved.isEmpty) return;
    if (!mounted) return;
    context.read<DownloadProvider>().addTask(resolved.first);
    AppNotifications.showSnackBar(context, message: 'Added to Downloading',
        action: SnackBarAction(label: 'View', onPressed: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          context.read<NavigationProvider>().setTab(1);
        }));
  }

  String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'YouTube';
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('instagram.com')) return 'Instagram';
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) return 'Facebook';
    if (lower.contains('twitter.com') || lower.contains('x.com')) return 'Twitter/X';
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.contains('twitch.tv')) return 'Twitch';
    if (lower.contains('soundcloud.com')) return 'SoundCloud';
    if (lower.contains('rumble.com')) return 'Rumble';
    if (lower.contains('bilibili.com') || lower.contains('b23.tv')) return 'Bilibili';
    try { return Uri.parse(url).host.replaceAll('www.', ''); } catch (_) { return 'Universal'; }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(isDark),

            // ── Scrollable content ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  children: [
                    // URL Input
                    _buildUrlInput(isDark),
                    const SizedBox(height: 16),

                    // Error
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                        ]),
                      ).animate().fadeIn().shakeX(hz: 2, amount: 3),

                    // Single video card
                    if (_singleVideo != null)
                      VideoInfoCard(
                        video: _singleVideo!,
                        selectedVideoQuality: _selectedVideoQuality,
                        selectedAudioQuality: _selectedAudioQuality,
                        selectedImageQuality: _selectedImageQuality,
                        isAudioOnly: _isAudioOnly,
                        isImageOnly: _isImageOnly,
                        outputPath: _outputPath,
                        onSelectQuality: _showQualitySheet,
                        onSelectFolder: _selectFolder,
                        onDownload: _downloadSingle,
                      ),

                    // Playlist
                    if (_singleVideo == null)
                      Consumer<PlaylistProvider>(builder: (ctx, pp, _) {
                        final playlist = pp.playlist;
                        if (playlist == null) return const SizedBox.shrink();
                        return Column(children: [
                          VideoInfoCard(
                            video: VideoEntity(
                              id: playlist.id, title: playlist.title, channelName: playlist.channelName,
                              thumbnailUrl: playlist.thumbnailUrl, duration: Duration.zero, viewCount: 0,
                              uploadDate: DateTime.now(), availableQualities: [], availableAudioQualities: [],
                            ),
                            isPlaylist: true, itemCount: playlist.videos.length,
                            selectedCount: pp.selectedVideoIds.length, onToggleAll: pp.toggleAll,
                            selectedVideoQuality: pp.globalVideoQuality ?? _selectedVideoQuality,
                            selectedAudioQuality: pp.globalAudioQuality ?? _selectedAudioQuality,
                            isAudioOnly: pp.globalIsAudioOnly, outputPath: _outputPath,
                            onSelectQuality: () {
                              final sample = playlist.videos.first;
                              final totalSecs = playlist.videos.where((v) => pp.isSelected(v.id)).fold<int>(0, (s, v) => s + v.duration.inSeconds);
                              QualitySelectorSheet.show(ctx,
                                videoQualities: sample.availableQualities.isNotEmpty ? sample.availableQualities : [
                                  VideoQuality(label: '1080p', height: 1080, fps: 60, isMuxed: true, fileSizeBytes: (4000000 * totalSecs) ~/ 8),
                                  VideoQuality(label: '720p', height: 720, fps: 30, isMuxed: true, fileSizeBytes: (2500000 * totalSecs) ~/ 8),
                                  VideoQuality(label: '480p', height: 480, fps: 30, isMuxed: true, fileSizeBytes: (1000000 * totalSecs) ~/ 8),
                                ],
                                audioQualities: sample.availableAudioQualities.isNotEmpty ? sample.availableAudioQualities : [
                                  AudioQuality(label: 'High (320kbps)', bitrate: 320000, format: 'm4a', fileSizeBytes: (320000 * totalSecs) ~/ 8),
                                  AudioQuality(label: 'Standard (128kbps)', bitrate: 128000, format: 'm4a', fileSizeBytes: (128000 * totalSecs) ~/ 8),
                                ],
                                selectedVideoQuality: pp.globalVideoQuality,
                                selectedAudioQuality: pp.globalAudioQuality,
                                isAudioOnly: pp.globalIsAudioOnly,
                                onVideoSelected: (v) => pp.setGlobalSettings(v, pp.globalAudioQuality, false),
                                onAudioSelected: (a) => pp.setGlobalSettings(pp.globalVideoQuality, a, true),
                              );
                            },
                            onSelectFolder: _selectFolder,
                            onDownload: () async {
                              final tasks = pp.createDownloadTasks(_outputPath);
                              final resolved = await _resolveConflicts(tasks);
                              if (resolved == null || resolved.isEmpty) return;
                              if (!ctx.mounted) return;
                              ctx.read<DownloadProvider>().addTasks(resolved);
                              AppNotifications.showSnackBar(ctx, message: 'Added ${resolved.length} videos to Downloading',
                                  action: SnackBarAction(label: 'View', onPressed: () {
                                    Navigator.of(ctx).popUntil((route) => route.isFirst);
                                    ctx.read<NavigationProvider>().setTab(1);
                                  }));
                            },
                          ),
                        ]);
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    const accentColor = Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: accentColor, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0.1)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language_rounded, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Universal Downloader', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accentColor)),
                Text('Works with 1700+ sites via yt-dlp', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  Widget _buildUrlInput(bool isDark) {
    const accentColor = Color(0xFF8B5CF6);
    return Column(
      children: [
        AnimatedContainer(
          duration: 250.ms,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _focusNode.hasFocus ? accentColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: _focusNode.hasFocus ? 2 : 1,
            ),
            boxShadow: _focusNode.hasFocus
                ? [BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.link_rounded, color: _focusNode.hasFocus ? accentColor : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary), size: 20),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) { if (!_isLoading) _fetchUrl(); },
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste any supported URL here…',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  ),
                ),
              ),
              if (_urlController.text.isNotEmpty)
                GestureDetector(
                  onTap: () { _urlController.clear(); setState(() { _singleVideo = null; _errorMessage = null; context.read<PlaylistProvider>().clear(); }); },
                  child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.close_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ),
              GestureDetector(
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) { _urlController.text = data!.text!; setState(() {}); if (!_isLoading && mounted) _fetchUrl(); }
                },
                child: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.content_paste_rounded, size: 16, color: accentColor),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        if (_isLoading) ...[
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: const LinearProgressIndicator(minHeight: 4, backgroundColor: Color(0x1A8B5CF6), valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)))),
          const SizedBox(height: 8),
          Text('Fetching info…', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        ] else if (_urlController.text.isNotEmpty && _singleVideo == null && _errorMessage == null && context.watch<PlaylistProvider>().playlist == null) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _fetchUrl,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Fetch Video Info', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.15, end: 0),
        ],
      ],
    );
  }
}
