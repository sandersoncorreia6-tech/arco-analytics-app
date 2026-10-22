enum CoachGameSource { fpb, lbc, arco }

class CoachGameRecord {
  final String id;
  final CoachGameSource source;
  final String teamId;
  final String seasonId;
  final String league;
  final String category;
  final String homeTeam;
  final String awayTeam;
  final String opponent;
  final bool trackedTeamIsHome;
  final int? homeScore;
  final int? awayScore;
  final DateTime? scheduledAt;
  final String status;
  final String venue;
  final String sourceUrl;
  final bool hasArcoStats;
  final String? arcoGameId;

  const CoachGameRecord({
    required this.id,
    required this.source,
    required this.teamId,
    required this.seasonId,
    required this.league,
    required this.category,
    required this.homeTeam,
    required this.awayTeam,
    required this.opponent,
    required this.trackedTeamIsHome,
    this.homeScore,
    this.awayScore,
    this.scheduledAt,
    required this.status,
    this.venue = '',
    this.sourceUrl = '',
    this.hasArcoStats = false,
    this.arcoGameId,
  });

  bool get hasScore => homeScore != null && awayScore != null;

  bool get isFinal {
    final normalized = status.toUpperCase();
    return normalized.contains('FINAL') ||
        normalized.contains('ENCERR') ||
        normalized.contains('FIM');
  }

  bool get isLive {
    final normalized = status.toUpperCase();
    return normalized.contains('AO VIVO') || normalized.contains('LIVE');
  }

  bool get isUpcoming => !isFinal && !isLive;

  String get scoreLabel => hasScore ? '$homeScore × $awayScore' : '— × —';

  CoachGameRecord copyWith({
    bool? hasArcoStats,
    String? arcoGameId,
  }) {
    return CoachGameRecord(
      id: id,
      source: source,
      teamId: teamId,
      seasonId: seasonId,
      league: league,
      category: category,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      opponent: opponent,
      trackedTeamIsHome: trackedTeamIsHome,
      homeScore: homeScore,
      awayScore: awayScore,
      scheduledAt: scheduledAt,
      status: status,
      venue: venue,
      sourceUrl: sourceUrl,
      hasArcoStats: hasArcoStats ?? this.hasArcoStats,
      arcoGameId: arcoGameId ?? this.arcoGameId,
    );
  }
}
