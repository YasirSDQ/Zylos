import 'dart:io';
import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../domain/entities/video_entity.dart';
import '../../../../core/services/plugin_service.dart';

class YoutubeDatasource {
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  final PluginService _pluginService;

  YoutubeDatasource(this._pluginService);

  String _cleanUrl(String url) {
    if (!url.startsWith('http')) return url;
    try {
      final uri = Uri.parse(url);
      final listId = uri.queryParameters['list'];
      final videoId = uri.queryParameters['v'];

      // If it's a standard playlist (starts with PL), prioritize playlist
      if (listId != null && listId.startsWith('PL')) {
        return 'https://www.youtube.com/playlist?list=$listId';
      }

      // Otherwise if it has a video ID, prioritize video
      if (videoId != null) {
        return 'https://www.youtube.com/watch?v=$videoId';
      }

      // Fallback to playlist if no video ID but has list ID (even if not PL)
      if (listId != null) {
        return 'https://www.youtube.com/playlist?list=$listId';
      }

      return url.split('?').first;
    } catch (e) {
      return url.split('?').first;
    }
  }

  bool isPlaylist(String url) {
    final cleaned = _cleanUrl(url);
    return cleaned.contains('list=');
  }

  /// Fetch video info with retry logic for transient network errors.
  Future<VideoEntity> fetchVideo(String urlOrId) async {
    final cleanUrl = _cleanUrl(urlOrId);
    Exception? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _fetchVideoOnce(cleanUrl);
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw lastError!;
  }

  Future<VideoEntity> _fetchVideoOnce(String urlOrId) async {
    final video = await _yt.videos.get(urlOrId).timeout(const Duration(seconds: 20));
    final manifest = await _yt.videos.streamsClient
        .getManifest(video.id)
        .timeout(const Duration(seconds: 30));

    // Find best audio size for estimating total size of video-only streams
    int bestAudioBytes = 0;
    final allAudio = manifest.audioOnly.toList();
    if (allAudio.isNotEmpty) {
      allAudio.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      bestAudioBytes = allAudio.first.size.totalBytes;
    }

    final Map<String, VideoQuality> qualityMap = {};

    // Muxed streams (Video + Audio combined)
    for (var stream in manifest.muxed) {
      if (stream.qualityLabel.isNotEmpty) {
        final label = stream.qualityLabel;
        final h = stream.videoResolution.height.toInt();
        final fps = stream.framerate.framesPerSecond.toInt();
        if (!qualityMap.containsKey(label) || fps > qualityMap[label]!.fps) {
          qualityMap[label] = VideoQuality(
            label: label,
            height: h,
            fps: fps,
            fileSizeBytes: stream.size.totalBytes,
            isMuxed: true,
          );
        }
      }
    }

    // Video-only streams (usually higher qualities)
    for (var stream in manifest.videoOnly) {
      if (stream.qualityLabel.isNotEmpty) {
        final label = stream.qualityLabel;
        final h = stream.videoResolution.height.toInt();
        final fps = stream.framerate.framesPerSecond.toInt();
        
        if (!qualityMap.containsKey(label) || fps > qualityMap[label]!.fps) {
          qualityMap[label] = VideoQuality(
            label: label,
            height: h,
            fps: fps,
            fileSizeBytes: stream.size.totalBytes + bestAudioBytes,
            isMuxed: false,
          );
        } else if (fps == qualityMap[label]!.fps && !qualityMap[label]!.isMuxed) {
           // if same framerate and both videoOnly, prefer the one with larger size (better bitrate)
           final currentSize = qualityMap[label]!.fileSizeBytes ?? 0;
           final newSize = stream.size.totalBytes + bestAudioBytes;
           if (newSize > currentSize) {
              qualityMap[label] = VideoQuality(
                label: label,
                height: h,
                fps: fps,
                fileSizeBytes: newSize,
                isMuxed: false,
              );
           }
        }
      }
    }

    final videoQualities = qualityMap.values.toList();
    // Sort highest → lowest resolution
    videoQualities.sort((a, b) => b.height.compareTo(a.height));

    final List<AudioQuality> audioQualities = [];
    final seen = <int>{};
    bool isFirstAudio = true;
    for (var stream in allAudio) {
      final kbps = (stream.bitrate.bitsPerSecond / 1000).round();
      if (seen.contains(kbps)) continue;
      seen.add(kbps);
      
      String label = '${kbps}kbps';
      if (isFirstAudio) {
        label = '$label (Best Quality)';
        isFirstAudio = false;
      }
      
      audioQualities.add(AudioQuality(
        label: label,
        bitrate: stream.bitrate.bitsPerSecond,
        format: stream.container.name,
        fileSizeBytes: stream.size.totalBytes,
      ));
    }

    // Inject MP3 option
    final durationSecs = video.duration?.inSeconds ?? 0;
    audioQualities.add(AudioQuality(
      label: 'MP3',
      bitrate: 192000,
      format: 'mp3',
      fileSizeBytes: durationSecs > 0 ? (192000 * durationSecs) ~/ 8 : null,
    ));

    return VideoEntity(
      id: video.id.value,
      title: video.title,
      channelName: video.author,
      thumbnailUrl: video.thumbnails.highResUrl,
      duration: video.duration ?? Duration.zero,
      viewCount: video.engagement.viewCount,
      uploadDate: video.uploadDate ?? DateTime.now(),
      availableQualities: videoQualities,
      availableAudioQualities: audioQualities,
    );
  }

  Future<PlaylistEntity> fetchPlaylist(String urlOrId) async {
    final cleanUrl = _cleanUrl(urlOrId);
    Exception? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _fetchPlaylistOnce(cleanUrl);
      } catch (e) {
        lastError = Exception(e.toString());
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw lastError!;
  }

  Future<PlaylistEntity> _fetchPlaylistOnce(String urlOrId) async {
    final ytdlpExe = await _pluginService.getYtDlpPath();
    if (ytdlpExe == null) {
      throw Exception('yt-dlp not found. Please install it in Plugin Manager.');
    }

    final args = [
      '--dump-json',
      '--flat-playlist',
      // Use ios,mweb,web,tv player to bypass bot detection
      '--extractor-args', 'youtube:player_client=ios,mweb,web,tv',
      '--user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      '--add-header', 'Accept-Language:en-US,en;q=0.9',
      '--no-warnings',
      '--no-check-certificates',
      urlOrId,
    ];

    final result = await Process.run(ytdlpExe, args, stdoutEncoding: utf8, stderrEncoding: utf8, environment: {'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'}).timeout(const Duration(minutes: 3));

    if (result.exitCode != 0) {
      final errStr = result.stderr as String;
      if (errStr.contains('403') || errStr.contains('Sign in')) {
        throw Exception('YouTube is blocking this request (403). Please update yt-dlp in Plugin Manager.');
      }
      throw Exception('Failed to fetch playlist: ${errStr.isEmpty ? result.stdout : errStr}');
    }

    final lines = (result.stdout as String).trim().split('\n');
    final List<VideoEntity> videos = [];
    String? playlistId;
    String? playlistTitle;
    String? playlistUploader;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line);
        final title = json['title'] as String? ?? 'Unknown Video';
        final id = json['id'] as String? ?? '';
        final durationSecs = (json['duration'] as num?)?.toInt() ?? 0;
        final url = json['url'] as String? ?? 'https://www.youtube.com/watch?v=$id';
        // Try multiple fields for channel/uploader name
        final uploader = json['channel'] as String?
            ?? json['uploader'] as String?
            ?? json['creator'] as String?
            ?? json['uploader_id'] as String?
            ?? '';
        
        // Sometimes flat-playlist includes the playlist entry itself. We skip it or use it for metadata.
        if (json['_type'] == 'playlist') {
          playlistId = id;
          playlistTitle = title.isNotEmpty && title != 'NA' ? title : playlistTitle;
          // Use channel from playlist entry itself
          final plChannel = json['channel'] as String?
              ?? json['uploader'] as String?
              ?? json['creator'] as String?;
          if (plChannel != null && plChannel.isNotEmpty) {
            playlistUploader = plChannel;
          }
          continue;
        }

        // Try extracting playlist metadata from individual video objects
        final pTitle = json['playlist_title'] as String?;
        if (pTitle != null && pTitle.isNotEmpty && pTitle != 'NA') {
          playlistTitle ??= pTitle;
        }
        final pUploader = json['playlist_uploader'] as String?;
        if (pUploader != null && pUploader.isNotEmpty && pUploader != 'NA') {
          playlistUploader ??= pUploader;
        }

        videos.add(VideoEntity(
          id: url,
          title: title,
          channelName: uploader,
          thumbnailUrl: 'https://img.youtube.com/vi/$id/maxresdefault.jpg',
          duration: Duration(seconds: durationSecs),
          viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
          uploadDate: DateTime.now(),
          availableQualities: [],
          availableAudioQualities: [],
        ));
      } catch (e) {
        // ignore parsing errors for individual lines
      }
    }

    if (videos.isEmpty) {
      throw Exception('No videos found in playlist');
    }

    // If playlist-level channel name is missing, fall back to the first video's channel
    final channelName = (playlistUploader?.isNotEmpty == true)
        ? playlistUploader!
        : (videos.firstOrNull?.channelName.isNotEmpty == true ? videos.first.channelName : null);

    return PlaylistEntity(
      id: playlistId ?? urlOrId,
      title: playlistTitle ?? 'YouTube Playlist',
      channelName: channelName ?? 'YouTube Playlist',
      thumbnailUrl: videos.isNotEmpty ? videos.first.thumbnailUrl : '',
      videos: videos,
    );
  }

  Future<yt.StreamManifest> getManifest(String videoId) async {
    return await _yt.videos.streamsClient
        .getManifest(videoId)
        .timeout(const Duration(seconds: 30));
  }
}
