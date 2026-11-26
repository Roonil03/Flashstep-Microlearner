import 'package:flutter/material.dart';

/// Original blank-card illustration, rendered with fogleman/ln at design time.
///
/// The geometry is the hidden-line output of three offset thin card cuboids.
/// Upstream renderer: github.com/fogleman/ln, commit
/// 12e6c6e7445909f817f1b8d5581be4255ffa1437. No renderer runs in the app.
class LnStudyCardsIllustration extends StatelessWidget {
  const LnStudyCardsIllustration({super.key, this.width = 184, this.color})
    : assert(width > 0);

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 320 / 220,
          child: CustomPaint(
            painter: _LnStudyCardsPainter(
              color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LnStudyCardsPainter extends CustomPainter {
  const _LnStudyCardsPainter(this.color);

  final Color color;

  // Each disconnected segment preserves the renderer's occlusion boundaries.
  static final Path _outline =
      Path()
        ..moveTo(14.35, 103.85)
        ..lineTo(14.00, 101.39)
        ..moveTo(14.35, 103.85)
        ..lineTo(137.56, 152.25)
        ..moveTo(14.00, 101.39)
        ..lineTo(26.56, 90.56)
        ..moveTo(54.38, 66.59)
        ..lineTo(91.56, 34.55)
        ..moveTo(14.00, 101.39)
        ..lineTo(121.79, 143.57)
        ..moveTo(91.56, 34.55)
        ..lineTo(103.80, 38.62)
        ..moveTo(261.23, 90.99)
        ..lineTo(276.25, 95.98)
        ..moveTo(275.90, 98.51)
        ..lineTo(275.95, 98.43)
        ..moveTo(274.72, 98.05)
        ..lineTo(276.25, 95.98)
        ..moveTo(275.95, 98.43)
        ..lineTo(276.25, 95.98)
        ..moveTo(26.84, 91.84)
        ..lineTo(26.52, 89.32)
        ..moveTo(26.84, 91.84)
        ..lineTo(136.97, 151.83)
        ..moveTo(26.52, 89.32)
        ..lineTo(32.95, 85.11)
        ..moveTo(102.63, 39.46)
        ..lineTo(119.01, 28.73)
        ..moveTo(26.52, 89.32)
        ..lineTo(110.85, 135.07)
        ..moveTo(119.01, 28.73)
        ..lineTo(120.47, 29.39)
        ..moveTo(287.50, 104.70)
        ..lineTo(296.74, 108.87)
        ..moveTo(296.44, 109.16)
        ..lineTo(296.74, 108.87)
        ..moveTo(296.67, 109.38)
        ..lineTo(296.74, 108.87)
        ..moveTo(29.96, 83.13)
        ..lineTo(29.64, 80.52)
        ..moveTo(29.96, 83.13)
        ..lineTo(206.84, 196.66)
        ..moveTo(29.64, 80.52)
        ..lineTo(131.35, 23.34)
        ..moveTo(29.64, 80.52)
        ..lineTo(207.00, 193.91)
        ..moveTo(131.35, 23.34)
        ..lineTo(306.00, 114.36)
        ..moveTo(206.84, 196.66)
        ..lineTo(207.00, 193.91)
        ..moveTo(206.84, 196.66)
        ..lineTo(305.59, 117.02)
        ..moveTo(207.00, 193.91)
        ..lineTo(306.00, 114.36)
        ..moveTo(305.59, 117.02)
        ..lineTo(306.00, 114.36);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.width / 320;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _outline,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LnStudyCardsPainter oldDelegate) =>
      oldDelegate.color != color;
}
