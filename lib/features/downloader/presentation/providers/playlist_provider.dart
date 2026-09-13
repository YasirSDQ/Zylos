import 'package:flutter/foundation.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/download_task.dart';
import 'package:uuid/uuid.dart';

class PlaylistProvider extends ChangeNotifier {
  PlaylistEntity? _playlist;
  Set<String> _selectedVideoIds = {};
  
  // Custom video-level overrides
  final Map<String, VideoQuality> _videoQualityOverrides = {};
  final Map<String, AudioQuality> _audioQualityOverrides = {};

  VideoQuality? globalVideoQuality;
  AudioQuality? globalAudioQuality;
  bool globalIsAudioOnly = false;

  PlaylistEntity? get playlist => _playlist;
  Set<String> get selectedVideoIds => _selectedVideoIds;

  void setPlaylist(PlaylistEntity entity) {
    _playlist = entity;
    _selectedVideoIds = entity.videos.map((v) => v.id).toSet();
    _videoQualityOverrides.clear();
    _audioQualityOverrides.clear();
    globalIsAudioOnly = false;
    notifyListeners();
  }

  void toggleVideo(String videoId) {
    if (_selectedVideoIds.contains(videoId)) {
      _selectedVideoIds.remove(videoId);
    } else {
      _selectedVideoIds.add(videoId);
    }
    notifyListeners();
  }

  void toggleAll() {
    if (_playlist == null) return;
    if (_selectedVideoIds.length == _playlist!.videos.length) {
      _selectedVideoIds.clear();
    } else {
      _selectedVideoIds = _playlist!.videos.map((v) => v.id).toSet();
    }
    notifyListeners();
  }

  void setGlobalSettings(VideoQuality? vQuality, AudioQuality? aQuality, bool isAudio) {
    globalVideoQuality = vQuality;
    globalAudioQuality = aQuality;
    globalIsAudioOnly = isAudio;
    notifyListeners();
  }

  bool isSelected(String videoId) => _selectedVideoIds.contains(videoId);
  
  bool isAudioOnly(String videoId) {
    if (_audioQualityOverrides.containsKey(videoId)) return true;
    if (_videoQualityOverrides.containsKey(videoId)) return false;
    return globalIsAudioOnly;
  }

  VideoQuality? getVideoQuality(String videoId) => _videoQualityOverrides[videoId];
  AudioQuality? getAudioQuality(String videoId) => _audioQualityOverrides[videoId];

  void setVideoOverride(String videoId, VideoQuality? vQuality, AudioQuality? aQuality, bool isAudio) {
    if (isAudio) {
      if (aQuality != null) _audioQualityOverrides[videoId] = aQuality;
      _videoQualityOverrides.remove(videoId);
    } else {
      if (vQuality != null) _videoQualityOverrides[videoId] = vQuality;
      _audioQualityOverrides.remove(videoId);
    }
    notifyListeners();
  }

  List<DownloadTask> createDownloadTasks(String basePath) {
    if (playlist == null) return [];
    
    final now = DateTime.now();
    int index = 0;
    
    return playlist!.videos
        .where((v) => _selectedVideoIds.contains(v.id))
        .map((v) {
              final currentIndex = index++;
              final isAudio = isAudioOnly(v.id);
              
              return DownloadTask(
                taskId: const Uuid().v4(),
                videoId: v.id,
                title: v.title,
                thumbnailUrl: v.thumbnailUrl,
                videoQualityLabel: _videoQualityOverrides[v.id] != null 
                    ? '${_videoQualityOverrides[v.id]!.label}|${_videoQualityOverrides[v.id]!.height}' 
                    : (globalVideoQuality != null ? '${globalVideoQuality!.label}|${globalVideoQuality!.height}' : null),
                audioQualityLabel: _audioQualityOverrides[v.id]?.label ?? globalAudioQuality?.label,
                isAudioOnly: isAudio,
                outputPath: basePath,
                playlistId: playlist!.id,
                playlistTitle: playlist!.title,
                playlistIndex: currentIndex + 1,
                createdAt: now.subtract(Duration(milliseconds: currentIndex)),
              );
            })
        .toList();
  }

  void clear() {
    _playlist = null;
    _selectedVideoIds.clear();
    _videoQualityOverrides.clear();
    _audioQualityOverrides.clear();
    notifyListeners();
  }
}
