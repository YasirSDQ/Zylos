import 'package:hive/hive.dart';
// import 'video_entity.dart'; // Removed unused import

part 'download_task.g.dart';

@HiveType(typeId: 0)
enum DownloadStatus {
  @HiveField(0)
  queued,
  @HiveField(1)
  fetchingInfo,
  @HiveField(2)
  downloading,
  @HiveField(3)
  merging,
  @HiveField(4)
  paused,
  @HiveField(5)
  done,
  @HiveField(6)
  failed,
  @HiveField(7)
  retrying
}

@HiveType(typeId: 1)
class DownloadTask {
  @HiveField(0)
  final String taskId;
  @HiveField(1)
  final String videoId;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String thumbnailUrl;
  
  // Store the string labels or full objects if needed, but for persistence string is easier
  @HiveField(4)
  final String? videoQualityLabel;
  @HiveField(5)
  final String? audioQualityLabel;
  @HiveField(6)
  final bool isAudioOnly;

  @HiveField(14)
  final String? sourceUrl;
  
  @HiveField(15)
  final String? platform;

  @HiveField(7)
  DownloadStatus status;
  @HiveField(8)
  double progress;
  @HiveField(9)
  int downloadedBytes;
  @HiveField(10)
  int totalBytes;
  @HiveField(11)
  String? outputPath;
  @HiveField(12)
  String? errorMessage;
  @HiveField(13)
  final DateTime createdAt;

  @HiveField(16)
  final String? playlistId;

  @HiveField(17)
  final String? playlistTitle;

  @HiveField(18)
  final int? playlistIndex;

  // Not persisted fields
  double speedBytesPerSecond = 0.0;
  Duration? eta;
  bool overwriteFile = false;

  DownloadTask({
    required this.taskId,
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    this.videoQualityLabel,
    this.audioQualityLabel,
    this.isAudioOnly = false,
    this.sourceUrl,
    this.platform,
    this.playlistId,
    this.playlistTitle,
    this.playlistIndex,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.outputPath,
    this.errorMessage,
    required this.createdAt,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? outputPath,
    String? errorMessage,
  }) {
    return DownloadTask(
      taskId: taskId,
      videoId: videoId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      videoQualityLabel: videoQualityLabel,
      audioQualityLabel: audioQualityLabel,
      isAudioOnly: isAudioOnly,
      sourceUrl: sourceUrl,
      platform: platform,
      playlistId: playlistId,
      playlistTitle: playlistTitle,
      playlistIndex: playlistIndex,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }
}
