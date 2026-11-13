import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/sheikh_image_service.dart';

/// Central visualizer with Sheikh portrait or Holy Quran calligraphy icon.
/// Surrounded by calm, smooth, organic glowing audio wave ripples.
class AudioPulsingVisualizer extends StatefulWidget {
  final String reciterName;
  final bool isPlaying;
  final double circleDiameter;

  const AudioPulsingVisualizer({
    super.key,
    required this.reciterName,
    required this.isPlaying,
    this.circleDiameter = 138, // Compact elegant diameter
  });

  @override
  State<AudioPulsingVisualizer> createState() => _AudioPulsingVisualizerState();
}

class _AudioPulsingVisualizerState extends State<AudioPulsingVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  File? _localImageFile;
  bool _isLoadingImage = false;
  SheikhImageService? get _sheikhService =>
      Get.isRegistered<SheikhImageService>() ? Get.find<SheikhImageService>() : null;

  @override
  void initState() {
    super.initState();

    // Slow, serene breathing animation (3.2 seconds loop for ultimate calmness)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (widget.isPlaying) {
      _waveController.repeat();
    }

    _loadSheikhImage();
  }

  @override
  void didUpdateWidget(covariant AudioPulsingVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_waveController.isAnimating) _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }

    if (widget.reciterName != oldWidget.reciterName) {
      _loadSheikhImage();
    }
  }

  Future<void> _loadSheikhImage() async {
    final service = _sheikhService;
    if (service != null && widget.reciterName.isNotEmpty) {
      // 1. Check local storage first (instant offline read)
      File? file = await service.getLocalCachedImage(widget.reciterName);

      // 2. If not found in local storage, attempt to fetch from known sources
      if (file == null && service.getKnownImageUrl(widget.reciterName) != null) {
        file = await service.cacheSheikhImage(widget.reciterName);
      }

      if (mounted) {
        setState(() {
          _localImageFile = file;
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxBounds = widget.circleDiameter + 85;

    return SizedBox(
      width: maxBounds,
      height: maxBounds,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Serene, smooth audio waves (Concentric organic ripples)
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(maxBounds, maxBounds),
                painter: _SereneAudioWavesPainter(
                  progress: _waveController.value,
                  isPlaying: widget.isPlaying,
                  baseRadius: widget.circleDiameter / 2,
                ),
              );
            },
          ),

          // 2. Central Circular Avatar (Compact & Elegant)
          Container(
            width: widget.circleDiameter,
            height: widget.circleDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(widget.isPlaying ? 0.40 : 0.20),
                  blurRadius: widget.isPlaying ? 24 : 12,
                  spreadRadius: widget.isPlaying ? 3 : 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.9), // Gold metallic border
                width: 3.0,
              ),
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (_localImageFile != null && _localImageFile!.existsSync()) {
      return Image.file(
        _localImageFile!,
        fit: BoxFit.cover,
        width: widget.circleDiameter,
        height: widget.circleDiameter,
        errorBuilder: (_, __, ___) => _buildQuranCalligraphyBadge(),
      );
    }

    if (_isLoadingImage) {
      return Container(
        color: const Color(0xFF0F1E24),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
          ),
        ),
      );
    }

    // Default: Exquisite Holy Quran Calligraphy Emblem
    return _buildQuranCalligraphyBadge();
  }

  /// Holy Quran Icon with beautiful Arabic typography and gold ornament
  Widget _buildQuranCalligraphyBadge() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF1B382F),
            Color(0xFF0A1813),
            Color(0xFF030A08),
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Golden Decorative Quran Book Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withOpacity(0.12),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.45),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 28,
                color: Color(0xFFE5C07B),
              ),
            ),
            const SizedBox(height: 6),
            // Calligraphy Text: "القرآن الكريم"
            const Text(
              'القرآن الكريم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                color: Color(0xFFFDE68A),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Color(0xFFD4AF37),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Smooth, calm, and harmonious concentric sound ripple waves
class _SereneAudioWavesPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double baseRadius;

  _SereneAudioWavesPainter({
    required this.progress,
    required this.isPlaying,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    if (!isPlaying) {
      // Subtle static ambient halo when paused
      final Paint calmPaint = Paint()
        ..color = const Color(0xFFD4AF37).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, baseRadius + 8, calmPaint);
      return;
    }

    // 3 harmonic, smooth wave rings expanding gently
    const int waveCount = 3;
    const double maxWaveExpansion = 38.0;

    for (int i = 0; i < waveCount; i++) {
      final double waveProgress = (progress + (i / waveCount)) % 1.0;
      final double currentRadius = baseRadius + (waveProgress * maxWaveExpansion);

      // Smooth sine curve for natural fade-in and fade-out
      final double alpha = math.sin(waveProgress * math.pi) * 0.38;

      final Paint wavePaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(alpha * 0.7) // Calm celestial cyan wave
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * (1.0 - (waveProgress * 0.4));

      canvas.drawCircle(center, currentRadius, wavePaint);

      // Subtle golden inner glow wave
      final Paint innerGlowPaint = Paint()
        ..color = const Color(0xFFD4AF37).withOpacity(alpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawCircle(center, currentRadius - 3, innerGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SereneAudioWavesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying;
  }
}
