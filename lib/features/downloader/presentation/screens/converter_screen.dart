import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/app_colors.dart';
import '../providers/converter_provider.dart';
import '../../../../core/utils/platform_utils.dart';

// ── Format metadata ────────────────────────────────────────────────────────────
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
  ConversionFormat.avif:   Icons.image_rounded,
  ConversionFormat.tga:    Icons.image_rounded,
};

const _formatDisplayNames = {
  ConversionFormat.tgp:    '3GP',
  ConversionFormat.jpg:    'JPG',
  ConversionFormat.png:    'PNG',
  ConversionFormat.webp:   'WEBP',
  ConversionFormat.gif:    'GIF',
  ConversionFormat.bmp:    'BMP',
  ConversionFormat.tiff:   'TIFF',
  ConversionFormat.truehd: 'TrueHD',
  ConversionFormat.hevc:   'H.265',
  ConversionFormat.prores: 'ProRes',
  ConversionFormat.mka:    'MKA',
  ConversionFormat.svg:    'SVG',
  ConversionFormat.heic:   'HEIC',
  ConversionFormat.avif:   'AVIF',
  ConversionFormat.tga:    'TGA',
};

// ── Format groupings ──────────────────────────────────────────────────────────
const _audioOutputFormats = [
  ConversionFormat.mp3,  ConversionFormat.aac,  ConversionFormat.m4a,
  ConversionFormat.wav,  ConversionFormat.flac,  ConversionFormat.ogg,
  ConversionFormat.opus, ConversionFormat.wma,  ConversionFormat.amr,
  ConversionFormat.ac3,  ConversionFormat.mp2,  ConversionFormat.aiff,
  ConversionFormat.ra,   ConversionFormat.mka,  ConversionFormat.dts,
  ConversionFormat.truehd, ConversionFormat.ape, ConversionFormat.m4b,
  ConversionFormat.caf,
];
const _videoOutputFormats = [
  ConversionFormat.mp4,   ConversionFormat.mkv,   ConversionFormat.mov,
  ConversionFormat.avi,   ConversionFormat.webm,  ConversionFormat.flv,
  ConversionFormat.wmv,   ConversionFormat.asf,   ConversionFormat.ts,
  ConversionFormat.tgp,   ConversionFormat.m4v,
  ConversionFormat.mpg,   ConversionFormat.vob,   ConversionFormat.divx,
  ConversionFormat.hevc,  ConversionFormat.prores,
];
const _imageOutputFormats = [
  ConversionFormat.jpg,  ConversionFormat.png,  ConversionFormat.webp,
  ConversionFormat.gif,  ConversionFormat.bmp,  ConversionFormat.tiff,
  ConversionFormat.svg,  ConversionFormat.heic,
  ConversionFormat.avif, ConversionFormat.tga, 
];
// Audio formats available when extracting audio from video
const _videoExtractAudioFormats = [
  ConversionFormat.mp3,  ConversionFormat.aac,  ConversionFormat.m4a,
  ConversionFormat.wav,  ConversionFormat.flac,  ConversionFormat.ogg,
  ConversionFormat.opus, ConversionFormat.ac3,  ConversionFormat.mp2,
  ConversionFormat.aiff, ConversionFormat.mka,  ConversionFormat.dts,
];

// ── Input type helpers ────────────────────────────────────────────────────────
String _inputTypeLabel(InputMediaType t) {
  switch (t) {
    case InputMediaType.audio:   return 'Audio';
    case InputMediaType.video:   return 'Video';
    case InputMediaType.image:   return 'Image';
    case InputMediaType.unknown: return 'Media';
  }
}
IconData _inputTypeIcon(InputMediaType t) {
  switch (t) {
    case InputMediaType.audio:   return Icons.audiotrack_rounded;
    case InputMediaType.video:   return Icons.videocam_rounded;
    case InputMediaType.image:   return Icons.image_rounded;
    case InputMediaType.unknown: return Icons.file_present_rounded;
  }
}
Color _inputTypeColor(InputMediaType t) {
  switch (t) {
    case InputMediaType.audio:   return AppColors.info;
    case InputMediaType.video:   return AppColors.primary;
    case InputMediaType.image:   return AppColors.success;
    case InputMediaType.unknown: return AppColors.primary;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConverterProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => AppColors.brandGradient.createShader(bounds),
          child: const Text(
            'Media Converter',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.drive_file_rename_outline_rounded, size: 18), text: 'Single File'),
            Tab(icon: Icon(Icons.filter_none_rounded, size: 18), text: 'Bulk Convert'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Single file converter ──────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFileSelector(context, provider, isDark),
                  if (provider.inputPath != null) ...[
                    const SizedBox(height: 16),
                    _buildInputTypeBanner(context, provider, isDark),
                    const SizedBox(height: 16),
                    _buildFormatGrid(context, provider, isDark),
                    const SizedBox(height: 16),
                    // ── Fine-tune controls per target type ─────────────────────
                    _buildFineTuneSection(context, provider, isDark),
                    const SizedBox(height: 20),
                    _buildActionArea(context, provider, isDark),
                  ],
                ],
              ),
            ),
          ),
          // ── Tab 2: Bulk converter ──────────────────────────────────────
          _BulkConverterTab(isDark: isDark),
        ],
      ),
    );
  }

  // ── File Selector ─────────────────────────────────────────────────────────
  Widget _buildFileSelector(BuildContext context, ConverterProvider provider, bool isDark) {
    final hasFile = provider.inputPath != null;
    return GestureDetector(
      onTap: provider.status == ConversionStatus.converting
          ? null
          : () async {
              final result = await FilePicker.platform.pickFiles(
                allowedExtensions: [
                  'mp3','aac','wav','flac','m4a','ogg','opus','wma','amr','ac3','aiff','alac',
                  'mp4','mkv','avi','mov','webm','flv','3gp','ts','wmv','asf','rmvb','m4v','mpeg','mpg',
                  'jpg','jpeg','png','webp','gif','bmp','tiff','tif','heic','heif','avif',
                ],
                type: FileType.custom,
                allowMultiple: true,
              );
              if (result != null && result.files.isNotEmpty) {
                final paths = result.files.where((f) => f.path != null).map((f) => f.path!).toList();
                if (paths.isNotEmpty) {
                  provider.setInputFiles(paths);
                }
              }
            },
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasFile
                ? AppColors.primary.withValues(alpha: 0.6)
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: hasFile ? 1.5 : 1.0,
          ),
          boxShadow: hasFile
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: hasFile
            ? Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(14)),
                  child: Icon(_inputTypeIcon(provider.inputType), color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Files Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(provider.inputPaths.length == 1 ? p.basename(provider.inputPath!) : '${provider.inputPaths.length} Files Selected',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(p.dirname(provider.inputPath!),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.autorenew_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Select Any Media File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Video · Audio · Image and more',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ]),
              ]),
      ),
    ).animate().fadeIn(duration: 120.ms);
  }

  // ── Input type banner ─────────────────────────────────────────────────────
  Widget _buildInputTypeBanner(BuildContext context, ConverterProvider provider, bool isDark) {
    final type = provider.inputType;
    final color = _inputTypeColor(type);
    final label = _inputTypeLabel(type);
    final icon = _inputTypeIcon(type);
    final ext = p.extension(provider.inputPath!).replaceFirst('.', '').toUpperCase();

    // Show detected resolution if available (video/image)
    final hasRes = provider.sourceWidth != null && provider.sourceHeight != null;
    final resLabel = hasRes ? '  •  ${provider.sourceWidth}×${provider.sourceHeight}' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          children: [
            TextSpan(text: '${provider.inputPaths.length > 1 ? "Bulk " : ""}$label file${provider.inputPaths.length > 1 ? "s" : ""} detected ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: provider.inputPaths.length == 1 ? '(.$ext)$resLabel ' : ' ', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            const TextSpan(text: '— select a target format below.'),
          ],
        ))),
      ]),
    ).animate().fadeIn(duration: 120.ms);
  }

  // ── Format Grid ───────────────────────────────────────────────────────────
  Widget _buildFormatGrid(BuildContext context, ConverterProvider provider, bool isDark) {
    final inputType = provider.inputType;
    final List<Widget> sections = [];

    switch (inputType) {
      case InputMediaType.audio:
        sections
          ..add(_FormatRow(label: '♪ AUDIO — Convert To', formats: _audioOutputFormats, provider: provider, isDark: isDark))
          ..add(const SizedBox(height: 16))
          ..add(_FormatRow(label: '▶ VIDEO — Wrap Audio In', formats: const [ConversionFormat.mp4, ConversionFormat.mkv, ConversionFormat.avi], provider: provider, isDark: isDark));
        break;
      case InputMediaType.video:
        sections
          ..add(_FormatRow(label: '▶ VIDEO — Convert To', formats: _videoOutputFormats, provider: provider, isDark: isDark))
          ..add(const SizedBox(height: 16))
          ..add(_FormatRow(label: '♪ AUDIO — Extract Audio', formats: _videoExtractAudioFormats, provider: provider, isDark: isDark));
        break;
      case InputMediaType.image:
        sections.add(_FormatRow(label: '🖼 IMAGE — Convert To', formats: _imageOutputFormats, provider: provider, isDark: isDark));
        break;
      case InputMediaType.unknown:
        sections
          ..add(_FormatRow(label: '♪ AUDIO', formats: _audioOutputFormats, provider: provider, isDark: isDark))
          ..add(const SizedBox(height: 16))
          ..add(_FormatRow(label: '▶ VIDEO', formats: _videoOutputFormats, provider: provider, isDark: isDark))
          ..add(const SizedBox(height: 16))
          ..add(_FormatRow(label: '🖼 IMAGE', formats: _imageOutputFormats, provider: provider, isDark: isDark));
    }

    return _SectionCard(
      isDark: isDark,
      label: 'TARGET FORMAT',
      delay: 30,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections),
    );
  }

  // ── Fine-tune section ─────────────────────────────────────────────────────
  Widget _buildFineTuneSection(BuildContext context, ConverterProvider provider, bool isDark) {
    if (provider.isAudioTarget) {
      return _AudioFineTune(provider: provider, isDark: isDark);
    }
    if (provider.isImageTarget) {
      return _ImageFineTune(provider: provider, isDark: isDark);
    }
    return _VideoFineTune(provider: provider, isDark: isDark);
  }

  // ── Action Area ───────────────────────────────────────────────────────────
  Widget _buildActionArea(BuildContext context, ConverterProvider provider, bool isDark) {
    if (provider.status == ConversionStatus.converting) {
      return _ConvertingCard(provider: provider, isDark: isDark);
    }
    if (provider.status == ConversionStatus.complete) {
      return _CompleteCard(provider: provider, isDark: isDark);
    }
    if (provider.status == ConversionStatus.error) {
      return _ErrorCard(provider: provider);
    }
    return GestureDetector(
      onTap: () => _handleStartConversion(context, provider),
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Text('Start Conversion', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    ).animate().fadeIn(duration: 150.ms);
  }

  Future<void> _handleStartConversion(BuildContext context, ConverterProvider provider) async {
    if (provider.inputPath == null) return;
    if (provider.outputFileExists()) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => _ConflictDialog(provider: provider),
      );
      if (result == null) return;
      await provider.startConversion(overwrite: result == 'overwrite');
    } else {
      await provider.startConversion();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FINE-TUNE: AUDIO BITRATE — chip buttons (no slider)
// ═══════════════════════════════════════════════════════════════════════════
class _AudioFineTune extends StatelessWidget {
  final ConverterProvider provider;
  final bool isDark;
  const _AudioFineTune({required this.provider, required this.isDark});

  static const _options = [
    (label: '128 kbps', kbps: 128, tag: 'Standard'),
    (label: '192 kbps', kbps: 192, tag: 'Good'),
    (label: '256 kbps', kbps: 256, tag: 'High'),
    (label: '320 kbps', kbps: 320, tag: 'Best'),
  ];

  int get _currentKbps => provider.customAudioKbps ?? 192;

  @override
  Widget build(BuildContext context) {
    final currentKbps = _currentKbps;
    return _SectionCard(
      isDark: isDark,
      label: 'AUDIO QUALITY',
      delay: 40,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Select audio bitrate',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _options.map((opt) {
            final isSelected = currentKbps == opt.kbps;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: provider.status == ConversionStatus.converting
                      ? null
                      : () => provider.setCustomAudioKbps(opt.kbps),
                  child: AnimatedContainer(
                    duration: 120.ms,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.info
                          : (isDark ? AppColors.darkBg : AppColors.lightBg),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.info
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.info.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                          : null,
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        opt.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        opt.tag,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FINE-TUNE: VIDEO RESOLUTION + CRF SLIDER
// ═══════════════════════════════════════════════════════════════════════════
class _VideoFineTune extends StatefulWidget {
  final ConverterProvider provider;
  final bool isDark;
  const _VideoFineTune({required this.provider, required this.isDark});
  @override
  State<_VideoFineTune> createState() => _VideoFineTuneState();
}

class _VideoFineTuneState extends State<_VideoFineTune> {
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  bool _showCustom = false;
  bool _keepAspect = true;
  double? _aspectRatio;

  @override
  void didUpdateWidget(_VideoFineTune old) {
    super.didUpdateWidget(old);
    _syncFromProvider();
  }

  @override
  void initState() {
    super.initState();
    _syncFromProvider();
  }

  void _syncFromProvider() {
    final p = widget.provider;
    if (p.sourceWidth != null && p.sourceHeight != null) {
      final w = p.sourceWidth!;
      final h = p.sourceHeight!;
      _aspectRatio = w / h;
      if (_wCtrl.text.isEmpty) _wCtrl.text = w.toString();
      if (_hCtrl.text.isEmpty) _hCtrl.text = h.toString();
    } else {
      if (p.customVideoWidth > 0 && p.customVideoHeight != null) {
          _wCtrl.text = p.customVideoWidth.toString();
          _hCtrl.text = p.customVideoHeight.toString();
      }
    }
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _onWidthChanged(String val) {
    if (!_keepAspect || _aspectRatio == null) return;
    final w = int.tryParse(val);
    if (w != null && w > 0) {
      final h = (w / _aspectRatio!).round();
      _hCtrl.text = h.toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_keepAspect || _aspectRatio == null) return;
    final h = int.tryParse(val);
    if (h != null && h > 0) {
      final w = (h * _aspectRatio!).round();
      _wCtrl.text = w.toString();
    }
  }

  void _applyDimensions() {
    final w = int.tryParse(_wCtrl.text) ?? 0;
    final h = int.tryParse(_hCtrl.text) ?? 0;
    widget.provider.setCustomVideoResolution(w, h);
  }

  String _resolutionLabelFor(VideoResolution res, ConverterProvider p) {
    if (res.height == -1) {
      // Original — show actual dims if detected
      if (p.sourceWidth != null && p.sourceHeight != null) {
        return 'Original (${p.sourceWidth}×${p.sourceHeight})';
      }
      return 'Original';
    }
    return res.label;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isDark = widget.isDark;
    final selectedHeight = provider.customVideoHeight;

    return Column(children: [
      // ── Resolution presets ──────────────────────────────────────────────
      _SectionCard(
        isDark: isDark,
        label: 'VIDEO RESOLUTION',
        delay: 40,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: VideoResolution.presets.map((res) {
              final isSelected = !_showCustom && selectedHeight == res.height;
              return GestureDetector(
                onTap: provider.status == ConversionStatus.converting ? null : () {
                  setState(() => _showCustom = false);
                  provider.setVideoResolutionPreset(res);
                },
                child: AnimatedContainer(
                  duration: 100.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBg : AppColors.lightBg),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
                  ),
                  child: Text(
                    _resolutionLabelFor(res, provider),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Custom resolution toggle
          GestureDetector(
            onTap: provider.status == ConversionStatus.converting ? null : () {
              setState(() => _showCustom = !_showCustom);
            },
            child: AnimatedContainer(
              duration: 120.ms,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showCustom ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showCustom ? AppColors.primary.withValues(alpha: 0.5) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 14, color: _showCustom ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                const SizedBox(width: 8),
                Text('Custom Resolution',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _showCustom ? AppColors.primary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
                const Spacer(),
                Icon(_showCustom ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _showCustom ? AppColors.primary : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ]),
            ),
          ),
          AnimatedSize(duration: 150.ms, child: _showCustom
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enter custom width × height (px)',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _ResTextField(ctrl: _wCtrl, hint: 'Width', isDark: isDark, onChanged: (v) { _onWidthChanged(v); _applyDimensions(); })),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ),
                    Expanded(child: _ResTextField(ctrl: _hCtrl, hint: 'Height', isDark: isDark, onChanged: (v) { _onHeightChanged(v); _applyDimensions(); })),
                  ]),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _keepAspect = !_keepAspect),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: 120.ms,
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: _keepAspect ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _keepAspect ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                        ),
                        child: _keepAspect ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Keep aspect ratio',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ]),
                  ),
                  if (provider.useCustomVideoResolution && provider.customVideoHeight != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Custom: ${provider.customVideoWidth > 0 ? provider.customVideoWidth : "auto"}×${provider.customVideoHeight}px',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ]),
                      ),
                    ),
                ]),
              )
            : const SizedBox.shrink(),
          ),
        ]),
      ),
    ]);
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// FINE-TUNE: IMAGE — dimension inputs + quality chips (no slider)
// ═══════════════════════════════════════════════════════════════════════════
class _ImageFineTune extends StatefulWidget {
  final ConverterProvider provider;
  final bool isDark;
  const _ImageFineTune({required this.provider, required this.isDark});
  @override
  State<_ImageFineTune> createState() => _ImageFineTuneState();
}

class _ImageFineTuneState extends State<_ImageFineTune> {
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();
  bool _keepAspect = true;
  double? _aspectRatio; // w/h

  @override
  void didUpdateWidget(_ImageFineTune old) {
    super.didUpdateWidget(old);
    _syncFromProvider();
  }

  @override
  void initState() {
    super.initState();
    _syncFromProvider();
  }

  void _syncFromProvider() {
    final p = widget.provider;
    // Pre-fill with detected source dimensions
    if (p.sourceWidth != null && p.sourceHeight != null) {
      final w = p.sourceWidth!;
      final h = p.sourceHeight!;
      _aspectRatio = w / h;
      if (_wCtrl.text.isEmpty) _wCtrl.text = w.toString();
      if (_hCtrl.text.isEmpty) _hCtrl.text = h.toString();
    }
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _onWidthChanged(String val) {
    if (!_keepAspect || _aspectRatio == null) return;
    final w = int.tryParse(val);
    if (w != null && w > 0) {
      final h = (w / _aspectRatio!).round();
      _hCtrl.text = h.toString();
    }
  }

  void _onHeightChanged(String val) {
    if (!_keepAspect || _aspectRatio == null) return;
    final h = int.tryParse(val);
    if (h != null && h > 0) {
      final w = (h * _aspectRatio!).round();
      _wCtrl.text = w.toString();
    }
  }

  void _applyDimensions() {
    final w = int.tryParse(_wCtrl.text) ?? 0;
    final h = int.tryParse(_hCtrl.text) ?? 0;
    widget.provider.setCustomImageDimensions(w, h);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final isDark = widget.isDark;
    final q = provider.customImageQuality ?? 90;

    // Quality chip options — null value = 'Original' (no custom quality set)
    const qualityOptions = [
      (label: 'Original', value: -1, tag: 'Auto'),
      (label: 'Low',      value: 65, tag: '65%'),
      (label: 'Medium',   value: 80, tag: '80%'),
      (label: 'High',     value: 95, tag: '95%'),
      (label: 'Max',      value: 100, tag: '100%'),
    ];


    return Column(children: [
      // ── Dimensions ─────────────────────────────────────────────────────
      _SectionCard(
        isDark: isDark,
        label: 'IMAGE SIZE (WIDTH × HEIGHT)',
        delay: 40,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (provider.sourceWidth != null && provider.sourceHeight != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Original: ${provider.sourceWidth}×${provider.sourceHeight} px',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
              ),
            ),
          Row(children: [
            Expanded(child: _ResTextField(ctrl: _wCtrl, hint: 'Width', isDark: isDark, onChanged: (v) { _onWidthChanged(v); _applyDimensions(); })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ),
            Expanded(child: _ResTextField(ctrl: _hCtrl, hint: 'Height', isDark: isDark, onChanged: (v) { _onHeightChanged(v); _applyDimensions(); })),
          ]),
          const SizedBox(height: 10),
          // Aspect ratio lock
          GestureDetector(
            onTap: () => setState(() => _keepAspect = !_keepAspect),
            child: Row(children: [
              AnimatedContainer(
                duration: 120.ms,
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _keepAspect ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _keepAspect ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                ),
                child: _keepAspect ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
              ),
              const SizedBox(width: 8),
              Text('Keep aspect ratio',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 12),

      // ── Quality ────────────────────────────────────────────────────────
      _SectionCard(
        isDark: isDark,
        label: 'IMAGE QUALITY',
        delay: 50,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Select output quality',
            style: TextStyle(fontSize: 12,
              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          ),
          const SizedBox(height: 12),
          Row(
            children: qualityOptions.map((opt) {
              final isSelected = opt.value == -1
                  ? provider.customImageQuality == null
                  : q == opt.value;
              final chipColor = opt.value == -1 ? AppColors.primary
                  : (opt.value >= 90 ? AppColors.success
                  : opt.value >= 70 ? AppColors.info
                  : AppColors.warning);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: provider.status == ConversionStatus.converting
                        ? null
                        : () => opt.value == -1
                            ? provider.setCustomImageQuality(null)
                            : provider.setCustomImageQuality(opt.value),
                    child: AnimatedContainer(
                      duration: 120.ms,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? chipColor : (isDark ? AppColors.darkBg : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? chipColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: chipColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          opt.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.tag,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected ? Colors.white.withValues(alpha: 0.85)
                                : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _ResTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool isDark;
  final ValueChanged<String>? onChanged;
  const _ResTextField({required this.ctrl, required this.hint, required this.isDark, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
        filled: true,
        fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final Widget child;
  final int delay;
  const _SectionCard({required this.isDark, required this.label, required this.child, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        )),
        const SizedBox(height: 12),
        child,
      ]),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 130.ms);
  }
}

class _FormatRow extends StatelessWidget {
  final String label;
  final List<ConversionFormat> formats;
  final ConverterProvider provider;
  final bool isDark;
  const _FormatRow({required this.label, required this.formats, required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5,
        color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: formats.map((format) {
        final isSelected = provider.targetFormat == format;
        final displayName = _formatDisplayNames[format] ?? format.name.toUpperCase();
        final icon = _formatIcons[format] ?? Icons.insert_drive_file_rounded;
        return GestureDetector(
          onTap: provider.status == ConversionStatus.converting ? null : () => provider.setTargetFormat(format),
          child: AnimatedContainer(
            duration: 100.ms,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBg : AppColors.lightBg),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              const SizedBox(width: 5),
              Text(displayName, style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              )),
              if (provider.isConditionallySupported(format)) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'This format may fail without specific codecs or parameters',
                  child: Icon(Icons.warning_amber_rounded, size: 12, color: isSelected ? Colors.white70 : AppColors.warning),
                ),
              ],
            ]),
          ),
        );
      }).toList()),
    ]);
  }
}

class _ConvertingCard extends StatelessWidget {
  final ConverterProvider provider;
  final bool isDark;
  const _ConvertingCard({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
          const SizedBox(width: 14),
          Text(provider.totalFiles > 1 
              ? 'Converting (${provider.currentFileIndex + 1}/${provider.totalFiles})...' 
              : 'Converting...', 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${(provider.progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.primary)),
        ]),
        if (provider.totalFiles > 1) ...[
          const SizedBox(height: 8),
          Text(p.basename(provider.inputPaths[provider.currentFileIndex]),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
          value: provider.progress.clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBorder.withValues(alpha: 0.5),
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        )),
        if (provider.timeRemainingStr.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Elapsed: ${provider.timeRemainingStr}',
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
        ],
      ]),
    ).animate().fadeIn();
  }
}

// Complete card — only 2 buttons (no "Convert to Another Format")
class _CompleteCard extends StatelessWidget {
  final ConverterProvider provider;
  final bool isDark;
  const _CompleteCard({required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            child: const Icon(Icons.done_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(provider.totalFiles > 1 ? 'Converted ${provider.totalFiles} files!' : 'Conversion Complete!',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.success)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'Tap any format chip above to re-convert this file.',
          style: TextStyle(fontSize: 11,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => provider.reset(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(provider.totalFiles > 1 ? 'New Files' : 'New File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            onPressed: () {
              if (provider.outputPath != null) PlatformUtils.openFolder(p.dirname(provider.outputPath!));
            },
            icon: const Icon(Icons.folder_open_rounded, size: 16),
            label: const Text('Open Folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
        ]),
      ]),
    ).animate().fadeIn(duration: 150.ms);
  }
}

class _ErrorCard extends StatelessWidget {
  final ConverterProvider provider;
  const _ErrorCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(
            provider.errorMessage ?? 'Conversion failed',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
          )),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: provider.startConversion,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
      ]),
    ).animate().fadeIn();
  }
}

class _ConflictDialog extends StatelessWidget {
  final ConverterProvider provider;
  const _ConflictDialog({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = provider.targetFormat.name;
    final ext = n == 'tgp' ? '3gp' : n;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
        ),
        const SizedBox(width: 12),
        const Text('File Already Exists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'A .${ext.toUpperCase()} version of this file already exists in the same folder.',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Text('What would you like to do?',
          style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w600)),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, 'overwrite'),
          icon: const Icon(Icons.file_copy_rounded, size: 16),
          label: const Text('Overwrite'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'keep'),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Save with Number (e.g. _2)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
      ],
    );
  }
}



// ===========================================================================
// BULK CONVERTER TAB — Full Featured
// ===========================================================================
class _BulkConverterTab extends StatefulWidget {
  final bool isDark;
  const _BulkConverterTab({required this.isDark});

  @override
  State<_BulkConverterTab> createState() => _BulkConverterTabState();
}

class _BulkConverterTabState extends State<_BulkConverterTab> {
  final List<_BatchItem> _items = [];
  bool _isConverting = false;
  bool _isDragging = false;

  static const _audioExts = {'.mp3','.aac','.wav','.flac','.m4a','.ogg','.opus','.wma','.amr','.ac3','.aiff','.alac','.mp2','.ra','.mka','.dts','.ape','.m4b','.caf'};
  static const _videoExts = {'.mp4','.mkv','.avi','.mov','.webm','.flv','.3gp','.ts','.wmv','.asf','.m4v','.mpeg','.mpg','.vob','.divx'};
  static const _imageExts = {'.jpg','.jpeg','.png','.webp','.gif','.bmp','.tiff','.tif','.heic','.heif','.svg','.avif','.tga'};

  InputMediaType _detectType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (_audioExts.contains(ext)) return InputMediaType.audio;
    if (_videoExts.contains(ext)) return InputMediaType.video;
    if (_imageExts.contains(ext)) return InputMediaType.image;
    return InputMediaType.unknown;
  }

  ConversionFormat _defaultFormat(InputMediaType t) {
    switch (t) {
      case InputMediaType.audio:   return ConversionFormat.mp3;
      case InputMediaType.video:   return ConversionFormat.mp4;
      case InputMediaType.image:   return ConversionFormat.jpg;
      case InputMediaType.unknown: return ConversionFormat.mp4;
    }
  }

  List<ConversionFormat> _formatsFor(InputMediaType t) {
    switch (t) {
      case InputMediaType.audio:   return [..._audioOutputFormats];
      case InputMediaType.video:   return [..._videoOutputFormats, ..._videoExtractAudioFormats.take(4)];
      case InputMediaType.image:   return [..._imageOutputFormats];
      case InputMediaType.unknown: return [..._videoOutputFormats.take(6), ..._audioOutputFormats.take(4)];
    }
  }

  String _fmtName(ConversionFormat f) => _formatDisplayNames[f] ?? f.name.toUpperCase();

  void _addPaths(List<String> paths) {
    setState(() {
      for (final path in paths) {
        if (!_items.any((i) => i.path == path)) {
          final type = _detectType(path);
          _items.add(_BatchItem(
            path: path,
            name: p.basename(path),
            type: type,
            targetFormat: _defaultFormat(type),
          ));
        }
      }
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp3','aac','wav','flac','m4a','ogg','opus','wma','amr','ac3','aiff','mp2','mka',
        'mp4','mkv','avi','mov','webm','flv','wmv','ts','m4v','mpg','mpeg',
        'jpg','jpeg','png','webp','gif','bmp','tiff','tif','heic','avif','tga',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      _addPaths(result.files.where((f) => f.path != null).map((f) => f.path!).toList());
    }
  }

  void _removeItem(String filePath) => setState(() => _items.removeWhere((i) => i.path == filePath));
  void _clearDone() => setState(() => _items.removeWhere((i) => i.status == 'done'));

  Future<void> _convertAll() async {
    if (_items.isEmpty) return;
    final provider = context.read<ConverterProvider>();
    setState(() => _isConverting = true);

    for (final item in List<_BatchItem>.from(_items)) {
      if (!mounted) break;
      if (item.status == 'done') continue;
      setState(() { item.status = 'converting'; item.progress = 0.1; item.errorMsg = null; });
      try {
        provider.setInputFiles([item.path]);
        provider.setTargetFormat(item.targetFormat);
        await provider.startConversion();
        while (provider.status == ConversionStatus.converting) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) break;
          setState(() { item.progress = (provider.progress * 0.9) + 0.1; });
        }
        if (!mounted) break;
        setState(() {
          if (provider.status == ConversionStatus.complete) {
            item.status = 'done';
            item.progress = 1.0;
            item.outputPath = provider.outputPath;
          } else {
            item.status = 'error';
            item.progress = 0;
            item.errorMsg = provider.errorMessage ?? 'Conversion failed';
          }
        });
      } catch (e) {
        if (!mounted) break;
        setState(() { item.status = 'error'; item.errorMsg = e.toString(); });
      }
    }
    if (mounted) setState(() => _isConverting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiary = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final doneCount = _items.where((i) => i.status == 'done').length;
    final pendingCount = _items.where((i) => i.status != 'done').length;
    final canConvert = pendingCount > 0 && !_isConverting;

    return SafeArea(
      child: Column(
        children: [
          // Drop Zone
          DragTarget<Object>(
            onWillAcceptWithDetails: (_) { setState(() => _isDragging = true); return true; },
            onLeave: (_) => setState(() => _isDragging = false),
            onAcceptWithDetails: (_) => setState(() => _isDragging = false),
            builder: (context, _, __) {
              return GestureDetector(
                onTap: _isConverting ? null : _pickFiles,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  height: _items.isEmpty ? 160 : 64,
                  decoration: BoxDecoration(
                    color: _isDragging ? AppColors.primary.withValues(alpha: 0.08) : cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDragging ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                      width: _isDragging ? 2 : 1.5,
                    ),
                  ),
                  child: _items.isEmpty
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ShaderMask(
                            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                            child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isDragging ? 'Drop files here!' : 'Drag & Drop or Tap to Add Files',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports video  audio  images — any mix of formats',
                            style: TextStyle(fontSize: 11, color: textTertiary),
                          ),
                        ])
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ShaderMask(
                            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                            child: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isDragging ? 'Drop to add more' : 'Add More Files',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textTertiary),
                          ),
                        ]),
                ),
              );
            },
          ),

          // Toolbar
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Text('${_items.length} file${_items.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textTertiary, letterSpacing: 1.1)),
                if (doneCount > 0) ...[
                  const SizedBox(width: 6),
                  Text('  $doneCount done', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                if (doneCount > 0 && !_isConverting)
                  _SmallBtn('Clear Done', AppColors.success, _clearDone),
                if (!_isConverting) ...[
                  const SizedBox(width: 6),
                  _SmallBtn('Clear All', AppColors.error, () => setState(() => _items.clear())),
                ],
              ]),
            ),

          // File list
          Expanded(
            child: _items.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _items.length,
                    itemBuilder: (context, idx) {
                      final item = _items[idx];
                      final isDone = item.status == 'done';
                      final isError = item.status == 'error';
                      final isActive = item.status == 'converting';
                      final typeColor = _inputTypeColor(item.type);
                      final fmtOptions = _formatsFor(item.type);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDone ? AppColors.success.withValues(alpha: 0.05)
                              : isError ? AppColors.error.withValues(alpha: 0.05)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDone ? AppColors.success.withValues(alpha: 0.3)
                                : isError ? AppColors.error.withValues(alpha: 0.3)
                                : isActive ? AppColors.primary.withValues(alpha: 0.4)
                                : borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_inputTypeIcon(item.type), size: 14, color: typeColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(item.name,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Row(children: [
                                    Text(_inputTypeLabel(item.type),
                                      style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text('-> ${_fmtName(item.targetFormat)}',
                                      style: TextStyle(fontSize: 10, color: textTertiary, fontWeight: FontWeight.w500)),
                                  ]),
                                ]),
                              ),
                              if (isDone)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Done', style: TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.w800)),
                                )
                              else if (isError)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Failed', style: TextStyle(fontSize: 9, color: AppColors.error, fontWeight: FontWeight.w800)),
                                )
                              else if (!_isConverting)
                                GestureDetector(
                                  onTap: () => _removeItem(item.path),
                                  child: Icon(Icons.close_rounded, size: 16, color: textTertiary),
                                ),
                            ]),
                            // Format selector
                            if (!isActive && !isDone) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 28,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: fmtOptions.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 5),
                                  itemBuilder: (context, fi) {
                                    final fmt = fmtOptions[fi];
                                    final selected = item.targetFormat == fmt;
                                    return GestureDetector(
                                      onTap: () => setState(() => item.targetFormat = fmt),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: selected ? AppColors.brandGradient : null,
                                          color: selected ? null : bgColor,
                                          borderRadius: BorderRadius.circular(7),
                                          border: Border.all(color: selected ? Colors.transparent : borderColor),
                                          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 5)] : null,
                                        ),
                                        child: Text(_fmtName(fmt),
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                            color: selected ? Colors.white : textTertiary)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            // Progress bar
                            if (isActive || isDone) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.progress,
                                  minHeight: 4,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDone ? AppColors.success : AppColors.primary),
                                ),
                              ),
                              if (isDone && item.outputPath != null) ...[
                                const SizedBox(height: 5),
                                Row(children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 11, color: AppColors.success),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(p.basename(item.outputPath!),
                                      style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  GestureDetector(
                                    onTap: () => Process.run('explorer.exe', ['/select,', item.outputPath!]),
                                    child: Text('Show', style: TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                              ],
                            ],
                            // Error msg
                            if (isError && item.errorMsg != null) ...[
                              const SizedBox(height: 5),
                              Text(item.errorMsg!, style: TextStyle(fontSize: 10, color: AppColors.error),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 40 * idx));
                    },
                  ),
          ),

          // Convert button
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: GestureDetector(
                onTap: canConvert ? _convertAll : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: canConvert ? AppColors.brandGradient : null,
                    color: canConvert ? null : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: canConvert ? [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: _isConverting
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Converting...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ])
                      : Text(
                          pendingCount == 0
                              ? 'All done  Add more files'
                              : 'Convert $pendingCount File${pendingCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: canConvert ? Colors.white
                                : (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                            fontWeight: FontWeight.w800, fontSize: 14,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
            ),
        ],
      ),
    );
  }
}

// Small button helper
class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}

// Batch item data model
class _BatchItem {
  final String path;
  final String name;
  final InputMediaType type;
  ConversionFormat targetFormat;
  String status;
  double progress;
  String? errorMsg;
  String? outputPath;

  _BatchItem({
    required this.path,
    required this.name,
    required this.type,
    required this.targetFormat,
    this.status = 'pending',
    this.progress = 0.0,
  });
}
