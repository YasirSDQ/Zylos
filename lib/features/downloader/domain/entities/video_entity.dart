class VideoEntity {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final Duration duration;
  final int viewCount;
  final DateTime uploadDate;
  
  // Available qualities parsed from YouTube
  final List<VideoQuality> availableQualities;
  final List<AudioQuality> availableAudioQualities;
  final List<ImageQuality> availableImageQualities;

  VideoEntity({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    required this.uploadDate,
    required this.availableQualities,
    required this.availableAudioQualities,
    this.availableImageQualities = const [],
  });
}

class PlaylistEntity {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final List<VideoEntity> videos;

  PlaylistEntity({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    required this.videos,
  });
}

class VideoQuality {
  final String label; // e.g. "1080p", "720p"
  final int height;
  final int fps;
  final int? fileSizeBytes;
  final bool isMuxed; // if true, has both audio and video

  VideoQuality({
    required this.label,
    required this.height,
    required this.fps,
    this.fileSizeBytes,
    required this.isMuxed,
  });
}

class AudioQuality {
  final String label;   // e.g. "192kbps"
  final int bitrate;    // e.g. 192000
  final String format;  // e.g. "mp4", "webm"
  final int? fileSizeBytes;

  AudioQuality({
    required this.label,
    required this.bitrate,
    required this.format,
    this.fileSizeBytes,
  });
}

class ImageQuality {
  final String label;
  final String code; // e.g. "IMG_1080"
  final String ext;
  final String directUrl;
  final String? fileSize;

  ImageQuality({
    required this.label,
    required this.code,
    required this.ext,
    required this.directUrl,
    this.fileSize,
  });
}
