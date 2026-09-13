import '../entities/video_entity.dart';
import '../entities/download_task.dart';

abstract class DownloadRepository {
  /// Fetch info for a single video, including available qualities.
  Future<VideoEntity> fetchVideoInfo(String urlOrId);

  /// Fetch info for a playlist, resolving all videos inside it.
  Future<PlaylistEntity> fetchPlaylistInfo(String urlOrId);

  /// Start a download stream for a specific task.
  /// onComplete is called with the resolved output file path.
    Future<void> downloadStream(
    DownloadTask task, {
    required Function(
      double progress,
      double speed,
      Duration? eta,
      int? downloadedBytes,
      int? totalBytes,
      DownloadStatus? status,
    ) onProgress,
    required Function(String finalPath) onComplete,
    required Function(String error) onError,
    Function(String retryMessage)? onRetry,
  });

  Future<void> logHistory(DownloadTask task);
  Future<void> removeHistory(String taskId);
  Future<void> clearHistory();
  Future<void> resetBinaries();
}
