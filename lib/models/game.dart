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

  Map<String, dynamic> toJson() => {
        'points': points,
        'assists': assists,
        'offensiveRebounds': offensiveRebounds,
        'defensiveRebounds': defensiveRebounds,
        'steals': steals,
        'blocks': blocks,
        'turnovers': turnovers,
        'fouls': fouls,
        'fgm': fgm,
        'fga': fga,
        'threePm': threePm,
        'threePa': threePa,
        'ftm': ftm,
        'fta': fta,
      };

  factory PlayerStatLine.fromJson(Map<String, dynamic> m) => PlayerStatLine(
        points: (m['points'] as num?)?.toInt() ?? 0,
        assists: (m['assists'] as num?)?.toInt() ?? 0,
        offensiveRebounds: (m['offensiveRebounds'] as num?)?.toInt() ?? 0,
        defensiveRebounds: (m['defensiveRebounds'] as num?)?.toInt() ?? 0,
        steals: (m['steals'] as num?)?.toInt() ?? 0,
        blocks: (m['blocks'] as num?)?.toInt() ?? 0,
        turnovers: (m['turnovers'] as num?)?.toInt() ?? 0,
        fouls: (m['fouls'] as num?)?.toInt() ?? 0,
        fgm: (m['fgm'] as num?)?.toInt() ?? 0,
        fga: (m['fga'] as num?)?.toInt() ?? 0,
        threePm: (m['threePm'] as num?)?.toInt() ?? 0,
        threePa: (m['threePa'] as num?)?.toInt() ?? 0,
        ftm: (m['ftm'] as num?)?.toInt() ?? 0,
        fta: (m['fta'] as num?)?.toInt() ?? 0,
      );
}

class Game {
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

  Map<String, dynamic> toJson() => {
        'opponent': opponent,
        'date': date.toIso8601String(),
        'ourScore': ourScore,
        'opponentScore': opponentScore,
        'possessions': possessions,
        'fgm': fgm,
        'fga': fga,
        'threePm': threePm,
        'threePa': threePa,
        'ftm': ftm,
        'fta': fta,
        'turnovers': turnovers,
        'offensiveRebounds': offensiveRebounds,
        'availableOffensiveRebounds': availableOffensiveRebounds,
        'opponentPoints': opponentPoints,
        'playerStats': {for (final e in playerStats.entries) e.key: e.value.toJson()},
        'events': [for (final e in events) e.toJson()],
      };

  factory Game.fromJson(Map<String, dynamic> m) => Game(
        opponent: m['opponent'] as String,
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        ourScore: (m['ourScore'] as num?)?.toInt() ?? 0,
        opponentScore: (m['opponentScore'] as num?)?.toInt() ?? 0,
        possessions: (m['possessions'] as num?)?.toInt() ?? 0,
        fgm: (m['fgm'] as num?)?.toInt() ?? 0,
        fga: (m['fga'] as num?)?.toInt() ?? 0,
        threePm: (m['threePm'] as num?)?.toInt() ?? 0,
        threePa: (m['threePa'] as num?)?.toInt() ?? 0,
        ftm: (m['ftm'] as num?)?.toInt() ?? 0,
        fta: (m['fta'] as num?)?.toInt() ?? 0,
        turnovers: (m['turnovers'] as num?)?.toInt() ?? 0,
        offensiveRebounds: (m['offensiveRebounds'] as num?)?.toInt() ?? 0,
        availableOffensiveRebounds: (m['availableOffensiveRebounds'] as num?)?.toInt() ?? 0,
        opponentPoints: (m['opponentPoints'] as num?)?.toInt() ?? 0,
        playerStats: {
          for (final e in ((m['playerStats'] as Map?) ?? const {}).entries)
            e.key.toString(): PlayerStatLine.fromJson((e.value as Map).cast<String, dynamic>()),
        },
        events: [
          for (final e in (m['events'] as List?) ?? const [])
            if (PlayEvent.fromJson((e as Map).cast<String, dynamic>()) case final event?) event,
        ],
      );
}
