import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated background supporting the user's custom GIFs in assets/images/backgrounds/
/// Rendered with dual-layer ambient fill to prevent pixelation without over-zooming:
/// - Background Layer: Ambient blurred fill (ImageFilter.blur) filling 100% of the screen seamlessly.
/// - Foreground Layer: Crisp unzoomed/proportional GIF with smooth feathered gradient fades.
class TranquilAnimatedBackground extends StatefulWidget {
  final Widget child;
  final int? initialIndex;

  const TranquilAnimatedBackground({
    super.key,
    required this.child,
    this.initialIndex,
  });

  @override
  State<TranquilAnimatedBackground> createState() => TranquilAnimatedBackgroundState();
}

class TranquilAnimatedBackgroundState extends State<TranquilAnimatedBackground> {
  // Safe default assets matching the user's curated GIFs
  static final List<String> defaultBackgroundAssets = [
    'assets/images/backgrounds/water_night.gif',
    'assets/images/backgrounds/paradise_sunset.gif',
    'assets/images/backgrounds/night_community.gif',
    'assets/images/backgrounds/moon_ocean.gif',
    'assets/images/backgrounds/moon_river.gif',
    'assets/images/backgrounds/eg_night.gif',
    'assets/images/backgrounds/palm_tree_water.gif',
    'assets/images/backgrounds/Water Night GIF.gif',
    'assets/images/backgrounds/Paradise Beach Sunset GIF.gif',
    'assets/images/backgrounds/Night Community GIF.gif',
  ];

  late List<String> _backgrounds;
  late int _currentIndex;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _backgrounds = List.from(defaultBackgroundAssets);
    _currentIndex = widget.initialIndex ?? _random.nextInt(_backgrounds.length);
    _discoverAllBackgroundAssets();
  }

  /// Dynamically discover any GIF files inside assets/images/backgrounds/
  Future<void> _discoverAllBackgroundAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = manifest
          .listAssets()
          .where((key) =>
              key.startsWith('assets/images/backgrounds/') &&
              key.toLowerCase().endsWith('.gif'))
          .toSet()
          .toList();

      if (discovered.isNotEmpty && mounted) {
        setState(() {
          _backgrounds = discovered;
          _currentIndex = _currentIndex % _backgrounds.length;
        });
      }
    } catch (_) {
      // Fallback safely to defaultBackgroundAssets
    }
  }

  /// Switch to a new random background different from the current one
  void nextRandomBackground() {
    if (_backgrounds.isEmpty) return;
    int next;
    if (_backgrounds.length == 1) {
      next = 0;
    } else {
      do {
        next = _random.nextInt(_backgrounds.length);
      } while (next == _currentIndex);
    }

    setState(() {
      _currentIndex = next;
    });
  }

  /// Set a specific background index
  void setBackground(int index) {
    if (index >= 0 && index < _backgrounds.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  int get totalBackgrounds => _backgrounds.length;
  int get currentBackgroundNumber => _currentIndex + 1;
  String get currentAssetPath => _backgrounds.isNotEmpty ? _backgrounds[_currentIndex] : '';

  @override
  Widget build(BuildContext context) {
    final String currentAsset = _backgrounds.isNotEmpty
        ? _backgrounds[_currentIndex]
        : 'assets/images/tranquil_sea.gif';

    return Stack(
      children: [
        // Base dark container
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF070B19)),
        ),

        // 1. Ambient Background Layer:
        // Heavily blurred (sigma 35) full-screen fill that reflects the exact live colors and motion
        // of the GIF across the entire screen without any pixelation or visible pixel blocks.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: ClipRect(
              key: ValueKey<String>('ambient_$currentAsset'),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                child: Transform.scale(
                  scale: 1.15, // Prevents border blur artifacts
                  child: Image.asset(
                    currentAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.low, // Lower quality is fine and faster when heavily blurred
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF070B19),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Soft Atmospheric Dark Wash (enhances contrast & tranquil depth)
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.35),
          ),
        ),

        // 3. Foreground Unzoomed Crisp GIF Layer:
        // Rendered with BoxFit.contain and FilterQuality.high so the GIF is NEVER stretched or zoomed in.
        // It keeps its native sharp pixel density and smooth motion.
        // Wrapped with a ShaderMask so the top and bottom borders smoothly dissolve into the ambient backdrop.
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 900),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: Center(
              key: ValueKey<String>('crisp_$currentAsset'),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.12, 0.88, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  currentAsset,
                  fit: BoxFit.contain, // Fits proportionally without zoom, keeping maximum crispness
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  width: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/tranquil_sea.gif',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // 4. Subtle Vignette & Gradient for text/controls legibility
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.40),
                  Colors.transparent,
                  Colors.black.withOpacity(0.65),
                ],
                stops: const [0.0, 0.40, 1.0],
              ),
            ),
          ),
        ),

        // 5. Child content (visualizer wave, sheikh circle, playback controls)
        widget.child,
      ],
    );
  }
}
