/// Registro canônico de uma partida (FPB, LBC, scout do ARCO ou manual).
///
/// Identificação própria e estável:
/// * [id] (gameId) — não muda com o placar, para vídeos e análises vinculados
///   não se perderem; para partidas da estatística online é `<liga>_m<id>`.
/// * [competitionId], [seasonId], [categoryId] — hierarquia
///   competição → temporada → categoria.
/// * [homeTeamId]/[awayTeamId] — equipes (id da fonte quando existe; senão o
///   nome normalizado + categoria, para "Monstrinho Sub-13" ≠ "Monstrinho Sub-16").
/// * [externalId] — id da partida na estatística online (box score, arremessos).
class LeagueGame {
  final String id;

  /// Fonte/organizadora: 'FPB', 'LBC', 'SCOUT', 'MANUAL'.
  final String league;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;

  /// Categoria no formato das ligas ("SUB 16 M").
  final String competition;
  final String venue;
  final String status;
  final DateTime? scheduledAt;

  /// Última atualização vinda da fonte.
  final DateTime fetchedAt;

  /// Página oficial da partida/competição.
  final String sourceUrl;

  /// `true` quando o jogo foi importado manualmente (texto colado).
  final bool manual;

  final String competitionId;

  /// Nome da competição na fonte ("SUB 16M 2026", "Campeonato Estadual SUB 16 Masculino").
  final String competitionName;
  final String seasonId;
  final String round;
  final String homeTeamId;
  final String awayTeamId;
  final String externalId;

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
    this.competitionId = '',
    this.competitionName = '',
    this.seasonId = '',
    this.round = '',
    this.homeTeamId = '',
    this.awayTeamId = '',
    this.externalId = '',
  });

  String get gameId => id;

  /// "SUB 16 M" → "sub16m"; vazio quando a categoria não é conhecida.
  String get categoryId => categoryIdOf(competition);

  /// Temporada informada pela fonte, ou o ano da partida.
  String get season => seasonId.isNotEmpty ? seasonId : (scheduledAt?.year.toString() ?? '');

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

  static String categoryIdOf(String category) => category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Atualiza este registro com dados mais novos da fonte, sem perder o que a
  /// nova leitura não trouxe (ids, local, rodada, placar já conhecido...).
  LeagueGame mergeNewer(LeagueGame n) => LeagueGame(
        id: id,
        league: league,
        homeTeam: n.homeTeam.isNotEmpty ? n.homeTeam : homeTeam,
        awayTeam: n.awayTeam.isNotEmpty ? n.awayTeam : awayTeam,
        homeScore: n.homeScore ?? homeScore,
        awayScore: n.awayScore ?? awayScore,
        competition: n.competition.isNotEmpty ? n.competition : competition,
        venue: n.venue.isNotEmpty ? n.venue : venue,
        // Um jogo encerrado não "volta" a agendado só porque a página mudou.
        status: isFinal && !n.isFinal && !n.isLive && !n.hasScore ? status : n.status,
        scheduledAt: n.scheduledAt ?? scheduledAt,
        fetchedAt: n.fetchedAt.isAfter(fetchedAt) ? n.fetchedAt : fetchedAt,
        sourceUrl: n.sourceUrl.isNotEmpty ? n.sourceUrl : sourceUrl,
        manual: manual && n.manual,
        competitionId: n.competitionId.isNotEmpty ? n.competitionId : competitionId,
        competitionName: n.competitionName.isNotEmpty ? n.competitionName : competitionName,
        seasonId: n.seasonId.isNotEmpty ? n.seasonId : seasonId,
        round: n.round.isNotEmpty ? n.round : round,
        homeTeamId: n.homeTeamId.isNotEmpty ? n.homeTeamId : homeTeamId,
        awayTeamId: n.awayTeamId.isNotEmpty ? n.awayTeamId : awayTeamId,
        externalId: n.externalId.isNotEmpty ? n.externalId : externalId,
      );

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
        if (competitionId.isNotEmpty) 'competitionId': competitionId,
        if (competitionName.isNotEmpty) 'competitionName': competitionName,
        if (seasonId.isNotEmpty) 'seasonId': seasonId,
        if (round.isNotEmpty) 'round': round,
        if (homeTeamId.isNotEmpty) 'homeTeamId': homeTeamId,
        if (awayTeamId.isNotEmpty) 'awayTeamId': awayTeamId,
        if (externalId.isNotEmpty) 'externalId': externalId,
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
        competitionId: (m['competitionId'] as String?) ?? '',
        competitionName: (m['competitionName'] as String?) ?? '',
        seasonId: (m['seasonId'] as String?) ?? '',
        round: (m['round'] as String?) ?? '',
        homeTeamId: (m['homeTeamId'] as String?) ?? '',
        awayTeamId: (m['awayTeamId'] as String?) ?? '',
        externalId: (m['externalId'] as String?) ?? '',
      );
}

/// "1 jogo", "3 jogos".
String gamesCount(int n) => n == 1 ? '1 jogo' : '$n jogos';
