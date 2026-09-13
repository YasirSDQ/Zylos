import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'plugin_service.dart';

class FFmpegService {
  final PluginService _pluginService;

  FFmpegService(this._pluginService);

  /// Returns the path to ffmpeg.exe using PluginService.
  /// Returns null if not installed (caller should handle).
  Future<String?> ensureFfmpegExists() async {
    return _pluginService.getFfmpegPath();
  }

  // ── Generic Media Converter Logic ──────────────────────────────────────────

  Future<void> convertMedia({
    required String inputPath,
    required String outputPath,
    required List<String> ffmpegArgs,
    List<String>? inputArgs,
    required Function(double progress, String timeStr) onProgress,
    required Function() onComplete,
    required Function(String error) onError,
    void Function(int pid, void Function() cancel)? onStart,
  }) async {
    try {
      final exe = await ensureFfmpegExists();
      if (exe == null) {
        onError('FFmpeg is not installed. Please install it from the Plugin Manager in Tools.');
        return;
      }

      final dir = Directory(p.dirname(outputPath));
      if (!await dir.exists()) await dir.create(recursive: true);

      // Get duration for progress reporting
      final args = [
        '-y',
        if (inputArgs != null) ...inputArgs,
        '-i', inputPath,
        ...ffmpegArgs,
        outputPath,
      ];

      final process = await Process.start(exe, args, mode: ProcessStartMode.normal);
      onStart?.call(process.pid, () {
        process.kill();
      });

      final timeRegex = RegExp(r'time=(\d{2}):(\d{2}):(\d{2}\.\d{2})');

      Duration? totalDuration;
      final durRes = await Process.run(exe, ['-i', inputPath]);
      final durMatch = RegExp(r'Duration:\s+(\d{2}):(\d{2}):(\d{2}\.\d{2})').firstMatch(durRes.stderr.toString());
      if (durMatch != null) {
        final h = int.parse(durMatch.group(1)!);
        final m = int.parse(durMatch.group(2)!);
        final s = double.parse(durMatch.group(3)!);
        totalDuration = Duration(milliseconds: ((h * 3600 + m * 60 + s) * 1000).toInt());
      }

      const decoder = Utf8Decoder(allowMalformed: true);
      final sub = process.stderr.transform(decoder).listen((data) {
        final match = timeRegex.firstMatch(data);
        if (match != null) {
          final h = int.parse(match.group(1)!);
          final m = int.parse(match.group(2)!);
          final s = double.parse(match.group(3)!);
          final currentDur = Duration(milliseconds: ((h * 3600 + m * 60 + s) * 1000).toInt());

          double progress = 0.0;
          if (totalDuration != null && totalDuration.inMilliseconds > 0) {
            progress = currentDur.inMilliseconds / totalDuration.inMilliseconds;
            if (progress > 1.0) progress = 1.0;
          }
          final timeStr = '${match.group(1)}:${match.group(2)}:${match.group(3)?.split('.')[0]}';
          onProgress(progress, timeStr);
        }
      });

      final exitCode = await process.exitCode;
      await sub.cancel();

      if (exitCode == 0 && File(outputPath).existsSync()) {
        onProgress(1.0, 'Done');
        onComplete();
      } else {
        onError('Conversion failed with exit code $exitCode. File may be unsupported or corrupted.');
      }
    } catch (e) {
      onError('Error: ${e.toString()}');
    }
  }

  /// Returns the (width, height) of the first video or image stream.
  /// Returns null if dimensions cannot be determined.
  Future<(int, int)?> getMediaDimensions(String inputPath) async {
    try {
      final exe = await ensureFfmpegExists();
      if (exe == null) return null;
      final result = await Process.run(exe, ['-i', inputPath]);
      final output = result.stderr.toString();
      // Match patterns like: 1920x1080 or 1920×1080 or Video: ... 1920x1080,
      final match = RegExp(r'(\d{2,5})x(\d{2,5})').firstMatch(output);
      if (match != null) {
        final w = int.tryParse(match.group(1) ?? '') ?? 0;
        final h = int.tryParse(match.group(2) ?? '') ?? 0;
        if (w > 0 && h > 0) return (w, h);
      }
    } catch (_) {}
    return null;
  }
}
