import 'dart:math';
import 'package:flutter/material.dart';

/// Cercle rempli d'eau avec des vagues animées. [progress] va de 0 à 1.
class WaterWave extends StatefulWidget {
  final double progress;
  final double size;
  const WaterWave({super.key, required this.progress, this.size = 260});

  @override
  State<WaterWave> createState() => _WaterWaveState();
}

class _WaterWaveState extends State<WaterWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, level, _) {
        return AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            size: Size.square(widget.size),
            painter: _WavePainter(
              level: level,
              phase: _c.value * 2 * pi,
              water: scheme.primary,
              background: scheme.surface.withValues(alpha: 0.6),
              border: scheme.primary.withValues(alpha: 0.35),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double level;
  final double phase;
  final Color water;
  final Color background;
  final Color border;

  _WavePainter({
    required this.level,
    required this.phase,
    required this.water,
    required this.background,
    required this.border,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r));

    canvas.drawPath(circle, Paint()..color = background);

    canvas.save();
    canvas.clipPath(circle);

    final lvl = level.clamp(0.0, 1.0);
    final top = size.height * (1 - lvl);
    final amplitude = (lvl <= 0.0 || lvl >= 1.0) ? 0.0 : 8.0;

    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = top +
            sin((x / size.width * 2 * pi) + phase + layer * 1.6) * amplitude;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = water.withValues(alpha: layer == 0 ? 0.5 : 0.85),
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.water != water ||
      old.background != background ||
      old.border != border;
}