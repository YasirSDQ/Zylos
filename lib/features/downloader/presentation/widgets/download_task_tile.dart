import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../domain/entities/download_task.dart';
import '../providers/download_provider.dart';

class DownloadTaskTile extends StatelessWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  Color get _statusColor {
    switch (task.status) {
      case DownloadStatus.queued:
        return AppColors.info;
      case DownloadStatus.fetchingInfo:
        return AppColors.accent;
      case DownloadStatus.downloading:
        return const Color(0xFF5ED1CC);
      case DownloadStatus.merging:
        return Colors.deepPurple;
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.done:
        return AppColors.success;
      case DownloadStatus.failed:
        return AppColors.error;
      case DownloadStatus.retrying:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<DownloadProvider>();
    final isSelected = provider.selectedTaskIds.contains(task.taskId);
    final isSelectionMode = provider.isSelectionMode;

    final isActive = task.status == DownloadStatus.downloading || 
                     task.status == DownloadStatus.merging || 
                     task.status == DownloadStatus.fetchingInfo || 
                     task.status == DownloadStatus.retrying;
    final isPaused = task.status == DownloadStatus.paused;
    final isDone = task.status == DownloadStatus.done;
    final isFailed = task.status == DownloadStatus.failed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isActive ? (isDark ? const Color(0xFF1E2828) : const Color(0xFFE0F2F1)) : (isDark ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? AppColors.primary
              : isActive ? const Color(0xFF5ED1CC).withValues(alpha: 0.6) 
              : isPaused ? Colors.amber.withValues(alpha: 0.6)
              : isDone ? const Color(0xFF10B981).withValues(alpha: 0.3) 
              : isFailed ? AppColors.error.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: (isActive || isDone || isFailed || isSelected) ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: (isPaused ? Colors.amber : const Color(0xFF5ED1CC)).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 2),
          if (!isPaused) BoxShadow(color: const Color(0xFF5ED1CC).withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 4),
        ] : isSelected ? [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 6)),
        ] : isDone ? [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1),
        ] : isFailed ? [
          BoxShadow(color: AppColors.error.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1),
        ] : [
          BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          InkWell(
            onLongPress: () => provider.toggleTaskSelection(task.taskId),
            onTap: isSelectionMode ? () => provider.toggleTaskSelection(task.taskId) : null,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: thumbnail + info + actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection checkbox
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.darkBorder,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                            : null,
                      ),
                    ),

                  // Thumbnail
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 100,
                        height: 64,
                        child: CachedNetworkImage(
                          imageUrl: task.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                            child: const Icon(Icons.video_library_outlined, color: AppColors.darkTextTertiary, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _QualityBadge(
                              label: task.isAudioOnly
                                  ? (task.audioQualityLabel?.split('|').first ?? 'Audio')
                                  : (task.videoQualityLabel?.split('|').first ?? 'Video'),
                              isDark: isDark,
                            ),
                            if (task.totalBytes > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                FormatUtils.formatBytes(task.totalBytes),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            _StatusBadge(task: task, color: _statusColor),
                            if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging) ...[
                               const SizedBox(width: 8),
                               Expanded(
                                 child: Row(
                                   children: [
                                     Text(
                                       '${(task.progress * 100).toInt()}%',
                                       style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _statusColor),
                                     ),
                                     const SizedBox(width: 8),
                                     Expanded(
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Expanded(
                                             child: Text(
                                               '${FormatUtils.formatSpeed(task.speedBytesPerSecond)} - ${FormatUtils.formatBytes(task.downloadedBytes)} / ${task.totalBytes > 0 ? FormatUtils.formatBytes(task.totalBytes) : '? MB'}',
                                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                                               maxLines: 1,
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                           const SizedBox(width: 8),
                                           Text(
                                             FormatUtils.formatEta(task.eta),
                                             style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                                           ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  _TaskActions(task: task, provider: provider),
                ],
              ),

              // Bottom actions depending on status
              if (task.status == DownloadStatus.done) ...[
                const SizedBox(height: 10),
                _DoneActions(task: task),
              ] else if (task.status == DownloadStatus.failed) ...[
                const SizedBox(height: 10),
                _FailedSection(task: task, provider: provider),
              ],
            ],
          ),
          ),
          ),
          
          if ((isActive || isPaused) && task.progress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuad,
                  alignment: Alignment.centerLeft,
                  widthFactor: task.progress.clamp(0.0, 1.0),
                  child: isPaused 
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.withValues(alpha: 0.15), Colors.amber.withValues(alpha: 0.25)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF5ED1CC).withValues(alpha: isDark ? 0.2 : 0.1),
                              const Color(0xFF5ED1CC).withValues(alpha: isDark ? 0.35 : 0.15),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                        duration: const Duration(milliseconds: 2000), 
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _QualityBadge extends StatelessWidget {
  final String label;
  final bool isDark;

  const _QualityBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DownloadTask task;
  final Color color;

  const _StatusBadge({required this.task, required this.color});

  String get _label {
    switch (task.status) {
      case DownloadStatus.queued:
        return 'IN QUEUE';
      case DownloadStatus.fetchingInfo:
        return 'FETCHING INFO';
      case DownloadStatus.downloading:
        return 'DOWNLOADING';
      case DownloadStatus.merging:
        return 'MERGING';
      case DownloadStatus.paused:
        return 'PAUSED';
      case DownloadStatus.done:
        return 'DONE';
      case DownloadStatus.failed:
        return 'FAILED';
      case DownloadStatus.retrying:
        return 'RETRYING';
    }
  }

  bool get _animate =>
      task.status == DownloadStatus.downloading || 
      task.status == DownloadStatus.merging || 
      task.status == DownloadStatus.fetchingInfo ||
      task.status == DownloadStatus.retrying;

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );

    if (_animate) {
      badge = badge.animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1400.ms, color: Colors.white24);
    }

    return badge;
  }
}

class _TaskActions extends StatelessWidget {
  final DownloadTask task;
  final DownloadProvider provider;

  const _TaskActions({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.downloading || 
            task.status == DownloadStatus.merging ||
            task.status == DownloadStatus.fetchingInfo ||
            task.status == DownloadStatus.retrying)
          _ActionBtn(
            icon: Icons.pause_rounded,
            color: AppColors.warning,
            onTap: () => provider.pauseTask(task.taskId),
            tooltip: 'Pause',
          )
        else if (task.status == DownloadStatus.paused)
          _ActionBtn(
            icon: Icons.play_arrow_rounded,
            color: AppColors.success,
            onTap: () => provider.resumeTask(task.taskId),
            tooltip: 'Resume',
          )
        else if (task.status == DownloadStatus.queued)
          _ActionBtn(
            icon: Icons.play_circle_fill_rounded,
            color: AppColors.info,
            onTap: () => provider.forceStartTask(task.taskId),
            tooltip: 'Start Now',
          ),
        const SizedBox(height: 4),
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.merging ||
            task.status == DownloadStatus.fetchingInfo ||
            task.status == DownloadStatus.retrying ||
            task.status == DownloadStatus.queued)
          _ActionBtn(
            icon: Icons.close_rounded,
            color: AppColors.darkTextTertiary,
            onTap: () => provider.cancelTask(task.taskId),
            tooltip: 'Cancel',
          )
        else if (task.status == DownloadStatus.done ||
            task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.paused)
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            color: AppColors.darkTextTertiary,
            onTap: () => provider.removeTask(task.taskId),
            tooltip: 'Remove',
          ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 150.ms,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final DownloadTask task;
  final Color statusColor;

  const _ProgressSection({required this.task, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final downloaded = FormatUtils.formatBytes(task.downloadedBytes);
    final total = FormatUtils.formatBytes(task.totalBytes);
    final hasSize = task.totalBytes > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final isMerging = task.status == DownloadStatus.merging;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row — fixed so nothing overlaps
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: percentage + speed + bytes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${(task.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          FormatUtils.formatSpeed(task.speedBytesPerSecond),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dimColor),
                        ),
                      ),
                    ],
                  ),
                  if (hasSize) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$downloaded / $total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tertiaryColor),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right side: ETA / status — fixed width so it can't squeeze left content
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isMerging ? 'Merging...' : FormatUtils.formatEta(task.eta),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dimColor),
                ),
                if (task.status == DownloadStatus.fetchingInfo)
                  Text(
                    'Preparing...',
                    style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneActions extends StatelessWidget {
  final DownloadTask task;

  const _DoneActions({required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TextActionButton(
          icon: Icons.play_circle_fill_rounded,
          label: 'Play',
          color: AppColors.success,
          onTap: () {
            if (task.outputPath != null) PlatformUtils.openVideoFile(task.outputPath!);
          },
        ),
        const SizedBox(width: 8),
        _TextActionButton(
          icon: Icons.folder_open_rounded,
          label: 'Folder',
          color: AppColors.info,
          onTap: () {
            if (task.outputPath != null) PlatformUtils.openFileInExplorer(task.outputPath!);
          },
        ),
      ],
    );
  }
}

class _FailedSection extends StatelessWidget {
  final DownloadTask task;
  final DownloadProvider provider;

  const _FailedSection({required this.task, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.errorMessage != null) ...[
          Text(
            task.errorMessage!.length > 80
                ? '${task.errorMessage!.substring(0, 80)}…'
                : task.errorMessage!,
            style: const TextStyle(fontSize: 11, color: AppColors.error),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _TextActionButton(
              icon: Icons.refresh_rounded,
              label: 'Retry',
              color: AppColors.primary,
              onTap: () => provider.retryTask(task.taskId),
            ),
            const SizedBox(width: 8),
            _TextActionButton(
              icon: Icons.close_rounded,
              label: 'Remove',
              color: AppColors.darkTextTertiary,
              onTap: () => provider.removeTask(task.taskId),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
