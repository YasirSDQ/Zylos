import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/ffmpeg_service.dart';
import '../../../../core/utils/platform_utils.dart';

enum ConversionStatus { idle, selecting, converting, complete, error }

enum InputMediaType { unknown, audio, video, image }

enum ConversionFormat {
  // Audio — original
  mp3, aac, wav, flac, m4a, ogg, opus, wma, amr, ac3,
  // Audio — new
  mp2, aiff, ra, mka, dts, truehd, ape, m4b, caf,
  // Video — original
  mp4, mkv, avi, mov, webm, flv, tgp, ts, wmv, asf,
  // Video — new
  m4v, mpg, vob, divx, hevc, prores,
  // Image — original
  jpg, png, webp, gif, bmp, tiff,
  // Image — new
  svg, heic, avif, tga,
}

enum ConversionQuality { 
  low,      // quick presets
  medium,
  high,
  original
}

// ── Video resolution presets ─────────────────────────────────────────────────
class VideoResolution {
  final String label;
  final int height;   // -1 = keep original
  const VideoResolution(this.label, this.height);

  static const original = VideoResolution('Original', -1);
  static const p240      = VideoResolution('240p',  240);
  static const p360      = VideoResolution('360p',  360);
  static const p480      = VideoResolution('480p',  480);
  static const p720      = VideoResolution('720p',  720);
  static const p1080     = VideoResolution('1080p', 1080);
  static const p1440     = VideoResolution('1440p', 1440);
  static const p2160     = VideoResolution('4K',    2160);

  static const List<VideoResolution> presets = [
    original, p240, p360, p480, p720, p1080, p1440, p2160,
  ];

  String get scaleArg => height == -1 ? '' : 'scale=-2:$height';
}

class ConverterProvider extends ChangeNotifier {
  final FFmpegService _ffmpegService;

  List<String> _inputPaths = [];
  ConversionFormat _targetFormat = ConversionFormat.mp3;
  ConversionQuality _targetQuality = ConversionQuality.original;
  ConversionStatus _status = ConversionStatus.idle;
  String? _outputPath;
  double _progress = 0.0;
  String _timeRemainingStr = '';
  String? _errorMessage;
  InputMediaType _inputType = InputMediaType.unknown;
  
  // Queue state for bulk conversion
  int _currentFileIndex = 0;
  int get totalFiles => _inputPaths.length;
  int get currentFileIndex => _currentFileIndex;

  // ── Source file dimensions (detected after file pick) ────────────────────
  int? _sourceWidth;
  int? _sourceHeight;

  // ── Fine-grained controls ───────────────────────────────────────────────
  /// Audio bitrate in kbps. null = use quality preset.
  int? _customAudioKbps;      // 32–320 kbps
  /// CRF for video (0=lossless, 51=worst). null = use quality preset.
  int? _customVideoCrf;       // 0–51
  /// Video height for scaling. -1 = original. null = use quality preset.
  int? _customVideoHeight;
  /// Custom width for video (0 = auto). Only used if height set.
  int _customVideoWidth = 0;
  /// Image quality percentage. null = use quality preset.
  int? _customImageQuality;   // 1–100
  /// Custom image output width (0 = auto from aspect). null = use source.
  int? _customImageWidth;
  /// Custom image output height. null = use source.
  int? _customImageHeight;
  
  // ── Advanced / Cross-Format Controls ──────────────────────────────────────
  int? _customFramerate;
  String? _customVideoCodec; // e.g., 'libx264', 'libx265'
  int? _customSampleRate;    // e.g., 44100, 48000
  int? _customAudioChannels; // 1 (mono), 2 (stereo)
  String? _extractFrameTime; // e.g. '00:00:05'
  String? _imageToVideoDuration; // e.g. '5'
  
  List<String>? _currentInputArgs;

  bool _useCustomVideoResolution = false; // toggled by user

  ConverterProvider(this._ffmpegService);

  Future<(int, int)?> getMediaDimensions(String path) => _ffmpegService.getMediaDimensions(path);

  // Getters ─────────────────────────────────────────────────────────────────
  String? get inputPath           => _inputPaths.isNotEmpty ? _inputPaths.first : null;
  List<String> get inputPaths     => _inputPaths;
  ConversionFormat get targetFormat => _targetFormat;
  ConversionQuality get targetQuality => _targetQuality;
  ConversionStatus get status     => _status;
  String? get outputPath          => _outputPath;
  double get progress             => _progress;
  String get timeRemainingStr     => _timeRemainingStr;
  String? get errorMessage        => _errorMessage;
  InputMediaType get inputType    => _inputType;

  int? get customAudioKbps            => _customAudioKbps;
  int? get customVideoCrf             => _customVideoCrf;
  int? get customVideoHeight          => _customVideoHeight;
  int get customVideoWidth            => _customVideoWidth;
  int? get customImageQuality         => _customImageQuality;
  int? get customImageWidth           => _customImageWidth;
  int? get customImageHeight          => _customImageHeight;
  bool get useCustomVideoResolution   => _useCustomVideoResolution;
  int? get sourceWidth                => _sourceWidth;
  int? get sourceHeight               => _sourceHeight;

  int? get customFramerate            => _customFramerate;
  String? get customVideoCodec        => _customVideoCodec;
  int? get customSampleRate           => _customSampleRate;
  int? get customAudioChannels        => _customAudioChannels;
  String? get extractFrameTime        => _extractFrameTime;
  String? get imageToVideoDuration    => _imageToVideoDuration;

  // ── Resolved values (what will actually be used) ──────────────────────────

  /// The audio bitrate string that will be passed to ffmpeg.
  String get resolvedAudioBitrate {
    if (_customAudioKbps != null) return '${_customAudioKbps}k';
    switch (_targetQuality) {
      case ConversionQuality.low:      return '96k';
      case ConversionQuality.medium:   return '192k';
      case ConversionQuality.high:     return '320k';
      case ConversionQuality.original: return '320k';
    }
  }

  /// The video scale filter string (empty = keep original).
  String get resolvedVideoScale {
    if (_customVideoHeight != null) {
      if (_customVideoHeight! <= 0) return '';
      final w = _customVideoWidth > 0 ? _customVideoWidth : -2;
      return 'scale=$w:$_customVideoHeight';
    }
    switch (_targetQuality) {
      case ConversionQuality.low:      return 'scale=-2:480';
      case ConversionQuality.medium:   return 'scale=-2:720';
      case ConversionQuality.high:     return 'scale=-2:1080';
      case ConversionQuality.original: return '';
    }
  }

  /// The CRF value string for video.
  String get resolvedCrf {
    if (_customVideoCrf != null) return _customVideoCrf!.toString();
    switch (_targetQuality) {
      case ConversionQuality.low:      return '28';
      case ConversionQuality.medium:   return '23';
      case ConversionQuality.high:     return '18';
      case ConversionQuality.original: return '16';
    }
  }

  /// The image quality percentage (1–100).
  int get resolvedImageQuality {
    if (_customImageQuality != null) return _customImageQuality!;
    switch (_targetQuality) {
      case ConversionQuality.low:      return 65;
      case ConversionQuality.medium:   return 80;
      case ConversionQuality.high:     return 95;
      case ConversionQuality.original: return 100;
    }
  }

  // A human-readable label for the current audio bitrate slider value
  String get audioBitrateLabel {
    final kbps = _customAudioKbps ?? _presetAudioKbps;
    return '${kbps}kbps';
  }

  int get _presetAudioKbps {
    switch (_targetQuality) {
      case ConversionQuality.low:      return 96;
      case ConversionQuality.medium:   return 192;
      case ConversionQuality.high:     return 320;
      case ConversionQuality.original: return 320;
    }
  }

  // ── format predicates ─────────────────────────────────────────────────────

  static const _audioExts = {'.mp3','.aac','.wav','.flac','.m4a','.ogg','.opus','.wma','.amr','.ac3','.aiff','.alac','.mp2','.ra','.mka','.dts','.ape','.m4b','.caf'};
  static const _videoExts = {'.mp4','.mkv','.avi','.mov','.webm','.flv','.3gp','.ts','.wmv','.asf','.m4v','.mpeg','.mpg','.vob','.divx'};
  static const _imageExts = {'.jpg','.jpeg','.png','.webp','.gif','.bmp','.tiff','.tif','.heic','.heif','.svg','.avif','.tga'};

  bool get isAudioTarget => [
    ConversionFormat.mp3, ConversionFormat.aac, ConversionFormat.wav,
    ConversionFormat.flac, ConversionFormat.m4a, ConversionFormat.ogg,
    ConversionFormat.opus, ConversionFormat.wma, ConversionFormat.amr, ConversionFormat.ac3,
    ConversionFormat.mp2, ConversionFormat.aiff, ConversionFormat.ra, ConversionFormat.mka,
    ConversionFormat.dts, ConversionFormat.truehd, ConversionFormat.ape,
    ConversionFormat.m4b, ConversionFormat.caf,
  ].contains(_targetFormat);

  bool get isImageTarget => [
    ConversionFormat.jpg, ConversionFormat.png, ConversionFormat.webp,
    ConversionFormat.gif, ConversionFormat.bmp, ConversionFormat.tiff,
    ConversionFormat.svg, ConversionFormat.heic,
    ConversionFormat.avif, ConversionFormat.tga,
  ].contains(_targetFormat);

  bool isConditionallySupported(ConversionFormat format) {
    return [
      ConversionFormat.vob, ConversionFormat.divx, ConversionFormat.prores,
      ConversionFormat.caf, ConversionFormat.truehd, ConversionFormat.mpg
    ].contains(format);
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  InputMediaType _detectInputType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (_audioExts.contains(ext)) return InputMediaType.audio;
    if (_videoExts.contains(ext)) return InputMediaType.video;
    if (_imageExts.contains(ext)) return InputMediaType.image;
    return InputMediaType.unknown;
  }

  ConversionFormat _defaultFormatFor(InputMediaType type) {
    switch (type) {
      case InputMediaType.audio:   return ConversionFormat.mp3;
      case InputMediaType.video:   return ConversionFormat.mp4;
      case InputMediaType.image:   return ConversionFormat.jpg;
      case InputMediaType.unknown: return ConversionFormat.mp3;
    }
  }

  void setInputFile(String path) {
    setInputFiles([path]);
  }

  void setInputFiles(List<String> paths) {
    _inputPaths = paths;
    _currentFileIndex = 0;
    _inputType = _detectInputType(paths.first);
    _targetFormat = _defaultFormatFor(_inputType);
    _status = ConversionStatus.selecting;
    _progress = 0.0;
    _errorMessage = null;
    _outputPath = null;
    _sourceWidth = null;
    _sourceHeight = null;
    _resetCustomControls();
    notifyListeners();
    // Asynchronously detect source dimensions of the first file
    _ffmpegService.getMediaDimensions(paths.first).then((dims) {
      if (dims != null && _inputPaths.isNotEmpty && _inputPaths.first == paths.first) {
        _sourceWidth = dims.$1;
        _sourceHeight = dims.$2;
        notifyListeners();
      }
    });
  }

  void _resetCustomControls() {
    _customAudioKbps = null;
    _customVideoCrf = null;
    _customVideoHeight = null;
    _customVideoWidth = 0;
    _customImageQuality = null;
    _customImageWidth = null;
    _customImageHeight = null;
    _useCustomVideoResolution = false;
    _customFramerate = null;
    _customVideoCodec = null;
    _customSampleRate = null;
    _customAudioChannels = null;
    _extractFrameTime = null;
    _imageToVideoDuration = null;
  }

  /// Called by ffprobe result after file pick to populate source dimensions.
  void setSourceDimensions(int width, int height) {
    _sourceWidth = width;
    _sourceHeight = height;
    notifyListeners();
  }

  /// Sets custom image output dimensions.
  void setCustomImageDimensions(int width, int height) {
    _customImageWidth = width > 0 ? width : null;
    _customImageHeight = height > 0 ? height : null;
    notifyListeners();
  }

  void convertAnother() {
    _status = ConversionStatus.selecting;
    _progress = 0.0;
    _timeRemainingStr = '';
    _errorMessage = null;
    _outputPath = null;
    _currentFileIndex = 0;
    _inputPaths = [];
    notifyListeners();
  }

  void setTargetFormat(ConversionFormat format) {
    _targetFormat = format;
    // If the user taps a format after a completed conversion, immediately
    // go back to selecting so the Convert button re-appears.
    if (_status == ConversionStatus.complete) {
      _status = ConversionStatus.selecting;
      _progress = 0.0;
      _outputPath = null;
      _timeRemainingStr = '';
    }
    notifyListeners();
  }

  void setTargetQuality(ConversionQuality quality) {
    _targetQuality = quality;
    // Reset custom controls when preset changes so they start synced
    _resetCustomControls();
    notifyListeners();
  }

  // ── Fine-tune setters ─────────────────────────────────────────────────────

  void setCustomAudioKbps(int kbps) {
    _customAudioKbps = kbps.clamp(32, 320);
    notifyListeners();
  }

  void setCustomVideoCrf(int crf) {
    _customVideoCrf = crf.clamp(0, 51);
    notifyListeners();
  }

  /// Sets video height from a preset VideoResolution.
  void setVideoResolutionPreset(VideoResolution res) {
    _customVideoHeight = res.height;
    _customVideoWidth = 0; // auto width
    _useCustomVideoResolution = false;
    notifyListeners();
  }

  /// Sets a fully custom resolution (width×height). Pass 0 for width to auto.
  void setCustomVideoResolution(int width, int height) {
    _customVideoWidth = width;
    _customVideoHeight = height;
    _useCustomVideoResolution = true;
    notifyListeners();
  }

  void setCustomImageQuality(int? quality) {
    _customImageQuality = quality != null ? quality.clamp(1, 100) : null;
    notifyListeners();
  }

  void setAdvancedControls({
    int? framerate,
    String? videoCodec,
    int? sampleRate,
    int? audioChannels,
    String? extractFrameTime,
    String? imageToVideoDuration,
  }) {
    if (framerate != null) _customFramerate = framerate;
    if (videoCodec != null) _customVideoCodec = videoCodec;
    if (sampleRate != null) _customSampleRate = sampleRate;
    if (audioChannels != null) _customAudioChannels = audioChannels;
    if (extractFrameTime != null) _extractFrameTime = extractFrameTime;
    if (imageToVideoDuration != null) _imageToVideoDuration = imageToVideoDuration;
    notifyListeners();
  }

  void reset() {
    _inputPaths = [];
    _currentFileIndex = 0;
    _status = ConversionStatus.idle;
    _progress = 0.0;
    _timeRemainingStr = '';
    _errorMessage = null;
    _outputPath = null;
    _resetCustomControls();
    notifyListeners();
  }

  // ── Output path ───────────────────────────────────────────────────────────

  String _buildOutputPath(String inputFilePath, {int? suffix}) {
    // Map formats to correct file extensions
    final extMap = {
      'tgp': '3gp',
      'truehd': 'thd',
      'hevc': 'h265',
      'prores': 'mov',
      'mpg': 'mpg',
      'divx': 'avi',
    };
    final ext = extMap[_targetFormat.name] ?? _targetFormat.name;
    final baseName = p.basenameWithoutExtension(inputFilePath);
    
    // Create folders for format: e.g. Zylos/mp3
    final activeDir = PlatformUtils.getActiveDownloadPath();
    final outputDir = p.join(activeDir, ext);
    if (!Directory(outputDir).existsSync()) Directory(outputDir).createSync(recursive: true);
    
    final suffixStr = suffix != null ? ' ($suffix)' : '';
    return p.join(outputDir, '$baseName$suffixStr.$ext');
  }

  String _autoNumberedPath(String inputFilePath) {
    var candidate = _buildOutputPath(inputFilePath);
    if (!File(candidate).existsSync()) return candidate;
    int i = 2;
    while (true) {
      candidate = _buildOutputPath(inputFilePath, suffix: i);
      if (!File(candidate).existsSync()) return candidate;
      i++;
    }
  }

  bool outputFileExists() {
    if (_inputPaths.isEmpty) return false;
    // Check if ANY file exists (just check the first one for simplicity of the prompt)
    return File(_buildOutputPath(_inputPaths.first)).existsSync();
  }

  Future<void> startConversion({bool overwrite = false}) async {
    if (_inputPaths.isEmpty) return;

    _status = ConversionStatus.converting;
    _errorMessage = null;
    _currentFileIndex = 0;
    notifyListeners();

    for (int i = 0; i < _inputPaths.length; i++) {
      _currentFileIndex = i;
      _progress = 0.0;
      notifyListeners();

      final currentInputPath = _inputPaths[i];
      final currentOutputPath = overwrite ? _buildOutputPath(currentInputPath) : _autoNumberedPath(currentInputPath);
      _outputPath = currentOutputPath; // keep track of the last output path for the complete screen

      final ffmpegArgs = _buildFfmpegArgs();

      try {
        await _ffmpegService.convertMedia(
          inputPath: currentInputPath,
          outputPath: currentOutputPath,
          ffmpegArgs: ffmpegArgs,
          inputArgs: _currentInputArgs,
          onProgress: (prog, timeStr) {
            _progress = prog;
            _timeRemainingStr = timeStr;
            notifyListeners();
          },
          onComplete: () {},
          onError: (err) {
            throw Exception(err);
          },
        );
      } catch (e) {
        _status = ConversionStatus.error;
        _errorMessage = e.toString();
        notifyListeners();
        return; // stop bulk conversion on error
      }
    }

    _status = ConversionStatus.complete;
    _progress = 1.0;
    notifyListeners();
  }

  /// Utility method to convert a single file without modifying the provider's global state.
  /// Useful for bulk/manager screens that track their own state.
  Future<void> convertFile({
    required String inputPath,
    required String outputPath,
    required ConversionFormat format,
    String? bitrate,
    String? resolution,
    required Function(double) onProgress,
    void Function(int pid, void Function() cancel)? onStart,
  }) async {
    final List<String> args = [];

    if (bitrate != null && bitrate != 'Auto' && bitrate != 'Original') {
      args.addAll(['-b:a', bitrate]);
    }

    final ext = inputPath.split('.').last.toLowerCase();
    final isAudioInput = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'opus', 'mka', 'wma', 'amr', 'ptt', 'ac3', 'dts'].contains(ext);

    if (resolution != null && resolution != 'Keep Original' && resolution != 'Original' && !isAudioInput) {
      // Check if it's an image format
      const imageFmts = [
        ConversionFormat.jpg, ConversionFormat.png, ConversionFormat.webp, 
        ConversionFormat.gif, ConversionFormat.bmp, ConversionFormat.tiff, 
        ConversionFormat.svg, ConversionFormat.heic
      ];
      
      if (imageFmts.contains(format)) {
        if (resolution!.endsWith('%') && !['100%', '80%', '60%'].contains(resolution)) {
          final pctStr = resolution.replaceAll('%', '');
          final pct = int.tryParse(pctStr);
          if (pct != null) {
            final factor = pct / 100.0;
            args.addAll(['-vf', 'scale=iw*${factor}:ih*${factor}']);
          }
        } else if (resolution!.contains('x')) {
          final parts = resolution.split('x');
          if (parts.length == 2 && int.tryParse(parts[0]) != null && int.tryParse(parts[1]) != null) {
            args.addAll(['-vf', 'scale=${parts[0]}:${parts[1]}']);
          }
        }
        if (format == ConversionFormat.jpg || format == ConversionFormat.webp) {
          int q = 25; // default low quality if 60%
          if (resolution == '100%' || resolution.contains('x') || resolution.endsWith('%')) q = 2; // high quality
          if (resolution == '80%') q = 10; // medium quality
          args.addAll(format == ConversionFormat.jpg ? ['-q:v', q.toString()] : ['-quality', (100 - (q*2)).toString()]);
        }
      } else {
        String scale;
        switch (resolution) {
          case '4K':
          case '4K (2160p)': scale = 'scale=-2:2160'; break;
          case '1080p': scale = 'scale=-2:1080'; break;
          case '720p': scale = 'scale=-2:720'; break;
          case '480p': scale = 'scale=-2:480'; break;
          case '360p': scale = 'scale=-2:360'; break;
          default: 
            if (resolution.endsWith('%')) {
              final pctStr = resolution.replaceAll('%', '');
              final pct = int.tryParse(pctStr);
              if (pct != null) {
                final factor = pct / 100.0;
                scale = 'scale=iw*${factor}:ih*${factor}';
              } else {
                scale = '';
              }
            } else if (resolution.contains('x')) {
              final parts = resolution.split('x');
              if (parts.length == 2 && int.tryParse(parts[0]) != null && int.tryParse(parts[1]) != null) {
                scale = 'scale=${parts[0]}:${parts[1]}';
              } else {
                scale = '';
              }
            } else {
              scale = ''; 
            }
            break;
        }
        if (scale.isNotEmpty) {
          args.addAll(['-vf', scale]);
        }
      }
    }

    await _ffmpegService.convertMedia(
      inputPath: inputPath,
      outputPath: outputPath,
      ffmpegArgs: args,
      onProgress: (prog, _) => onProgress(prog),
      onComplete: () {},
      onError: (err) => throw Exception(err),
      onStart: onStart,
    );
  }

  // ── FFmpeg args builder ───────────────────────────────────────────────────

  List<String> _buildFfmpegArgs() {
    _currentInputArgs = null;
    final audioBitrate = resolvedAudioBitrate;
    final videoScale   = resolvedVideoScale;
    final crf          = resolvedCrf;
    final imgQuality   = resolvedImageQuality;

    List<String> ffmpegArgs = [];

    // ── IMAGE ───────────────────────────────────────────────────────────────
    if (isImageTarget) {
      if (_inputType == InputMediaType.video) {
        // Video to Picture
        final time = _extractFrameTime ?? '00:00:01';
        return ['-ss', time, '-vframes', '1', '-q:v', '2'];
      }
      if (_inputType == InputMediaType.audio) {
        // Audio to Picture (Extract album art)
        return ['-map', '0:v', '-c', 'copy'];
      }
      // Build scale filter if custom dimensions are specified
      String? imgScaleFilter;
      if (_customImageWidth != null || _customImageHeight != null) {
        final w = _customImageWidth != null ? _customImageWidth!.toString() : '-1';
        final h = _customImageHeight != null ? _customImageHeight!.toString() : '-1';
        // For GIF we handle it inline; for others use a simple scale
        if (_targetFormat != ConversionFormat.gif) {
          imgScaleFilter = 'scale=$w:$h';
        }
      }

      switch (_targetFormat) {
        case ConversionFormat.jpg:
          ffmpegArgs = [
            if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ],
            '-q:v', ((100 - imgQuality) ~/ 4).clamp(1, 25).toString(),
          ];
          break;
        case ConversionFormat.png:
          ffmpegArgs = [
            if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ],
            '-compression_level', '6',
          ];
          break;
        case ConversionFormat.webp:
          ffmpegArgs = [
            if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ],
            '-quality', imgQuality.toString(),
          ];
          break;
        case ConversionFormat.gif:
          final scaleW = _customImageWidth != null ? _customImageWidth!.toString() : '-1';
          final scaleH = _customImageHeight != null ? _customImageHeight!.toString() : '320';
          ffmpegArgs = ['-vf', 'fps=15,scale=$scaleW:$scaleH:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse'];
          break;
        case ConversionFormat.bmp:
          ffmpegArgs = [ if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ] ];
          break;
        case ConversionFormat.tiff:
          ffmpegArgs = [
            if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ],
            '-compression_algo', 'lzw',
          ];
          break;
        default:
          ffmpegArgs = [ if (imgScaleFilter != null) ...[ '-vf', imgScaleFilter ] ];
      }
      return ffmpegArgs;
    }

    // ── AUDIO ────────────────────────────────────────────────────────────────
    if (isAudioTarget) {
      ffmpegArgs = ['-vn'];
      switch (_targetFormat) {
        case ConversionFormat.mp3:
          ffmpegArgs.addAll(['-acodec', 'libmp3lame', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.aac:
        case ConversionFormat.m4a:
          ffmpegArgs.addAll(['-acodec', 'aac', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.wav:
          ffmpegArgs.addAll(['-acodec', 'pcm_s16le']);
          break;
        case ConversionFormat.flac:
          ffmpegArgs.addAll(['-acodec', 'flac']);
          break;
        case ConversionFormat.ogg:
          ffmpegArgs.addAll(['-acodec', 'libvorbis', '-q:a', '4']);
          break;
        case ConversionFormat.opus:
          ffmpegArgs.addAll(['-acodec', 'libopus', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.wma:
          ffmpegArgs.addAll(['-acodec', 'wmav2', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.amr:
          ffmpegArgs.addAll(['-acodec', 'libopencore_amrnb', '-ar', '8000', '-ac', '1', '-b:a', '12.2k']);
          break;
        case ConversionFormat.ac3:
          ffmpegArgs.addAll(['-acodec', 'ac3', '-b:a', audioBitrate]);
          break;
        // ── New audio formats ─────────────────────────────────────────────
        case ConversionFormat.mp2:
          ffmpegArgs.addAll(['-acodec', 'mp2', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.aiff:
          ffmpegArgs.addAll(['-acodec', 'pcm_s16be']);
          break;
        case ConversionFormat.ra:
          ffmpegArgs.addAll(['-acodec', 'real_144']);
          break;
        case ConversionFormat.mka:
          ffmpegArgs.addAll(['-acodec', 'flac']);
          break;
        case ConversionFormat.dts:
          ffmpegArgs.addAll(['-acodec', 'dca', '-b:a', audioBitrate, '-strict', '-2']);
          break;
        case ConversionFormat.truehd:
          ffmpegArgs.addAll(['-acodec', 'truehd']);
          break;
        case ConversionFormat.ape:
          ffmpegArgs.addAll(['-acodec', 'ape']);
          break;
        case ConversionFormat.m4b:
          ffmpegArgs.addAll(['-acodec', 'aac', '-b:a', audioBitrate]);
          break;
        case ConversionFormat.caf:
          ffmpegArgs.addAll(['-acodec', 'pcm_s16le']);
          break;
        default:
          ffmpegArgs.addAll(['-b:a', audioBitrate]);
      }
      return ffmpegArgs;
    }

    // ── VIDEO ────────────────────────────────────────────────────────────────
    if (!isAudioTarget && !isImageTarget) {
      if (_inputType == InputMediaType.image) {
        final duration = _imageToVideoDuration ?? '5';
        _currentInputArgs = ['-loop', '1'];
        return ['-t', duration, '-c:v', 'libx264', '-pix_fmt', 'yuv420p'];
      }
      if (_inputType == InputMediaType.audio) {
        return ['-f', 'lavfi', '-i', 'color=c=black:s=1280x720:r=30', '-map', '1:v', '-map', '0:a', '-c:v', 'libx264', '-tune', 'stillimage', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', audioBitrate, '-shortest'];
      }
      
      if (videoScale.isNotEmpty) {
      ffmpegArgs = ['-vf', videoScale, '-c:v', 'libx264', '-crf', crf, '-preset', 'medium', '-c:a', 'aac', '-b:a', '192k'];
    } else {
      ffmpegArgs = ['-c:v', 'libx264', '-crf', crf, '-preset', 'slow', '-c:a', 'aac', '-b:a', '256k'];
    }

    switch (_targetFormat) {
      case ConversionFormat.avi:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'libxvid', '-qscale:v', '3', '-c:a', 'libmp3lame', '-b:a', '128k'];
        break;
      case ConversionFormat.webm:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'libvpx-vp9', '-crf', crf, '-b:v', '0', '-c:a', 'libopus'];
        break;
      case ConversionFormat.flv:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'flv1', '-c:a', 'libmp3lame'];
        break;
      case ConversionFormat.tgp:
        ffmpegArgs = ['-vf', 'scale=320:240', '-c:v', 'h263', '-c:a', 'aac', '-b:a', '32k', '-ar', '8000', '-ac', '1'];
        break;
      case ConversionFormat.ts:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'libx264', '-crf', crf, '-preset', 'fast', '-c:a', 'aac', '-b:a', '192k', '-f', 'mpegts'];
        break;
      case ConversionFormat.wmv:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'wmv2', '-b:v', '1500k', '-c:a', 'wmav2', '-b:a', audioBitrate];
        break;
      case ConversionFormat.asf:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'msmpeg4v2', '-b:v', '1500k', '-c:a', 'wmav2', '-b:a', audioBitrate];
        break;

      // ── New video formats ───────────────────────────────────────────────
      case ConversionFormat.m4v:
      case ConversionFormat.mpg:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'mpeg2video', '-b:v', '2000k', '-c:a', 'mp2', '-b:a', audioBitrate];
        break;
      case ConversionFormat.vob:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'mpeg2video', '-c:a', 'ac3', '-b:a', audioBitrate, '-f', 'vob'];
        break;
      case ConversionFormat.divx:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'mpeg4', '-vtag', 'DIVX', '-qscale:v', '3', '-c:a', 'libmp3lame', '-b:a', audioBitrate];
        break;
      case ConversionFormat.hevc:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'libx265', '-crf', crf, '-preset', 'medium', '-c:a', 'aac', '-b:a', '192k'];
        break;
      case ConversionFormat.prores:
        ffmpegArgs = [if (videoScale.isNotEmpty) ...['-vf', videoScale], '-c:v', 'prores_ks', '-profile:v', '3', '-c:a', 'pcm_s16le'];
        break;
      default:
        break;
    }
    }
    return ffmpegArgs;
  }
}
