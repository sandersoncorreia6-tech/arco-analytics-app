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
  final double? shotX;
  final double? shotY;

  const PlayEvent({
    required this.type,
    required this.period,
    required this.timestamp,
    this.playerId,
    this.lineupIds = const [],
    this.shotX,
    this.shotY,
  });

  bool get hasShotLocation => shotX != null && shotY != null;

  bool get isShot =>
      type == PlayEventType.twoMade ||
      type == PlayEventType.twoMiss ||
      type == PlayEventType.threeMade ||
      type == PlayEventType.threeMiss;

  bool get shotMade =>
      type == PlayEventType.twoMade || type == PlayEventType.threeMade;

  int get shotPoints =>
      type == PlayEventType.threeMade || type == PlayEventType.threeMiss ? 3 : 2;
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
}
