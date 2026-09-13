import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/video_entity.dart';

class VideoInfoCard extends StatefulWidget {
  final VideoEntity video;
  final VideoQuality? selectedVideoQuality;
  final AudioQuality? selectedAudioQuality;
  final ImageQuality? selectedImageQuality;
  final bool isAudioOnly;
  final bool isImageOnly;
  final String outputPath;
  final VoidCallback? onSelectQuality;
  final VoidCallback onSelectFolder;
  final VoidCallback onDownload;
  final bool isPlaylist;
  final int? itemCount;
  final int? selectedCount;
  final VoidCallback? onToggleAll;

  const VideoInfoCard({
    super.key,
    required this.video,
    this.selectedVideoQuality,
    this.selectedAudioQuality,
    this.selectedImageQuality,
    this.isAudioOnly = false,
    this.isImageOnly = false,
    required this.outputPath,
    this.onSelectQuality,
    required this.onSelectFolder,
    required this.onDownload,
    this.isPlaylist = false,
    this.itemCount,
    this.selectedCount,
    this.onToggleAll,
  });

  @override
  State<VideoInfoCard> createState() => _VideoInfoCardState();
}

class _VideoInfoCardState extends State<VideoInfoCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder.withValues(alpha: 0.5) : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Area ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail left
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 240,
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: widget.video.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: isDark ? const Color(0xFF1E1E32) : Colors.grey[300]!,
                              highlightColor: isDark ? const Color(0xFF2A2A42) : Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
                              child: const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.darkTextTertiary),
                            ),
                          ),
                        ),
                        if (!widget.isPlaylist)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                FormatUtils.formatDuration(widget.video.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info right
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isPlaylist)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.itemCount} videos',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.isPlaylist) const SizedBox(height: 12),
                      Text(
                        widget.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: isDark ? Colors.white70 : AppColors.lightTextSecondary, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.video.channelName,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Controls Panel ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quality + Folder
                Row(
                  children: [
                    Expanded(
                      child: _ActionChip(
                        icon: widget.isImageOnly ? Icons.image_rounded : (widget.isAudioOnly ? Icons.music_note_rounded : Icons.hd_rounded),
                        subtitle: 'Quality',
                        label: widget.isImageOnly
                            ? (widget.selectedImageQuality?.label ?? 'Select Image')
                            : (widget.isAudioOnly
                                ? (widget.selectedAudioQuality?.label ?? 'Select Quality')
                                : '${widget.selectedVideoQuality?.label ?? '720p'} • MP4'),
                        accent: AppColors.accent,
                        onTap: widget.onSelectQuality,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.folder_open_rounded,
                        subtitle: 'Location',
                        label: 'Change Folder',
                        accent: AppColors.info,
                        onTap: widget.onSelectFolder,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                // Output path subtext
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drive_folder_upload_rounded,
                        size: 12,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.outputPath,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Playlist selection row
                if (widget.isPlaylist) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.selectedCount ?? 0} of ${widget.itemCount ?? 0} selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onToggleAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (widget.selectedCount ?? 0) == (widget.itemCount ?? 0)
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ── Download CTA ────────────────────────────────
                _DownloadButton(
                  isPlaylist: widget.isPlaylist,
                  onPressed: widget.onDownload,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool isDark;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.accent,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : AppColors.lightTextSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : AppColors.lightTextTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final bool isPlaylist;
  final VoidCallback onPressed;

  const _DownloadButton({required this.isPlaylist, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPlaylist ? Icons.playlist_add_check_rounded : Icons.download_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              isPlaylist ? 'Download Selection' : 'Download Now',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(delay: 150.ms, begin: const Offset(0.96, 0.96), end: const Offset(1, 1));
  }
}
