import '../models/box_score.dart';
import '../models/game.dart';
import '../models/play_event.dart';
import '../models/player.dart';
import '../services/schedule_parser.dart';

/// Converte um jogo registrado no Scout ao vivo do ARCO em [GameBoxScore],
/// para que estatísticas, relatórios e o Analista tratem scout e estatística
/// online da mesma forma.
class ScoutAdapter {
  static GameBoxScore toBoxScore(Game g, {required String teamName, required List<Player> roster}) {
    final names = {for (final p in roster) p.id: p};
    final periodsUs = <int, int>{}, periodsThem = <int, int>{};
    final plays = <PlayAction>[];
    var us = 0, them = 0;
    for (final e in g.events) {
      final (type, sub, ok, pts) = switch (e.type) {
        PlayEventType.twoMade => ('2pt', '', true, 2),
        PlayEventType.twoMiss => ('2pt', '', false, 0),
        PlayEventType.threeMade => ('3pt', '', true, 3),
        PlayEventType.threeMiss => ('3pt', '', false, 0),
        PlayEventType.freeThrowMade => ('freethrow', '', true, 1),
        PlayEventType.freeThrowMiss => ('freethrow', '', false, 0),
        PlayEventType.assist => ('assist', '', true, 0),
        PlayEventType.offensiveRebound => ('rebound', 'offensive', true, 0),
        PlayEventType.defensiveRebound => ('rebound', 'defensive', true, 0),
        PlayEventType.steal => ('steal', '', true, 0),
        PlayEventType.block => ('block', '', true, 0),
        PlayEventType.turnover => ('turnover', '', true, 0),
        PlayEventType.foul => ('foul', '', true, 0),
        PlayEventType.opponentOne => ('freethrow', '', true, 1),
        PlayEventType.opponentTwo => ('2pt', '', true, 2),
        PlayEventType.opponentThree => ('3pt', '', true, 3),
      };
      final opponent = e.type == PlayEventType.opponentOne || e.type == PlayEventType.opponentTwo || e.type == PlayEventType.opponentThree;
      if (opponent) {
        them += pts;
        periodsThem[e.period] = (periodsThem[e.period] ?? 0) + pts;
      } else {
        us += pts;
        periodsUs[e.period] = (periodsUs[e.period] ?? 0) + pts;
      }
      plays.add(PlayAction(
        period: e.period,
        clock: '',
        team: opponent ? 2 : 1,
        player: opponent ? '' : (names[e.playerId]?.name ?? ''),
        type: type,
        subType: sub,
        success: ok,
        score: '$us-$them',
      ));
    }
    final maxPeriod = [...periodsUs.keys, ...periodsThem.keys, 4].reduce((a, b) => a > b ? a : b);

    final players = <PlayerBox>[
      for (final e in g.playerStats.entries)
        () {
          final s = e.value;
          final p = names[e.key];
          final name = p?.name ?? 'Jogador';
          return PlayerBox(
            key: ScheduleParser.normalize(name),
            name: name,
            number: p == null ? '' : '${p.number}',
            position: p?.position ?? '',
            stats: StatLine(
              points: s.points,
              fgm: s.fgm,
              fga: s.fga,
              tpm: s.threePm,
              tpa: s.threePa,
              ftm: s.ftm,
              fta: s.fta,
              oreb: s.offensiveRebounds,
              dreb: s.defensiveRebounds,
              ast: s.assists,
              tov: s.turnovers,
              stl: s.steals,
              blk: s.blocks,
              pf: s.fouls,
            ),
          );
        }(),
    ];
    final totals = players.fold(StatLine.zero, (sum, p) => sum + p.stats);

    return GameBoxScore(
      matchId: 'scout_${g.date.millisecondsSinceEpoch}',
      league: 'SCOUT',
      sourceUrl: '',
      home: TeamBox(
        name: teamName,
        score: g.ourScore,
        totals: totals,
        players: players,
        periodScores: [for (var i = 1; i <= maxPeriod; i++) periodsUs[i] ?? 0],
      ),
      away: TeamBox(
        name: g.opponent,
        score: g.opponentScore,
        totals: StatLine(points: g.opponentScore),
        periodScores: [for (var i = 1; i <= maxPeriod; i++) periodsThem[i] ?? 0],
      ),
      status: 'FINAL',
      fetchedAt: g.date,
      plays: plays.reversed.toList(),
    );
  }
}
