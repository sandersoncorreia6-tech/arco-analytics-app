/// Jogo de uma competição externa (FPB, LBC...).
///
/// O [id] é estável: depende só de liga, categoria, equipes e data — não do
/// placar — para que vídeos vinculados não se percam quando o placar muda.
class LeagueGame {
  final String id;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String competition;
  final String venue;
  final String status;
  final DateTime? scheduledAt;
  final DateTime fetchedAt;
  final String sourceUrl;

  /// `true` quando o jogo foi importado manualmente (texto colado), e não
  /// pela sincronização automática. Jogos manuais sobrevivem às sincronizações.
  final bool manual;

  const LeagueGame({
    required this.id,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    this.competition = '',
    this.venue = '',
    this.status = 'AGENDADO',
    this.scheduledAt,
    required this.fetchedAt,
    required this.sourceUrl,
    this.manual = false,
  });

  bool get hasScore => homeScore != null && awayScore != null;
  bool get isLive => status.toUpperCase().contains('AO VIVO') || status.toUpperCase().contains('LIVE');
  bool get isFinal => status.toUpperCase().contains('FINAL');

  String get scoreLabel => hasScore ? '$homeScore × $awayScore' : '— × —';

  String get dateLabel {
    final d = scheduledAt;
    if (d == null) return '';
    final date = '${_two(d.day)}/${_two(d.month)}/${d.year}';
    if (d.hour == 0 && d.minute == 0) return date;
    return '$date ${_two(d.hour)}:${_two(d.minute)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'id': id,
        'league': league,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'competition': competition,
        'venue': venue,
        'status': status,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'fetchedAt': fetchedAt.toIso8601String(),
        'sourceUrl': sourceUrl,
        'manual': manual,
      };

  factory LeagueGame.fromJson(Map<String, dynamic> m, {required String league, required String fallbackUrl}) => LeagueGame(
        id: m['id'] as String,
        league: (m['league'] as String?) ?? league,
        homeTeam: m['homeTeam'] as String,
        awayTeam: m['awayTeam'] as String,
        homeScore: (m['homeScore'] as num?)?.toInt(),
        awayScore: (m['awayScore'] as num?)?.toInt(),
        competition: (m['competition'] as String?) ?? '',
        venue: (m['venue'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'AGENDADO',
        scheduledAt: m['scheduledAt'] == null ? null : DateTime.tryParse(m['scheduledAt'] as String),
        fetchedAt: DateTime.tryParse(m['fetchedAt'] as String? ?? '') ?? DateTime.now(),
        sourceUrl: (m['sourceUrl'] as String?) ?? fallbackUrl,
        manual: (m['manual'] as bool?) ?? false,
      );
}
