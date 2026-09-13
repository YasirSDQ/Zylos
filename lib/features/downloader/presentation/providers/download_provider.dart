import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/services/queue_manager.dart';
import '../../domain/entities/download_task.dart';
import '../../../../main.dart';
import '../../../../core/utils/app_notifications.dart';
import 'package:uuid/uuid.dart';

class DownloadProvider extends ChangeNotifier {
  final QueueManager _queueManager;
  final Box<DownloadTask> _historyBox;

  DownloadProvider(this._queueManager, this._historyBox) {
    _queueManager.onTaskUpdated = (task) {
      if (task.status == DownloadStatus.done) {
        _historyBox.put(task.taskId, task); // Save to history
        AppNotifications.showSnackBarWithKey(
          scaffoldMessengerKey,
          message: 'Download completed: ${task.title}',
        );
      }
      notifyListeners();
    };
    _queueManager.onQueueChanged = () {
      notifyListeners();
    };
  }

  final Set<String> _selectedTaskIds = {};
  bool _isSelectionMode = false;

  Set<String> get selectedTaskIds => _selectedTaskIds;
  bool get isSelectionMode => _isSelectionMode;

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) _selectedTaskIds.clear();
    notifyListeners();
  }

  void toggleTaskSelection(String taskId) {
    if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
      if (_selectedTaskIds.isEmpty) _isSelectionMode = false;
    } else {
      _selectedTaskIds.add(taskId);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedTaskIds.addAll(tasks.map((t) => t.taskId));
    _isSelectionMode = true;
    notifyListeners();
  }

  void deselectAll() {
    _selectedTaskIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void clearSelected() {
    for (var id in _selectedTaskIds.toList()) {
      _queueManager.removeTask(id);
    }
    deselectAll();
  }

  void clearAll() {
    for (var task in tasks.toList()) {
      _queueManager.removeTask(task.taskId);
    }
    notifyListeners();
  }

  List<DownloadTask> get tasks => _queueManager.tasks;
  
  // Show all tasks including failed ones, so the user can see if something failed instead of it disappearing
  List<DownloadTask> get displayTasks => _queueManager.tasks.toList();
  
  List<DownloadTask> get completedTasks => _queueManager.tasks.where((t) => 
    t.status == DownloadStatus.done
  ).toList();

  void addTask(DownloadTask task) {
    _queueManager.addTask(task);
  }

  String startDownload(String url, {String? qualityLabel, String? title, String? thumbnailUrl, bool isAudioOnly = false, bool overwriteFile = false}) {
    final taskId = const Uuid().v4();
    final task = DownloadTask(
      taskId: taskId,
      videoId: url,
      sourceUrl: url,
      title: title ?? 'Fetching details...',
      thumbnailUrl: thumbnailUrl ?? '',
      videoQualityLabel: isAudioOnly ? null : (qualityLabel ?? 'Auto'),
      audioQualityLabel: isAudioOnly ? (qualityLabel ?? 'Best') : null,
      isAudioOnly: isAudioOnly,
      platform: detectPlatformFromUrl(url),
      createdAt: DateTime.now(),
      status: DownloadStatus.queued,
    );
    task.overwriteFile = overwriteFile;
    addTask(task);
    return taskId;
  }

  static String detectPlatformFromUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) return 'YouTube';
    if (u.contains('tiktok.com'))                            return 'TikTok';
    if (u.contains('instagram.com'))                         return 'Instagram';
    if (u.contains('facebook.com') || u.contains('fb.watch')) return 'Facebook';
    if (u.contains('twitter.com') || u.contains('x.com'))   return 'Twitter/X';
    if (u.contains('vimeo.com'))                             return 'Vimeo';
    if (u.contains('dailymotion.com') || u.contains('dai.ly')) return 'Dailymotion';
    if (u.contains('twitch.tv'))                             return 'Twitch';
    if (u.contains('bilibili.com') || u.contains('b23.tv')) return 'Bilibili';
    if (u.contains('reddit.com'))                            return 'Reddit';
    if (u.contains('soundcloud.com'))                        return 'SoundCloud';
    if (u.contains('rumble.com'))                            return 'Rumble';
    if (u.contains('pinterest.com') || u.contains('pin.it')) return 'Pinterest';
    if (u.contains('linkedin.com'))                          return 'LinkedIn';
    if (u.contains('threads.net'))                           return 'Threads';
    
    try {
      final uri = Uri.parse(url);
      String host = uri.host.toLowerCase().replaceFirst('www.', '');
      if (host.isNotEmpty) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          String domain = parts[parts.length - 2];
          return domain[0].toUpperCase() + domain.substring(1);
        } else {
          return host[0].toUpperCase() + host.substring(1);
        }
      }
    } catch (_) {}
    return 'Other';
  }

  void addTasks(List<DownloadTask> tasks) {
    _queueManager.addTasks(tasks);
  }

  void cancelTask(String taskId) {
    _queueManager.cancelTask(taskId);
  }

  void increaseConcurrentLimit() {
    if (_queueManager.maxConcurrentTasks < 5) {
      _queueManager.maxConcurrentTasks++;
      notifyListeners();
    }
  }

  void setConcurrentLimit(int limit) {
    _queueManager.maxConcurrentTasks = limit;
    notifyListeners();
  }

  void retryTask(String taskId) {
    _queueManager.retryTask(taskId);
  }

  void pauseTask(String taskId) {
    _queueManager.pauseTask(taskId);
  }

  void resumeTask(String taskId) {
    _queueManager.resumeTask(taskId);
  }

  void pauseAll() {
    for (var task in tasks.toList()) {
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging || task.status == DownloadStatus.queued) {
        _queueManager.pauseTask(task.taskId);
      }
    }
    notifyListeners();
  }

  void resumeAll() {
    for (var task in tasks.toList()) {
      if (task.status == DownloadStatus.paused) {
        _queueManager.resumeTask(task.taskId);
      }
    }
    notifyListeners();
  }

  void forceStartTask(String taskId) {
    _queueManager.forceStartTask(taskId);
  }

  void removeTask(String taskId) {
    _queueManager.removeTask(taskId);
  }

  Future<void> resetBinaries() async {
    await _queueManager.resetBinaries();
    notifyListeners();
  }
}
