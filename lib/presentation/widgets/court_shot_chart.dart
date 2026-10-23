import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:arco_analytics/domain/analysis/shot_zones.dart';
import 'package:arco_analytics/domain/models/box_score.dart';

export 'package:arco_analytics/domain/analysis/shot_zones.dart';

enum ShotChartMode { points, zones }

/// Mapa de arremessos tático.
///
/// * Pontos: ● verde = cesta, ✕ vermelho = erro.
/// * Zonas: cada zona pintada pela eficiência (pontos por arremesso); zonas
///   com menos de [zoneMinAttempts] tentativas ficam cinza (amostra baixa).
///
/// [defense] inverte a leitura de cor: na defesa, zona "quente" é zona onde
/// o adversário pontua bem contra nós.
class CourtShotChart extends StatefulWidget {
  final List<ShotAttempt> shots;
  final bool showZones;
  final bool defense;
  const CourtShotChart({super.key, required this.shots, this.showZones = true, this.defense = false});

  @override
  State<CourtShotChart> createState() => _CourtShotChartState();
}

/// Referência de eficiência: ~1 ponto por arremesso de quadra.
const _goodPps = 1.1, _poorPps = 0.9;

Color zoneColor(ZoneSplit z, {bool defense = false}) {
  if (z.attempts < zoneMinAttempts) return Colors.white24;
  final good = z.pointsPerShot >= _goodPps, poor = z.pointsPerShot < _poorPps;
  if (good) return defense ? Colors.redAccent : Colors.greenAccent;
  if (poor) return defense ? Colors.greenAccent : Colors.redAccent;
  return Colors.amberAccent;
}

class _CourtShotChartState extends State<CourtShotChart> {
  ShotChartMode mode = ShotChartMode.points;

  @override
  Widget build(BuildContext context) {
    final shots = widget.shots;
    final made = shots.where((s) => s.made).length;
    final splits = zoneSplits(shots);
    final reading = ZoneReading.of(shots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showZones && shots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<ShotChartMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ShotChartMode.points, label: Text('Pontos'), icon: Icon(Icons.scatter_plot_outlined, size: 18)),
                ButtonSegment(value: ShotChartMode.zones, label: Text('Zonas'), icon: Icon(Icons.grid_view, size: 18)),
              ],
              selected: {mode},
              onSelectionChanged: (s) => setState(() => mode = s.first),
            ),
          ),
        AspectRatio(
          aspectRatio: courtWidthM / courtHeightM,
          child: CustomPaint(
            painter: _CourtPainter(
              shots: mode == ShotChartMode.points ? shots : const [],
              zones: mode == ShotChartMode.zones ? splits : const [],
              defense: widget.defense,
              accent: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if (mode == ShotChartMode.points) ...[
              const _Legend(color: Colors.greenAccent, label: 'Cesta', filled: true),
              const _Legend(color: Colors.redAccent, label: 'Erro', filled: false),
            ] else ...[
              _Legend(color: widget.defense ? Colors.redAccent : Colors.greenAccent, label: '≥ 1,1 pts/arr.', filled: true),
              const _Legend(color: Colors.amberAccent, label: '0,9–1,1', filled: true),
              _Legend(color: widget.defense ? Colors.greenAccent : Colors.redAccent, label: '< 0,9', filled: true),
              const _Legend(color: Colors.white24, label: 'amostra baixa', filled: true),
            ],
            Text(
              '${shots.length} arremessos • $made cestas • ${shots.isEmpty ? 0 : (made * 100 / shots.length).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        if (widget.showZones && shots.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ReadingText(reading: reading, defense: widget.defense),
          const SizedBox(height: 8),
          const _ZoneHeader(),
          for (final z in splits.where((z) => z.attempts > 0)) _ZoneRow(split: z, defense: widget.defense),
        ],
      ],
    );
  }
}

class _ReadingText extends StatelessWidget {
  final ZoneReading reading;
  final bool defense;
  const _ReadingText({required this.reading, required this.defense});

  @override
  Widget build(BuildContext context) {
    String pps(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    final used = reading.mostUsed;
    final parts = <String>[
      if (used != null) '${defense ? 'Mais cedida' : 'Mais usada'}: ${used.zone.short} (${used.share.toStringAsFixed(0)}% do volume)',
      if (reading.best != null)
        '${defense ? 'Onde mais sofre' : 'Mais eficiente'}: ${(defense ? reading.best! : reading.best!).zone.short} (${pps(reading.best!.pointsPerShot)} pts/arr.)',
      if (reading.worst != null)
        '${defense ? 'Onde melhor defende' : 'Menos eficiente'}: ${reading.worst!.zone.short} (${pps(reading.worst!.pointsPerShot)} pts/arr.)',
      if (reading.best == null) 'Amostra baixa para comparar zonas (mín. $zoneMinAttempts tentativas por zona).',
    ];
    return Text(parts.join('\n'), style: const TextStyle(fontSize: 12, height: 1.4));
  }
}

class _ZoneHeader extends StatelessWidget {
  const _ZoneHeader();
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 11, color: Colors.white54);
    return const Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text('Zona', style: st)),
          SizedBox(
            width: 46,
            child: Text('C/T', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 40,
            child: Text('%', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 44,
            child: Text('Volume', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 48,
            child: Text('Pts/arr', textAlign: TextAlign.right, style: st),
          ),
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final ZoneSplit split;
  final bool defense;
  const _ZoneRow({required this.split, required this.defense});

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 12);
    final low = split.attempts < zoneMinAttempts;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.square_rounded, size: 10, color: zoneColor(split, defense: defense)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(split.zone.short, overflow: TextOverflow.ellipsis, style: st),
          ),
          SizedBox(
            width: 46,
            child: Text('${split.made}/${split.attempts}', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 40,
            child: Text('${split.pct.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 44,
            child: Text('${split.share.toStringAsFixed(0)}%', textAlign: TextAlign.right, style: st),
          ),
          SizedBox(
            width: 48,
            child: Text(
              split.pointsPerShot.toStringAsFixed(2).replaceAll('.', ','),
              textAlign: TextAlign.right,
              style: st.copyWith(color: low ? Colors.white38 : null, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;
  const _Legend({required this.color, required this.label, required this.filled});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      filled ? Icon(Icons.circle, size: 10, color: color) : Icon(Icons.close, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

class _CourtPainter extends CustomPainter {
  final List<ShotAttempt> shots;
  final List<ZoneSplit> zones;
  final bool defense;
  final Color accent;
  _CourtPainter({required this.shots, required this.zones, required this.defense, required this.accent});

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

    if (zones.isNotEmpty) _paintZones(canvas, size);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);

    // Garrafão e lance livre.
    final keyRect = Rect.fromLTWH((courtWidthM - keyWidthM) / 2 * k, 0, keyWidthM * k, keyHeightM * k);
    if (zones.isEmpty) canvas.drawRect(keyRect, Paint()..color = accent.withValues(alpha: .07));
    canvas.drawRect(keyRect, line);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, keyHeightM), radius: 1.8 * k), 0, math.pi, false, line);

    // Linha de 3: retas nas zonas mortas (0,9 m da lateral) + arco de 6,75 m.
    final dx = courtWidthM / 2 - cornerLineM;
    final dy = math.sqrt(threeRadiusM * threeRadiusM - dx * dx);
    canvas.drawLine(p(cornerLineM, 0), p(cornerLineM, basketYM + dy), line);
    canvas.drawLine(p(courtWidthM - cornerLineM, 0), p(courtWidthM - cornerLineM, basketYM + dy), line);
    final start = math.atan2(dy, dx);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, basketYM), radius: threeRadiusM * k), start, math.pi - 2 * start, false, line);

    // Tabela, aro e área restrita.
    canvas.drawLine(p(courtWidthM / 2 - .9, 1.2), p(courtWidthM / 2 + .9, 1.2), line..strokeWidth = 2);
    line.strokeWidth = 1.4;
    canvas.drawCircle(p(courtWidthM / 2, basketYM), .225 * k, line);
    canvas.drawArc(Rect.fromCircle(center: p(courtWidthM / 2, basketYM), radius: restrictedRadiusM * k), 0, math.pi, false, line);

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

  /// Pinta cada zona com a cor da eficiência e escreve o aproveitamento no centro.
  void _paintZones(Canvas canvas, Size size) {
    const step = 0.25; // metros
    final byZone = {for (final z in zones) z.zone: z};
    final paints = {
      for (final z in zones)
        z.zone: Paint()..color = zoneColor(z, defense: defense).withValues(alpha: z.attempts == 0 ? .04 : .10 + .30 * (z.share / 100).clamp(0, 1)),
    };
    final sums = <ShotZone, (double, double, int)>{};
    final cw = step / courtWidthM * size.width, ch = step / courtHeightM * size.height;
    for (var y = 0.0; y < courtHeightM; y += step) {
      for (var x = 0.0; x < courtWidthM; x += step) {
        final nx = (x + step / 2) / courtWidthM, ny = (y + step / 2) / courtHeightM;
        final z = zoneAt(nx, ny);
        canvas.drawRect(Rect.fromLTWH(nx * size.width - cw / 2, ny * size.height - ch / 2, cw + .5, ch + .5), paints[z]!);
        final s = sums[z] ?? (0.0, 0.0, 0);
        sums[z] = (s.$1 + nx, s.$2 + ny, s.$3 + 1);
      }
    }
    // Centros visuais fixos para zonas de formato irregular.
    final anchors = <ShotZone, Offset>{
      ShotZone.rim: const Offset(.5, .07),
      ShotZone.corner3Left: const Offset(.03, .12),
      ShotZone.corner3Right: const Offset(.97, .12),
      ShotZone.aboveBreak3: const Offset(.5, .80),
    };
    for (final entry in sums.entries) {
      final z = byZone[entry.key];
      if (z == null || z.attempts == 0) continue;
      final c = anchors[entry.key] ?? Offset(entry.value.$1 / entry.value.$3, entry.value.$2 / entry.value.$3);
      final tp = TextPainter(
        text: TextSpan(
          text: '${z.made}/${z.attempts}',
          style: TextStyle(fontSize: math.max(9, size.width / 34), fontWeight: FontWeight.w800, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var o = Offset(c.dx * size.width - tp.width / 2, c.dy * size.height - tp.height / 2);
      o = Offset(o.dx.clamp(2, size.width - tp.width - 2), o.dy.clamp(2, size.height - tp.height - 2));
      tp.paint(canvas, o);
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter old) => old.shots != shots || old.zones != zones || old.defense != defense || old.accent != accent;
}
