import 'package:arco_analytics/domain/models/box_score.dart';
import 'package:arco_analytics/data/sources/schedule_parser.dart';

/// Jogo de um jogador (para o histórico jogo a jogo).
class PlayerGameEntry {
  final GameBoxScore game;
  final int team;
  final PlayerBox box;
  const PlayerGameEntry(this.game, this.team, this.box);

  String get opponent => game.team(team == 1 ? 2 : 1).name;
}

class PlayerSeason {
  final String key;
  final String teamKey;
  String name;
  String number;
  String position;
  String teamName;
  StatLine totals = StatLine.zero;
  int games = 0;
  int starts = 0;
  final List<ShotAttempt> shots = [];
  final List<PlayerGameEntry> log = [];

  PlayerSeason({required this.key, required this.teamKey, required this.name, required this.number, required this.position, required this.teamName});

  double perGame(int value) => games == 0 ? 0 : value / games;
  double get ppg => perGame(totals.points);
  double get rpg => perGame(totals.reb);
  double get apg => perGame(totals.ast);
  double get mpg => games == 0 ? 0 : totals.minutes / games;
  double get effPerGame => perGame(totals.efficiency);
}

class TeamSeason {
  final String key;
  String name;
  final Set<String> leagues = {};
  int wins = 0;
  int losses = 0;
  int games = 0;
  StatLine totals = StatLine.zero;
  StatLine opponents = StatLine.zero;
  int pointsFor = 0;
  int pointsAgainst = 0;
  final List<ShotAttempt> shots = [];
  final List<GameBoxScore> gameList = [];
  final Map<String, PlayerSeason> players = {};

  TeamSeason({required this.key, required this.name});

  double perGame(int v) => games == 0 ? 0 : v / games;
  double get ppg => perGame(pointsFor);
  double get oppPpg => perGame(pointsAgainst);

  /// Pontos por 100 posses (ataque/defesa) e saldo.
  double get offRating => totals.possessions <= 0 ? 0 : pointsFor * 100 / totals.possessions;
  double get defRating => opponents.possessions <= 0 ? 0 : pointsAgainst * 100 / opponents.possessions;
  double get netRating => offRating - defRating;
  double get pace => games == 0 ? 0 : (totals.possessions + opponents.possessions) / 2 / games;

  /// Four factors.
  double get tovPct => totals.possessions <= 0 ? 0 : totals.tov * 100 / totals.possessions;
  double get orbPct {
    final d = totals.oreb + opponents.dreb;
    return d == 0 ? 0 : totals.oreb * 100 / d;
  }

  double get ftRate => totals.fga == 0 ? 0 : totals.ftm * 100 / totals.fga;

  List<PlayerSeason> get roster => players.values.toList()..sort((a, b) => b.ppg.compareTo(a.ppg));
}

class StatsAggregator {
  static String teamKey(String name) => ScheduleParser.normalize(name);

  static Map<String, TeamSeason> build(Iterable<GameBoxScore> games) {
    final teams = <String, TeamSeason>{};
    for (final g in games) {
      for (final t in const [1, 2]) {
        final box = g.team(t);
        final opp = g.team(t == 1 ? 2 : 1);
        final hasData = box.totals.fga > 0 || box.score > 0 || box.players.any((p) => p.played);
        if (!hasData) continue;

        final key = teamKey(box.name);
        final season = teams.putIfAbsent(key, () => TeamSeason(key: key, name: box.name));
        season.leagues.add(g.league);
        season.games++;
        season.gameList.add(g);
        season.totals = season.totals + box.totals;
        season.opponents = season.opponents + opp.totals;
        season.pointsFor += box.score;
        season.pointsAgainst += opp.score;
        if (g.isFinal) {
          if (box.score > opp.score) season.wins++;
          if (box.score < opp.score) season.losses++;
        }
        season.shots.addAll(g.shots.where((s) => s.team == t));

        for (final p in box.players.where((p) => p.played)) {
          final ps = season.players.putIfAbsent(
            p.key,
            () => PlayerSeason(key: p.key, teamKey: key, name: p.name, number: p.number, position: p.position, teamName: box.name),
          );
          ps.games++;
          if (p.starter) ps.starts++;
          ps.totals = ps.totals + p.stats;
          if (p.number.isNotEmpty) ps.number = p.number;
          if (p.position.isNotEmpty) ps.position = p.position;
          ps.log.add(PlayerGameEntry(g, t, p));
          ps.shots.addAll(g.shots.where((s) => s.team == t && s.playerKey == p.key));
        }
      }
    }
    return teams;
  }
}
