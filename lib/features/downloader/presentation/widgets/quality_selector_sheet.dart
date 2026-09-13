import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/video_entity.dart';

class QualitySelectorSheet extends StatelessWidget {
  final List<VideoQuality> videoQualities;
  final List<AudioQuality> audioQualities;
  final List<ImageQuality>? imageQualities;
  final VideoQuality? selectedVideoQuality;
  final AudioQuality? selectedAudioQuality;
  final ImageQuality? selectedImageQuality;
  final bool isAudioOnly;
  final bool isImageOnly;
  final Function(VideoQuality)? onVideoSelected;
  final Function(AudioQuality)? onAudioSelected;
  final Function(ImageQuality)? onImageSelected;

  const QualitySelectorSheet({
    super.key,
    required this.videoQualities,
    required this.audioQualities,
    this.imageQualities,
    required this.selectedVideoQuality,
    required this.selectedAudioQuality,
    this.selectedImageQuality,
    required this.isAudioOnly,
    this.isImageOnly = false,
    this.onVideoSelected,
    this.onAudioSelected,
    this.onImageSelected,
  });

  static void show(
    BuildContext context, {
    required List<VideoQuality> videoQualities,
    required List<AudioQuality> audioQualities,
    List<ImageQuality>? imageQualities,
    required VideoQuality? selectedVideoQuality,
    required AudioQuality? selectedAudioQuality,
    ImageQuality? selectedImageQuality,
    required bool isAudioOnly,
    bool isImageOnly = false,
    Function(VideoQuality)? onVideoSelected,
    Function(AudioQuality)? onAudioSelected,
    Function(ImageQuality)? onImageSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) => _SheetContent(
          scrollController: controller,
          videoQualities: videoQualities,
          audioQualities: audioQualities,
          imageQualities: imageQualities ?? [],
          selectedVideoQuality: selectedVideoQuality,
          selectedAudioQuality: selectedAudioQuality,
          selectedImageQuality: selectedImageQuality,
          initialIsAudioOnly: isAudioOnly,
          initialIsImageOnly: isImageOnly,
          onVideoSelected: onVideoSelected,
          onAudioSelected: onAudioSelected,
          onImageSelected: onImageSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _SheetContent extends StatefulWidget {
  final ScrollController scrollController;
  final List<VideoQuality> videoQualities;
  final List<AudioQuality> audioQualities;
  final List<ImageQuality> imageQualities;
  final VideoQuality? selectedVideoQuality;
  final AudioQuality? selectedAudioQuality;
  final ImageQuality? selectedImageQuality;
  final bool initialIsAudioOnly;
  final bool initialIsImageOnly;
  final Function(VideoQuality)? onVideoSelected;
  final Function(AudioQuality)? onAudioSelected;
  final Function(ImageQuality)? onImageSelected;

  const _SheetContent({
    required this.scrollController,
    required this.videoQualities,
    required this.audioQualities,
    required this.imageQualities,
    required this.selectedVideoQuality,
    required this.selectedAudioQuality,
    required this.selectedImageQuality,
    required this.initialIsAudioOnly,
    required this.initialIsImageOnly,
    required this.onVideoSelected,
    required this.onAudioSelected,
    required this.onImageSelected,
  });

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  // 0: Video, 1: Audio, 2: Image
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsImageOnly && widget.imageQualities.isNotEmpty) {
      _currentTab = 2;
    } else if (widget.initialIsAudioOnly) {
      _currentTab = 1;
    } else {
      _currentTab = 0;
    }
    // Fallback if requested tab is completely empty
    if (_currentTab == 0 && widget.videoQualities.isEmpty && widget.imageQualities.isNotEmpty) _currentTab = 2;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool hasImages = widget.imageQualities.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Select Quality',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Toggle: Video / Audio / Image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (widget.videoQualities.isNotEmpty)
                    _ToggleTab(
                      label: 'Video',
                      icon: Icons.video_library_rounded,
                      isSelected: _currentTab == 0,
                      onTap: () => setState(() => _currentTab = 0),
                    ),
                  if (widget.audioQualities.isNotEmpty)
                    _ToggleTab(
                      label: 'Audio',
                      icon: Icons.music_note_rounded,
                      isSelected: _currentTab == 1,
                      onTap: () => setState(() => _currentTab = 1),
                    ),
                  if (hasImages)
                    _ToggleTab(
                      label: 'Image',
                      icon: Icons.image_rounded,
                      isSelected: _currentTab == 2,
                      onTap: () => setState(() => _currentTab = 2),
                    ),
                ],
              ),
            ),
          ),

          // Quality list
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _currentTab == 0
                  ? _buildVideoList()
                  : (_currentTab == 1 ? _buildAudioList() : _buildImageList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ListView.builder(
      key: const ValueKey('video'),
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: widget.videoQualities.length,
      itemBuilder: (context, i) {
        final q = widget.videoQualities[i];
        final isSelected = q == widget.selectedVideoQuality && _currentTab == 0;
        final isBest = i == 0;
        final isRecommended = q.height == 1080 && i != 0;

        return _QualityTile(
          title: q.label,
          subtitle: q.fps > 30 ? '${q.fps} fps' : '',
          sizeLabel: q.fileSizeBytes != null ? FormatUtils.formatBytes(q.fileSizeBytes!) : 'Unknown',
          isSelected: isSelected,
          badge: isBest ? 'BEST' : (isRecommended ? 'REC' : null),
          badgeColor: isBest ? AppColors.warning : AppColors.accent,
          icon: Icons.videocam_rounded,
          onTap: () {
            widget.onVideoSelected?.call(q);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildAudioList() {
    return ListView.builder(
      key: const ValueKey('audio'),
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: widget.audioQualities.length,
      itemBuilder: (context, i) {
        final q = widget.audioQualities[i];
        final isSelected = q == widget.selectedAudioQuality && _currentTab == 1;
        final isBest = i == 0;

        return _QualityTile(
          title: q.label,
          subtitle: q.format.toUpperCase(),
          sizeLabel: q.fileSizeBytes != null ? FormatUtils.formatBytes(q.fileSizeBytes!) : 'Unknown',
          isSelected: isSelected,
          badge: isBest ? 'BEST' : null,
          badgeColor: AppColors.success,
          icon: Icons.music_note_rounded,
          onTap: () {
            widget.onAudioSelected?.call(q);
            Navigator.pop(context);
          },
        );
      },
    );
  }
  
  Widget _buildImageList() {
    return ListView.builder(
      key: const ValueKey('image'),
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: widget.imageQualities.length,
      itemBuilder: (context, i) {
        final q = widget.imageQualities[i];
        final isSelected = q == widget.selectedImageQuality && _currentTab == 2;
        final isBest = i == 0; // Usually highest res is first

        return _QualityTile(
          title: q.label,
          subtitle: q.ext.toUpperCase(),
          sizeLabel: q.fileSize ?? 'Unknown',
          isSelected: isSelected,
          badge: isBest ? 'BEST' : null,
          badgeColor: AppColors.primary,
          icon: Icons.image_rounded,
          onTap: () {
            widget.onImageSelected?.call(q);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.brandGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sizeLabel;
  final bool isSelected;
  final String? badge;
  final Color badgeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _QualityTile({
    required this.title,
    required this.subtitle,
    required this.sizeLabel,
    required this.isSelected,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkSurface : AppColors.lightCardElevated),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Size pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                ),
              ),
              child: Text(
                sizeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
