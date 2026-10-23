import 'dart:math' as math;

import 'package:arco_analytics/domain/models/box_score.dart';

/// Zonas táticas da meia quadra (vista do ataque, cesta no topo do mapa).
enum ShotZone { rim, paint, midLeft, midRight, corner3Left, corner3Right, aboveBreak3 }

extension ShotZoneLabel on ShotZone {
  String get label => switch (this) {
    ShotZone.rim => 'Aro (área restrita)',
    ShotZone.paint => 'Garrafão',
    ShotZone.midLeft => 'Meia distância esquerda',
    ShotZone.midRight => 'Meia distância direita',
    ShotZone.corner3Left => '3 do canto esquerdo',
    ShotZone.corner3Right => '3 do canto direito',
    ShotZone.aboveBreak3 => '3 frontal',
  };

  /// Rótulo curto para tabelas em tela de celular.
  String get short => switch (this) {
    ShotZone.rim => 'Aro',
    ShotZone.paint => 'Garrafão',
    ShotZone.midLeft => 'Média esq.',
    ShotZone.midRight => 'Média dir.',
    ShotZone.corner3Left => 'Canto 3 esq.',
    ShotZone.corner3Right => 'Canto 3 dir.',
    ShotZone.aboveBreak3 => '3 frontal',
  };

  bool get isThree => this == ShotZone.corner3Left || this == ShotZone.corner3Right || this == ShotZone.aboveBreak3;

  /// Valor do arremesso convertido nesta zona.
  int get value => isThree ? 3 : 2;
}

// Medidas FIBA em metros, meia quadra 15 × 14 m, cesta no topo.
const courtWidthM = 15.0;
const courtHeightM = 14.0;
const basketYM = 1.575;
const keyWidthM = 4.9;
const keyHeightM = 5.8;
const restrictedRadiusM = 1.25;

/// Distância do arremesso até a cesta, em metros.
double distanceOf(ShotAttempt s) => math.sqrt(math.pow(s.x * courtWidthM - courtWidthM / 2, 2) + math.pow(s.y * courtHeightM - basketYM, 2));

ShotZone zoneOf(ShotAttempt s) {
  final x = s.x * courtWidthM, y = s.y * courtHeightM;
  final left = x < courtWidthM / 2;
  if (s.isThree) {
    if (y < 3.0) return left ? ShotZone.corner3Left : ShotZone.corner3Right;
    return ShotZone.aboveBreak3;
  }
  if (distanceOf(s) <= restrictedRadiusM) return ShotZone.rim;
  final inKey = (x - courtWidthM / 2).abs() <= keyWidthM / 2 && y <= keyHeightM;
  if (inKey) return ShotZone.paint;
  return left ? ShotZone.midLeft : ShotZone.midRight;
}

/// Linha de 3 FIBA: retas a 0,9 m da lateral até cruzar o arco de 6,75 m.
const threeRadiusM = 6.75;
const cornerLineM = 0.9;

/// Ponto (em metros) atrás da linha de 3?
bool isThreeAt(double x, double y) {
  final dx = courtWidthM / 2 - cornerLineM;
  final cornerEnd = basketYM + math.sqrt(threeRadiusM * threeRadiusM - dx * dx);
  if (y <= cornerEnd) return x < cornerLineM || x > courtWidthM - cornerLineM;
  return math.sqrt(math.pow(x - courtWidthM / 2, 2) + math.pow(y - basketYM, 2)) > threeRadiusM;
}

/// Zona de um ponto da quadra (normalizado 0–1), usada para pintar o mapa.
ShotZone zoneAt(double nx, double ny) => zoneOf(ShotAttempt(x: nx, y: ny, made: false, points: isThreeAt(nx * courtWidthM, ny * courtHeightM) ? 3 : 2));

/// Lado da quadra do ponto de vista do ataque (x < 0,4 esquerda, > 0,6 direita).
String sideOf(ShotAttempt s) => s.x < .4 ? 'esquerdo' : (s.x > .6 ? 'direito' : 'central');

/// Volume e eficiência de uma zona.
class ZoneSplit {
  final ShotZone zone;
  final int made;
  final int attempts;

  /// Total de arremessos do conjunto (para calcular a fatia de volume).
  final int total;
  const ZoneSplit(this.zone, this.made, this.attempts, this.total);

  double get pct => attempts == 0 ? 0 : made * 100 / attempts;
  double get share => total == 0 ? 0 : attempts * 100 / total;

  /// Pontos por arremesso (o que de fato importa para escolher zonas).
  double get pointsPerShot => attempts == 0 ? 0 : made * zone.value / attempts;
}

List<ZoneSplit> zoneSplits(List<ShotAttempt> shots) {
  final made = {for (final z in ShotZone.values) z: 0};
  final att = {for (final z in ShotZone.values) z: 0};
  for (final s in shots) {
    final z = zoneOf(s);
    att[z] = att[z]! + 1;
    if (s.made) made[z] = made[z]! + 1;
  }
  return [for (final z in ShotZone.values) ZoneSplit(z, made[z]!, att[z]!, shots.length)];
}

/// Mínimo de tentativas para tirar conclusão de uma zona.
const zoneMinAttempts = 5;

/// Leitura tática do mapa: zona mais usada, mais eficiente e mais fraca
/// (só zonas com amostra mínima entram em "melhor" e "pior").
class ZoneReading {
  final ZoneSplit? mostUsed;
  final ZoneSplit? best;
  final ZoneSplit? worst;
  final double pointsPerShot;
  const ZoneReading(this.mostUsed, this.best, this.worst, this.pointsPerShot);

  static ZoneReading of(List<ShotAttempt> shots) {
    final splits = zoneSplits(shots).where((z) => z.attempts > 0).toList();
    if (splits.isEmpty) return const ZoneReading(null, null, null, 0);
    final pts = shots.where((s) => s.made).fold<int>(0, (t, s) => t + (s.points == 3 ? 3 : 2));
    final sample = splits.where((z) => z.attempts >= zoneMinAttempts).toList()..sort((a, b) => b.pointsPerShot.compareTo(a.pointsPerShot));
    return ZoneReading(
      splits.reduce((a, b) => b.attempts > a.attempts ? b : a),
      sample.length >= 2 ? sample.first : null,
      sample.length >= 2 ? sample.last : null,
      pts / shots.length,
    );
  }
}
