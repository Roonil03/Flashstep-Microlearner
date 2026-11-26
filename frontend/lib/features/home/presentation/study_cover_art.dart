import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small screen print, drawn in its own area so it never obscures real data.
class StudyCoverArt extends StatelessWidget {
  const StudyCoverArt({super.key});

  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: CustomPaint(painter: _StudyCoverPainter()));
}

class _StudyCoverPainter extends CustomPainter {
  const _StudyCoverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 180, size.height / 210);
    canvas.save();
    canvas.translate(
      (size.width - 180 * scale) / 2,
      (size.height - 210 * scale) / 2,
    );
    canvas.scale(scale);

    const orange = Color(0xFFFF9557);
    const cream = Color(0xFFFFF4DC);
    const petrol = Color(0xFF123F43);
    final ink = Paint()..color = orange;

    // Each pass shifts slightly, like bands printed from separate blocks.
    for (var band = 0; band < 5; band++) {
      final top = 8.0 + band * 27;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, top, 180, 22));
      canvas.drawCircle(Offset(band.isEven ? 94 : 103, 74), 66, ink);
      canvas.restore();
    }

    void card(Offset origin, double angle, Color paper) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        const Rect.fromLTWH(-51, -34, 102, 68),
        Paint()..color = paper,
      );
      final rule =
          Paint()
            ..color = petrol
            ..strokeWidth = 3;
      canvas.drawLine(const Offset(-36, -15), const Offset(-7, -15), rule);
      rule.strokeWidth = 1.5;
      canvas.drawLine(const Offset(-36, 6), const Offset(34, 6), rule);
      canvas.drawLine(const Offset(-36, 17), const Offset(22, 17), rule);
      canvas.restore();
    }

    card(const Offset(72, 137), -.19, const Color(0xFFE2D7B9));
    card(const Offset(109, 166), .12, cream);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StudyCoverPainter oldDelegate) => false;
}
