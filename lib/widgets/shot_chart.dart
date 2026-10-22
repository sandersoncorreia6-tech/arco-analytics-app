import 'package:flutter/material.dart';
import '../models/shot.dart';

class ShotChart extends StatelessWidget {
  final List<Shot> shots;
  const ShotChart({super.key, required this.shots});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: CustomPaint(
        painter: _ShotChartPainter(shots),
      ),
    );
  }
}

class _ShotChartPainter extends CustomPainter {
  final List<Shot> shots;
  _ShotChartPainter(this.shots);

  @override
  void paint(Canvas canvas, Size size) {
    final court = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final w = size.width;
    final h = size.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, w - 2, h - 2), const Radius.circular(12)), court);
    canvas.drawLine(Offset(0, h * .73), Offset(w, h * .73), court);
    canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, h * .73), width: w * .38, height: h * .33), 3.14159, 3.14159, false, court);
    canvas.drawRect(Rect.fromLTWH(w * .37, 0, w * .26, h * .28), court);
    canvas.drawCircle(Offset(w / 2, h * .12), w * .055, court);

    for (final shot in shots) {
      final center = Offset(shot.x * w, shot.y * h);
      final dot = Paint()
        ..color = shot.made ? Colors.greenAccent : Colors.redAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 6, dot);
      if (!shot.made) {
        final cross = Paint()..color = Colors.black87..strokeWidth = 1.5;
        canvas.drawLine(center + const Offset(-3, -3), center + const Offset(3, 3), cross);
        canvas.drawLine(center + const Offset(3, -3), center + const Offset(-3, 3), cross);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShotChartPainter oldDelegate) => oldDelegate.shots != shots;
}
