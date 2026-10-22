import 'package:arco_analytics/domain/models/play_event.dart';

class LiveGameSession {
  final String opponent;
  final DateTime startedAt;
  int period;
  int ourScore;
  int opponentScore;
  bool finished;
  String? selectedPlayerId;
  final List<String> lineupIds;
  final List<PlayEvent> events;
  final Map<String, PlayerGameStats> playerStats;

  LiveGameSession({
    required this.opponent,
    required this.startedAt,
    required this.lineupIds,
    this.period = 1,
    this.ourScore = 0,
    this.opponentScore = 0,
    this.finished = false,
    this.selectedPlayerId,
    List<PlayEvent>? events,
    Map<String, PlayerGameStats>? playerStats,
  }) : events = events ?? [],
       playerStats = playerStats ?? {};

  int get fgm => playerStats.values.fold(0, (sum, s) => sum + s.fgm);
  int get fga => playerStats.values.fold(0, (sum, s) => sum + s.fga);
  int get threePm => playerStats.values.fold(0, (sum, s) => sum + s.threePm);
  int get threePa => playerStats.values.fold(0, (sum, s) => sum + s.threePa);
  int get ftm => playerStats.values.fold(0, (sum, s) => sum + s.ftm);
  int get fta => playerStats.values.fold(0, (sum, s) => sum + s.fta);
  int get turnovers => playerStats.values.fold(0, (sum, s) => sum + s.turnovers);
  int get offensiveRebounds => playerStats.values.fold(0, (sum, s) => sum + s.offensiveRebounds);

  String get periodLabel => period >= 5 ? 'Prorrogação' : '${period}Q';

  double get estimatedPossessions {
    final estimate = fga - offensiveRebounds + turnovers + (0.44 * fta);
    return estimate < 1 ? 1 : estimate;
  }

  Map<String, dynamic> toJson() => {
    'opponent': opponent,
    'startedAt': startedAt.toIso8601String(),
    'period': period,
    'ourScore': ourScore,
    'opponentScore': opponentScore,
    'finished': finished,
    'selectedPlayerId': selectedPlayerId,
    'lineupIds': lineupIds,
    'events': [for (final e in events) e.toJson()],
    'playerStats': {for (final e in playerStats.entries) e.key: e.value.toJson()},
  };

  factory LiveGameSession.fromJson(Map<String, dynamic> m) => LiveGameSession(
    opponent: m['opponent'] as String,
    startedAt: DateTime.tryParse(m['startedAt'] as String? ?? '') ?? DateTime.now(),
    period: (m['period'] as num?)?.toInt() ?? 1,
    ourScore: (m['ourScore'] as num?)?.toInt() ?? 0,
    opponentScore: (m['opponentScore'] as num?)?.toInt() ?? 0,
    finished: (m['finished'] as bool?) ?? false,
    selectedPlayerId: m['selectedPlayerId'] as String?,
    lineupIds: ((m['lineupIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    events: [
      for (final e in (m['events'] as List?) ?? const [])
        if (PlayEvent.fromJson((e as Map).cast<String, dynamic>()) case final event?) event,
    ],
    playerStats: {
      for (final e in ((m['playerStats'] as Map?) ?? const {}).entries) e.key.toString(): PlayerGameStats.fromJson((e.value as Map).cast<String, dynamic>()),
    },
  );
}
