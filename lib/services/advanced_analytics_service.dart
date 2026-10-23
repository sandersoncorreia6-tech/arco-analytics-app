import '../models/game.dart';
import 'analytics_service.dart';

class TeamPerformanceSummary {
  final int games;
  final int wins;
  final int losses;
  final int possessions;
  final int pointsFor;
  final int pointsAgainst;
  final int fgm;
  final int fga;
  final int threePm;
  final int fta;
  final int turnovers;
  final int offensiveRebounds;
  final int availableOffensiveRebounds;
  final bool usesDemoData;

  const TeamPerformanceSummary({
    required this.games,
    required this.wins,
    required this.losses,
    required this.possessions,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.fgm,
    required this.fga,
    required this.threePm,
    required this.fta,
    required this.turnovers,
    required this.offensiveRebounds,
    required this.availableOffensiveRebounds,
    required this.usesDemoData,
  });

  double get winPct => games == 0 ? 0 : (wins / games) * 100;
  double get avgPointsFor => games == 0 ? 0 : pointsFor / games;
  double get avgPointsAgainst => games == 0 ? 0 : pointsAgainst / games;
  double get offensiveRating =>
      AnalyticsService.offensiveRating(points: pointsFor, possessions: possessions);
  double get defensiveRating => AnalyticsService.defensiveRating(
        opponentPoints: pointsAgainst,
        possessions: possessions,
      );
  double get netRating => offensiveRating - defensiveRating;
  double get efg => AnalyticsService.efg(
        fgm: fgm,
        threePm: threePm,
        fga: fga,
      );
  double get turnoverPct => AnalyticsService.turnoverPct(
        turnovers: turnovers,
        possessions: possessions,
      );
  double get offensiveReboundPct => AnalyticsService.offensiveReboundPct(
        offensiveRebounds: offensiveRebounds,
        available: availableOffensiveRebounds,
      );
  double get freeThrowRate => fga == 0 ? 0 : (fta / fga) * 100;
  String get sampleConfidence => AnalyticsService.sampleConfidence(possessions);
}

class OpponentReport {
  final String opponent;
  final TeamPerformanceSummary summary;
  final List<Game> games;

  const OpponentReport({
    required this.opponent,
    required this.summary,
    required this.games,
  });

  String get record => '${summary.wins}-${summary.losses}';
}

class AdvancedAnalyticsService {
  static List<Game> preferredSample(List<Game> games) {
    final real = games.where((game) => game.source != 'mock').toList();
    return real.isNotEmpty ? real : List<Game>.from(games);
  }

  static TeamPerformanceSummary summarize(List<Game> games) {
    final sample = preferredSample(games);
    return TeamPerformanceSummary(
      games: sample.length,
      wins: sample.where((game) => game.won).length,
      losses: sample.where((game) => !game.won).length,
      possessions: sample.fold(0, (sum, game) => sum + game.possessions),
      pointsFor: sample.fold(0, (sum, game) => sum + game.ourScore),
      pointsAgainst:
          sample.fold(0, (sum, game) => sum + game.opponentScore),
      fgm: sample.fold(0, (sum, game) => sum + game.fgm),
      fga: sample.fold(0, (sum, game) => sum + game.fga),
      threePm: sample.fold(0, (sum, game) => sum + game.threePm),
      fta: sample.fold(0, (sum, game) => sum + game.fta),
      turnovers: sample.fold(0, (sum, game) => sum + game.turnovers),
      offensiveRebounds:
          sample.fold(0, (sum, game) => sum + game.offensiveRebounds),
      availableOffensiveRebounds: sample.fold(
        0,
        (sum, game) => sum + game.availableOffensiveRebounds,
      ),
      usesDemoData: sample.isNotEmpty && sample.every((g) => g.source == 'mock'),
    );
  }

  static List<OpponentReport> opponents(List<Game> games) {
    final sample = preferredSample(games);
    final buckets = <String, List<Game>>{};
    for (final game in sample) {
      final key = game.opponent.trim().toLowerCase();
      if (key.isEmpty) continue;
      buckets.putIfAbsent(key, () => []).add(game);
    }

    final result = buckets.entries.map((entry) {
      final games = [...entry.value]..sort((a, b) => b.date.compareTo(a.date));
      return OpponentReport(
        opponent: games.first.opponent,
        summary: summarize(games),
        games: games,
      );
    }).toList();

    result.sort((a, b) => b.games.first.date.compareTo(a.games.first.date));
    return result;
  }

  static List<String> recentForm(List<Game> games, {int limit = 5}) {
    final sample = preferredSample(games)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sample.take(limit).map((game) => game.won ? 'V' : 'D').toList();
  }

  static List<String> buildGamePlan({
    required TeamPerformanceSummary team,
    required OpponentReport opponent,
  }) {
    final plan = <String>[];

    if (team.turnoverPct > 18) {
      plan.add(
        'Prioridade ofensiva: reduzir perdas de bola; a amostra atual está em '
        '${team.turnoverPct.toStringAsFixed(1)}% de TOV.',
      );
    } else {
      plan.add(
        'Manter proteção da posse; TOV da amostra está em '
        '${team.turnoverPct.toStringAsFixed(1)}%.',
      );
    }

    if (team.offensiveReboundPct < 25) {
      plan.add(
        'Buscar mais segundas chances sem desmontar o balanço defensivo; ORB '
        '${team.offensiveReboundPct.toStringAsFixed(1)}%.',
      );
    } else {
      plan.add(
        'O rebote ofensivo é uma vantagem atual; preservar ocupação do aro e '
        'do lado contrário.',
      );
    }

    if (opponent.summary.avgPointsAgainst >= opponent.summary.avgPointsFor) {
      plan.add(
        'Nos confrontos cadastrados, o ARCO pontuou mais do que sofreu contra '
        '${opponent.opponent}; repetir ações que geraram vantagem sem assumir '
        'que o padrão continuará automaticamente.',
      );
    } else {
      plan.add(
        'Nos confrontos cadastrados, ${opponent.opponent} teve saldo favorável; '
        'tratar o início do jogo e as posses de alta pressão como prioridade.',
      );
    }

    if (team.efg < 50) {
      plan.add(
        'Melhorar qualidade de finalização: eFG da amostra em '
        '${team.efg.toStringAsFixed(1)}%; priorizar aro, transição e chutes '
        'equilibrados de 3 pontos.',
      );
    } else {
      plan.add(
        'Eficiência de arremesso está sustentável na amostra '
        '(${team.efg.toStringAsFixed(1)}% eFG); evitar trocar qualidade por volume.',
      );
    }

    plan.add(
      'Confiança estatística atual: ${team.sampleConfidence}. '
      'Decisões devem considerar ${team.possessions} posses registradas.',
    );
    return plan;
  }
}
