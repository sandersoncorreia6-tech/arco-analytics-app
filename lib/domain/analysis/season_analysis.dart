import 'package:arco_analytics/domain/models/box_score.dart';
import 'package:arco_analytics/domain/services/stats_aggregator.dart';
import 'package:arco_analytics/domain/analysis/game_analysis.dart';
import 'package:arco_analytics/domain/analysis/lineups.dart';
import 'package:arco_analytics/domain/analysis/sample_size.dart';
import 'package:arco_analytics/domain/analysis/shot_zones.dart';

/// Uso de posses (USG%): fatia das posses da equipe que o jogador finaliza
/// (arremesso, lance livre ou erro) enquanto está em quadra.
double? usageRate(PlayerSeason p, TeamSeason t) {
  final pl = p.totals, tm = t.totals;
  final teamPoss = tm.fga + 0.44 * tm.fta + tm.tov;
  final teamSeconds = tm.seconds > 0 ? tm.seconds : t.players.values.fold<int>(0, (s, x) => s + x.totals.seconds);
  if (pl.seconds == 0 || teamSeconds == 0 || teamPoss == 0) return null;
  return 100 * (pl.fga + 0.44 * pl.fta + pl.tov) * (teamSeconds / 5) / (pl.seconds * teamPoss);
}

/// Médias de um grupo de jogos (ex.: vitórias × derrotas).
class SplitAverages {
  final int games;
  final double points, allowed, efg, tovPct, orbPct, ftPct, tpPct, tov, oreb, oppOreb;
  const SplitAverages(this.games, this.points, this.allowed, this.efg, this.tovPct, this.orbPct, this.ftPct, this.tpPct, this.tov, this.oreb, this.oppOreb);

  static SplitAverages of(List<GameAnalysis> list) {
    if (list.isEmpty) return const SplitAverages(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    var us = StatLine.zero, them = StatLine.zero;
    var pts = 0, allowed = 0;
    for (final a in list) {
      us = us + a.us.totals;
      them = them + a.them.totals;
      pts += a.us.score;
      allowed += a.them.score;
    }
    final f = FourFactors.of(us, them);
    final n = list.length;
    return SplitAverages(n, pts / n, allowed / n, f.efg, f.tovPct, f.orbPct, us.ftPct, us.tpPct, us.tov / n, us.oreb / n, them.oreb / n);
  }
}

/// Análise da temporada de uma equipe: padrões, quartos, lados da quadra,
/// quintetos, jogadores e onde o time mais perde pontos.
class SeasonAnalysis {
  final TeamSeason team;
  SeasonAnalysis(this.team);

  late final List<GameAnalysis> games = [for (final g in team.gameList) GameAnalysis(g, StatsAggregator.teamKey(g.home.name) == team.key ? 1 : 2)];

  List<GameAnalysis> get finals => games.where((g) => g.game.isFinal).toList();
  List<GameAnalysis> get wins => finals.where((g) => g.won).toList();
  List<GameAnalysis> get losses => finals.where((g) => g.margin < 0).toList();

  /// Saldo médio por quarto (1º a 4º).
  List<(String, double, double)> quarterAverages() {
    final out = <(String, double, double)>[];
    for (var q = 0; q < 4; q++) {
      final list = games.where((g) => g.us.periodScores.length > q && g.them.periodScores.length > q).toList();
      if (list.isEmpty) continue;
      final us = list.fold<int>(0, (s, g) => s + g.us.periodScores[q]) / list.length;
      final them = list.fold<int>(0, (s, g) => s + g.them.periodScores[q]) / list.length;
      if (us + them > 0) out.add(('${q + 1}º quarto', us, them));
    }
    return out;
  }

  List<(ShotZone, int, int)> zones([List<ShotAttempt>? shots]) {
    final list = shots ?? team.shots;
    return [for (final z in ShotZone.values) (z, list.where((s) => zoneOf(s) == z && s.made).length, list.where((s) => zoneOf(s) == z).length)];
  }

  /// Aproveitamento por lado (esquerdo/central/direito), opcionalmente só bolas de 3.
  List<(String, int, int)> sides({bool threesOnly = false, List<ShotAttempt>? shots}) {
    final list = (shots ?? team.shots).where((s) => !threesOnly || s.isThree).toList();
    return [
      for (final side in const ['esquerdo', 'central', 'direito'])
        (side, list.where((s) => sideOf(s) == side && s.made).length, list.where((s) => sideOf(s) == side).length),
    ];
  }

  List<LineupStat> lineups() => LineupBuilder.combine([for (final g in games) LineupBuilder.forGame(g.game, g.side)]);

  /// Derrotas que mudariam com lances livres a 75%.
  List<(GameAnalysis, WhatIf)> lossesFlippedByFreeThrows() => [
    for (final g in losses)
      for (final w in g.whatIfs())
        if (w.title == 'Lances livres' && w.flipsResult) (g, w),
  ];

  /// Conclusões da temporada em frases.
  List<Finding> findings() {
    final out = <Finding>[];
    final w = SplitAverages.of(wins), l = SplitAverages.of(losses);
    if (wins.isNotEmpty && losses.isNotEmpty) {
      if (l.tov - w.tov >= 2) {
        out.add(
          Finding(
            'Erros decidem jogos',
            'Nas derrotas o time comete ${n1(l.tov)} erros por jogo, contra ${n1(w.tov)} nas vitórias.',
            level: FindingLevel.critical,
          ),
        );
      }
      if (w.efg - l.efg >= 5) {
        out.add(Finding('Aproveitamento decide jogos', 'eFG ${p1(w.efg)} nas vitórias × ${p1(l.efg)} nas derrotas.', level: FindingLevel.warning));
      }
      if (l.oppOreb - w.oppOreb >= 2) {
        out.add(
          Finding(
            'Rebote defensivo nas derrotas',
            'O adversário pega ${n1(l.oppOreb)} rebotes ofensivos nas derrotas, contra ${n1(w.oppOreb)} nas vitórias.',
            level: FindingLevel.warning,
          ),
        );
      }
      if (w.ftPct - l.ftPct >= 8) {
        out.add(Finding('Lances livres nas derrotas', '${p0(l.ftPct)} nas derrotas × ${p0(w.ftPct)} nas vitórias.', level: FindingLevel.warning));
      }
    }

    final flipped = lossesFlippedByFreeThrows();
    if (flipped.isNotEmpty) {
      out.add(
        Finding(
          'Lances livres custaram ${flipped.length} ${flipped.length == 1 ? 'vitória' : 'vitórias'}',
          flipped.map((e) => 'vs ${e.$1.them.name}: ${e.$2.detail}').join('\n'),
          level: FindingLevel.critical,
        ),
      );
    }

    final qs = quarterAverages();
    if (qs.length >= 2) {
      final sorted = [...qs]..sort((a, b) => (a.$2 - a.$3).compareTo(b.$2 - b.$3));
      final worst = sorted.first, best = sorted.last;
      out.add(
        Finding(
          'Período em que o time mais cai: ${worst.$1}',
          'Média ${n1(worst.$2)} × ${n1(worst.$3)} (saldo ${n1(worst.$2 - worst.$3)} por jogo).',
          level: worst.$2 < worst.$3 ? FindingLevel.warning : FindingLevel.neutral,
        ),
      );
      out.add(
        Finding(
          'Período em que o time mais cresce: ${best.$1}',
          'Média ${n1(best.$2)} × ${n1(best.$3)} (saldo ${best.$2 >= best.$3 ? '+' : ''}${n1(best.$2 - best.$3)}).',
          level: FindingLevel.positive,
        ),
      );
    }

    final fromTov = games.fold<int>(0, (s, g) => s + (g.them.extras['fromTurnovers'] ?? 0));
    final allowed = games.fold<int>(0, (s, g) => s + g.them.score);
    if (fromTov > 0 && allowed > 0) {
      out.add(
        Finding(
          'Pontos sofridos após erros',
          'O time sofreu ${p0(fromTov * 100 / allowed)} dos pontos após turnovers.',
          level: fromTov * 100 / allowed >= 18 ? FindingLevel.critical : FindingLevel.neutral,
        ),
      );
    }

    final zs = zones().where((z) => z.$3 >= 8).toList();
    if (zs.isNotEmpty) {
      final byMisses = [...zs]..sort((a, b) => (b.$3 - b.$2).compareTo(a.$3 - a.$2));
      final m = byMisses.first;
      out.add(
        Finding(
          'Onde o time mais erra: ${m.$1.label}',
          '${m.$3 - m.$2 == 1 ? '1 erro' : '${m.$3 - m.$2} erros'} em ${m.$3} arremessos (${p0(m.$2 * 100 / m.$3)}).',
          level: FindingLevel.warning,
        ),
      );
    }
    final threeSides = sides(threesOnly: true).where((s) => s.$1 != 'central' && s.$3 >= 6).toList();
    if (threeSides.length == 2) {
      final a = threeSides[0], b = threeSides[1];
      final pa = a.$2 * 100 / a.$3, pb = b.$2 * 100 / b.$3;
      if ((pa - pb).abs() >= 10) {
        final better = pa > pb ? a : b, worse = pa > pb ? b : a;
        out.add(
          Finding(
            'Lado da quadra nas bolas de 3',
            'Lado ${better.$1}: ${p0(better.$2 * 100 / better.$3)} (${better.$2}/${better.$3}); lado ${worse.$1}: '
                '${p0(worse.$2 * 100 / worse.$3)} (${worse.$2}/${worse.$3}).',
          ),
        );
      }
    }

    final ranked = lineups().where((x) => x.minutes >= 6).toList()..sort((a, b) => b.plusMinus.compareTo(a.plusMinus));
    if (ranked.length >= 2) {
      final best = ranked.first, worst = ranked.last;
      out.add(
        Finding(
          'Melhor formação',
          '${best.sample.phrase}: ${best.names.join(' – ')} com saldo ${best.plusMinus >= 0 ? '+' : ''}${best.plusMinus} em ${n1(best.minutes)} min juntos '
              '(${best.games} ${best.games == 1 ? 'jogo' : 'jogos'}).',
          level: best.sample == SampleLevel.low ? FindingLevel.neutral : FindingLevel.positive,
        ),
      );
      if (worst.plusMinus < 0) {
        out.add(
          Finding(
            'Pior formação',
            '${worst.sample.phrase}: ${worst.names.join(' – ')} com saldo ${worst.plusMinus} em ${n1(worst.minutes)} min juntos.',
            level: worst.sample == SampleLevel.low ? FindingLevel.neutral : FindingLevel.warning,
          ),
        );
      }
    }

    // Impacto com contexto: saldo em quadra e com quem a diferença foi maior.
    final all = lineups();
    if (all.isNotEmpty) {
      final solos = Groups.of(all, 1).where((g) => g.seconds >= 300).toList()..sort((a, b) => b.plusMinus.compareTo(a.plusMinus));
      if (solos.isNotEmpty) {
        final sentence = Groups.impactSentence(all, solos.first.keys.single);
        if (sentence != null) out.add(Finding('Maior impacto em quadra: ${solos.first.names.single}', sentence, level: FindingLevel.positive));
      }
    }

    final roster = team.roster;
    for (final p in roster.where((p) => p.games >= 3)) {
      final last = p.log.length > 3 ? p.log.sublist(p.log.length - 3) : p.log;
      final recent = last.fold<int>(0, (s, e) => s + e.box.stats.points) / last.length;
      if (recent - p.ppg >= 5) {
        out.add(Finding('Em alta: ${p.name}', '${n1(recent)} pts nos últimos ${last.length} jogos (média ${n1(p.ppg)}).', level: FindingLevel.positive));
      } else if (p.ppg - recent >= 5) {
        out.add(Finding('Em queda: ${p.name}', '${n1(recent)} pts nos últimos ${last.length} jogos (média ${n1(p.ppg)}).', level: FindingLevel.warning));
      }
    }
    return out;
  }

  /// Pontos de melhoria priorizados para os treinos.
  List<String> trainingPriorities() {
    final counts = <String, int>{};
    for (final g in games) {
      for (final rec in g.trainingPlan()) {
        final key = rec.split(':').first;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(5)) '${e.key} — apareceu em ${e.value} de ${games.length} jogos'];
  }
}

/// Relatório pré-jogo do adversário a partir das partidas dele importadas.
class OpponentReport {
  final TeamSeason team;
  OpponentReport(this.team);

  late final SeasonAnalysis season = SeasonAnalysis(team);

  List<PlayerSeason> get topScorers => team.roster.take(5).toList();

  String get style {
    final l = team.totals;
    final threeRate = l.fga == 0 ? 0 : l.tpa * 100 / l.fga;
    final parts = <String>[
      team.pace >= 72 ? 'joga em ritmo alto (${n1(team.pace)} posses)' : 'ritmo controlado (${n1(team.pace)} posses)',
      threeRate >= 38
          ? 'arremessa muito de 3 (${p0(threeRate.toDouble())} dos arremessos)'
          : 'ataque mais interno (${p0(threeRate.toDouble())} dos arremessos de 3)',
      'rebote ofensivo ${p0(team.orbPct)}',
      'erra ${n1(team.perGame(l.tov))} bolas por jogo',
    ];
    return parts.join('; ');
  }

  List<String> strengths() {
    final l = team.totals;
    return [
      if (l.efgPct >= 50) 'Bom aproveitamento geral (eFG ${p1(l.efgPct)}).',
      if (l.tpPct >= 35 && l.tpa >= 10) 'Perigoso de 3: ${p0(l.tpPct)}.',
      if (team.orbPct >= 32) 'Ataca o rebote ofensivo (${p0(team.orbPct)}).',
      if (team.tovPct <= 14) 'Protege bem a bola (TOV% ${p0(team.tovPct)}).',
      for (final z in season.zones().where((z) => z.$3 >= 6 && z.$2 / z.$3 >= .5)) 'Eficiente em ${z.$1.label.toLowerCase()}: ${z.$2}/${z.$3}.',
    ];
  }

  List<String> weaknesses() {
    final l = team.totals;
    return [
      if (team.tovPct >= 20) 'Erra muito: TOV% ${p0(team.tovPct)} (${n1(team.perGame(l.tov))} por jogo).',
      if (l.ftPct < 62 && l.fta >= 10) 'Lances livres fracos: ${p0(l.ftPct)}.',
      if (l.tpPct < 28 && l.tpa >= 10) 'Pouco efetivo de 3: ${p0(l.tpPct)}.',
      if (team.orbPct < 22) 'Pouca presença no rebote ofensivo (${p0(team.orbPct)}).',
      for (final z in season.zones().where((z) => z.$3 >= 6 && z.$2 / z.$3 < .3)) 'Fraco em ${z.$1.label.toLowerCase()}: ${z.$2}/${z.$3}.',
    ];
  }

  List<String> defensivePlan() {
    final l = team.totals;
    final top = topScorers;
    return [
      if (top.isNotEmpty) 'Marcação prioritária em ${top.first.name} (${n1(top.first.ppg)} pts): negar recepção e forçar a mão fraca.',
      if (l.tpPct >= 35 && l.tpa >= 10) 'Fechar as linhas de 3: contestar todo arremesso, evitar ajuda longa.',
      if (l.tpPct < 30) 'Fechar o garrafão e conceder o arremesso de 3 a quem arremessa mal.',
      if (team.tovPct >= 18) 'Pressionar a saída de bola: o adversário erra ${p0(team.tovPct)} das posses.',
      if (team.orbPct >= 30) 'Bloqueio de rebote com os 5 jogadores.',
      if (l.ftPct < 62 && l.fta >= 10) 'Em final apertado, falta tática em quem arremessa mal lances livres.',
    ];
  }
}
