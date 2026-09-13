import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/plugin_provider.dart';

// ── Supported output formats ──────────────────────────────────────────────────

enum _BulkFmt {
  // Audio
  mp3, m4a, aac, flac, wav, ogg, opus,
  // Video
  mp4, mkv, webm, avi, mov,
  // Image
  jpg, png, webp, gif,
}

extension _BulkFmtExt on _BulkFmt {
  String get label => name.toUpperCase();
  String get ext => name;
  bool get isAudio => [_BulkFmt.mp3, _BulkFmt.m4a, _BulkFmt.aac, _BulkFmt.flac, _BulkFmt.wav, _BulkFmt.ogg, _BulkFmt.opus].contains(this);
  bool get isVideo => [_BulkFmt.mp4, _BulkFmt.mkv, _BulkFmt.webm, _BulkFmt.avi, _BulkFmt.mov].contains(this);
  bool get isImage => [_BulkFmt.jpg, _BulkFmt.png, _BulkFmt.webp, _BulkFmt.gif].contains(this);
  Color get color {
    if (isAudio) return const Color(0xFF8B5CF6);
    if (isVideo) return const Color(0xFF06B6D4);
    return const Color(0xFFEC4899);
  }
  IconData get icon {
    if (isAudio) return Icons.music_note_rounded;
    if (isVideo) return Icons.videocam_rounded;
    return Icons.image_rounded;
  }
}

// ── Per-file job ──────────────────────────────────────────────────────────────

enum _JobStatus { pending, converting, done, error }

class _BulkJob {
  final String id;
  final String sourcePath;
  String fileName;
  _BulkFmt outputFormat;
  _JobStatus status;
  double progress; // 0.0 – 1.0
  String? errorMessage;
  String? outputPath;

  _BulkJob({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.outputFormat,
    this.status = _JobStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BulkConverterScreen extends StatefulWidget {
  const BulkConverterScreen({super.key});

  @override
  State<BulkConverterScreen> createState() => _BulkConverterScreenState();
}

class _BulkConverterScreenState extends State<BulkConverterScreen> {
  final List<_BulkJob> _jobs = [];
  bool _isDragOver = false;
  bool _isRunning = false;
  _BulkFmt _globalFormat = _BulkFmt.mp4;
  String _outputDir = '';

  @override
  void initState() {
    super.initState();
    _outputDir = _defaultOutputDir();
  }

  String _defaultOutputDir() {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      return p.join(home, 'Downloads', 'Zylos', 'Converter');
    } catch (_) {
      return '';
    }
  }

  // ── File Management ─────────────────────────────────────────────────────────

  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        final name = p.basename(path);
        final fmt = _guessOutputFormat(path);
        _jobs.add(_BulkJob(
          id: '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
          sourcePath: path,
          fileName: name,
          outputFormat: fmt,
        ));
      }
    });
  }

  _BulkFmt _guessOutputFormat(String path) {
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    // Audio input → mp3 output
    if (['mp3','m4a','aac','flac','wav','ogg','opus','wma','aiff'].contains(ext)) return _BulkFmt.mp3;
    // Image input → png output
    if (['jpg','jpeg','png','webp','gif','bmp','tiff','heic','avif'].contains(ext)) return _BulkFmt.jpg;
    // Video → mp4
    return _BulkFmt.mp4;
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      _addFiles(result.files.map((f) => f.path!).toList());
    }
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Output Folder');
    if (result != null) setState(() => _outputDir = result);
  }

  void _removeJob(String id) {
    if (_isRunning) return;
    setState(() => _jobs.removeWhere((j) => j.id == id));
  }

  void _clearCompleted() {
    setState(() => _jobs.removeWhere((j) => j.status == _JobStatus.done || j.status == _JobStatus.error));
  }

  void _setGlobalFormat(_BulkFmt fmt) {
    setState(() {
      _globalFormat = fmt;
      for (final job in _jobs.where((j) => j.status == _JobStatus.pending)) {
        job.outputFormat = fmt;
      }
    });
  }

  // ── Conversion ──────────────────────────────────────────────────────────────

  Future<void> _runConversion() async {
    final pending = _jobs.where((j) => j.status == _JobStatus.pending).toList();
    if (pending.isEmpty) return;

    final pluginProv = context.read<PluginProvider>();
    final ffmpegPath = await pluginProv.service.getFfmpegPath();
    if (ffmpegPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('FFmpeg not installed. Please go to Plugin Manager.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Ensure output dir
    final outDir = Directory(_outputDir);
    if (!await outDir.exists()) await outDir.create(recursive: true);

    setState(() => _isRunning = true);

    for (final job in pending) {
      if (!mounted) break;
      setState(() {
        job.status = _JobStatus.converting;
        job.progress = 0.02;
      });

      try {
        final outPath = _buildOutputPath(job);
        // Ensure output subfolder
        await Directory(p.dirname(outPath)).create(recursive: true);

        // Build ffmpeg args
        final args = _buildFfmpegArgs(job.sourcePath, outPath, job.outputFormat);

        final process = await Process.start(ffmpegPath, args);
        final errLines = <String>[];
        // Parse progress from stderr (ffmpeg writes progress there)
        process.stderr.transform(const SystemEncoding().decoder).listen((chunk) {
          errLines.add(chunk);
          // Simple indeterminate pulse: tick 0.1→0.9
          if (mounted) {
            setState(() {
              if (job.progress < 0.9) job.progress += 0.015;
            });
          }
        });

        final exitCode = await process.exitCode;

        if (!mounted) break;
        setState(() {
          if (exitCode == 0) {
            job.status = _JobStatus.done;
            job.progress = 1.0;
            job.outputPath = outPath;
          } else {
            job.status = _JobStatus.error;
            job.errorMessage = errLines.isNotEmpty ? errLines.last.trim().split('\n').last : 'FFmpeg error code $exitCode';
          }
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            job.status = _JobStatus.error;
            job.errorMessage = e.toString();
          });
        }
      }
    }

    if (mounted) setState(() => _isRunning = false);
  }

  String _buildOutputPath(_BulkJob job) {
    final baseName = p.basenameWithoutExtension(job.sourcePath);
    final subFolder = job.outputFormat.isAudio ? 'Audio' : (job.outputFormat.isVideo ? 'Video' : 'Images');
    final dir = p.join(_outputDir, subFolder);
    return p.join(dir, '$baseName.${job.outputFormat.ext}');
  }

  List<String> _buildFfmpegArgs(String input, String output, _BulkFmt fmt) {
    final args = ['-y', '-i', input];
    switch (fmt) {
      case _BulkFmt.mp3:
        args.addAll(['-vn', '-acodec', 'libmp3lame', '-q:a', '2']);
      case _BulkFmt.m4a:
        args.addAll(['-vn', '-acodec', 'aac', '-b:a', '256k']);
      case _BulkFmt.aac:
        args.addAll(['-vn', '-acodec', 'aac', '-b:a', '256k']);
      case _BulkFmt.flac:
        args.addAll(['-vn', '-acodec', 'flac']);
      case _BulkFmt.wav:
        args.addAll(['-vn', '-acodec', 'pcm_s16le']);
      case _BulkFmt.ogg:
        args.addAll(['-vn', '-acodec', 'libvorbis', '-q:a', '6']);
      case _BulkFmt.opus:
        args.addAll(['-vn', '-acodec', 'libopus', '-b:a', '192k']);
      case _BulkFmt.mp4:
        args.addAll(['-c:v', 'libx264', '-crf', '23', '-preset', 'fast', '-c:a', 'aac', '-b:a', '192k']);
      case _BulkFmt.mkv:
        args.addAll(['-c:v', 'libx264', '-crf', '23', '-preset', 'fast', '-c:a', 'copy']);
      case _BulkFmt.webm:
        args.addAll(['-c:v', 'libvpx-vp9', '-crf', '30', '-b:v', '0', '-c:a', 'libopus']);
      case _BulkFmt.avi:
        args.addAll(['-c:v', 'libxvid', '-qscale:v', '5', '-c:a', 'libmp3lame']);
      case _BulkFmt.mov:
        args.addAll(['-c:v', 'libx264', '-crf', '23', '-preset', 'fast', '-c:a', 'aac']);
      case _BulkFmt.jpg:
        args.addAll(['-vf', 'scale=iw:ih', '-q:v', '2']);
      case _BulkFmt.png:
        args.addAll(['-vf', 'scale=iw:ih']);
      case _BulkFmt.webp:
        args.addAll(['-vf', 'scale=iw:ih', '-quality', '80']);
      case _BulkFmt.gif:
        args.addAll(['-vf', 'fps=15,scale=480:-1:flags=lanczos', '-loop', '0']);
    }
    args.add(output);
    return args;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: _jobs.isEmpty
                  ? _buildDropZone(isDark)
                  : _buildJobList(isDark),
            ),
            if (_jobs.isNotEmpty) _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bulk Converter',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text('Convert multiple files at once — drag & drop or browse',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ],
            ),
          ),
          // Global format picker
          _FormatPicker(
            selected: _globalFormat,
            onSelected: _setGlobalFormat,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          // Add files
          Tooltip(
            message: 'Add files',
            child: InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildDropZone(bool isDark) {
    return DropTarget(
      onDragDone: (detail) => _addFiles(detail.files.map((f) => f.path).toList()),
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isDragOver
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isDragOver ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: _isDragOver ? 2 : 1.5,
          ),
          boxShadow: _isDragOver
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 24, spreadRadius: 2)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: _pickFiles,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 36),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1800.ms, curve: Curves.easeInOut),
                const SizedBox(height: 24),
                Text(
                  _isDragOver ? 'Drop files here!' : 'Drag & Drop Files Here',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: _isDragOver ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'or tap to browse — supports video, audio & images',
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _FormatChip('MP4', _BulkFmt.mp4.color),
                    _FormatChip('MP3', _BulkFmt.mp3.color),
                    _FormatChip('MKV', _BulkFmt.mkv.color),
                    _FormatChip('FLAC', _BulkFmt.flac.color),
                    _FormatChip('WEBM', _BulkFmt.webm.color),
                    _FormatChip('JPG', _BulkFmt.jpg.color),
                    _FormatChip('PNG', _BulkFmt.png.color),
                    _FormatChip('+ more', Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(delay: 150.ms, begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack);
  }

  Widget _buildJobList(bool isDark) {
    return DropTarget(
      onDragDone: (detail) => _addFiles(detail.files.map((f) => f.path).toList()),
      onDragEntered: (_) => setState(() => _isDragOver = true),
      onDragExited: (_) => setState(() => _isDragOver = false),
      child: Column(
        children: [
          // Drag overlay hint
          if (_isDragOver)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Drop to add more files', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ).animate().fadeIn(),

          // Stats bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                _StatPill('${_jobs.length} files', isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                const SizedBox(width: 8),
                _StatPill('${_jobs.where((j) => j.status == _JobStatus.done).length} done', const Color(0xFF22C55E)),
                if (_jobs.any((j) => j.status == _JobStatus.error)) ...[
                  const SizedBox(width: 8),
                  _StatPill('${_jobs.where((j) => j.status == _JobStatus.error).length} failed', AppColors.error),
                ],
                const Spacer(),
                if (!_isRunning && _jobs.any((j) => j.status == _JobStatus.done || j.status == _JobStatus.error))
                  TextButton.icon(
                    onPressed: _clearCompleted,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear done'),
                    style: TextButton.styleFrom(foregroundColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                  ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              itemCount: _jobs.length,
              itemBuilder: (ctx, i) => _JobTile(
                key: ValueKey(_jobs[i].id),
                job: _jobs[i],
                isDark: isDark,
                canEdit: !_isRunning,
                onRemove: () => _removeJob(_jobs[i].id),
                onFormatChanged: (fmt) => setState(() => _jobs[i].outputFormat = fmt),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 30)).slideY(begin: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final pendingCount = _jobs.where((j) => j.status == _JobStatus.pending).length;
    final allDone = _jobs.every((j) => j.status == _JobStatus.done || j.status == _JobStatus.error);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkNavBar : AppColors.lightNavBar,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Output path
          GestureDetector(
            onTap: _pickOutputDir,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open_rounded, size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _outputDir.isEmpty ? 'Select output folder' : _outputDir,
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit_rounded, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Add more files
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : _pickFiles,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Files'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Convert button
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (_isRunning || pendingCount == 0) ? null : _runConversion,
                  icon: _isRunning
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(
                    _isRunning
                        ? 'Converting...'
                        : (allDone ? 'All Done ✓' : 'Convert $pendingCount ${pendingCount == 1 ? "File" : "Files"}'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Job Tile ─────────────────────────────────────────────────────────────────

class _JobTile extends StatelessWidget {
  final _BulkJob job;
  final bool isDark;
  final bool canEdit;
  final VoidCallback onRemove;
  final ValueChanged<_BulkFmt> onFormatChanged;

  const _JobTile({
    super.key,
    required this.job,
    required this.isDark,
    required this.canEdit,
    required this.onRemove,
    required this.onFormatChanged,
  });

  Color get _statusColor {
    switch (job.status) {
      case _JobStatus.done: return const Color(0xFF22C55E);
      case _JobStatus.error: return AppColors.error;
      case _JobStatus.converting: return AppColors.primary;
      case _JobStatus.pending: return isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case _JobStatus.done: return Icons.check_circle_rounded;
      case _JobStatus.error: return Icons.error_outline_rounded;
      case _JobStatus.converting: return Icons.sync_rounded;
      case _JobStatus.pending: return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: job.status == _JobStatus.error
              ? AppColors.error.withValues(alpha: 0.3)
              : job.status == _JobStatus.done
                  ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Format badge
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: job.outputFormat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(job.outputFormat.icon, color: job.outputFormat.color, size: 18),
              ),
              const SizedBox(width: 12),
              // File name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.fileName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Icon(_statusIcon, size: 12, color: _statusColor),
                      const SizedBox(width: 4),
                      Text(
                        job.status == _JobStatus.pending ? 'Pending'
                          : job.status == _JobStatus.converting ? 'Converting…'
                          : job.status == _JobStatus.done ? 'Done'
                          : 'Error',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Format picker (if pending/editable)
              if (job.status == _JobStatus.pending && canEdit)
                _MiniFormatPicker(
                  selected: job.outputFormat,
                  onSelected: onFormatChanged,
                  isDark: isDark,
                ),
              const SizedBox(width: 4),
              if (canEdit)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          // Progress bar
          if (job.status == _JobStatus.converting) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress > 0 ? job.progress : null,
                minHeight: 4,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
          // Error message
          if (job.status == _JobStatus.error && job.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(job.errorMessage!,
              style: const TextStyle(fontSize: 11, color: AppColors.error),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          // Output path for done
          if (job.status == _JobStatus.done && job.outputPath != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Process.run('explorer', ['/select,', job.outputPath!], runInShell: true),
              child: Text('→ ${p.basename(job.outputPath!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E), fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Format Picker ─────────────────────────────────────────────────────────────

class _FormatPicker extends StatelessWidget {
  final _BulkFmt selected;
  final ValueChanged<_BulkFmt> onSelected;
  final bool isDark;

  const _FormatPicker({required this.selected, required this.onSelected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BulkFmt>(
      initialValue: selected,
      onSelected: onSelected,
      tooltip: 'Set format for all pending files',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected.icon, color: selected.color, size: 16),
            const SizedBox(width: 6),
            Text(selected.label, style: TextStyle(color: selected.color, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, color: selected.color, size: 18),
          ],
        ),
      ),
      itemBuilder: (_) => _buildMenuItems(),
    );
  }

  List<PopupMenuEntry<_BulkFmt>> _buildMenuItems() {
    final items = <PopupMenuEntry<_BulkFmt>>[];
    items.add(const PopupMenuItem(enabled: false, height: 28,
        child: Text('VIDEO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4), letterSpacing: 1))));
    for (final f in _BulkFmt.values.where((f) => f.isVideo)) {
      items.add(PopupMenuItem(value: f, child: Row(children: [Icon(f.icon, size: 16, color: f.color), const SizedBox(width: 10), Text(f.label)])));
    }
    items.add(const PopupMenuDivider());
    items.add(const PopupMenuItem(enabled: false, height: 28,
        child: Text('AUDIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6), letterSpacing: 1))));
    for (final f in _BulkFmt.values.where((f) => f.isAudio)) {
      items.add(PopupMenuItem(value: f, child: Row(children: [Icon(f.icon, size: 16, color: f.color), const SizedBox(width: 10), Text(f.label)])));
    }
    items.add(const PopupMenuDivider());
    items.add(const PopupMenuItem(enabled: false, height: 28,
        child: Text('IMAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEC4899), letterSpacing: 1))));
    for (final f in _BulkFmt.values.where((f) => f.isImage)) {
      items.add(PopupMenuItem(value: f, child: Row(children: [Icon(f.icon, size: 16, color: f.color), const SizedBox(width: 10), Text(f.label)])));
    }
    return items;
  }
}

class _MiniFormatPicker extends StatelessWidget {
  final _BulkFmt selected;
  final ValueChanged<_BulkFmt> onSelected;
  final bool isDark;

  const _MiniFormatPicker({required this.selected, required this.onSelected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BulkFmt>(
      initialValue: selected,
      onSelected: onSelected,
      tooltip: 'Change format',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected.color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: selected.color)),
            Icon(Icons.arrow_drop_down_rounded, size: 14, color: selected.color),
          ],
        ),
      ),
      itemBuilder: (_) {
        final items = <PopupMenuEntry<_BulkFmt>>[];
        for (final f in _BulkFmt.values) {
          items.add(PopupMenuItem(value: f, height: 36,
            child: Row(children: [Icon(f.icon, size: 14, color: f.color), const SizedBox(width: 8), Text(f.label, style: const TextStyle(fontSize: 13))])));
        }
        return items;
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FormatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FormatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
