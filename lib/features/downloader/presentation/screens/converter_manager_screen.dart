import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:desktop_drop/desktop_drop.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../core/utils/windows_process_manager.dart';
import '../providers/plugin_provider.dart';
import '../providers/converter_provider.dart';
import '../providers/settings_provider.dart';

// ── Supported output formats ─────────────────────────────────────────────────

const _formatIcons = {
  // Audio
  ConversionFormat.mp3:    Icons.music_note_rounded,
  ConversionFormat.aac:    Icons.music_note_rounded,
  ConversionFormat.wav:    Icons.graphic_eq_rounded,
  ConversionFormat.flac:   Icons.high_quality_rounded,
  ConversionFormat.m4a:    Icons.music_note_rounded,
  ConversionFormat.ogg:    Icons.music_note_rounded,
  ConversionFormat.opus:   Icons.music_note_rounded,
  ConversionFormat.wma:    Icons.music_note_rounded,
  ConversionFormat.amr:    Icons.phone_in_talk_rounded,
  ConversionFormat.ac3:    Icons.surround_sound_rounded,
  ConversionFormat.mp2:    Icons.music_note_rounded,
  ConversionFormat.aiff:   Icons.graphic_eq_rounded,
  ConversionFormat.ra:     Icons.radio_rounded,
  ConversionFormat.mka:    Icons.audio_file_rounded,
  ConversionFormat.dts:    Icons.surround_sound_rounded,
  ConversionFormat.truehd: Icons.hd_rounded,
  ConversionFormat.ape:    Icons.high_quality_rounded,
  ConversionFormat.m4b:    Icons.library_music_rounded,
  ConversionFormat.caf:    Icons.audiotrack_rounded,
  // Video
  ConversionFormat.mp4:    Icons.videocam_rounded,
  ConversionFormat.mkv:    Icons.videocam_rounded,
  ConversionFormat.avi:    Icons.videocam_rounded,
  ConversionFormat.mov:    Icons.videocam_rounded,
  ConversionFormat.webm:   Icons.videocam_rounded,
  ConversionFormat.flv:    Icons.videocam_rounded,
  ConversionFormat.tgp:    Icons.stay_primary_portrait_rounded,
  ConversionFormat.ts:     Icons.live_tv_rounded,
  ConversionFormat.wmv:    Icons.videocam_rounded,
  ConversionFormat.asf:    Icons.videocam_rounded,
  ConversionFormat.m4v:    Icons.videocam_rounded,
  ConversionFormat.mpg:    Icons.video_file_rounded,
  ConversionFormat.vob:    Icons.disc_full_rounded,
  ConversionFormat.divx:   Icons.videocam_rounded,
  ConversionFormat.hevc:   Icons.hd_rounded,
  ConversionFormat.prores: Icons.movie_filter_rounded,
  // Image
  ConversionFormat.jpg:    Icons.image_rounded,
  ConversionFormat.png:    Icons.image_rounded,
  ConversionFormat.webp:   Icons.image_rounded,
  ConversionFormat.gif:    Icons.gif_rounded,
  ConversionFormat.bmp:    Icons.image_rounded,
  ConversionFormat.tiff:   Icons.image_rounded,
  ConversionFormat.svg:    Icons.design_services_rounded,
  ConversionFormat.heic:   Icons.image_rounded,
};

// ── Bulk job ─────────────────────────────────────────────────────────────────

enum _JobStatus { pending, converting, paused, done, error }

class _BulkJob {
  final String id;
  final String sourcePath;
  String fileName;
  final String fileSizeStr;
  final String originalFormat;
  ConversionFormat outputFormat;
  String bitrate;
  String resolution;
  _JobStatus status;
  double progress;
  String? errorMessage;
  String? outputPath;
  void Function()? cancelMethod;
  int? processId;
  String? conflictResolution;

  _BulkJob({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.fileSizeStr,
    required this.originalFormat,
    required this.outputFormat,
    this.bitrate = 'Original',
    this.resolution = 'Original',
    this.status = _JobStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    this.cancelMethod,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERTER MANAGER SCREEN — Update 3.0
// ═══════════════════════════════════════════════════════════════════════════════

class ConverterManagerScreen extends StatefulWidget {
  const ConverterManagerScreen({super.key});

  @override
  State<ConverterManagerScreen> createState() => _ConverterManagerScreenState();
}

class _ConverterManagerScreenState extends State<ConverterManagerScreen>
    with SingleTickerProviderStateMixin {
  // ── Bulk mode state ───────────────────────────────────────────────────────
  final List<_BulkJob> _bulkJobs = [];
  bool _isDragging = false;
  ConversionFormat _bulkGlobalFormat = ConversionFormat.mp4;
  String _bulkGlobalQuality = 'Original';
  bool _bulkRunning = false;
  bool _advancedAutoDetect = true;
  bool _isQueuePaused = false;
  String? _globalConflictResolution;

  int get _actualMaxConcurrent {
    return context.read<SettingsProvider>().converterMaxConcurrent;
  }

  // ── Shared ────────────────────────────────────────────────────────────────
  String get _outputDir => context.read<SettingsProvider>().currentDownloadPath ?? PlatformUtils.getDefaultDownloadPath();

  final _bitrateOptions = ['Auto', '128k', '192k', '256k', '320k', '64k', '96k'];
  final _resolutionOptions = ['Keep Original', '4K (2160p)', '1080p', '720p', '480p', '360p', '240p', '144p'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Format helpers ────────────────────────────────────────────────────────

  Color _formatColor(ConversionFormat fmt) {
    if (_isAudio(fmt)) return const Color(0xFF8B5CF6);
    if (_isVideo(fmt)) return const Color(0xFF06B6D4);
    return const Color(0xFFEC4899);
  }

  String _getCategoryFolder(ConversionFormat fmt) {
    if (_isAudio(fmt)) return 'Audio';
    if (_isVideo(fmt)) return 'Video';
    return 'Image';
  }

  bool _isAudio(ConversionFormat fmt) {
    const audioFmts = {
      ConversionFormat.mp3, ConversionFormat.aac, ConversionFormat.wav,
      ConversionFormat.flac, ConversionFormat.m4a, ConversionFormat.ogg,
      ConversionFormat.opus, ConversionFormat.wma, ConversionFormat.amr,
      ConversionFormat.ac3, ConversionFormat.mp2, ConversionFormat.aiff,
      ConversionFormat.ra, ConversionFormat.mka, ConversionFormat.dts,
      ConversionFormat.truehd, ConversionFormat.ape, ConversionFormat.m4b,
      ConversionFormat.caf,
    };
    return audioFmts.contains(fmt);
  }

  bool _isVideo(ConversionFormat fmt) {
    const videoFmts = {
      ConversionFormat.mp4, ConversionFormat.mkv, ConversionFormat.avi,
      ConversionFormat.mov, ConversionFormat.webm, ConversionFormat.flv,
      ConversionFormat.tgp, ConversionFormat.ts, ConversionFormat.wmv,
      ConversionFormat.asf, ConversionFormat.m4v, ConversionFormat.mpg,
      ConversionFormat.vob, ConversionFormat.divx, ConversionFormat.hevc,
      ConversionFormat.prores,
    };
    return videoFmts.contains(fmt);
  }

  String _formatLabel(ConversionFormat fmt) => fmt.name.toUpperCase();

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const s = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < s.length - 1) { size /= 1024; i++; }
    return '${size.toStringAsFixed(1)} ${s[i]}';
  }

  // ── File picking ──────────────────────────────────────────────────────────



  Future<void> _pickBulkFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', 'ts', 'wmv', 'm4v',
        'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg', 'wma', 'ptt', 'ac3', 'mka', 'opus',
        'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'heic'
      ],
    );
    if (result != null) {
      for (final f in result.files) {
        if (f.path != null) _addBulkFile(f.path!);
      }
    }
  }
  void _applyAutoDetectToPending(bool enabled) {
    for (var job in _bulkJobs.where((j) => j.status != _JobStatus.converting)) {
      if (enabled) {
        final ext = p.extension(job.sourcePath).toLowerCase();
        const audioExts = ['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.wma', '.ptt', '.ac3', '.mka', '.opus'];
        const videoExts = ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts'];
        const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.tiff', '.heic'];
        
        if (audioExts.contains(ext)) job.outputFormat = ConversionFormat.mp3;
        else if (videoExts.contains(ext)) job.outputFormat = ConversionFormat.mp4;
        else if (imageExts.contains(ext)) job.outputFormat = ConversionFormat.jpg;
      } else {
        job.outputFormat = _bulkGlobalFormat;
      }
      
      if (job.status == _JobStatus.done || job.status == _JobStatus.error) {
        job.status = _JobStatus.pending;
        job.errorMessage = null;
        job.progress = 0.0;
      }
    }
  }
  void _addBulkFile(String path) {
    final name = p.basenameWithoutExtension(path);
    if (_bulkJobs.any((j) => j.sourcePath == path)) return;

    final file = File(path);
    String sizeStr = '';
    if (file.existsSync()) {
      final bytes = file.lengthSync();
      if (bytes < 1024 * 1024) {
        sizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }
    final origFormat = p.extension(path).replaceAll('.', '').toUpperCase();

    // Advanced Auto-Detect logic
    ConversionFormat initialFormat = _bulkGlobalFormat;
    if (_advancedAutoDetect) {
      final ext = p.extension(path).toLowerCase();
      const audioExts = ['.mp3', '.m4a', '.wav', '.aac', '.flac', '.ogg', '.wma', '.ptt', '.ac3', '.mka', '.opus'];
      const videoExts = ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts'];
      const imageExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.tiff', '.heic'];
      
      if (audioExts.contains(ext)) {
        initialFormat = ConversionFormat.mp3;
      } else if (videoExts.contains(ext)) {
        initialFormat = ConversionFormat.mp4;
      } else if (imageExts.contains(ext)) {
        initialFormat = ConversionFormat.jpg;
      }
    }

    setState(() {
      _bulkJobs.add(_BulkJob(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_bulkJobs.length}',
        sourcePath: path,
        fileName: name,
        fileSizeStr: sizeStr,
        originalFormat: origFormat,
        outputFormat: initialFormat,
        bitrate: _bulkGlobalQuality,
        resolution: _bulkGlobalQuality,
      ));
    });
  }

  void _removeBulkJob(String id) {
    setState(() => _bulkJobs.removeWhere((j) => j.id == id));
  }

  void _clearCompleted() {
    setState(() {
      _bulkJobs.removeWhere((j) => j.status == _JobStatus.done);
      _globalConflictResolution = null;
    });
  }

  // ── Bulk conversion ───────────────────────────────────────────────────────

  // ── Queue Processing ────────────────────────────────────────────────────────

  Future<void> _processQueue() async {
    if (_bulkJobs.isEmpty || !_bulkRunning) return;
    
    final activeJobs = _bulkJobs.where((j) => j.status == _JobStatus.converting).length;
    if (activeJobs >= _actualMaxConcurrent || _isQueuePaused) return;

    final pending = _bulkJobs.where((j) => j.status == _JobStatus.pending).toList();
    if (pending.isEmpty) {
      if (activeJobs == 0 && mounted) {
        setState(() => _bulkRunning = false);
      }
      return;
    }

    final job = pending.first;
    
    // IMMEDIATELY mark as converting to prevent concurrent workers from grabbing the same job
    setState(() {
      job.status = _JobStatus.converting;
      job.progress = 0.0;
    });

    await _processSpecificJob(job, fromQueue: true);
  }

  Future<void> _processSpecificJob(_BulkJob job, {bool fromQueue = false}) async {
    // If not already marked as converting, mark it now (for single job triggers)
    if (job.status != _JobStatus.converting) {
      setState(() {
        job.status = _JobStatus.converting;
        job.progress = 0.0;
      });
    }

    bool hasConflicts = false;
    final ext = job.outputFormat.name;
    final baseName = p.basenameWithoutExtension(job.sourcePath);
    final category = _getCategoryFolder(job.outputFormat);
    final outDir = p.join(_outputDir, 'Converter', category);
    final conflictPath = p.join(outDir, '$baseName.$ext');
    
    if (File(conflictPath).existsSync()) {
      hasConflicts = true;
    }

    String conflictResolution = 'skip';
    if (job.conflictResolution != null) {
      conflictResolution = job.conflictResolution!;
    } else if (hasConflicts) {
      if (_globalConflictResolution != null) {
        conflictResolution = _globalConflictResolution!;
      } else {
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            bool applyToAll = false;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('File Already Exists', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Destination file "${p.basename(conflictPath)}" already exists. What would you like to do?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: applyToAll,
                            onChanged: (v) => setDialogState(() => applyToAll = v ?? false),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Text('Apply to all remaining conflicts', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, applyToAll ? 'skip_all' : 'skip'), child: const Text('Skip')),
                    TextButton(onPressed: () => Navigator.pop(ctx, applyToAll ? 'keep_all' : 'keep'), child: const Text('Keep Both')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, applyToAll ? 'overwrite_all' : 'overwrite'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                      child: const Text('Overwrite'),
                    ),
                  ],
                );
              }
            );
          },
        );
        if (result == null) {
          setState(() => job.status = _JobStatus.paused);
          if (fromQueue && _bulkRunning) _processQueue();
          return; // Dialog canceled
        }
        
        if (result.endsWith('_all')) {
          _globalConflictResolution = result.replaceAll('_all', '');
          conflictResolution = _globalConflictResolution!;
        } else {
          conflictResolution = result;
        }
      }
    }

    if (!mounted) return;
    
    // Only set bulkRunning if we started from queue
    if (fromQueue) {
      setState(() => _bulkRunning = true);
    }

    if (!Directory(outDir).existsSync()) Directory(outDir).createSync(recursive: true);
    
    var outPath = conflictPath;
    bool useTempFile = false;

    if (File(outPath).existsSync()) {
      if (conflictResolution == 'skip') {
        setState(() {
          job.status = _JobStatus.done;
          job.progress = 1.0;
          job.outputPath = outPath;
        });
        if (fromQueue || _bulkRunning) _processQueue(); // proceed to next
        return;
      } else if (conflictResolution == 'keep') {
        int suffix = 1;
        while (File(outPath).existsSync()) {
          outPath = p.join(outDir, '$baseName ($suffix).$ext');
          suffix++;
        }
      } else if (conflictResolution == 'overwrite') {
        if (job.sourcePath == outPath) {
          useTempFile = true;
        }
      }
    }

    final actualFFmpegOutputPath = useTempFile ? '$outPath.tmp' : outPath;

    final provider = context.read<ConverterProvider>();

    try {
      await provider.convertFile(
        inputPath: job.sourcePath,
        outputPath: actualFFmpegOutputPath,
        format: job.outputFormat,
        bitrate: job.bitrate,
        resolution: job.resolution,
        onProgress: (prog) {
          if (mounted && job.status == _JobStatus.converting) {
            setState(() => job.progress = prog);
          }
        },
        onStart: (pid, cancelFn) {
          job.processId = pid;
          job.cancelMethod = cancelFn;
        }
      );
      
      // If we got here and status is paused, it means it was cancelled intentionally.
      if (job.status == _JobStatus.paused) {
        if (File(actualFFmpegOutputPath).existsSync()) File(actualFFmpegOutputPath).deleteSync();
        if (fromQueue || _bulkRunning) _processQueue(); // trigger next
        return;
      }
      
      if (useTempFile) {
        final tempFile = File(actualFFmpegOutputPath);
        if (tempFile.existsSync()) tempFile.renameSync(outPath);
      }

      if (mounted) setState(() {
        job.status = _JobStatus.done;
        job.outputPath = outPath;
        job.progress = 1.0;
        job.cancelMethod = null;
      });
    } catch (e) {
      if (job.status == _JobStatus.paused || job.status == _JobStatus.pending) {
        if (File(actualFFmpegOutputPath).existsSync()) File(actualFFmpegOutputPath).deleteSync();
      } else {
        if (useTempFile && File(actualFFmpegOutputPath).existsSync()) File(actualFFmpegOutputPath).deleteSync();
        if (mounted) setState(() {
          job.status = _JobStatus.error;
          job.errorMessage = e.toString();
          job.cancelMethod = null;
        });
      }
    }

    // Process next item in queue if queue is running
    if (fromQueue || _bulkRunning) {
      _processQueue();
    }
  }

  void _pauseJob(String id) {
    final job = _bulkJobs.firstWhere((j) => j.id == id);
    if (job.status == _JobStatus.converting) {
      if (Platform.isWindows && job.processId != null) {
        WindowsProcessManager.suspendProcess(job.processId!);
      } else {
        job.cancelMethod?.call();
      }
    }
    setState(() {
      job.status = _JobStatus.paused;
    });
    _processQueue(); // Try to fill the newly opened slot
  }

  void _resumeJob(String id) {
    final job = _bulkJobs.firstWhere((j) => j.id == id);
    if (Platform.isWindows && job.processId != null) {
      setState(() {
        job.status = _JobStatus.converting;
        _isQueuePaused = false;
      });
      WindowsProcessManager.resumeProcess(job.processId!);
    } else {
      setState(() {
        job.status = _JobStatus.pending;
        _isQueuePaused = false;
      });
      _processQueue();
    }
  }

  void _pauseAll() {
    setState(() {
      _isQueuePaused = true;
      for (final j in _bulkJobs) {
        if (j.status == _JobStatus.converting) {
          if (Platform.isWindows && j.processId != null) {
            WindowsProcessManager.suspendProcess(j.processId!);
          } else {
            j.cancelMethod?.call();
            j.progress = 0.0;
          }
          j.status = _JobStatus.paused;
        } else if (j.status == _JobStatus.pending) {
          j.status = _JobStatus.paused;
        }
      }
      _bulkRunning = false;
    });
  }

  Future<void> _cancelAll() async {
    final confirm = await _showCancelWarningDialog(context);
    if (!confirm) return;

    setState(() {
      for (final job in _bulkJobs) {
        if (job.status == _JobStatus.converting || job.status == _JobStatus.paused) {
          if (Platform.isWindows && job.processId != null && job.status == _JobStatus.paused) {
            WindowsProcessManager.resumeProcess(job.processId!);
          }
          job.cancelMethod?.call();
          job.status = _JobStatus.pending;
          job.progress = 0.0;
          job.errorMessage = null;
        }
      }
      _bulkRunning = false;
      _isQueuePaused = false;
    });
  }

  Future<void> _cancelSpecificJob(_BulkJob job) async {
    final confirm = await _showCancelWarningDialog(context);
    if (!confirm) return;

    setState(() {
      if (Platform.isWindows && job.processId != null && job.status == _JobStatus.paused) {
        WindowsProcessManager.resumeProcess(job.processId!);
      }
      job.cancelMethod?.call();
      job.status = _JobStatus.pending;
      job.progress = 0.0;
      job.errorMessage = null;
    });
  }

  void _playAll() async {
    final pendingJobs = _bulkJobs.where((j) => j.status == _JobStatus.paused || j.status == _JobStatus.error || j.status == _JobStatus.pending).toList();
    if (pendingJobs.isEmpty) return;

    final toResume = pendingJobs.where((j) => j.status == _JobStatus.paused && j.processId != null).toList();
    final toRestart = pendingJobs.where((j) => !toResume.contains(j)).toList();

    final conflictingJobs = <_BulkJob>[];
    for (final job in toRestart) {
      final ext = job.outputFormat.name;
      final baseName = p.basenameWithoutExtension(job.sourcePath);
      final category = _getCategoryFolder(job.outputFormat);
      final outDir = p.join(_outputDir, 'Converter', category);
      final conflictPath = p.join(outDir, '$baseName.$ext');
      if (File(conflictPath).existsSync()) {
        conflictingJobs.add(job);
      }
    }

    if (conflictingJobs.isNotEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final resolutions = await _showBulkConflictDialog(conflictingJobs, isDark);
      if (resolutions == null) return;
      for (final job in toRestart) {
        if (resolutions.containsKey(job.id)) {
          job.conflictResolution = resolutions[job.id];
        } else {
          job.conflictResolution = null;
        }
      }
    } else {
      for (final job in toRestart) {
        job.conflictResolution = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _isQueuePaused = false;
      _bulkRunning = true;
      _globalConflictResolution = null;
      for (final j in toResume) {
        j.status = _JobStatus.converting;
      }
      for (final j in toRestart) {
        j.status = _JobStatus.pending;
      }
    });

    for (final j in toResume) {
      if (Platform.isWindows) WindowsProcessManager.resumeProcess(j.processId!);
    }

    final workers = _actualMaxConcurrent;
    for (int i = 0; i < workers; i++) {
      _processQueue();
    }
  }

  Future<Map<String, String>?> _showBulkConflictDialog(List<_BulkJob> conflicts, bool isDark) async {
    final resolutions = <String, String>{};
    for (final j in conflicts) { resolutions[j.id] = 'skip'; } // default

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void setAll(String val) {
              setDialogState(() {
                for (final j in conflicts) {
                  resolutions[j.id] = val;
                }
              });
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Files Already Exist', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${conflicts.length} files already exist in the output directory. How would you like to resolve this?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => setAll('skip'), child: const Text('Skip All')),
                        TextButton(onPressed: () => setAll('keep'), child: const Text('Keep All')),
                        TextButton(onPressed: () => setAll('overwrite'), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Overwrite All')),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: conflicts.length,
                        itemBuilder: (context, index) {
                          final job = conflicts[index];
                          final ext = job.outputFormat.name;
                          final baseName = p.basenameWithoutExtension(job.sourcePath);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text('$baseName.$ext', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: resolutions[job.id],
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                    items: const [
                                      DropdownMenuItem(value: 'skip', child: Text('Skip')),
                                      DropdownMenuItem(value: 'keep', child: Text('Keep Both')),
                                      DropdownMenuItem(value: 'overwrite', child: Text('Overwrite', style: TextStyle(color: AppColors.error))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => resolutions[job.id] = val);
                                    },
                                  )
                                )
                              ],
                            ),
                          );
                        }
                      )
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, resolutions),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Continue'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
                ),
                child: _buildBulkMode(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final queueCount = _bulkJobs.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F3F3F), Color(0xFF2D2D2D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: const Icon(Icons.sync_alt_rounded, color: Color(0xFFFF8B94), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Converter', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: isDark ? Colors.white : AppColors.lightTextPrimary, letterSpacing: -0.5)),
              Text(
                '${queueCount} FILES QUEUED',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFFB3B3), letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1);
  }

  // ── Mode Toggle ───────────────────────────────────────────────────────────

  // ── Output Dir Bar ────────────────────────────────────────────────────────

  Widget _buildOutputDirBar(bool isDark) {
    // Hidden in new design, will not be called.
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BULK MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBulkMode(bool isDark) {
    return DropTarget(
      key: const ValueKey('bulk'),
      onDragDone: (details) {
        for (final f in details.files) { _addBulkFile(f.path); }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          Column(
            children: [
              // Global format + controls bar
              _buildBulkControlBar(isDark),
              // Drop zone indicator (overlay when dragging)
              if (_isDragging)
                _buildDragOverlay(isDark),
              // File queue
              Expanded(
                child: _bulkJobs.isEmpty
                    ? _buildBulkEmptyState(isDark)
                    : _buildBulkJobList(isDark),
              ),
              // Extra space for bottom bar
              if (_bulkJobs.isNotEmpty)
                const SizedBox(height: 80), 
            ],
          ),
          // Action bar at bottom
          if (_bulkJobs.isNotEmpty)
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: _buildBulkActionBar(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkControlBar(bool isDark) {
    final done = _bulkJobs.where((j) => j.status == _JobStatus.done).length;
    final total = _bulkJobs.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildTopDropdown(
            isDark: isDark,
            icon: Icons.settings_rounded,
            label: 'Default Format:',
            value: _formatLabel(_bulkGlobalFormat),
            valueIcon: _formatIcons[_bulkGlobalFormat],
            onTap: () {
              if (_advancedAutoDetect) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turn off Auto-Detect to set default format.'), backgroundColor: AppColors.error));
                return;
              }
              _showFormatSelectionSheet(context, isDark, true, null);
            }
          ),
          _buildTopDropdown(
            isDark: isDark,
            label: 'Quality:',
            value: _bulkGlobalQuality,
            items: _isVideo(_bulkGlobalFormat) 
                ? ['Original', '4K', '1080p', '720p', '480p', '360p', '240p', '144p', 'Custom...']
                : _isAudio(_bulkGlobalFormat)
                    ? ['Original', '320k', '256k', '192k', '128k', '96k', '64k', 'Custom...']
                    : ['Original', '100%', '80%', '60%', '50%', '25%', 'Custom...'],
            currentValue: _bulkGlobalQuality,
            onChanged: (v) async {
              if (v != null) {
                String finalQuality = v;
                if (v == 'Custom...') {
                  if (_isVideo(_bulkGlobalFormat)) {
                    final customRes = await showCustomResolutionDialog(context);
                    if (customRes == null) return;
                    finalQuality = customRes;
                  } else if (_isAudio(_bulkGlobalFormat)) {
                    final customBit = await showCustomNumberDialog(context, 'Enter Bitrate (kbps)');
                    if (customBit == null || customBit.isEmpty) return;
                    finalQuality = '${customBit}k';
                  } else {
                    final customRes = await showCustomResolutionDialog(context);
                    if (customRes == null) return;
                    finalQuality = customRes;
                  }
                }
                setState(() {
                  _bulkGlobalQuality = finalQuality;
                  for (final j in _bulkJobs.where((x) => x.status != _JobStatus.converting)) {
                    String vidRes = 'Original'; String audBit = 'Original';
                    if (finalQuality == '4K') { vidRes = '4K'; audBit = '320k'; }
                    else if (finalQuality == '1080p') { vidRes = '1080p'; audBit = '256k'; }
                    else if (finalQuality == '720p') { vidRes = '720p'; audBit = '192k'; }
                    else if (finalQuality == '480p') { vidRes = '480p'; audBit = '128k'; }
                    else if (finalQuality == '360p' || finalQuality == '240p' || finalQuality == '144p') { vidRes = finalQuality; audBit = '96k'; }
                    else if (finalQuality != 'Original') {
                      if (finalQuality.contains('x')) { vidRes = finalQuality; audBit = '320k'; }
                      else if (finalQuality.endsWith('k')) { audBit = finalQuality; vidRes = '1080p'; }
                      else if (finalQuality.endsWith('%')) { vidRes = 'Original'; audBit = 'Original'; }
                    }
                    if (_isAudio(j.outputFormat)) { j.resolution = audBit; j.bitrate = audBit; }
                    else if (_isVideo(j.outputFormat)) { j.resolution = vidRes; j.bitrate = vidRes; }
                    else {
                      if (finalQuality.endsWith('%') || finalQuality.contains('x')) {
                        j.resolution = finalQuality;
                      } else {
                        j.resolution = finalQuality == 'Original' ? 'Original' : (finalQuality == '4K' ? '100%' : '80%');
                      }
                    }
                    if (j.status == _JobStatus.done || j.status == _JobStatus.error) { j.status = _JobStatus.pending; j.errorMessage = null; j.progress = 0.0; }
                  }
                });
              }
            }
          ),
          // Auto-detect toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _advancedAutoDetect = !_advancedAutoDetect;
                _applyAutoDetectToPending(_advancedAutoDetect);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _advancedAutoDetect ? (isDark ? const Color(0xFF381F4B) : const Color(0xFFF3E8FF)) : (isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _advancedAutoDetect ? const Color(0xFF9F7AEA) : (isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: _advancedAutoDetect ? (isDark ? const Color(0xFFD6BCFA) : const Color(0xFF6B46C1)) : (isDark ? Colors.white54 : AppColors.lightTextSecondary)),
                  const SizedBox(width: 8),
                  Text('Auto-Detect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _advancedAutoDetect ? (isDark ? const Color(0xFFD6BCFA) : const Color(0xFF6B46C1)) : (isDark ? Colors.white70 : AppColors.lightTextSecondary))),
                  const SizedBox(width: 10),
                  Container(
                    width: 32, height: 18,
                    decoration: BoxDecoration(
                      color: _advancedAutoDetect ? const Color(0xFF9F7AEA) : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _advancedAutoDetect ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: CircleAvatar(radius: 7, backgroundColor: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (total > 0)
            Text('$done/$total done', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.lightTextSecondary)),
          if (total > 0)
            GestureDetector(
              onTap: () => setState(() {
                _bulkJobs.clear();
                _globalConflictResolution = null;
              }),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFFF8B94)),
                  SizedBox(width: 4),
                  Text('Clear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF8B94))),
                ],
              ),
            ),
          GestureDetector(
            onTap: _pickBulkFiles,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF8B94).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFFFF8B94)),
                  SizedBox(width: 6),
                  Text('Add Files', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF8B94))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopDropdown({required bool isDark, IconData? icon, required String label, required String value, IconData? valueIcon, VoidCallback? onTap, List<String>? items, String? currentValue, void Function(String?)? onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: isDark ? Colors.white70 : AppColors.lightTextSecondary), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary)),
        const SizedBox(width: 8),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  if (valueIcon != null) ...[Icon(valueIcon, size: 14, color: isDark ? Colors.white : AppColors.lightTextPrimary), const SizedBox(width: 6)],
                  Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
                ],
              ),
            ),
          )
        else
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items!.contains(currentValue) ? currentValue : (items.contains('Custom...') && currentValue != null && currentValue.contains('Custom') ? 'Custom...' : items.first),
                icon: Icon(Icons.arrow_drop_down_rounded, size: 16, color: isDark ? Colors.white70 : AppColors.lightTextSecondary),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                items: [
                  ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  if (!items.contains(currentValue) && currentValue != null && !currentValue.contains('Custom'))
                    DropdownMenuItem(value: currentValue, child: Text(currentValue)),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactFormatPicker(bool isDark) {
    return GestureDetector(
      onTap: () {
        if (_advancedAutoDetect) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Auto-Detect is ON. Turn it off to set a default format.'),
            backgroundColor: AppColors.error,
          ));
          return;
        }
        _showFormatSelectionSheet(context, isDark, true, null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _formatColor(_bulkGlobalFormat).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _formatColor(_bulkGlobalFormat).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(_formatIcons[_bulkGlobalFormat] ?? Icons.transform_rounded, size: 14, color: _formatColor(_bulkGlobalFormat)),
            const SizedBox(width: 6),
            Text(_formatLabel(_bulkGlobalFormat), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _formatColor(_bulkGlobalFormat))),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _formatColor(_bulkGlobalFormat)),
          ],
        ),
      ),
    );
  }

  void _showFormatSelectionSheet(BuildContext context, bool isDark, bool isGlobal, _BulkJob? job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(isGlobal ? 'Select Default Format' : 'Select Format for ${job?.fileName}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              const SizedBox(height: 24),
              _buildFormatGrid(isDark, isGlobal ? _bulkGlobalFormat : (job?.outputFormat ?? ConversionFormat.mp4), (fmt) async {
                Navigator.pop(ctx);
                
                final affectedJobs = isGlobal 
                    ? _bulkJobs.where((x) => x.status == _JobStatus.converting || x.status == _JobStatus.paused).toList()
                    : (job != null && (job.status == _JobStatus.converting || job.status == _JobStatus.paused) ? [job] : <_BulkJob>[]);
                
                if (affectedJobs.isNotEmpty) {
                  final confirm = await _showFormatChangeWarningDialog(context);
                  if (!confirm) return;
                }

                setState(() {
                  void applyFormatAndQuality(_BulkJob j, ConversionFormat format) {
                    j.outputFormat = format;
                    if (j.status == _JobStatus.converting || j.status == _JobStatus.paused) {
                      if (Platform.isWindows && j.processId != null) {
                        if (j.status == _JobStatus.paused) {
                          WindowsProcessManager.resumeProcess(j.processId!);
                        }
                      }
                      j.cancelMethod?.call();
                    }
                    if (j.status != _JobStatus.pending) {
                      j.status = _JobStatus.pending;
                      j.errorMessage = null;
                      j.progress = 0.0;
                    }
                    String vidRes = 'Original';
                    String audBit = 'Original';
                    if (_bulkGlobalQuality == '4K') { vidRes = '4K'; audBit = '320k'; }
                    else if (_bulkGlobalQuality == '1080p') { vidRes = '1080p'; audBit = '256k'; }
                    else if (_bulkGlobalQuality == '720p') { vidRes = '720p'; audBit = '192k'; }
                    else if (_bulkGlobalQuality == '480p') { vidRes = '480p'; audBit = '128k'; }

                    if (_isAudio(format)) {
                      j.resolution = audBit;
                      j.bitrate = audBit;
                    } else if (_isVideo(format)) {
                      j.resolution = vidRes;
                      j.bitrate = vidRes;
                    } else {
                      j.resolution = _bulkGlobalQuality == 'Original' ? 'Original' : (_bulkGlobalQuality == '4K' ? '100%' : '80%');
                    }
                  }

                  if (isGlobal) {
                    _bulkGlobalFormat = fmt;
                    for (final j in _bulkJobs) {
                      applyFormatAndQuality(j, fmt);
                    }
                  } else if (job != null) {
                    applyFormatAndQuality(job, fmt);
                  }
                });
              }),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showFormatChangeWarningDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        title: Text('Progress Loss Warning', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text('Changing the file format will result in the loss of your converting progress. Do you wish to proceed?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Continue with other format'),
          ),
        ],
      )
    ) ?? false;
  }

  Future<bool> _showCancelWarningDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        title: Text('Progress Loss Warning', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text('Canceling the conversion will result in the loss of your progress. Do you wish to proceed?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, continue', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Yes, cancel'),
          ),
        ],
      )
    ) ?? false;
  }

  Widget _buildBulkEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: _isDragging ? AppColors.brandGradient : null,
              color: _isDragging ? null : (isDark ? AppColors.darkCard : AppColors.lightCard),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _isDragging ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: 2,
              ),
              boxShadow: _isDragging 
                  ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 10)] 
                  : (isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))]),
            ),
            child: Icon(Icons.cloud_upload_rounded, size: 54, color: _isDragging ? Colors.white : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          ).animate(onPlay: (c) => _isDragging ? c.repeat(reverse: true) : c.stop()).scaleXY(begin: 1.0, end: 1.05, duration: 800.ms, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          Text(_isDragging ? 'Release to Drop Files!' : 'Drag & Drop Your Videos Here', 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _isDragging ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
          const SizedBox(height: 8),
          Text('Supported: MP4, MKV, MP3, WAV, FLAC & more', 
              style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickBulkFiles,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: 2),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle_rounded, size: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Add Files to Convert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildDragOverlay(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.accent.withValues(alpha: 0.1)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
      ),
      child: const Center(child: Text('Release to add files', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary))),
    );
  }

  Widget _buildBulkJobList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _bulkJobs.length,
      itemBuilder: (context, index) {
        final job = _bulkJobs[index];
        return _BulkJobTile(
          key: ValueKey(job.id),
          job: job,
          isDark: isDark,
          formatColor: _formatColor(job.outputFormat),
          isAudio: _isAudio(job.outputFormat),
          isVideo: _isVideo(job.outputFormat),
          onRemove: () => _removeBulkJob(job.id),
          onRetry: (j) {
            setState(() {
              j.status = _JobStatus.pending;
              j.errorMessage = null;
              j.progress = 0.0;
            });
          },
          onFormatChange: (fmt) {
            setState(() {
              job.outputFormat = fmt;
              if (job.status == _JobStatus.done || job.status == _JobStatus.error) {
                job.status = _JobStatus.pending;
                job.errorMessage = null;
                job.progress = 0.0;
              }
            });
          },
          formatLabel: _formatLabel,
          formatIcon: (f) => _formatIcons[f] ?? Icons.transform_rounded,
          formatColor2: _formatColor,
          onShowInFolder: (path) {
            if (Platform.isWindows) Process.run('explorer.exe', ['/select,', path]);
            else if (Platform.isMacOS) Process.run('open', ['-R', path]);
            else Process.run('xdg-open', [p.dirname(path)]);
          },
          onConfigure: () => _showFormatSelectionSheet(context, isDark, false, job),
          onResolutionChange: (res) {
            setState(() {
              job.resolution = res;
              if (job.status == _JobStatus.converting || job.status == _JobStatus.paused) {
                if (Platform.isWindows && job.processId != null && job.status == _JobStatus.paused) {
                  WindowsProcessManager.resumeProcess(job.processId!);
                }
                job.cancelMethod?.call();
              }
              if (job.status != _JobStatus.pending) {
                job.status = _JobStatus.pending;
                job.errorMessage = null;
                job.progress = 0.0;
              }
            });
          },
          onPause: () => _pauseJob(job.id),
          onResume: () => _resumeJob(job.id),
          onStart: () {
            _processSpecificJob(job);
          },
          onCancel: () => _cancelSpecificJob(job),
        ).animate().fadeIn(duration: 200.ms, delay: (20 * math.min(index, 8)).ms).slideX(begin: 0.05);
      },
    );
  }

  void _showJobSettings(BuildContext context, _BulkJob job, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Job Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                            Text(job.fileName, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isAudio(job.outputFormat) || _isVideo(job.outputFormat)) ...[
                    Text('Bitrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: DropdownButton<String>(
                        value: job.bitrate,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        items: _bitrateOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => job.bitrate = v);
                            setState(() {}); // Update main UI if needed
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isVideo(job.outputFormat)) ...[
                    Text('Resolution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: DropdownButton<String>(
                        value: job.resolution,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        items: [
                          ..._resolutionOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))),
                          if (!_resolutionOptions.contains(job.resolution) && job.resolution.contains('x'))
                            DropdownMenuItem(value: job.resolution, child: Text('Custom (${job.resolution})')),
                          const DropdownMenuItem(value: 'Custom', child: Text('Custom...')),
                        ],
                        onChanged: (v) async {
                          if (v != null) {
                            if (v == 'Custom') {
                               final customRes = await showCustomResolutionDialog(context, inputPath: job.sourcePath);
                               if (customRes != null) {
                                 setModalState(() => job.resolution = customRes);
                                 setState(() {});
                               }
                            } else {
                               setModalState(() => job.resolution = v);
                               setState(() {});
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    final remaining = _bulkJobs.where((j) => j.status != _JobStatus.done).length;
    final failed = _bulkJobs.where((j) => j.status == _JobStatus.error).length;
    final done = _bulkJobs.where((j) => j.status == _JobStatus.done).length;
    final isConverting = _bulkRunning && !_isQueuePaused;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConverting 
              ? const Color(0xFF5ED1CC).withValues(alpha: 0.3) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
        ),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4)),
          if (isConverting) BoxShadow(color: const Color(0xFF5ED1CC).withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining == 0 ? 'All jobs completed' : '$remaining files remaining', 
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.lightTextPrimary)
              ),
              if (failed > 0) 
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('$failed failed', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error)),
                ),
            ],
          ),
          const Spacer(),
          if (remaining == 0 && _bulkJobs.isNotEmpty)
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _bulkJobs.removeWhere((j) => j.status == _JobStatus.done)),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white24 : AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.clear_all_rounded, size: 16, color: isDark ? Colors.white : AppColors.lightTextSecondary),
                        const SizedBox(width: 6),
                        Text('Clear Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary)),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_advancedAutoDetect) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Auto-Detect is ON. Turn it off to set a default format.'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }
                    _showFormatSelectionSheet(context, isDark, true, null);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5ED1CC), Color(0xFF339D98)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF5ED1CC).withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF0F3A38)),
                        SizedBox(width: 8),
                        Text(
                          'Try Other Format (All)',
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            color: Color(0xFF0F3A38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.3)),
              ],
            )
          else if (remaining > 0 || _bulkRunning)
            Row(
              children: [
                if (done > 0)
                  GestureDetector(
                    onTap: () => setState(() => _bulkJobs.removeWhere((j) => j.status == _JobStatus.done)),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.clear_all_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Clear Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                if (_bulkRunning) ...[
                  GestureDetector(
                    onTap: _pauseAll,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.pause_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Pause All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelAll,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stop_rounded, size: 16, color: AppColors.error),
                          SizedBox(width: 6),
                          Text('Cancel All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onTap: isConverting ? null : _playAll,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: isConverting ? null : const LinearGradient(
                        colors: [Color(0xFFFFB3B3), Color(0xFFFF8B94)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      color: isConverting ? const Color(0xFF2A2A2A) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isConverting)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xFFFF8B94)))
                        else
                          const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFF8B1A24)),
                        const SizedBox(width: 8),
                        Text(
                          isConverting ? 'Converting...' : 'Convert Remaining',
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            color: isConverting ? const Color(0xFFFF8B94) : const Color(0xFF8B1A24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Format Grid ───────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary));
  }

  Widget _buildFormatGrid(bool isDark, ConversionFormat selected, void Function(ConversionFormat) onSelect) {
    final audioFmts = ConversionFormat.values.where(_isAudio).toList();
    final videoFmts = ConversionFormat.values.where(_isVideo).toList();
    final imageFmts = ConversionFormat.values.where((f) => !_isAudio(f) && !_isVideo(f)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormatCategory('VIDEO', videoFmts, selected, onSelect, isDark),
        const SizedBox(height: 10),
        _buildFormatCategory('AUDIO', audioFmts, selected, onSelect, isDark),
        const SizedBox(height: 10),
        _buildFormatCategory('IMAGE', imageFmts, selected, onSelect, isDark),
      ],
    );
  }

  Widget _buildFormatCategory(String label, List<ConversionFormat> fmts, ConversionFormat selected, void Function(ConversionFormat) onSelect, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fmts.map((fmt) {
            final isSelected = fmt == selected;
            final col = _formatColor(fmt);
            return GestureDetector(
              onTap: () => onSelect(fmt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? col.withValues(alpha: 0.18) : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? col.withValues(alpha: 0.6) : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isSelected ? 1.5 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_formatIcons[fmt] ?? Icons.transform_rounded, size: 14, color: isSelected ? col : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    const SizedBox(width: 5),
                    Text(_formatLabel(fmt), style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, color: isSelected ? col : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BULK JOB TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _BulkJobTile extends StatelessWidget {
  final _BulkJob job;
  final bool isDark;
  final Color formatColor;
  final bool isAudio;
  final bool isVideo;
  final VoidCallback onRemove;
  final void Function(_BulkJob) onRetry;
  final void Function(ConversionFormat) onFormatChange;
  final String Function(ConversionFormat) formatLabel;
  final IconData Function(ConversionFormat) formatIcon;
  final Color Function(ConversionFormat) formatColor2;
  final void Function(String) onShowInFolder;
  final VoidCallback onConfigure;
  final void Function(String) onResolutionChange;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _BulkJobTile({
    super.key,
    required this.job,
    required this.isDark,
    required this.formatColor,
    required this.isAudio,
    required this.isVideo,
    required this.onRemove,
    required this.onRetry,
    required this.onFormatChange,
    required this.formatLabel,
    required this.formatIcon,
    required this.formatColor2,
    required this.onShowInFolder,
    required this.onConfigure,
    required this.onResolutionChange,
    required this.onPause,
    required this.onResume,
    required this.onStart,
    required this.onCancel,
  });

  Color get _statusColor {
    switch (job.status) {
      case _JobStatus.done: return const Color(0xFF10B981);
      case _JobStatus.error: return AppColors.error;
      case _JobStatus.converting: return AppColors.primary;
      case _JobStatus.paused: return Colors.orange;
      case _JobStatus.pending: return const Color(0xFF6B7280);
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case _JobStatus.done: return Icons.check_circle_rounded;
      case _JobStatus.error: return Icons.error_rounded;
      case _JobStatus.converting: return Icons.sync_rounded;
      case _JobStatus.paused: return Icons.pause_circle_rounded;
      case _JobStatus.pending: return Icons.schedule_rounded;
    }
  }

  String get _statusLabel {
    switch (job.status) {
      case _JobStatus.done: return 'Done';
      case _JobStatus.error: return 'Failed';
      case _JobStatus.converting: return 'Converting ${(job.progress * 100).toInt()}%';
      case _JobStatus.paused: return 'Paused';
      case _JobStatus.pending: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConverting = job.status == _JobStatus.converting;
    final bool isPaused = job.status == _JobStatus.paused;
    final bool isDone = job.status == _JobStatus.done;
    final bool isError = job.status == _JobStatus.error;
    final bool isActive = isConverting || isPaused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isActive ? (isDark ? const Color(0xFF1E2828) : const Color(0xFFE0F2F1)) : (isDark ? const Color(0xFF1E1E1E) : AppColors.lightCardElevated),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConverting ? const Color(0xFF5ED1CC).withValues(alpha: 0.6) 
              : isPaused ? Colors.amber.withValues(alpha: 0.6)
              : isDone ? const Color(0xFF10B981).withValues(alpha: 0.3) 
              : isError ? AppColors.error.withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          width: (isActive || isDone || isError) ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: (isPaused ? Colors.amber : const Color(0xFF5ED1CC)).withValues(alpha: 0.25), blurRadius: 16, spreadRadius: 2),
          if (!isPaused) BoxShadow(color: const Color(0xFF5ED1CC).withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5),
        ] : isDone ? [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1),
        ] : isError ? [
          BoxShadow(color: AppColors.error.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1),
        ] : [
          BoxShadow(color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Left Icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      isDone ? Icons.image_rounded : formatIcon(job.outputFormat), 
                      size: 20, 
                      color: isDone ? const Color(0xFF10B981) : isConverting ? const Color(0xFF5ED1CC) : isPaused ? Colors.amber : (isDark ? Colors.white54 : AppColors.lightTextTertiary)
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.fileName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isConverting) ...[
                            const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF5ED1CC)),
                            const SizedBox(width: 4),
                            Text('Converting ${(job.progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5ED1CC))),
                          ] else if (isPaused) ...[
                            const Icon(Icons.pause_circle_filled_rounded, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('Paused ${(job.progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.amber)),
                          ] else if (isDone) ...[
                            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            const Text('Completed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                          ] else if (isError) ...[
                            const Icon(Icons.error_rounded, size: 12, color: AppColors.error),
                            const SizedBox(width: 4),
                            const Text('Failed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.error)),
                          ] else ...[
                            const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFFFB3B3)),
                            const SizedBox(width: 4),
                            const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFFB3B3))),
                          ],
                          const SizedBox(width: 8),
                          Text('•  ${job.fileSizeStr}  •  ${job.originalFormat}${isActive ? ' ➔ ${formatLabel(job.outputFormat)}' : ''}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : AppColors.lightTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      if (isError && job.errorMessage != null)
                         Padding(
                           padding: const EdgeInsets.only(top: 4),
                           child: Text(job.errorMessage!, style: const TextStyle(fontSize: 10, color: AppColors.error), maxLines: 1, overflow: TextOverflow.ellipsis),
                         ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Actions (Right side)
                if (isConverting) ...[
                  _buildMiniDropdown(formatLabel(job.outputFormat), onConfigure),
                  const SizedBox(width: 12),
                  _buildIconButton(Icons.pause_rounded, onPause, tooltip: 'Pause'),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.stop_rounded, onCancel, tooltip: 'Cancel'),
                ] else if (isPaused) ...[
                  _buildMiniDropdown(formatLabel(job.outputFormat), onConfigure),
                  const SizedBox(width: 8),
                  _buildMiniDropdown(job.resolution, () => _showQualitySheet(context)),
                  const SizedBox(width: 16),
                  _buildIconButton(Icons.play_arrow_rounded, onResume, tooltip: 'Resume'),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.stop_rounded, onCancel, tooltip: 'Cancel'),
                ] else if (isDone) ...[
                  GestureDetector(
                    onTap: onConfigure,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5ED1CC).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.autorenew_rounded, size: 14, color: Color(0xFF5ED1CC)),
                          SizedBox(width: 6),
                          Text('Try Other Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF5ED1CC))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () { if (job.outputPath != null) onShowInFolder(job.outputPath!); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 14, color: Colors.white70),
                          SizedBox(width: 6),
                          Text('Show File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ] else if (isError) ...[
                  _buildMiniDropdown(formatLabel(job.outputFormat), onConfigure),
                  const SizedBox(width: 12),
                  _buildIconButton(Icons.refresh_rounded, () => onRetry(job)),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.close_rounded, onRemove),
                ] else ...[
                  _buildMiniDropdown(formatLabel(job.outputFormat), onConfigure),
                  const SizedBox(width: 8),
                  _buildMiniDropdown(job.resolution, () => _showQualitySheet(context)),
                  const SizedBox(width: 16),
                  _buildIconButton(Icons.play_arrow_rounded, onStart, tooltip: 'Start'),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.close_rounded, onRemove, tooltip: 'Remove'),
                ],
              ],
            ),
          ),
          
          // Overlay progress bar for converting/paused state
          if (isActive && job.progress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuad,
                  alignment: Alignment.centerLeft,
                  widthFactor: job.progress,
                  child: isPaused 
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber.withValues(alpha: 0.15), Colors.amber.withValues(alpha: 0.25)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF5ED1CC).withValues(alpha: isDark ? 0.2 : 0.1),
                              const Color(0xFF5ED1CC).withValues(alpha: isDark ? 0.35 : 0.15),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat()).shimmer(
                        duration: const Duration(milliseconds: 2000), 
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniDropdown(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.transparent : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppColors.lightTextPrimary)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? Colors.white54 : AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {String? tooltip}) {
    Widget btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : AppColors.lightCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.transparent : AppColors.lightBorder),
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.white70 : AppColors.lightTextPrimary),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  void _showQualitySheet(BuildContext context) {
    final isAud = isAudio;
    final isVid = isVideo;
    final items = isVid 
        ? ['Original', '4K', '1080p', '720p', '480p', '360p', '240p', '144p', 'Custom']
        : isAud 
            ? ['Original', '320k', '256k', '192k', '128k', '96k', '64k', 'Custom']
            : ['Original', '100%', '80%', '60%', '50%', '25%', 'Custom'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('Select Quality for ${job.fileName}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: items.map((q) {
                  final isSelected = q == job.resolution;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (q == 'Custom') {
                        if (isVid) {
                          final customRes = await showCustomResolutionDialog(context, inputPath: job.sourcePath);
                          if (customRes != null) onResolutionChange(customRes);
                        } else if (isAud) {
                          final customBit = await showCustomNumberDialog(context, 'Enter Bitrate (kbps)');
                          if (customBit != null && customBit.isNotEmpty) {
                            onResolutionChange('${customBit}k');
                          }
                        } else {
                          final customRes = await showCustomResolutionDialog(context, inputPath: job.sourcePath);
                          if (customRes != null) onResolutionChange(customRes);
                        }
                      } else {
                        onResolutionChange(q);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF9F7AEA).withOpacity(0.2) : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF9F7AEA) : (isDark ? Colors.white10 : Colors.black12)),
                      ),
                      child: Text(q, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? const Color(0xFF9F7AEA) : (isDark ? Colors.white70 : AppColors.lightTextPrimary))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }
    );
  }
}

Future<String?> showCustomResolutionDialog(BuildContext context, {String? inputPath}) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CustomResolutionDialog(inputPath: inputPath),
  );
}

class _CustomResolutionDialog extends StatefulWidget {
  final String? inputPath;
  const _CustomResolutionDialog({this.inputPath});

  @override
  State<_CustomResolutionDialog> createState() => _CustomResolutionDialogState();
}

class _CustomResolutionDialogState extends State<_CustomResolutionDialog> {
  final wCtrl = TextEditingController();
  final hCtrl = TextEditingController();
  bool isLinked = true;
  bool isLoading = false;
  int? originalW;
  int? originalH;
  double? aspectRatio;

  @override
  void initState() {
    super.initState();
    if (widget.inputPath == null) {
      hCtrl.text = 'Auto';
    }
    _loadDimensions();
  }

  Future<void> _loadDimensions() async {
    if (widget.inputPath == null) return;
    setState(() => isLoading = true);
    final provider = context.read<ConverterProvider>();
    final dims = await provider.getMediaDimensions(widget.inputPath!);
    if (dims != null && mounted) {
      originalW = dims.$1;
      originalH = dims.$2;
      aspectRatio = originalW! / originalH!;
      wCtrl.text = originalW.toString();
      hCtrl.text = originalH.toString();
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _onWidthChanged(String v) {
    if (isLinked) {
      if (aspectRatio != null) {
        final w = int.tryParse(v);
        if (w != null) {
          hCtrl.text = (w / aspectRatio!).round().toString();
          setState((){});
        }
      } else {
        if (v.isNotEmpty && v != 'Auto') {
          if (hCtrl.text != 'Auto') {
            hCtrl.text = 'Auto';
            setState((){});
          }
        }
      }
    } else {
      setState((){});
    }
  }

  void _onHeightChanged(String v) {
    if (isLinked) {
      if (aspectRatio != null) {
        final h = int.tryParse(v);
        if (h != null) {
          wCtrl.text = (h * aspectRatio!).round().toString();
          setState((){});
        }
      } else {
        if (v.isNotEmpty && v != 'Auto') {
          if (wCtrl.text != 'Auto') {
            wCtrl.text = 'Auto';
            setState((){});
          }
        }
      }
    } else {
      setState((){});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wVal = int.tryParse(wCtrl.text) ?? 0;
    final hVal = int.tryParse(hCtrl.text) ?? 0;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Custom Resolution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      content: SizedBox(
        width: 320,
        child: isLoading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Width (px)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: wCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: _onWidthChanged,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: IconButton(
                          icon: Icon(isLinked ? Icons.link_rounded : Icons.link_off_rounded),
                          color: isLinked ? const Color(0xFF3B82F6) : (isDark ? Colors.white38 : Colors.black38),
                          onPressed: () {
                            setState(() {
                              isLinked = !isLinked;
                              if (isLinked) {
                                if (aspectRatio != null) {
                                  final w = int.tryParse(wCtrl.text);
                                  if (w != null) hCtrl.text = (w / aspectRatio!).round().toString();
                                } else {
                                  if (wCtrl.text.isNotEmpty && wCtrl.text != 'Auto') {
                                    hCtrl.text = 'Auto';
                                  } else {
                                    wCtrl.text = 'Auto';
                                  }
                                }
                              } else {
                                if (wCtrl.text == 'Auto') wCtrl.text = '';
                                if (hCtrl.text == 'Auto') hCtrl.text = '';
                              }
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Height (px)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: hCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              onChanged: _onHeightChanged,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (originalW != null && originalH != null) ...[
                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current:', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                        Text('$originalW x $originalH pixels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('New:', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                        Text('${wVal > 0 ? wVal : originalW} x ${hVal > 0 ? hVal : originalH} pixels', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.black87),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String w = wCtrl.text.trim();
            String h = hCtrl.text.trim();
            if (w.isEmpty) w = '-1';
            if (h.isEmpty) h = '-1';
            if (w == '-1' && h == '-1') {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context, '${w}x$h');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

Future<String?> showCustomNumberDialog(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Enter a number',
            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (int.tryParse(ctrl.text) != null) Navigator.pop(ctx, ctrl.text);
            },
            child: const Text('Apply'),
          ),
        ],
      );
    }
  );
}
