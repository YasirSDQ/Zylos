import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/entities/video_entity.dart';

class PlaylistVideoItem extends StatelessWidget {
  final VideoEntity video;
  final int index;
  final bool isSelected;
  final VideoQuality? overrideVideoQuality;
  final AudioQuality? overrideAudioQuality;
  final bool overrideIsAudioOnly;
  final Function(bool?) onToggle;
  final VoidCallback onEditQuality;

  const PlaylistVideoItem({
    super.key,
    required this.video,
    required this.index,
    required this.isSelected,
    this.overrideVideoQuality,
    this.overrideAudioQuality,
    required this.overrideIsAudioOnly,
    required this.onToggle,
    required this.onEditQuality,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasOverride = overrideVideoQuality != null || overrideAudioQuality != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? AppColors.darkCard : AppColors.lightCard)
            : (isDark
                ? AppColors.darkCard.withValues(alpha: 0.3)
                : AppColors.lightCardElevated.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isDark
                  ? AppColors.darkBorder.withValues(alpha: 0.2)
                  : AppColors.lightBorder.withValues(alpha: 0.2)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: InkWell(
        onTap: () => onToggle(!isSelected),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              // Index + Checkbox area
              SizedBox(
                width: 30,
                child: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                    : Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 90,
                  height: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: isDark ? const Color(0xFF1E1E32) : Colors.grey[300]!,
                          highlightColor: isDark ? const Color(0xFF2A2A42) : Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
                          child: const Icon(Icons.broken_image_outlined, size: 20, color: AppColors.darkTextTertiary),
                        ),
                      ),
                      if (!isSelected)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            FormatUtils.formatDuration(video.duration),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                          if (hasOverride) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                overrideIsAudioOnly
                                    ? (overrideAudioQuality?.label ?? 'Audio')
                                    : (overrideVideoQuality?.label ?? 'Video'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Edit quality icon button
              if (isSelected)
                GestureDetector(
                  onTap: onEditQuality,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
