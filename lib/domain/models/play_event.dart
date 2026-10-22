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

  /// Contexto tático marcado no scout (transição, pick-and-roll...).
  final String? tag;

  const PlayEvent({required this.type, required this.period, required this.timestamp, this.playerId, this.lineupIds = const [], this.tag});

  static const tags = ['Transição', 'Contra-ataque', 'Pick-and-roll', 'Isolamento', 'Bola parada'];

  String get label => switch (type) {
    PlayEventType.twoMade => '2 pontos ✓',
    PlayEventType.twoMiss => '2 pontos ✕',
    PlayEventType.threeMade => '3 pontos ✓',
    PlayEventType.threeMiss => '3 pontos ✕',
    PlayEventType.freeThrowMade => 'Lance livre ✓',
    PlayEventType.freeThrowMiss => 'Lance livre ✕',
    PlayEventType.assist => 'Assistência',
    PlayEventType.offensiveRebound => 'Rebote ofensivo',
    PlayEventType.defensiveRebound => 'Rebote defensivo',
    PlayEventType.steal => 'Roubo',
    PlayEventType.block => 'Toco',
    PlayEventType.turnover => 'Turnover',
    PlayEventType.foul => 'Falta',
    PlayEventType.opponentOne => 'Adversário +1',
    PlayEventType.opponentTwo => 'Adversário +2',
    PlayEventType.opponentThree => 'Adversário +3',
  };

  /// Grupo usado nos filtros de clipes.
  String get group => switch (type) {
    PlayEventType.twoMade || PlayEventType.twoMiss || PlayEventType.threeMade || PlayEventType.threeMiss => 'Arremessos',
    PlayEventType.freeThrowMade || PlayEventType.freeThrowMiss => 'Lances livres',
    PlayEventType.assist => 'Assistências',
    PlayEventType.offensiveRebound || PlayEventType.defensiveRebound => 'Rebotes',
    PlayEventType.steal => 'Roubos',
    PlayEventType.block => 'Tocos',
    PlayEventType.turnover => 'Turnovers',
    PlayEventType.foul => 'Faltas',
    _ => 'Adversário',
  };

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'playerId': playerId,
    'period': period,
    'timestamp': timestamp.toIso8601String(),
    'lineupIds': lineupIds,
    if (tag != null) 'tag': tag,
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
      tag: m['tag'] as String?,
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
