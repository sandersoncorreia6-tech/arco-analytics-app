import 'play_event.dart';

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
  })  : events = events ?? [],
        playerStats = playerStats ?? {};

  int get fgm => playerStats.values.fold(0, (sum, s) => sum + s.fgm);
  int get fga => playerStats.values.fold(0, (sum, s) => sum + s.fga);
  int get threePm => playerStats.values.fold(0, (sum, s) => sum + s.threePm);
  int get threePa => playerStats.values.fold(0, (sum, s) => sum + s.threePa);
  int get ftm => playerStats.values.fold(0, (sum, s) => sum + s.ftm);
  int get fta => playerStats.values.fold(0, (sum, s) => sum + s.fta);
  int get turnovers => playerStats.values.fold(0, (sum, s) => sum + s.turnovers);
  int get offensiveRebounds => playerStats.values.fold(0, (sum, s) => sum + s.offensiveRebounds);

  double get estimatedPossessions {
    final estimate = fga - offensiveRebounds + turnovers + (0.44 * fta);
    return estimate < 1 ? 1 : estimate;
  }
}
