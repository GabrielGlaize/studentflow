import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Logo Swikko : un « S » fait de deux flèches courbes qui se répondent
/// (école ⇄ entreprise). Même dessin que l'icône de l'app
/// (`design/app-icon/draw_swikko_logo.py`), en vectoriel.
class SwikkoLogo extends StatelessWidget {
  const SwikkoLogo({this.size = 34, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C4A5E), Color(0xFF052D3A)],
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: CustomPaint(painter: _SwikkoMarkPainter()),
    );
  }
}

class _SwikkoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Repère du dessin d'origine : 1024 x 1024.
    final k = size.width / 1024;
    const radius = 190.0;
    const width = 118.0;
    _arrowArc(
      canvas,
      k,
      center: const Offset(512, 512 - radius + width / 2),
      start: 90,
      end: 335,
      color: AppColors.mint,
    );
    _arrowArc(
      canvas,
      k,
      center: const Offset(512, 512 + radius - width / 2),
      start: 270,
      end: 515,
      color: AppColors.sky,
    );
  }

  void _arrowArc(
    Canvas canvas,
    double k, {
    required Offset center,
    required double start,
    required double end,
    required Color color,
  }) {
    const radius = 190.0;
    const width = 118.0;
    const head = 1.15 * width;
    final stop = end - (head * 0.55 / radius) * 180 / math.pi;
    final midRadius = radius - width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * k;

    final rect = Rect.fromCircle(center: center * k, radius: midRadius * k);
    canvas.drawArc(
      rect,
      start * math.pi / 180,
      (stop - start) * math.pi / 180,
      false,
      paint,
    );

    final a = stop * math.pi / 180;
    final base = center + Offset(math.cos(a), math.sin(a)) * midRadius;
    final tangent = Offset(-math.sin(a), math.cos(a));
    final normal = Offset(math.cos(a), math.sin(a));
    final tip = base + tangent * head * 1.05;
    final left = base + normal * head * 0.95;
    final right = base - normal * head * 0.95;
    canvas.drawPath(
      Path()
        ..moveTo(left.dx * k, left.dy * k)
        ..lineTo(tip.dx * k, tip.dy * k)
        ..lineTo(right.dx * k, right.dy * k)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SwikkoMarkPainter oldDelegate) => false;
}
