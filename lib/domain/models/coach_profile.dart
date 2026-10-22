import 'package:arco_analytics/data/sources/schedule_parser.dart';
import 'package:arco_analytics/domain/models/league_game.dart';

class CoachProfile {
  /// Identificador do treinador (coachId).
  final String id;
  final String name;
  final String role;
  final String club;
  final String city;

  /// Equipe que o treinador comanda (ex.: Sub-16 masculino da FPB).
  final String team;

  /// Categoria no formato das ligas ("SUB 16 M"); vazio = todas.
  final String category;

  /// Competição principal da equipe.
  final String league;

  /// Temporada acompanhada ("2026"); vazio = todas.
  final String season;

  /// Competições acompanhadas na fonte (id da estatística online ou link),
  /// ex.: a competição "SUB 16M 2026" da FPB.
  final List<String> competitionIds;

  /// Termos que identificam a equipe do treinador nas tabelas das ligas
  /// (comparação sem acentos: "Tupã" encontra "TUPA", "ATB – Associação Tupã Basquete"...).
  final List<String> teamKeywords;

  const CoachProfile({
    this.id = '',
    required this.name,
    required this.role,
    required this.club,
    required this.city,
    this.team = '',
    this.category = '',
    this.league = '',
    this.season = '',
    this.competitionIds = const [],
    this.teamKeywords = const [],
  });

  /// Identificador da equipe acompanhada (teamId): clube + categoria.
  String get teamId => ScheduleParser.normalize('${teamKeywords.isEmpty ? club : teamKeywords.first} $category').replaceAll(' ', '-');

  CoachProfile copyWith({
    String? name,
    String? role,
    String? club,
    String? city,
    String? team,
    String? category,
    String? league,
    String? season,
    List<String>? competitionIds,
    List<String>? teamKeywords,
  }) => CoachProfile(
    id: id,
    name: name ?? this.name,
    role: role ?? this.role,
    club: club ?? this.club,
    city: city ?? this.city,
    team: team ?? this.team,
    category: category ?? this.category,
    league: league ?? this.league,
    season: season ?? this.season,
    competitionIds: competitionIds ?? this.competitionIds,
    teamKeywords: teamKeywords ?? this.teamKeywords,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'club': club,
    'city': city,
    'team': team,
    'category': category,
    'league': league,
    'season': season,
    'competitionIds': competitionIds,
    'teamKeywords': teamKeywords,
  };

  factory CoachProfile.fromJson(Map<String, dynamic> m) => CoachProfile(
    id: (m['id'] as String?) ?? '',
    name: (m['name'] as String?) ?? '',
    role: (m['role'] as String?) ?? 'Treinador',
    club: (m['club'] as String?) ?? '',
    city: (m['city'] as String?) ?? '',
    team: (m['team'] as String?) ?? '',
    category: (m['category'] as String?) ?? '',
    league: (m['league'] as String?) ?? '',
    season: (m['season'] as String?) ?? '',
    competitionIds: ((m['competitionIds'] as List?) ?? const []).map((e) => e.toString()).toList(),
    teamKeywords: ((m['teamKeywords'] as List?) ?? const []).map((e) => e.toString()).toList(),
  );

  /// Rótulo curto da equipe, ex.: "Tupã Sub-16 • FPB".
  String get teamLabel => [team.isEmpty ? club : team, if (league.isNotEmpty) league].join(' • ');

  bool isMyTeam(String teamName) {
    final normalized = ' ${ScheduleParser.normalize(teamName)} ';
    return teamKeywords.any((k) => normalized.contains(' ${ScheduleParser.normalize(k)} '));
  }

  /// A categoria do jogo é a do treinador? Jogos sem categoria informada contam.
  bool isMyCategory(String competition) {
    if (category.isEmpty || competition.trim().isEmpty) return true;
    final want = ScheduleParser.normalize(category).split(' ');
    final got = ScheduleParser.normalize(competition).split(' ');
    // "sub 16" precisa bater; o naipe (m/f) só é comparado quando os dois informam.
    if (want.length >= 2 && got.length >= 2 && (want[0] != got[0] || want[1] != got[1])) return false;
    if (want.length >= 3 && got.length >= 3 && want[2] != got[2]) return false;
    return true;
  }

  /// A temporada do jogo é a acompanhada? Jogos sem data/temporada contam.
  bool isMySeason(LeagueGame g) => season.isEmpty || g.season.isEmpty || g.season == season;

  /// Jogo da equipe do treinador: clube, categoria e temporada certos.
  /// (Não basta o nome "Monstrinho": o Sub-13 e o Sub-16 são equipes diferentes.)
  bool isMyGame(LeagueGame g) => (isMyTeam(g.homeTeam) || isMyTeam(g.awayTeam)) && isMyCategory(g.competition) && isMySeason(g);

  /// O treinador joga em casa nesta partida?
  bool isHome(LeagueGame g) => isMyTeam(g.homeTeam);

  /// Cadastro inicial (o treinador pode editar em Mais → Minha equipe).
  static const adrianoMiao = CoachProfile(
    id: 'coach-adriano-miao',
    name: 'Adriano Mião',
    role: 'Treinador',
    club: 'Tupã / Monstrinho',
    city: 'Tupã - SP',
    team: 'Tupã Sub-16',
    category: 'SUB 16 M',
    league: 'FPB',
    season: '2026',
    teamKeywords: ['Tupã', 'Monstrinho'],
  );
}
