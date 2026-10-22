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
