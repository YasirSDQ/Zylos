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
import '../widgets/playlist_video_item.dart';
import '../../../../core/utils/app_notifications.dart';

// ── Platform meta ─────────────────────────────────────────────────────────────
class PlatformMeta {
  final String name;
  final Color color;
  final IconData icon;
  final String hint;
  final String description;
  final List<String> supportedHosts;
  final bool hasWatermarkNote;

  const PlatformMeta({
    required this.name,
    required this.color,
    required this.icon,
    required this.hint,
    required this.description,
    required this.supportedHosts,
    this.hasWatermarkNote = false,
  });

  bool isValidUrl(String url) => supportedHosts.any((h) => url.contains(h));
}

const platformRegistry = {
  'YouTube': PlatformMeta(
    name: 'YouTube', color: Color(0xFFFF0000), icon: Icons.smart_display_rounded,
    hint: 'Paste YouTube URL or playlist link…',
    description: 'Download videos & full playlists in any quality',
    supportedHosts: ['youtube.com', 'youtu.be'],
  ),
  'TikTok': PlatformMeta(
    name: 'TikTok', color: Color(0xFF555555), icon: Icons.music_video_rounded,
    hint: 'Paste TikTok video link…',
    description: 'Download TikTok videos (watermark may appear)',
    supportedHosts: ['tiktok.com', 'vm.tiktok.com'],
    hasWatermarkNote: true,
  ),
  'Facebook': PlatformMeta(
    name: 'Facebook', color: Color(0xFF1877F2), icon: Icons.facebook_rounded,
    hint: 'Paste Facebook video or reel link…',
    description: 'Download public Facebook videos & reels',
    supportedHosts: ['facebook.com', 'fb.watch'],
  ),
  'Instagram': PlatformMeta(
    name: 'Instagram', color: Color(0xFFE1306C), icon: Icons.camera_alt_rounded,
    hint: 'Paste Instagram Reel or post link…',
    description: 'Download Instagram Reels, videos & posts',
    supportedHosts: ['instagram.com'],
  ),
  'Twitter/X': PlatformMeta(
    name: 'Twitter/X', color: Color(0xFF1DA1F2), icon: Icons.alternate_email_rounded,
    hint: 'Paste Twitter / X video tweet link…',
    description: 'Download videos from tweets on Twitter & X',
    supportedHosts: ['twitter.com', 'x.com', 't.co'],
  ),
  'Vimeo': PlatformMeta(
    name: 'Vimeo', color: Color(0xFF19B7EA), icon: Icons.videocam_rounded,
    hint: 'Paste Vimeo video link…',
    description: 'Download HD videos from Vimeo',
    supportedHosts: ['vimeo.com'],
  ),
  'Dailymotion': PlatformMeta(
    name: 'Dailymotion', color: Color(0xFF0066DC), icon: Icons.play_circle_rounded,
    hint: 'Paste Dailymotion video link…',
    description: 'Download videos from Dailymotion',
    supportedHosts: ['dailymotion.com'],
  ),
  'Twitch': PlatformMeta(
    name: 'Twitch', color: Color(0xFF9146FF), icon: Icons.live_tv_rounded,
    hint: 'Paste Twitch clip or VOD link…',
    description: 'Download Twitch clips and VODs',
    supportedHosts: ['twitch.tv', 'clips.twitch.tv'],
  ),
  'Reddit': PlatformMeta(
    name: 'Reddit', color: Color(0xFFFF4500), icon: Icons.reddit_rounded,
    hint: 'Paste Reddit video post link…',
    description: 'Download Reddit video posts',
    supportedHosts: ['reddit.com', 'v.redd.it'],
  ),
  'SoundCloud': PlatformMeta(
    name: 'SoundCloud', color: Color(0xFFFF5500), icon: Icons.audiotrack_rounded,
    hint: 'Paste SoundCloud track link…',
    description: 'Download SoundCloud tracks as audio',
    supportedHosts: ['soundcloud.com'],
  ),
  'Bilibili': PlatformMeta(
    name: 'Bilibili', color: Color(0xFF00A1D6), icon: Icons.smart_display_outlined,
    hint: 'Paste Bilibili video link…',
    description: 'Download Bilibili videos',
    supportedHosts: ['bilibili.com', 'b23.tv'],
  ),
  'Rumble': PlatformMeta(
    name: 'Rumble', color: Color(0xFF85C742), icon: Icons.videocam_rounded,
    hint: 'Paste Rumble video link…',
    description: 'Download videos from Rumble',
    supportedHosts: ['rumble.com'],
  ),
};

// ── Screen ────────────────────────────────────────────────────────────────────
class PlatformDownloaderScreen extends StatefulWidget {
  final String platformName;
  final String? initialUrl;
  const PlatformDownloaderScreen({super.key, required this.platformName, this.initialUrl});

  @override
  State<PlatformDownloaderScreen> createState() => _PlatformDownloaderScreenState();
}

class _PlatformDownloaderScreenState extends State<PlatformDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isValid = false;
  String? _errorMessage;
  VideoEntity? _singleVideo;
  String? _localOutputPath;
  String get _outputPath => _localOutputPath ?? context.read<SettingsProvider>().currentDownloadPath ?? PlatformUtils.getDefaultDownloadPath();

  VideoQuality? _selectedVideoQuality;
  AudioQuality? _selectedAudioQuality;
  ImageQuality? _selectedImageQuality;
  bool _isAudioOnly = false;
  bool _isImageOnly = false;

  PlatformMeta get _meta {
    final meta = platformRegistry[widget.platformName];
    if (meta != null) return meta;
    
    return PlatformMeta(
      name: widget.platformName,
      color: AppColors.primary,
      icon: Icons.language_rounded,
      hint: 'Paste ${widget.platformName} URL here...',
      description: 'Download media from ${widget.platformName}',
      supportedHosts: [widget.platformName.toLowerCase()],
    );
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _isValid = _meta.isValidUrl(widget.initialUrl!);
    }

    // Clear any leftover playlist from a previous platform screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaylistProvider>().clear();
      
      if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty && _isValid) {
        _fetchUrl();
      } else {
        _checkClipboard();
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (_meta.isValidUrl(text)) {
      if (!mounted) return;
      setState(() { _urlController.text = text; _isValid = true; });
    }
  }

  void _validateUrl(String text) {
    setState(() => _isValid = _meta.isValidUrl(text));
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
      if (mounted) setState(() => _errorMessage = 'Failed to fetch info. Check the URL and try again.');
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

    // Dedup by label (keep highest fps), then sort highest → lowest
    final Map<String, VideoQuality> vMap = {};
    for (final q in _singleVideo!.availableQualities) {
      if (!vMap.containsKey(q.label) || q.fps > vMap[q.label]!.fps) {
        vMap[q.label] = q;
      }
    }
    final dedupedVideo = vMap.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));

    // Dedup audio by label (keep first seen)
    final Map<String, AudioQuality> aMap = {};
    for (final q in _singleVideo!.availableAudioQualities) {
      aMap.putIfAbsent(q.label, () => q);
    }
    final dedupedAudio = aMap.values.toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

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
      final category = task.isAudioOnly ? 'Audios' : (ext == 'jpg' ? 'Images' : 'Videos');
      final path = p.join(task.outputPath ?? _outputPath, 'Downloader', widget.platformName, category, '$safeTitle.$ext');
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
        content: Text('${conflicting.length == 1 ? "This video" : "${conflicting.length} videos"} already exist. What to do?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('Skip Existing')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'rename'), child: const Text('Keep Both')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white), child: const Text('Overwrite')),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return null;
    if (choice == 'skip') { final ids = conflicting.map((t) => t.taskId).toSet(); return tasks.where((t) => !ids.contains(t.taskId)).toList(); }
    if (choice == 'overwrite') {
      for (var t in tasks) { t.overwriteFile = true; }
    }
    return tasks;
  }

  void _downloadSingle() async {
    if (_singleVideo == null) return;
    final task = DownloadTask(
      taskId: const Uuid().v4(), videoId: _singleVideo!.id, title: _singleVideo!.title,
      thumbnailUrl: _singleVideo!.thumbnailUrl, 
      videoQualityLabel: _isImageOnly 
          ? _selectedImageQuality?.directUrl 
          : (_selectedVideoQuality != null ? '${_selectedVideoQuality!.label}|${_selectedVideoQuality!.height}' : null),
      audioQualityLabel: _selectedAudioQuality?.label, isAudioOnly: _isAudioOnly,
      sourceUrl: _isImageOnly ? _selectedImageQuality?.directUrl : null,
      outputPath: _outputPath, createdAt: DateTime.now(),
      platform: widget.platformName,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _meta;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(children: [
          // ── Header bar ────────────────────────────────────────
          _buildHeader(isDark, meta),

          // ── Scrollable content ────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(children: [
              // Watermark note for TikTok
              if (meta.hasWatermarkNote) _WatermarkNote(color: meta.color),

              // ── URL Input ────────────────────────────────────
              _buildUrlInput(isDark, meta),
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
                  video: _singleVideo!, selectedVideoQuality: _selectedVideoQuality,
                  selectedAudioQuality: _selectedAudioQuality, selectedImageQuality: _selectedImageQuality, 
                  isAudioOnly: _isAudioOnly, isImageOnly: _isImageOnly,
                  outputPath: _outputPath, onSelectQuality: _showQualitySheet,
                  onSelectFolder: _selectFolder, onDownload: _downloadSingle,
                ),

              // Playlist
              if (_singleVideo == null)
                Consumer<PlaylistProvider>(builder: (ctx, pp, _) {
                  final playlist = pp.playlist;
                  if (playlist == null) return const SizedBox.shrink();
                  return Column(children: [
                    VideoInfoCard(
                      video: VideoEntity(id: playlist.id, title: playlist.title, channelName: playlist.channelName,
                          thumbnailUrl: playlist.thumbnailUrl, duration: Duration.zero, viewCount: 0,
                          uploadDate: DateTime.now(), availableQualities: [], availableAudioQualities: []),
                      isPlaylist: true, itemCount: playlist.videos.length, selectedCount: pp.selectedVideoIds.length,
                      onToggleAll: pp.toggleAll,
                      selectedVideoQuality: pp.globalVideoQuality ?? _selectedVideoQuality,
                      selectedAudioQuality: pp.globalAudioQuality ?? _selectedAudioQuality,
                      isAudioOnly: pp.globalIsAudioOnly, outputPath: _outputPath,
                      onSelectQuality: () {
                        final sample = playlist.videos.first;
                        final totalSecs = playlist.videos.where((v) => pp.isSelected(v.id)).fold<int>(0, (s, v) => s + v.duration.inSeconds);
                        QualitySelectorSheet.show(ctx,
                          videoQualities: sample.availableQualities.isNotEmpty ? sample.availableQualities : [
                            VideoQuality(label: '4K', height: 2160, fps: 60, isMuxed: true, fileSizeBytes: (15000000 * totalSecs) ~/ 8),
                            VideoQuality(label: '1440p', height: 1440, fps: 60, isMuxed: true, fileSizeBytes: (8000000 * totalSecs) ~/ 8),
                            VideoQuality(label: '1080p', height: 1080, fps: 60, isMuxed: true, fileSizeBytes: (4000000 * totalSecs) ~/ 8),
                            VideoQuality(label: '720p', height: 720, fps: 30, isMuxed: true, fileSizeBytes: (2500000 * totalSecs) ~/ 8),
                            VideoQuality(label: '480p', height: 480, fps: 30, isMuxed: true, fileSizeBytes: (1000000 * totalSecs) ~/ 8),
                            VideoQuality(label: '360p', height: 360, fps: 30, isMuxed: true, fileSizeBytes: (500000 * totalSecs) ~/ 8),
                            VideoQuality(label: '144p', height: 144, fps: 30, isMuxed: true, fileSizeBytes: (100000 * totalSecs) ~/ 8),
                          ],
                          audioQualities: sample.availableAudioQualities.isNotEmpty ? sample.availableAudioQualities : [
                            AudioQuality(label: 'High (320kbps)', bitrate: 320000, format: 'm4a', fileSizeBytes: (320000 * totalSecs) ~/ 8),
                            AudioQuality(label: 'Standard (128kbps)', bitrate: 128000, format: 'm4a', fileSizeBytes: (128000 * totalSecs) ~/ 8),
                            AudioQuality(label: 'Low (64kbps)', bitrate: 64000, format: 'm4a', fileSizeBytes: (64000 * totalSecs) ~/ 8),
                          ],
                          selectedVideoQuality: pp.globalVideoQuality, selectedAudioQuality: pp.globalAudioQuality,
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
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text('Manage Videos (${playlist.videos.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                        initiallyExpanded: false,
                        children: [
                          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            itemCount: playlist.videos.length,
                            itemBuilder: (ctx2, i) {
                              final v = playlist.videos[i];
                              return PlaylistVideoItem(
                                video: v, index: i, isSelected: pp.isSelected(v.id),
                                overrideVideoQuality: pp.getVideoQuality(v.id), overrideAudioQuality: pp.getAudioQuality(v.id),
                                overrideIsAudioOnly: pp.isAudioOnly(v.id), onToggle: (_) => pp.toggleVideo(v.id),
                                onEditQuality: () {
                                  final secs = v.duration.inSeconds;
                                  QualitySelectorSheet.show(ctx2,
                                    videoQualities: v.availableQualities.isNotEmpty ? v.availableQualities : [
                                      VideoQuality(label: '4K', height: 2160, fps: 60, isMuxed: true, fileSizeBytes: (15000000 * secs) ~/ 8),
                                      VideoQuality(label: '1440p', height: 1440, fps: 60, isMuxed: true, fileSizeBytes: (8000000 * secs) ~/ 8),
                                      VideoQuality(label: '1080p', height: 1080, fps: 60, isMuxed: true, fileSizeBytes: (4000000 * secs) ~/ 8),
                                      VideoQuality(label: '720p', height: 720, fps: 30, isMuxed: true, fileSizeBytes: (2500000 * secs) ~/ 8),
                                      VideoQuality(label: '480p', height: 480, fps: 30, isMuxed: true, fileSizeBytes: (1000000 * secs) ~/ 8),
                                      VideoQuality(label: '360p', height: 360, fps: 30, isMuxed: true, fileSizeBytes: (500000 * secs) ~/ 8),
                                      VideoQuality(label: '144p', height: 144, fps: 30, isMuxed: true, fileSizeBytes: (100000 * secs) ~/ 8),
                                    ],
                                    audioQualities: v.availableAudioQualities.isNotEmpty ? v.availableAudioQualities : [
                                      AudioQuality(label: 'High (320kbps)', bitrate: 320000, format: 'm4a', fileSizeBytes: (320000 * secs) ~/ 8),
                                      AudioQuality(label: 'Standard (128kbps)', bitrate: 128000, format: 'm4a', fileSizeBytes: (128000 * secs) ~/ 8),
                                      AudioQuality(label: 'Low (64kbps)', bitrate: 64000, format: 'm4a', fileSizeBytes: (64000 * secs) ~/ 8),
                                    ],
                                    selectedVideoQuality: pp.getVideoQuality(v.id) ?? pp.globalVideoQuality,
                                    selectedAudioQuality: pp.getAudioQuality(v.id) ?? pp.globalAudioQuality,
                                    isAudioOnly: pp.isAudioOnly(v.id),
                                    onVideoSelected: (vq) => pp.setVideoOverride(v.id, vq, null, false),
                                    onAudioSelected: (aq) => pp.setVideoOverride(v.id, null, aq, true),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ]);
                }),
            ]),
          )),
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, PlatformMeta meta) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(bottom: BorderSide(color: meta.color.withValues(alpha: 0.2), width: 1)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: meta.color, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(meta.icon, color: meta.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meta.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: meta.color)),
          Text(meta.description, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        ])),
      ]),
    ).animate().fadeIn().slideY(begin: -0.05);
  }

  // ── URL Input ────────────────────────────────────────────────────────────────
  Widget _buildUrlInput(bool isDark, PlatformMeta meta) {
    return Column(children: [
      AnimatedContainer(
        duration: 250.ms,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _focusNode.hasFocus ? meta.color : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: _focusNode.hasFocus ? 2 : 1),
          boxShadow: _focusNode.hasFocus ? [BoxShadow(color: meta.color.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.link_rounded, color: _focusNode.hasFocus ? meta.color : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary), size: 20),
          Expanded(child: TextField(
            controller: _urlController,
            focusNode: _focusNode,
            onChanged: _validateUrl,
            onSubmitted: (_) { if (_isValid && !_isLoading) _fetchUrl(); },
            style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: meta.hint,
              hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontSize: 13),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            ),
          )),
          if (_urlController.text.isNotEmpty)
            GestureDetector(
              onTap: () { _urlController.clear(); setState(() { _isValid = false; _singleVideo = null; _errorMessage = null; context.read<PlaylistProvider>().clear(); }); },
              child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.close_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
            ),
          GestureDetector(
            onTap: () async {
              final data = await Clipboard.getData('text/plain');
              if (data?.text != null) { _urlController.text = data!.text!; _validateUrl(data.text!); if (_isValid && !_isLoading && mounted) _fetchUrl(); }
            },
            child: Container(
              margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.content_paste_rounded, size: 16, color: meta.color),
            ),
          ),
          const SizedBox(width: 4),
        ]),
      ),

      if (_isLoading) ...[
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 4, backgroundColor: meta.color.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(meta.color))),
        const SizedBox(height: 8),
        Text('Fetching video info…', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
      ] else if (_isValid && _singleVideo == null && _errorMessage == null && context.watch<PlaylistProvider>().playlist == null) ...[
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _fetchUrl,
          child: Container(
            width: double.infinity, height: 52,
            decoration: BoxDecoration(
              color: meta.color, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: meta.color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text('Fetch Video Info', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ).animate().fadeIn().slideY(begin: 0.15, end: 0),
      ],
    ]);
  }
}

// ── Watermark note ────────────────────────────────────────────────────────────
class _WatermarkNote extends StatelessWidget {
  final Color color;
  const _WatermarkNote({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text('TikTok videos may include a watermark. The download will save the video as-is from TikTok.',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
      ]),
    ).animate().fadeIn();
  }
}
