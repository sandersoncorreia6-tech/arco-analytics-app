class LbcGameSnapshot {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String competition;
  final String status;
  final DateTime? scheduledAt;
  final DateTime fetchedAt;
  final String sourceUrl;

  const LbcGameSnapshot({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    this.competition = '',
    this.status = 'AGENDADO',
    this.scheduledAt,
    required this.fetchedAt,
    required this.sourceUrl,
  });

  bool get hasScore => homeScore != null && awayScore != null;
  bool get isLive => status.toUpperCase().contains('AO VIVO') || status.toUpperCase().contains('LIVE');
  String get scoreLabel => hasScore ? '$homeScore × $awayScore' : '— × —';
}
