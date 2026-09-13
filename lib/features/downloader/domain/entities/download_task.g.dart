// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually updated for Update 2.5 to add playlist fields (HiveFields 16, 17, 18)

part of 'download_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadTaskAdapter extends TypeAdapter<DownloadTask> {
  @override
  final int typeId = 1;

  @override
  DownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTask(
      taskId: fields[0] as String,
      videoId: fields[1] as String,
      title: fields[2] as String,
      thumbnailUrl: fields[3] as String,
      videoQualityLabel: fields[4] as String?,
      audioQualityLabel: fields[5] as String?,
      isAudioOnly: fields[6] as bool,
      sourceUrl: fields[14] as String?,
      platform: fields[15] as String?,
      playlistId: fields[16] as String?,
      playlistTitle: fields[17] as String?,
      playlistIndex: fields[18] as int?,
      status: fields[7] as DownloadStatus,
      progress: fields[8] as double,
      downloadedBytes: fields[9] as int,
      totalBytes: fields[10] as int,
      outputPath: fields[11] as String?,
      errorMessage: fields[12] as String?,
      createdAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTask obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.videoId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.thumbnailUrl)
      ..writeByte(4)
      ..write(obj.videoQualityLabel)
      ..writeByte(5)
      ..write(obj.audioQualityLabel)
      ..writeByte(6)
      ..write(obj.isAudioOnly)
      ..writeByte(14)
      ..write(obj.sourceUrl)
      ..writeByte(15)
      ..write(obj.platform)
      ..writeByte(16)
      ..write(obj.playlistId)
      ..writeByte(17)
      ..write(obj.playlistTitle)
      ..writeByte(18)
      ..write(obj.playlistIndex)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.progress)
      ..writeByte(9)
      ..write(obj.downloadedBytes)
      ..writeByte(10)
      ..write(obj.totalBytes)
      ..writeByte(11)
      ..write(obj.outputPath)
      ..writeByte(12)
      ..write(obj.errorMessage)
      ..writeByte(13)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 0;

  @override
  DownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadStatus.queued;
      case 1:
        return DownloadStatus.fetchingInfo;
      case 2:
        return DownloadStatus.downloading;
      case 3:
        return DownloadStatus.merging;
      case 4:
        return DownloadStatus.paused;
      case 5:
        return DownloadStatus.done;
      case 6:
        return DownloadStatus.failed;
      case 7:
        return DownloadStatus.retrying;
      default:
        return DownloadStatus.queued;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    switch (obj) {
      case DownloadStatus.queued:
        writer.writeByte(0);
        break;
      case DownloadStatus.fetchingInfo:
        writer.writeByte(1);
        break;
      case DownloadStatus.downloading:
        writer.writeByte(2);
        break;
      case DownloadStatus.merging:
        writer.writeByte(3);
        break;
      case DownloadStatus.paused:
        writer.writeByte(4);
        break;
      case DownloadStatus.done:
        writer.writeByte(5);
        break;
      case DownloadStatus.failed:
        writer.writeByte(6);
        break;
      case DownloadStatus.retrying:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
