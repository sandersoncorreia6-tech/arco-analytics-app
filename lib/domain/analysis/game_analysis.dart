import 'package:arco_analytics/domain/models/box_score.dart';
import 'package:arco_analytics/domain/analysis/shot_zones.dart';

enum FindingLevel { positive, neutral, warning, critical }

/// Uma conclusão do Analista ARCO, sempre com a evidência numérica.
class Finding {
  final String title;
  final String detail;
  final FindingLevel level;

  /// Pontos estimados ganhos/perdidos por este fator (quando faz sentido).
  final double? points;
  const Finding(this.title, this.detail, {this.level = FindingLevel.neutral, this.points});
}

/// Cenário "e se": quantos pontos a mais e se mudaria o resultado.
class WhatIf {
  final String title;
  final String detail;
  final int extraPoints;
  final bool flipsResult;
  const WhatIf(this.title, this.detail, this.extraPoints, this.flipsResult);
}

String p0(double v) => '${v.toStringAsFixed(0)}%';
String p1(double v) => '${v.toStringAsFixed(1)}%';
String n1(double v) => v.toStringAsFixed(1);

/// Os quatro fatores de Dean Oliver de uma equipe em um jogo/temporada.
class FourFactors {
  final double efg, tovPct, orbPct, ftRate;
  const FourFactors(this.efg, this.tovPct, this.orbPct, this.ftRate);

  factory FourFactors.of(StatLine us, StatLine them) {
    final poss = us.possessions;
    final orbBase = us.oreb + them.dreb;
    return FourFactors(us.efgPct, poss <= 0 ? 0 : us.tov * 100 / poss, orbBase == 0 ? 0 : us.oreb * 100 / orbBase, us.fga == 0 ? 0 : us.ftm * 100 / us.fga);
  }
}

/// Análise de uma partida do ponto de vista de uma equipe ([side] 1 ou 2).
class GameAnalysis {
  final GameBoxScore game;
  final int side;
  GameAnalysis(this.game, this.side);

  TeamBox get us => game.team(side);
  TeamBox get them => game.team(side == 1 ? 2 : 1);
  int get margin => us.score - them.score;
  bool get won => margin > 0;
  bool get hasDetail => us.totals.fga > 0 && them.totals.fga > 0;
  double get ppp => us.totals.possessions <= 0 ? 0 : us.score / us.totals.possessions;
  double get oppPpp => them.totals.possessions <= 0 ? 0 : them.score / them.totals.possessions;

  String get resultLabel => margin > 0 ? 'Vitória por $margin' : (margin < 0 ? 'Derrota por ${-margin}' : 'Empate');

  String _outcome(int extra) {
    final m = margin + extra;
    if (margin > 0) return 'a vitória seria por $m';
    if (m > 0) return 'teria VENCIDO por $m';
    if (m == 0) return 'teria EMPATADO';
    return 'ainda perderia por ${-m}';
  }

  /// Cenários "e se" ordenados pelo impacto.
  List<WhatIf> whatIfs() {
    final l = us.totals;
    final out = <WhatIf>[];
    if (l.fta >= 4) {
      final target = (l.fta * 0.75).round();
      final extra = target - l.ftm;
      if (extra > 0) {
        out.add(
          WhatIf(
            'Lances livres',
            'Fez ${l.ftm}/${l.fta} (${p0(l.ftPct)}). Com 75% ($target/${l.fta}) seriam +$extra pontos e ${_outcome(extra)}. '
                'Convertendo todos, +${l.fta - l.ftm}.',
            extra,
            margin <= 0 && margin + extra > 0,
          ),
        );
      }
    }
    final tovDiff = l.tov - them.totals.tov;
    if (tovDiff > 0 && ppp > 0) {
      final extra = (tovDiff * ppp).round();
      if (extra > 0) {
        out.add(
          WhatIf(
            'Erros (turnovers)',
            '${l.tov} erros contra ${them.totals.tov} do adversário. Com o mesmo número de erros dele, '
                'as $tovDiff posses a mais valeriam ~$extra pontos (${n1(ppp)} pts/posse) e ${_outcome(extra)}.',
            extra,
            margin <= 0 && margin + extra > 0,
          ),
        );
      }
    }
    final orbDiff = them.totals.oreb - l.oreb;
    if (orbDiff > 0 && oppPpp > 0) {
      final extra = (orbDiff * oppPpp).round();
      if (extra > 0) {
        out.add(
          WhatIf(
            'Rebotes ofensivos cedidos',
            'O adversário pegou ${them.totals.oreb} rebotes ofensivos (nós, ${l.oreb}). '
                'Essas $orbDiff segundas chances a mais valem ~$extra pontos contra; anulando, ${_outcome(extra)}.',
            extra,
            margin <= 0 && margin + extra > 0,
          ),
        );
      }
    }
    if (l.tpa >= 8 && l.tpPct < 33) {
      final extra = ((l.tpa * 0.33).round() - l.tpm) * 3;
      if (extra > 0) {
        out.add(
          WhatIf(
            'Bolas de 3',
            'Fez ${l.tpm}/${l.tpa} de 3 (${p0(l.tpPct)}). Com 33% seriam +$extra pontos e ${_outcome(extra)}.',
            extra,
            margin <= 0 && margin + extra > 0,
          ),
        );
      }
    }
    out.sort((a, b) => b.extraPoints.compareTo(a.extraPoints));
    return out;
  }

  /// Qual dos quatro fatores mais pesou no resultado (pesos de Dean Oliver).
  Finding? decisiveFactor() {
    if (!hasDetail) return null;
    final a = FourFactors.of(us.totals, them.totals);
    final b = FourFactors.of(them.totals, us.totals);
    final items = <(String, double, String)>[
      ('Aproveitamento (eFG%)', (a.efg - b.efg) * .40, 'eFG ${p1(a.efg)} × ${p1(b.efg)}'),
      ('Erros (TOV%)', (b.tovPct - a.tovPct) * .25, 'TOV% ${p1(a.tovPct)} × ${p1(b.tovPct)}'),
      ('Rebote ofensivo (REB OF%)', (a.orbPct - b.orbPct) * .20, 'REB OF% ${p1(a.orbPct)} × ${p1(b.orbPct)}'),
      ('Lances livres (LL/arremesso)', (a.ftRate - b.ftRate) * .15, 'LL feitos por arremesso ${p1(a.ftRate)} × ${p1(b.ftRate)}'),
    ];
    items.sort((x, y) => won ? y.$2.compareTo(x.$2) : x.$2.compareTo(y.$2));
    final top = items.first;
    return Finding(
      won ? 'O que decidiu a vitória: ${top.$1}' : 'O que mais pesou na derrota: ${top.$1}',
      '${top.$3} (nós × adversário).',
      level: won ? FindingLevel.positive : FindingLevel.critical,
    );
  }

  /// Saldo por quarto: onde o time cresce ou cai.
  List<(String, int, int)> quarters() {
    final n = [us.periodScores.length, them.periodScores.length].reduce((a, b) => a < b ? a : b);
    return [
      for (var i = 0; i < n; i++)
        if (us.periodScores[i] + them.periodScores[i] > 0) (i < 4 ? '${i + 1}º quarto' : 'Prorrogação ${i - 3}', us.periodScores[i], them.periodScores[i]),
    ];
  }

  List<ShotAttempt> get shots => game.shots.where((s) => s.team == side).toList();

  /// Aproveitamento por zona (só zonas com volume).
  List<(ShotZone, int, int)> zones() => [
    for (final z in ShotZone.values)
      () {
        final list = shots.where((s) => zoneOf(s) == z).toList();
        return (z, list.where((s) => s.made).length, list.length);
      }(),
  ];

  List<Finding> findings() {
    final out = <Finding>[];
    final l = us.totals;
    final decisive = decisiveFactor();
    if (decisive != null) out.add(decisive);

    final qs = quarters();
    if (qs.length >= 2) {
      final sorted = [...qs]..sort((a, b) => (a.$2 - a.$3).compareTo(b.$2 - b.$3));
      final worst = sorted.first, best = sorted.last;
      if (worst.$2 - worst.$3 < 0) {
        out.add(
          Finding(
            'Pior período: ${worst.$1}',
            'Perdemos o ${worst.$1} por ${worst.$3 - worst.$2} (${worst.$2} × ${worst.$3}).',
            level: FindingLevel.warning,
            points: (worst.$2 - worst.$3).toDouble(),
          ),
        );
      }
      if (best.$2 - best.$3 > 0) {
        out.add(
          Finding('Melhor período: ${best.$1}', 'Vencemos o ${best.$1} por ${best.$2 - best.$3} (${best.$2} × ${best.$3}).', level: FindingLevel.positive),
        );
      }
    }

    final fromTov = them.extras['fromTurnovers'];
    if (fromTov != null && them.score > 0 && fromTov > 0) {
      final share = fromTov * 100 / them.score;
      out.add(
        Finding(
          'Pontos sofridos após erros',
          'O adversário fez $fromTov pontos depois dos nossos erros (${p0(share)} dos pontos dele).',
          level: share >= 20 ? FindingLevel.critical : FindingLevel.neutral,
          points: -fromTov.toDouble(),
        ),
      );
    }
    final paintThem = them.extras['paint'];
    final paintUs = us.extras['paint'];
    if (paintThem != null && paintUs != null && paintThem - paintUs >= 8) {
      out.add(Finding('Garrafão', 'Sofremos $paintThem pontos no garrafão e fizemos $paintUs.', level: FindingLevel.warning));
    }

    final zs = zones().where((z) => z.$3 >= 4).toList()..sort((a, b) => (a.$2 / a.$3).compareTo(b.$2 / b.$3));
    if (zs.isNotEmpty) {
      final w = zs.first;
      out.add(
        Finding(
          'Zona de arremesso mais fraca: ${w.$1.label}',
          '${w.$2}/${w.$3} (${p0(w.$2 * 100 / w.$3)}).',
          level: w.$2 / w.$3 < .3 ? FindingLevel.warning : FindingLevel.neutral,
        ),
      );
    }

    final played = us.players.where((p) => p.played).toList();
    if (played.isNotEmpty) {
      final top = [...played]..sort((a, b) => b.stats.efficiency.compareTo(a.stats.efficiency));
      final t = top.first;
      out.add(
        Finding(
          'Destaque: ${t.name}',
          '${t.stats.points} pts, ${t.stats.reb} reb, ${t.stats.ast} ast, eficiência ${t.stats.efficiency}.',
          level: FindingLevel.positive,
        ),
      );
      for (final p in played.where((p) => p.stats.fga >= 8 && p.stats.efgPct < 35)) {
        out.add(
          Finding('Baixo aproveitamento: ${p.name}', '${p.stats.fgm}/${p.stats.fga} nos arremessos (eFG ${p0(p.stats.efgPct)}).', level: FindingLevel.warning),
        );
      }
      for (final p in played.where((p) => p.stats.tov >= 5)) {
        out.add(Finding('Muitos erros: ${p.name}', '${p.stats.tov} turnovers.', level: FindingLevel.warning));
      }
      for (final p in played.where((p) => p.stats.pf >= 5)) {
        out.add(Finding('Excluído por faltas: ${p.name}', '${p.stats.pf} faltas.', level: FindingLevel.warning));
      }
    }
    if (l.fta >= 6 && l.ftPct < 60) {
      out.add(Finding('Lances livres', '${l.ftm}/${l.fta} (${p0(l.ftPct)}).', level: FindingLevel.warning, points: (l.fta * .75 - l.ftm)));
    }
    return out;
  }

  /// Recomendações objetivas para o próximo treino.
  List<String> trainingPlan() {
    final l = us.totals;
    final a = FourFactors.of(l, them.totals);
    final b = FourFactors.of(them.totals, l);
    final out = <String>[];
    if (l.fta >= 4 && l.ftPct < 70) {
      out.add('Lances livres sob fadiga: séries de 10 após sprint, meta 75% (hoje ${p0(l.ftPct)}).');
    }
    if (a.tovPct > 18 || l.tov - them.totals.tov >= 4) {
      out.add('Proteção de bola: saída de pressão e passe sob marcação (TOV% ${p1(a.tovPct)}, ${l.tov} erros).');
    }
    if (b.orbPct > 30) {
      out.add('Bloqueio de rebote defensivo: o adversário recuperou ${p0(b.orbPct)} dos próprios erros.');
    }
    if (l.tpa >= 8 && l.tpPct < 30) {
      out.add('Seleção de arremessos: ${l.tpm}/${l.tpa} de 3. Priorizar infiltração e passe extra para o arremesso livre.');
    }
    final qs = quarters();
    if (qs.isNotEmpty) {
      final worst = [...qs]..sort((x, y) => (x.$2 - x.$3).compareTo(y.$2 - y.$3));
      if (worst.first.$2 < worst.first.$3) {
        out.add('Atenção ao ${worst.first.$1}: simular no treino situações de início/volta de intervalo e rotação de banco.');
      }
    }
    final zs = zones().where((z) => z.$3 >= 4 && z.$2 / z.$3 < .3).toList();
    for (final z in zs) {
      out.add('Arremesso de ${z.$1.label.toLowerCase()}: ${z.$2}/${z.$3}. Repetição específica dessa zona ou evitar o volume nela.');
    }
    if (out.isEmpty) out.add('Manter a base do jogo: os principais indicadores ficaram em faixa saudável.');
    return out;
  }
}
