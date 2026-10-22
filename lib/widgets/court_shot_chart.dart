import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/shot_zones.dart';
import '../models/box_score.dart';

export '../analysis/shot_zones.dart';

/// Mapa de arremessos: ● verde = cesta, ✕ vermelho = erro.
class CourtShotChart extends StatelessWidget {
  final List<ShotAttempt> shots;
  final bool showZones;
  const CourtShotChart({super.key, required this.shots, this.showZones = true});

  @override
  Widget build(BuildContext context) {
    final made = shots.where((s) => s.made).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: courtWidthM / courtHeightM,
        child: CustomPaint(painter: _CourtPainter(shots, Theme.of(context).colorScheme.primary)),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        const _Legend(color: Colors.greenAccent, label: 'Cesta', filled: true),
        const _Legend(color: Colors.redAccent, label: 'Erro', filled: false),
        Text('${shots.length} arremessos • $made cestas • ${shots.isEmpty ? 0 : (made * 100 / shots.length).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
      if (showZones && shots.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final zone in ShotZone.values) _ZoneRow(zone: zone, shots: shots.where((s) => zoneOf(s) == zone).toList()),
      ],
    ]);
  }
}

class _ZoneRow extends StatelessWidget {
  final ShotZone zone;
  final List<ShotAttempt> shots;
  const _ZoneRow({required this.zone, required this.shots});

  @override
  Widget build(BuildContext context) {
    final made = shots.where((s) => s.made).length;
    final pct = shots.isEmpty ? 0.0 : made / shots.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(zone.label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white10),
          ),
        ),
        SizedBox(
          width: 86,
          child: Text('$made/${shots.length} • ${(pct * 100).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;
  const _Legend({required this.color, required this.label, required this.filled});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        filled ? Icon(Icons.circle, size: 10, color: color) : Icon(Icons.close, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]);
}

class _CourtPainter extends CustomPainter {
  final List<ShotAttempt> shots;
  final Color accent;
  _CourtPainter(this.shots, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / courtWidthM;
    Offset p(double x, double y) => Offset(x * k, y * k);
    final line = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final floor = Paint()..color = Colors.white.withValues(alpha: .03);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), floor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);

    // Garrafão e lance livre.
    final keyRect = Rect.fromLTWH((courtWidthM - keyWidthM) / 2 * k, 0, keyWidthM * k, keyHeightM * k);
    canvas.drawRect(keyRect, Paint()..color = accent.withValues(alpha: .07));
    canvas.drawRect(keyRect, line);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, keyHeightM), radius: 1.8 * k), 0, math.pi, false, line);

    // Linha de 3: retas nas zonas mortas (0,9 m da lateral) + arco de 6,75 m.
    const r3 = 6.75;
    const side = 0.9;
    final dx = courtWidthM / 2 - side;
    final dy = math.sqrt(r3 * r3 - dx * dx);
    canvas.drawLine(p(side, 0), p(side, basketYM + dy), line);
    canvas.drawLine(p(courtWidthM - side, 0), p(courtWidthM - side, basketYM + dy), line);
    final start = math.atan2(dy, dx);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, basketYM), radius: r3 * k), start, math.pi - 2 * start, false, line);

    // Tabela, aro e área restrita.
    canvas.drawLine(p(courtWidthM / 2 - .9, 1.2), p(courtWidthM / 2 + .9, 1.2), line..strokeWidth = 2);
    line.strokeWidth = 1.4;
    canvas.drawCircle(p(courtWidthM / 2, basketYM), .225 * k, line);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, basketYM), radius: 1.25 * k), 0, math.pi, false, line);

    // Meio da quadra.
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, courtHeightM), radius: 1.8 * k), math.pi, math.pi, false, line);

    final r = math.max(3.0, size.width / 95);
    final made = Paint()..color = Colors.greenAccent.withValues(alpha: .85);
    final ring = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final miss = Paint()
      ..color = Colors.redAccent.withValues(alpha: .85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final s in shots.where((s) => !s.made)) {
      final c = Offset(s.x * size.width, s.y * size.height);
      canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), miss);
      canvas.drawLine(c + Offset(r, -r), c + Offset(-r, r), miss);
    }
    for (final s in shots.where((s) => s.made)) {
      final c = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(c, r, made);
      canvas.drawCircle(c, r, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter old) => old.shots != shots || old.accent != accent;
}
