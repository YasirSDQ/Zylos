import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/download_provider.dart';
import '../../domain/entities/download_task.dart';
import 'download_task_tile.dart';

class DownloadQueuePanel extends StatelessWidget {
  const DownloadQueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final displayTasks = provider.displayTasks;

        if (displayTasks.isEmpty) {
          return _EmptyState();
        }

        // Group tasks while preserving insertion order
        final List<dynamic> listItems = [];
        final Map<String, List<DownloadTask>> playlistGroups = {};

        for (final task in displayTasks) {
          if (task.playlistId != null && task.playlistId!.isNotEmpty) {
            if (!playlistGroups.containsKey(task.playlistId!)) {
              playlistGroups[task.playlistId!] = [];
              listItems.add(task.playlistId!); // Add placeholder for the group
            }
            playlistGroups[task.playlistId!]!.add(task);
          } else {
            listItems.add(task); // Individual video
          }
        }

        return Column(
          children: [
            _QueueHeader(provider: provider),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: listItems.length,
                itemBuilder: (context, index) {
                  final item = listItems[index];
                  if (item is DownloadTask) {
                    return DownloadTaskTile(task: item, key: ValueKey(item.taskId));
                  } else if (item is String) {
                    final tasks = playlistGroups[item]!;
                    return _PlaylistGroupTile(
                      playlistId: item,
                      tasks: tasks,
                      key: ValueKey('group_$item'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 50,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.96, end: 1.02, duration: 2000.ms, curve: Curves.easeInOut),
            const SizedBox(height: 28),
            Text(
              'No Active Downloads',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            Text(
              'Paste a YouTube link on the\nHome tab to start downloading.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  final DownloadProvider provider;
  const _QueueHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        child: Row(
          children: [
            // Logo + Title
            Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Downloads',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                    ),
                    Text(
                      '${provider.displayTasks.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Pause All
            _HeaderIconButton(
              icon: Icons.pause_circle_outline_rounded,
              color: AppColors.warning,
              tooltip: 'Pause All',
              onTap: () => provider.pauseAll(),
            ),
            const SizedBox(width: 4),
            // Resume All
            _HeaderIconButton(
              icon: Icons.play_circle_outline_rounded,
              color: AppColors.success,
              tooltip: 'Resume All',
              onTap: () => provider.resumeAll(),
            ),
            const SizedBox(width: 4),
            // Clear All
            _HeaderIconButton(
              icon: Icons.delete_sweep_rounded,
              color: AppColors.error,
              tooltip: 'Clear All',
              onTap: () => _confirmClearAll(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, DownloadProvider provider) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Downloads?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Active downloads will be cancelled. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, bottom: 4),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) provider.clearAll();
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _PlaylistGroupTile extends StatefulWidget {
  final String playlistId;
  final List<DownloadTask> tasks;

  const _PlaylistGroupTile({
    super.key,
    required this.playlistId,
    required this.tasks,
  });

  @override
  State<_PlaylistGroupTile> createState() => _PlaylistGroupTileState();
}

class _PlaylistGroupTileState extends State<_PlaylistGroupTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Aggregate calculations
    final totalTasks = widget.tasks.length;
    final completedTasks = widget.tasks.where((t) => t.status == DownloadStatus.done).length;
    final failedTasks = widget.tasks.where((t) => t.status == DownloadStatus.failed).length;
    final inProgressTasks = widget.tasks.where((t) => 
      t.status == DownloadStatus.downloading || 
      t.status == DownloadStatus.merging || 
      t.status == DownloadStatus.fetchingInfo).length;
      
    final playlistTitle = widget.tasks.first.playlistTitle ?? 'YouTube Playlist';
    final thumbnailUrl = widget.tasks.first.thumbnailUrl;

    double totalProgress = 0.0;
    for (final t in widget.tasks) {
      totalProgress += t.progress;
    }
    final avgProgress = totalProgress / totalTasks;
    
    // Status color logic
    Color statusColor = AppColors.primary;
    if (failedTasks > 0) statusColor = AppColors.error;
    else if (completedTasks == totalTasks) statusColor = AppColors.success;
    else if (inProgressTasks == 0 && completedTasks == 0) statusColor = AppColors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbnailUrl.isNotEmpty 
                      ? Image.network(
                          thumbnailUrl, 
                          width: 80, 
                          height: 45, 
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackThumb(isDark),
                        )
                      : _buildFallbackThumb(isDark),
                  ),
                  const SizedBox(width: 14),
                  
                  // Text and Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlistTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.playlist_play_rounded, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              '$completedTasks / $totalTasks completed',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(avgProgress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: avgProgress.clamp(0.0, 1.0),
                            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  // Expand Icon
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded Items
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    children: widget.tasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: DownloadTaskTile(
                          task: task, 
                          key: ValueKey('child_${task.taskId}')
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 50.ms);
  }
  
  Widget _buildFallbackThumb(bool isDark) {
    return Container(
      width: 80,
      height: 45,
      color: isDark ? AppColors.darkBg : AppColors.lightBg,
      child: const Icon(Icons.playlist_play_rounded, size: 24, color: AppColors.primary),
    );
  }
}
