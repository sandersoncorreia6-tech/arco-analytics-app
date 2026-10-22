enum PlayEventType {
  twoMade,
  twoMiss,
  threeMade,
  threeMiss,
  freeThrowMade,
  freeThrowMiss,
  assist,
  offensiveRebound,
  defensiveRebound,
  steal,
  block,
  turnover,
  foul,
  opponentOne,
  opponentTwo,
  opponentThree,
}

class PlayEvent {
  final PlayEventType type;
  final String? playerId;
  final int period;
  final DateTime timestamp;
  final List<String> lineupIds;

  const PlayEvent({
    required this.type,
    required this.period,
    required this.timestamp,
    this.playerId,
    this.lineupIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'playerId': playerId,
        'period': period,
        'timestamp': timestamp.toIso8601String(),
        'lineupIds': lineupIds,
      };

  /// `null` para tipos desconhecidos (dados de uma versão futura do app).
  static PlayEvent? fromJson(Map<String, dynamic> m) {
    final type = PlayEventType.values.where((t) => t.name == m['type']).firstOrNull;
    if (type == null) return null;
    return PlayEvent(
      type: type,
      playerId: m['playerId'] as String?,
      period: (m['period'] as num?)?.toInt() ?? 1,
      timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
      lineupIds: ((m['lineupIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class PlayerGameStats {
  int points = 0;
  int assists = 0;
  int offensiveRebounds = 0;
  int defensiveRebounds = 0;
  int steals = 0;
  int blocks = 0;
  int turnovers = 0;
  int fouls = 0;
  int fgm = 0;
  int fga = 0;
  int threePm = 0;
  int threePa = 0;
  int ftm = 0;
  int fta = 0;

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

  static PlayerGameStats fromJson(Map<String, dynamic> m) => PlayerGameStats()
    ..points = (m['points'] as num?)?.toInt() ?? 0
    ..assists = (m['assists'] as num?)?.toInt() ?? 0
    ..offensiveRebounds = (m['offensiveRebounds'] as num?)?.toInt() ?? 0
    ..defensiveRebounds = (m['defensiveRebounds'] as num?)?.toInt() ?? 0
    ..steals = (m['steals'] as num?)?.toInt() ?? 0
    ..blocks = (m['blocks'] as num?)?.toInt() ?? 0
    ..turnovers = (m['turnovers'] as num?)?.toInt() ?? 0
    ..fouls = (m['fouls'] as num?)?.toInt() ?? 0
    ..fgm = (m['fgm'] as num?)?.toInt() ?? 0
    ..fga = (m['fga'] as num?)?.toInt() ?? 0
    ..threePm = (m['threePm'] as num?)?.toInt() ?? 0
    ..threePa = (m['threePa'] as num?)?.toInt() ?? 0
    ..ftm = (m['ftm'] as num?)?.toInt() ?? 0
    ..fta = (m['fta'] as num?)?.toInt() ?? 0;
}
