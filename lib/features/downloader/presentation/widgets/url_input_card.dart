import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

class UrlInputCard extends StatefulWidget {
  final Function(String url) onSubmit;
  final bool isLoading;

  const UrlInputCard({super.key, required this.onSubmit, this.isLoading = false});

  @override
  State<UrlInputCard> createState() => _UrlInputCardState();
}

class _UrlInputCardState extends State<UrlInputCard> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isValid = false;
  bool _hasInteracted = false;
  String? _detectedPlatform;

  static const _supportedHosts = [
    'youtube.com', 'youtu.be',
    'tiktok.com', 'vm.tiktok.com',
    'facebook.com', 'fb.watch',
    'instagram.com',
    'twitter.com', 'x.com', 't.co',
    'vimeo.com',
    'dailymotion.com',
  ];

  String? _detectPlatform(String text) {
    if (text.contains('youtube.com') || text.contains('youtu.be')) return 'YouTube';
    if (text.contains('tiktok.com') || text.contains('vm.tiktok.com')) return 'TikTok';
    if (text.contains('facebook.com') || text.contains('fb.watch')) return 'Facebook';
    if (text.contains('instagram.com')) return 'Instagram';
    if (text.contains('twitter.com') || text.contains('x.com') || text.contains('t.co')) return 'Twitter/X';
    if (text.contains('vimeo.com')) return 'Vimeo';
    if (text.contains('dailymotion.com')) return 'Dailymotion';
    return null;
  }

  bool _isSupportedUrl(String text) => _supportedHosts.any((h) => text.contains(h));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(() => setState(() {}));
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    if (_controller.text.isNotEmpty) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (_isSupportedUrl(text)) {
      if (!mounted) return;
      setState(() {
        _controller.text = text;
        _validateUrl(text);
      });
      if (_isValid && !widget.isLoading) widget.onSubmit(text);
    }
  }

  void _validateUrl(String text) {
    setState(() {
      _hasInteracted = true;
      _isValid = _isSupportedUrl(text);
      _detectedPlatform = _detectPlatform(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Hero Header ───────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.heroGradient
                : const LinearGradient(
                    colors: [Color(0xFFFFF0F5), Color(0xFFF8F0FF), Color(0xFFFFF0F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // YouTube-style logo row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
                      child: Text(
                        'Zylos',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),

                const SizedBox(height: 8),
                Text(
                  'Download from YouTube, TikTok, Facebook, Instagram & more',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 24),

                // ── Search / URL Input ────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppColors.primary
                          : _hasInteracted && !_isValid && _controller.text.isNotEmpty
                              ? AppColors.error
                              : isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                      width: _focusNode.hasFocus ? 2.0 : 1.0,
                    ),
                    boxShadow: _focusNode.hasFocus
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.link_rounded,
                        color: _focusNode.hasFocus
                            ? AppColors.primary
                            : isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                        size: 20,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _validateUrl,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            fontSize: 14,
                          ),
                          onSubmitted: (val) {
                            if (_isValid) {
                              FocusScope.of(context).unfocus();
                              widget.onSubmit(val);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Paste a video URL (YouTube, TikTok, FB…)',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                          ),
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() {
                              _isValid = false;
                              _hasInteracted = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () async {
                          final focusScope = FocusScope.of(context);
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _controller.text = data!.text!;
                            _validateUrl(data.text!);
                            if (_isValid && !widget.isLoading) {
                              if (mounted) {
                                focusScope.unfocus();
                                widget.onSubmit(data.text!);
                              }
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ).animate(target: _controller.text.isEmpty ? 1 : 0).fade(),
                      const SizedBox(width: 4),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1, end: 0),

                // ── Validation / Loading / Fetch Button ───────────
                if (widget.isLoading) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 4,
                    ),
                  ).animate().fadeIn(),
                  const SizedBox(height: 10),
                  Text(
                    'Fetching video info...',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (_hasInteracted && !_isValid && _controller.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        'Please enter a valid YouTube URL',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().shakeX(hz: 3, amount: 3),
                ] else if (_isValid) ...[
                  const SizedBox(height: 18),
                  _GradientButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      widget.onSubmit(_controller.text);
                    },
                    label: 'Fetch Video Info',
                    icon: Icons.search_rounded,
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _GradientButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
