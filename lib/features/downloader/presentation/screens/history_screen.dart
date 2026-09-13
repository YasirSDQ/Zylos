import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../domain/entities/download_task.dart';
import '../providers/settings_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Videos, Audio, Images, Playlists
  String _timeFilter = 'All Time'; // All Time, Today, This Week
  String _platformFilter = 'All'; // All, YouTube, TikTok...
  String _sortMode = 'Latest'; // Latest, Oldest, Name, Size, Playlist

  // Grid / List view
  bool _isGridView = false;


  // Selection logic
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _detectSource(DownloadTask task) {
    // Use stored platform field if available (set since v1.1)
    if (task.platform != null && task.platform!.isNotEmpty && task.platform != 'Other') {
      return task.platform!;
    }
    // Fall back to URL-based detection for older downloads
    var url = task.sourceUrl?.toLowerCase() ?? '';
    if (url.isEmpty) url = task.videoId.toLowerCase();
    
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'YouTube';
    if (url.contains('tiktok.com')) return 'TikTok';
    if (url.contains('facebook.com') || url.contains('fb.watch') || url.contains('fb.com')) return 'Facebook';
    if (url.contains('instagram.com')) return 'Instagram';
    if (url.contains('twitter.com') || url.contains('x.com')) return 'Twitter/X';
    if (url.contains('vimeo.com')) return 'Vimeo';
    if (url.contains('dailymotion.com') || url.contains('dai.ly')) return 'Dailymotion';
    if (url.contains('pinterest.com') || url.contains('pin.it')) return 'Pinterest';
    if (url.contains('reddit.com')) return 'Reddit';
    if (url.contains('twitch.tv')) return 'Twitch';
    if (url.contains('soundcloud.com')) return 'SoundCloud';
    if (url.contains('linkedin.com')) return 'LinkedIn';
    if (url.contains('threads.net')) return 'Threads';
    if (url.contains('bilibili.com') || url.contains('b23.tv')) return 'Bilibili';
    if (url.contains('rumble.com')) return 'Rumble';
    
    return 'Other';
  }

  static const _platformColors = {
    'YouTube':   Color(0xFFFF0000),
    'TikTok':    Color(0xFF010101),
    'Facebook':  Color(0xFF1877F2),
    'Instagram': Color(0xFFE1306C),
    'Twitter/X': Color(0xFF1DA1F2),
    'Vimeo':     Color(0xFF19B7EA),
    'Dailymotion': Color(0xFF0066DC),
    'Pinterest': Color(0xFFBD081C),
    'Reddit':    Color(0xFFFF4500),
    'Twitch':    Color(0xFF9146FF),
    'SoundCloud': Color(0xFFFF5500),
    'LinkedIn':  Color(0xFF0A66C2),
    'Threads':   Color(0xFF101010),
    'Bilibili':  Color(0xFF00A1D6),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animScale = context.watch<SettingsProvider>().animationScale;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Custom AppBar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  if (_isSelectionMode) ...[
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.primary),
                      onPressed: () => setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedIds.length} Selected',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                    ),
                  ] else ...[
                    Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                          ),
                          Text(
                            'Your media collection',
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
                  ],
                  const Spacer(),
                  if (_isSelectionMode)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final box = Hive.box<DownloadTask>('history');
                            setState(() {
                              _selectedIds.addAll(box.keys.map((k) => k.toString()));
                            });
                          },
                          icon: const Icon(Icons.select_all_rounded, size: 20),
                          label: const Text('Select All', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white : Colors.black),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Delete Selected',
                          child: GestureDetector(
                            onTap: () => _confirmDeleteSelected(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    // Sort Menu
                    PopupMenuButton<String>(
                      onSelected: (val) => setState(() => _sortMode = val),
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      offset: const Offset(0, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      icon: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.sort_rounded, color: isDark ? Colors.white : Colors.black, size: 20),
                      ),
                      itemBuilder: (context) => [
                        _buildSortItem('Latest', Icons.calendar_today_rounded, isDark),
                        _buildSortItem('Oldest', Icons.history_toggle_off_rounded, isDark),
                        _buildSortItem('Name', Icons.sort_by_alpha_rounded, isDark),
                        _buildSortItem('Size', Icons.storage_rounded, isDark),
                        _buildSortItem('Playlist', Icons.playlist_play_rounded, isDark),
                      ],
                    ),
                    const SizedBox(width: 6),
                    // Grid/List toggle
                    GestureDetector(
                      onTap: () => setState(() => _isGridView = !_isGridView),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _isGridView ? AppColors.primary.withValues(alpha: 0.15) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                          borderRadius: BorderRadius.circular(12),
                          border: _isGridView ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                        ),
                        child: Icon(_isGridView ? Icons.grid_view_rounded : Icons.list_rounded, color: _isGridView ? AppColors.primary : (isDark ? Colors.white : Colors.black), size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: 'Clear All History',
                      child: GestureDetector(
                        onTap: () => _confirmClearHistory(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 20),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Search Bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search downloads...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          suffixIcon: _searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ) 
                            : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats Bar ──────────────────────────────────────
            _buildStatsBar(isDark),

            // ── Modern Categorized Filters ─────────────────────
            _buildCategorizedFilters(isDark),

            // ── History List ───────────────────────────────────
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Hive.box<DownloadTask>('history').listenable(),
                builder: (context, Box<DownloadTask> box, _) {
                  List<DownloadTask> history = box.values.toList();
                  
                  // Apply Categorized Filters FIRST
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));

                  // Time
                  if (_timeFilter == 'Today') {
                    history = history.where((t) => t.createdAt.isAfter(todayStart) || t.createdAt.isAtSameMomentAs(todayStart)).toList();
                  } else if (_timeFilter == 'This Week') {
                    history = history.where((t) => t.createdAt.isAfter(weekStart) || t.createdAt.isAtSameMomentAs(weekStart)).toList();
                  }

                   // Type
                  if (_typeFilter == 'Videos') {
                    history = history.where((t) => !t.isAudioOnly).toList();
                  } else if (_typeFilter == 'Audio') {
                    history = history.where((t) => t.isAudioOnly).toList();
                  } else if (_typeFilter == 'Playlists') {
                    history = history.where((t) => t.playlistId != null && t.playlistId!.isNotEmpty).toList();
                  }

                  // Platform
                  if (_platformFilter != 'All') {
                    history = history.where((t) => _detectSource(t) == _platformFilter).toList();
                  }

                  // Search
                  if (_searchQuery.isNotEmpty) {
                    history = history
                        .where((t) => t.title.toLowerCase().contains(_searchQuery))
                        .toList();
                  }

                  // Apply Sorting
                  if (_sortMode == 'Latest') {
                    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  } else if (_sortMode == 'Oldest') {
                    history.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  } else if (_sortMode == 'Name') {
                    history.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
                  } else if (_sortMode == 'Size') {
                    history.sort((a, b) => (b.totalBytes).compareTo(a.totalBytes));
                  } else if (_sortMode == 'Playlist') {
                    history.sort((a, b) {
                      final pa = a.playlistTitle ?? '';
                      final pb = b.playlistTitle ?? '';
                      final cmp = pa.compareTo(pb);
                      if (cmp != 0) return cmp;
                      return (a.playlistIndex ?? 999).compareTo(b.playlistIndex ?? 999);
                    });
                  }

                  if (history.isEmpty) {
                    return _EmptyHistory(searchQuery: _searchQuery, isDark: isDark);
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final task = history[index];
                        final isSelected = _selectedIds.contains(task.taskId);
                        final itemDelay = (index.clamp(0, 12) * 20 * animScale).ms;
                        final itemDuration = (250 * animScale).ms;
                        return _HistoryGridCard(
                          task: task,
                          box: box,
                          isDark: isDark,
                          source: _detectSource(task),
                          sourceColor: _platformColors[_detectSource(task)] ?? AppColors.primary,
                          isSelected: isSelected,
                          onLongPress: () => setState(() { _isSelectionMode = true; _selectedIds.add(task.taskId); }),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (_selectedIds.contains(task.taskId)) {
                                  _selectedIds.remove(task.taskId);
                                  if (_selectedIds.isEmpty) _isSelectionMode = false;
                                } else {
                                  _selectedIds.add(task.taskId);
                                }
                              });
                            }
                          },
                        )
                        .animate()
                        .fadeIn(duration: itemDuration, delay: itemDelay)
                        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: itemDuration, curve: Curves.easeOutBack);
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final task = history[index];
                      final isSelected = _selectedIds.contains(task.taskId);
                      
                      // Cap index multiplier to 10 to avoid massive cascading delays for long lists
                      final itemDelay = (index.clamp(0, 12) * 20 * animScale).ms;
                      final itemDuration = (250 * animScale).ms;
                      
                      return _HistoryCard(
                        task: task,
                        box: box,
                        isDark: isDark,
                        source: _detectSource(task),
                        sourceColor: _platformColors[_detectSource(task)] ?? AppColors.primary,
                        isSelected: isSelected,
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIds.add(task.taskId);
                          });
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (_selectedIds.contains(task.taskId)) {
                                _selectedIds.remove(task.taskId);
                                if (_selectedIds.isEmpty) _isSelectionMode = false;
                              } else {
                                _selectedIds.add(task.taskId);
                              }
                            });
                          }
                        },
                      )
                      .animate()
                      .fadeIn(duration: itemDuration, delay: itemDelay, curve: Curves.easeOut)
                      .slideY(begin: 0.1, end: 0, duration: itemDuration, curve: Curves.easeOutCubic)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: itemDuration, curve: Curves.easeOutBack);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedFilters(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DownloadTask>('history').listenable(),
      builder: (context, Box<DownloadTask> box, _) {
        final history = box.values.toList();
        final availablePlatforms = history.map((t) => _detectSource(t)).toSet().toList();
        availablePlatforms.sort();

        // ── Auto-Reset Filter Logic ──────────────────────
        // If current filter platform was deleted from history, reset to All
        if (_platformFilter != 'All' && !availablePlatforms.contains(_platformFilter)) {
          // Use Future.microtask to avoid modifying state during build
          Future.microtask(() => setState(() => _platformFilter = 'All'));
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Type Filter
              Expanded(
                child: _FilterMenu(
                  label: _typeFilter,
                  icon: Icons.category_rounded,
                  isDark: isDark,
                  items: ['All', 'Videos', 'Audio', 'Playlists'],
                  onSelected: (val) => setState(() => _typeFilter = val),
                ),
              ),
              const SizedBox(width: 8),
              
              // Time Filter
              Expanded(
                child: _FilterMenu(
                  label: _timeFilter == 'All Time' ? 'Anytime' : _timeFilter,
                  icon: Icons.calendar_today_rounded,
                  isDark: isDark,
                  items: ['All Time', 'Today', 'This Week'],
                  onSelected: (val) => setState(() => _timeFilter = val),
                  displayNames: {'All Time': 'Anytime', 'Today': 'Today', 'This Week': 'Week'},
                ),
              ),
              const SizedBox(width: 8),

              // Platform Filter
              Expanded(
                child: _FilterMenu(
                  label: _platformFilter == 'All' ? 'Sources' : _platformFilter,
                  icon: Icons.language_rounded,
                  isDark: isDark,
                  items: ['All', ...availablePlatforms],
                  onSelected: (val) => setState(() => _platformFilter = val),
                  displayNames: {'All': 'Sources'},
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatsBar(bool isDark) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DownloadTask>('history').listenable(),
      builder: (context, Box<DownloadTask> box, _) {
        final history = box.values.toList();
        final totalSize = history.fold<int>(0, (sum, t) => sum + t.totalBytes);
        final videoCount = history.where((t) => !t.isAudioOnly).length;
        final audioCount = history.where((t) => t.isAudioOnly).length;
        final playlistCount = history.where((t) => t.playlistId != null).map((t) => t.playlistId).toSet().length;

        String formatSize(int bytes) {
          if (bytes <= 0) return '0 B';
          const s = ['B', 'KB', 'MB', 'GB'];
          int i = 0;
          double size = bytes.toDouble();
          while (size >= 1024 && i < s.length - 1) { size /= 1024; i++; }
          return '${size.toStringAsFixed(1)} ${s[i]}';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _buildStatChip(Icons.download_done_rounded, '${history.length}', 'Total', const Color(0xFF8B5CF6), isDark),
              const SizedBox(width: 6),
              _buildStatChip(Icons.storage_rounded, formatSize(totalSize), 'Size', const Color(0xFF06B6D4), isDark),
              const SizedBox(width: 6),
              _buildStatChip(Icons.videocam_rounded, '$videoCount', 'Videos', const Color(0xFF10B981), isDark),
              const SizedBox(width: 6),
              _buildStatChip(Icons.music_note_rounded, '$audioCount', 'Audio', const Color(0xFFEC4899), isDark),
              if (playlistCount > 0) ...[
                const SizedBox(width: 6),
                _buildStatChip(Icons.playlist_play_rounded, '$playlistCount', 'Playlists', const Color(0xFFF59E0B), isDark),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String label, IconData icon, bool isDark) {
    final isSelected = _sortMode == label;
    return PopupMenuItem<String>(
      value: label,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
          const Spacer(),
          if (isSelected) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }

  void _confirmDeleteSelected(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${_selectedIds.length} items?', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This removes the history records from the app. Downloaded files remain on disk.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final box = Hive.box<DownloadTask>('history');
              for (final id in _selectedIds) {
                box.delete(id);
              }
              setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This removes all history records. Your downloaded files will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Hive.box<DownloadTask>('history').clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final List<String> items;
  final Function(String) onSelected;
  final Map<String, String>? displayNames;

  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.items,
    required this.onSelected,
    this.displayNames,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final isDefault = label == 'All' || label == 'Anytime' || label == 'Sources';

    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => items.map((item) {
        final isSelected = item == label || (displayNames?[item] == label);
        return PopupMenuItem<String>(
          value: item,
          child: Row(
            children: [
              Text(
                displayNames?[item] ?? item,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
              const Spacer(),
              if (isSelected) const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
            ],
          ),
        );
      }).toList(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDefault 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04))
              : activeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDefault 
                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : activeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 14, 
              color: isDefault 
                  ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                  : activeColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDefault ? FontWeight.w600 : FontWeight.w800,
                  color: isDefault 
                      ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                      : activeColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded, 
              size: 16, 
              color: isDefault 
                  ? (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)
                  : activeColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final DownloadTask task;
  final Box<DownloadTask> box;
  final bool isDark;
  final String source;
  final Color sourceColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryCard({
    required this.task,
    required this.box,
    required this.isDark,
    required this.source,
    required this.sourceColor,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _fileExists = true;

  @override
  void initState() {
    super.initState();
    _checkFile();
  }

  Future<void> _checkFile() async {
    if (widget.task.outputPath != null) {
      final exists = await File(widget.task.outputPath!).exists();
      if (mounted && _fileExists != exists) {
        setState(() => _fileExists = exists);
      }
    }
  }

  void _showDeleteOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: widget.isDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: Text('Remove Download', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)),
          content: Text(
            'Remove just from history, or permanently delete the file from your device?',
            style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                widget.box.delete(widget.task.taskId);
                Navigator.pop(ctx);
              },
              child: const Text('Remove from History', style: TextStyle(color: AppColors.primary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                if (widget.task.outputPath != null) {
                  final file = File(widget.task.outputPath!);
                  if (file.existsSync()) {
                    try { file.deleteSync(); } catch (_) {}
                  }
                }
                widget.box.delete(widget.task.taskId);
                Navigator.pop(ctx);
              },
              child: const Text('Delete File', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.task.outputPath != null
        ? p.basenameWithoutExtension(widget.task.outputPath!)
        : widget.task.title;
    
    // Date formatting (2024-03-24 11:00:27 -> 24 Mar 2024 • 11:00)
    final date = widget.task.createdAt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${date.day} ${months[date.month - 1]} ${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    final qualityLabel = (widget.task.videoQualityLabel ?? widget.task.audioQualityLabel ?? 'Unknown').split('|').first;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? AppColors.primary.withValues(alpha: 0.1) 
                : (widget.isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected 
                  ? AppColors.primary 
                  : (widget.isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              if (!widget.isSelected)
                BoxShadow(
                  color: widget.isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.task.thumbnailUrl,
                            width: 100,
                            height: 60,
                            fit: BoxFit.cover,
                            errorWidget: (ctx, u, e) => Container(
                              width: 100,
                              height: 60,
                              color: widget.isDark ? AppColors.darkSurface : AppColors.lightCardElevated,
                              child: const Icon(Icons.broken_image_outlined, color: AppColors.darkTextTertiary, size: 24),
                            ),
                          ),
                        ),
                        if (!_fileExists)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        if (widget.isSelected)
                           Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.sourceColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _getPlatformIcon(widget.source, widget.sourceColor),
                                    const SizedBox(width: 4),
                                    Text(widget.source, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: widget.sourceColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.task.isAudioOnly)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Audio', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accent)),
                                ),
                              const Spacer(),
                              if (!_fileExists)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('REMOVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.error)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12,
                                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              const SizedBox(width: 4),
                              Text(
                                '$dateStr • $timeStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.monitor_rounded, size: 12,
                                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                              const SizedBox(width: 4),
                              Text(
                                qualityLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
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
              if (_fileExists) ...[
                 Container(
                  height: 1,
                  color: widget.isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      _HistoryAction(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play',
                        color: Colors.white,
                        backgroundColor: AppColors.primary,
                        onTap: () {
                          if (widget.task.outputPath != null) PlatformUtils.openVideoFile(widget.task.outputPath!);
                        },
                      ),
                      const SizedBox(width: 10),
                      _HistoryAction(
                        icon: Icons.folder_open_rounded,
                        label: 'Open Folder',
                        color: widget.isDark ? Colors.white70 : AppColors.lightTextSecondary,
                        backgroundColor: widget.isDark ? AppColors.darkSurface.withValues(alpha: 0.8) : AppColors.lightCardElevated,
                        onTap: () {
                          if (widget.task.outputPath != null) PlatformUtils.openFileInExplorer(widget.task.outputPath!);
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Color(0xFFE8336D)),
                        tooltip: 'Share',
                        onPressed: () => _shareFile(widget.task),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        tooltip: 'Remove',
                        onPressed: () => _showDeleteOptions(context),
                      ),
                      Text(
                        _formatSize(widget.task.totalBytes),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                 Container(
                  height: 1,
                  color: widget.isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      const Text(
                        'File moved or deleted externally',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Trigger re-download logic if integrated
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Re-download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getPlatformIcon(String source, Color color) {
    IconData icon;
    switch (source) {
      case 'YouTube': icon = Icons.play_circle_filled_rounded; break;
      case 'TikTok': icon = Icons.music_note_rounded; break;
      case 'Facebook': icon = Icons.facebook_rounded; break;
      case 'Instagram': icon = Icons.camera_alt_rounded; break;
      case 'Twitter/X': icon = Icons.close_rounded; break;
      case 'Vimeo': icon = Icons.play_circle_outline_rounded; break;
      case 'Dailymotion': icon = Icons.video_library_rounded; break;
      case 'Pinterest': icon = Icons.pin_drop_rounded; break;
      case 'Reddit': icon = Icons.reddit_rounded; break;
      case 'Twitch': icon = Icons.videogame_asset_rounded; break;
      case 'SoundCloud': icon = Icons.cloud_rounded; break;
      case 'LinkedIn': icon = Icons.business_rounded; break;
      case 'Threads': icon = Icons.alternate_email_rounded; break;
      default: icon = Icons.public_rounded;
    }
    return Icon(icon, size: 10, color: color);
}

  // Share the actual video file using system share
  Future<void> _shareFile(DownloadTask video) async {
    if(video.outputPath != null) {
        final file = XFile(video.outputPath!);
        await Share.shareXFiles(
          [file],
          text: 'Shared from Zylos',
        );
    }
  }
}
class _HistoryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _HistoryAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final String searchQuery;
  final bool isDark;

  const _EmptyHistory({required this.searchQuery, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2), width: 1),
              ),
              child: Icon(
                searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.video_library_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searchQuery.isNotEmpty ? 'No results found' : 'Library is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try a different search term.'
                  : 'Downloaded media will appear here.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Card for Library ────────────────────────────────────────────────────

class _HistoryGridCard extends StatelessWidget {
  final DownloadTask task;
  final Box<DownloadTask> box;
  final bool isDark;
  final String source;
  final Color sourceColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HistoryGridCard({
    super.key,
    required this.task,
    required this.box,
    required this.isDark,
    required this.source,
    required this.sourceColor,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const s = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < s.length - 1) { size /= 1024; i++; }
    return '${size.toStringAsFixed(1)} ${s[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = task.thumbnailUrl.isNotEmpty;
    final hasFile = task.outputPath != null && File(task.outputPath!).existsSync();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.7)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  if (hasThumbnail)
                    CachedNetworkImage(
                      imageUrl: task.thumbnailUrl,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: double.infinity, height: 110,
                        color: sourceColor.withValues(alpha: 0.15),
                        child: Icon(task.isAudioOnly ? Icons.music_note_rounded : Icons.videocam_rounded, size: 36, color: sourceColor.withValues(alpha: 0.5)),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity, height: 110,
                      color: sourceColor.withValues(alpha: 0.15),
                      child: Icon(task.isAudioOnly ? Icons.music_note_rounded : Icons.videocam_rounded, size: 36, color: sourceColor.withValues(alpha: 0.5)),
                    ),
                  // Type badge
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: task.isAudioOnly ? const Color(0xFF8B5CF6).withValues(alpha: 0.85) : const Color(0xFF06B6D4).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(task.isAudioOnly ? Icons.music_note_rounded : Icons.videocam_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                  // Selection overlay
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)),
                      ),
                    ),
                  // File missing indicator
                  if (!hasFile)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.broken_image_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: sourceColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(source, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sourceColor), overflow: TextOverflow.ellipsis),
                        ),
                        if (task.totalBytes > 0)
                          Text(_formatSize(task.totalBytes), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                      ],
                    ),
                    if (task.playlistTitle != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.playlist_play_rounded, size: 10, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(task.playlistTitle!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
