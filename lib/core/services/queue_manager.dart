import 'package:hive_flutter/hive_flutter.dart';
import '../../features/downloader/domain/entities/download_task.dart';
import '../../features/downloader/domain/repositories/download_repository.dart';
import 'download_service.dart';

class QueueManager {
  final DownloadRepository _repository;
  final DownloadService _downloadService;
  final Box<DownloadTask> _queueBox;

  final List<DownloadTask> _queue = [];

  int maxConcurrentTasks = 3;



  Function(DownloadTask)? onTaskUpdated;
  Function()? onQueueChanged;

  QueueManager(this._repository, this._downloadService, this._queueBox) {
    _initQueue();
  }

  void _initQueue() {
    _queue.clear();
    for (var task in _queueBox.values) {
      // If task was downloading/merging when app killed, set to paused
      if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging) {
        task.status = DownloadStatus.paused;
        task.speedBytesPerSecond = 0.0;
        task.eta = null;
        _save(task);
      }
      _queue.add(task);
    }
    _queue.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Automatically start the queue for pending tasks
    Future.microtask(() => _checkQueue());
  }

  void _save(DownloadTask task) {
    _queueBox.put(task.taskId, task);
  }

  List<DownloadTask> get tasks => List.unmodifiable(_queue);

  void addTask(DownloadTask task) {
    _queue.insert(0, task);
    _save(task);
    onQueueChanged?.call();
    _checkQueue();
  }

  void addTasks(List<DownloadTask> newTasks) {
    if (newTasks.isEmpty) return;
    _queue.insertAll(0, newTasks);
    for (var task in newTasks) {
      _save(task);
    }
    onQueueChanged?.call();
    _checkQueue();
  }

  /// Cancel an active/queued download — actually signals DownloadService to stop.

  void cancelTask(String taskId) {
    final index = _queue.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return;
    final task = _queue[index];

    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.merging) {
      // Signal the actual download to stop via DownloadService
      _downloadService.cancelDownload(taskId);
    }

    _queue.removeAt(index);
    _queueBox.delete(taskId);
    onTaskUpdated?.call(task);
    onQueueChanged?.call();
    _checkQueue();
  }

  void retryTask(String taskId) {
    final index = _queue.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return;
    final task = _queue[index];
    task.status = DownloadStatus.queued;
    task.progress = 0.0;
    task.speedBytesPerSecond = 0.0;
    task.eta = null;
    task.errorMessage = null;
    _save(task);
    onTaskUpdated?.call(task);
    onQueueChanged?.call();
    _checkQueue();
  }

  void removeTask(String taskId) {
    cancelTask(taskId);
  }

  void pauseTask(String taskId) {
    final index = _queue.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return;
    final task = _queue[index];

    if (task.status == DownloadStatus.downloading || task.status == DownloadStatus.merging) {
      _downloadService.pauseDownload(taskId);
      task.status = DownloadStatus.paused;
      _save(task);
      onTaskUpdated?.call(task);
      onQueueChanged?.call();
      _checkQueue();
    } else if (task.status == DownloadStatus.queued) {
      task.status = DownloadStatus.paused;
      _save(task);
      onTaskUpdated?.call(task);
      onQueueChanged?.call();
    }
  }

  void resumeTask(String taskId) {
    final index = _queue.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return;
    final task = _queue[index];

    if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) {
      task.status = DownloadStatus.queued;
      _save(task);
      onQueueChanged?.call();
      _checkQueue();
    }
  }

  void forceStartTask(String taskId) {
    final index = _queue.indexWhere((t) => t.taskId == taskId);
    if (index == -1) return;
    final task = _queue[index];

    if (task.status == DownloadStatus.queued || task.status == DownloadStatus.paused) {
      _startTask(task);
      _save(task);
      onQueueChanged?.call();
    }
  }

  void setConcurrentLimit(int limit) {
    maxConcurrentTasks = limit;
    _checkQueue();
  }

  void _checkQueue() {
    final activeCount = _queue
        .where((t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.merging)
        .length;

    if (activeCount < maxConcurrentTasks) {
      final slots = maxConcurrentTasks - activeCount;
      final nextTasks = _queue
          .where((t) => t.status == DownloadStatus.queued)
          .take(slots)
          .toList();
      for (final task in nextTasks) {
        _startTask(task);
      }
    }
  }

  void _startTask(DownloadTask task) {
    task.status = DownloadStatus.fetchingInfo;
    _save(task);
    onTaskUpdated?.call(task);

    _repository.downloadStream(
      task,
      onProgress: (progress, speed, eta, downloadedBytes, totalBytes, status) {
        // Guard: task may have been removed or cancelled
        if (!_queue.any((t) => t.taskId == task.taskId)) return;
        if (task.status == DownloadStatus.failed || task.status == DownloadStatus.paused) return;

        if (status != null) {
          task.status = status;
        } else if (progress >= 0.9 && !task.isAudioOnly && task.status == DownloadStatus.downloading) {
          task.status = DownloadStatus.merging;
        }

        task.progress = progress;
        task.speedBytesPerSecond = speed;
        task.eta = eta;
        if (downloadedBytes != null) task.downloadedBytes = downloadedBytes;
        if (totalBytes != null) task.totalBytes = totalBytes;
        
        _save(task);
        onTaskUpdated?.call(task);
      },
      onComplete: (finalPath) {
        if (!_queue.any((t) => t.taskId == task.taskId)) return;
        task.status = DownloadStatus.done;
        task.progress = 1.0;
        task.outputPath = finalPath;
        _queueBox.delete(task.taskId);
        onTaskUpdated?.call(task);
        onQueueChanged?.call();
        _checkQueue();
      },
      onRetry: (msg) {
        if (!_queue.any((t) => t.taskId == task.taskId)) return;
        task.errorMessage = msg;
        _save(task);
        onTaskUpdated?.call(task);
      },
      onError: (e) {
        if (!_queue.any((t) => t.taskId == task.taskId)) return;
        if (e == 'Cancelled') {
          task.status = DownloadStatus.failed;
          task.errorMessage = 'Cancelled by user';
        } else if (e == 'Paused' || e.contains('Paused')) {
          task.status = DownloadStatus.paused;
        } else {
          task.status = DownloadStatus.failed;
          task.errorMessage = e;
        }
        _save(task);
        onTaskUpdated?.call(task);
        onQueueChanged?.call();
        _checkQueue();
      },
    );
  }

  Future<void> resetBinaries() async {
    await _repository.resetBinaries();
  }
}
