import 'package:arco_analytics/domain/models/box_score.dart';

/// Zonas de arremesso usadas no resumo do mapa.
enum ShotZone { paint, midRange, corner3, aboveBreak3 }

extension ShotZoneLabel on ShotZone {
  String get label => switch (this) {
    ShotZone.paint => 'Garrafão',
    ShotZone.midRange => 'Meia distância',
    ShotZone.corner3 => '3 da zona morta',
    ShotZone.aboveBreak3 => '3 frontal',
  };
}

// Medidas FIBA em metros, meia quadra 15 × 14 m, cesta no topo.
const courtWidthM = 15.0;
const courtHeightM = 14.0;
const basketYM = 1.575;
const keyWidthM = 4.9;
const keyHeightM = 5.8;

ShotZone zoneOf(ShotAttempt s) {
  final x = s.x * courtWidthM, y = s.y * courtHeightM;
  if (s.isThree) return y < 3.0 ? ShotZone.corner3 : ShotZone.aboveBreak3;
  final inKey = (x - courtWidthM / 2).abs() <= keyWidthM / 2 && y <= keyHeightM;
  return inKey ? ShotZone.paint : ShotZone.midRange;
}

/// Lado da quadra do ponto de vista do ataque (x < 0,4 esquerda, > 0,6 direita).
String sideOf(ShotAttempt s) => s.x < .4 ? 'esquerdo' : (s.x > .6 ? 'direito' : 'central');
