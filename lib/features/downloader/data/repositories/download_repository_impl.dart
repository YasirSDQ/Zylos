import 'package:hive/hive.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/repositories/download_repository.dart';
import '../../../../core/services/download_service.dart';
import '../../../../core/services/ytdlp_metadata_service.dart';
import '../datasources/youtube_datasource.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  final YoutubeDatasource _datasource;
  final DownloadService _downloadService;
  final YtDlpMetadataService _ytDlpMeta = YtDlpMetadataService();

  DownloadRepositoryImpl({
    required YoutubeDatasource datasource,
    required DownloadService downloadService,
  })  : _datasource = datasource,
        _downloadService = downloadService;

  static bool _isYouTubeUrl(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be') || !url.startsWith('http');

  @override
  Future<VideoEntity> fetchVideoInfo(String urlOrId) {
    if (_isYouTubeUrl(urlOrId)) {
      return _datasource.fetchVideo(urlOrId);
    }
    // Non-YouTube: use yt-dlp to get metadata
    return _ytDlpMeta.fetchMetadata(urlOrId);
  }

  @override
  Future<PlaylistEntity> fetchPlaylistInfo(String urlOrId) {
    return _datasource.fetchPlaylist(urlOrId);
  }

  @override
  Future<void> clearHistory() async {
    final box = Hive.box<DownloadTask>('history');
    await box.clear();
  }

  @override
  Future<void> resetBinaries() async {
    await _downloadService.resetBinaries();
  }

  @override
  Future<void> logHistory(DownloadTask task) async {
    final box = Hive.box<DownloadTask>('history');
    await box.put(task.taskId, task);
  }

  @override
  Future<void> removeHistory(String taskId) async {
    final box = Hive.box<DownloadTask>('history');
    await box.delete(taskId);
  }

  @override
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
  }) {
    return _downloadService.downloadVideo(
      task,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
      onRetry: onRetry,
    );
  }
}
