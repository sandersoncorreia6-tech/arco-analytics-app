import '../models/player.dart';
import '../models/game.dart';
import '../models/lineup.dart';
import '../models/play_event.dart';

class AnalyticsService {
  static double percentage(num made, num attempts) =>
      attempts == 0 ? 0 : (made / attempts) * 100;

  static double efg({required int fgm, required int threePm, required int fga}) {
    if (fga == 0) return 0;
    return ((fgm + 0.5 * threePm) / fga) * 100;
  }

  static double trueShooting({required int points, required int fga, required int fta}) {
    final denominator = 2 * (fga + 0.44 * fta);
    if (denominator == 0) return 0;
    return (points / denominator) * 100;
  }

  static double offensiveRating({required int points, required int possessions}) {
    if (possessions == 0) return 0;
    return (points / possessions) * 100;
  }

  static double defensiveRating({required int opponentPoints, required int possessions}) {
    if (possessions == 0) return 0;
    return (opponentPoints / possessions) * 100;
  }

  static double turnoverPct({required int turnovers, required int possessions}) {
    if (possessions == 0) return 0;
    return (turnovers / possessions) * 100;
  }

  static double offensiveReboundPct({required int offensiveRebounds, required int available}) {
    if (available == 0) return 0;
    return (offensiveRebounds / available) * 100;
  }

  static double onOffNet(Player p) {
    final onNet = p.onCourtOffRating - p.onCourtDefRating;
    final offNet = p.offCourtOffRating - p.offCourtDefRating;
    return onNet - offNet;
  }

  /// Índice de desempenho por jogo (Game Score de Hollinger): resume a
  /// produção do jogador em um número comparável, sem teto artificial.
  /// ~10 = jogo médio; 15+ = muito bom; 20+ = excelente.
  static double impactScore(Player p) {
    final g = p.games <= 0 ? 1 : p.games;
    final fgm = p.fgm / g, fga = p.fga / g, ftm = p.ftm / g, fta = p.fta / g;
    return p.points + 0.4 * fgm - 0.7 * fga - 0.4 * (fta - ftm) + 0.5 * p.rebounds + p.steals + 0.7 * p.assists + 0.7 * p.blocks - p.turnovers;
  }

  static String sampleConfidence(int possessions) {
    if (possessions >= 300) return 'ALTA';
    if (possessions >= 100) return 'MÉDIA';
    return 'BAIXA';
  }

  static List<Lineup> lineupsFromGame(Game game, Map<String, String> playerNames) {
    if (game.events.isEmpty) return const [];
    final buckets = <String, _LineupAccumulator>{};
    for (final event in game.events) {
      if (event.lineupIds.length != 5) continue;
      final ids = [...event.lineupIds]..sort();
      final key = ids.join('|');
      final bucket = buckets.putIfAbsent(key, () => _LineupAccumulator(ids));
      bucket.add(event.type);
    }
    final result = <Lineup>[];
    for (final bucket in buckets.values) {
      final poss = bucket.estimatedPossessions;
      if (poss < 1) continue;
      final roundedPoss = poss.round().clamp(1, 999);
      final off = (bucket.pointsFor / poss) * 100;
      final def = (bucket.pointsAgainst / poss) * 100;
      result.add(Lineup(
        name: 'Lineup registrado',
        players: bucket.playerIds.map((id) => playerNames[id] ?? id).toList(),
        possessions: roundedPoss,
        offensiveRating: off,
        defensiveRating: def,
      ));
    }
    result.sort((a, b) => b.netRating.compareTo(a.netRating));
    return result;
  }
}


class _LineupAccumulator {
  final List<String> playerIds;
  int pointsFor = 0;
  int pointsAgainst = 0;
  int fga = 0;
  int fta = 0;
  int offensiveRebounds = 0;
  int turnovers = 0;

  _LineupAccumulator(this.playerIds);

  double get estimatedPossessions {
    final value = fga - offensiveRebounds + turnovers + (0.44 * fta);
    return value < 1 ? 1 : value;
  }

  void add(PlayEventType type) {
    switch (type) {
      case PlayEventType.twoMade:
        pointsFor += 2; fga++;
        break;
      case PlayEventType.twoMiss:
        fga++;
        break;
      case PlayEventType.threeMade:
        pointsFor += 3; fga++;
        break;
      case PlayEventType.threeMiss:
        fga++;
        break;
      case PlayEventType.freeThrowMade:
        pointsFor++; fta++;
        break;
      case PlayEventType.freeThrowMiss:
        fta++;
        break;
      case PlayEventType.offensiveRebound:
        offensiveRebounds++;
        break;
      case PlayEventType.turnover:
        turnovers++;
        break;
      case PlayEventType.opponentOne:
        pointsAgainst++;
        break;
      case PlayEventType.opponentTwo:
        pointsAgainst += 2;
        break;
      case PlayEventType.opponentThree:
        pointsAgainst += 3;
        break;
      case PlayEventType.assist:
      case PlayEventType.defensiveRebound:
      case PlayEventType.steal:
      case PlayEventType.block:
      case PlayEventType.foul:
        break;
    }
  }
}
