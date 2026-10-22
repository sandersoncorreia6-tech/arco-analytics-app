import 'play_event.dart';

class PlayerStatLine {
  final int points;
  final int assists;
  final int offensiveRebounds;
  final int defensiveRebounds;
  final int steals;
  final int blocks;
  final int turnovers;
  final int fouls;
  final int fgm;
  final int fga;
  final int threePm;
  final int threePa;
  final int ftm;
  final int fta;

  const PlayerStatLine({
    this.points = 0,
    this.assists = 0,
    this.offensiveRebounds = 0,
    this.defensiveRebounds = 0,
    this.steals = 0,
    this.blocks = 0,
    this.turnovers = 0,
    this.fouls = 0,
    this.fgm = 0,
    this.fga = 0,
    this.threePm = 0,
    this.threePa = 0,
    this.ftm = 0,
    this.fta = 0,
  });

  int get rebounds => offensiveRebounds + defensiveRebounds;
}

class Game {
  final String id;
  final String teamId;
  final String seasonId;
  final String competition;
  final String category;
  final String venue;
  final String source;
  final String sourceUrl;
  final bool isHome;
  final String opponent;
  final DateTime date;
  final int ourScore;
  final int opponentScore;
  final int possessions;
  final int fgm;
  final int fga;
  final int threePm;
  final int threePa;
  final int ftm;
  final int fta;
  final int turnovers;
  final int offensiveRebounds;
  final int availableOffensiveRebounds;
  final int opponentPoints;
  final Map<String, PlayerStatLine> playerStats;
  final List<PlayEvent> events;

  const Game({
    this.id = '',
    this.teamId = '',
    this.seasonId = '',
    this.competition = '',
    this.category = '',
    this.venue = '',
    this.source = 'arco',
    this.sourceUrl = '',
    this.isHome = true,
    required this.opponent,
    required this.date,
    required this.ourScore,
    required this.opponentScore,
    required this.possessions,
    required this.fgm,
    required this.fga,
    required this.threePm,
    required this.threePa,
    required this.ftm,
    required this.fta,
    required this.turnovers,
    required this.offensiveRebounds,
    required this.availableOffensiveRebounds,
    required this.opponentPoints,
    this.playerStats = const {},
    this.events = const [],
  });

  bool get won => ourScore > opponentScore;
}
