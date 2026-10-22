import '../services/schedule_parser.dart';
import 'league_game.dart';

class CoachProfile {
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

  /// Termos que identificam a equipe do treinador nas tabelas das ligas
  /// (comparação sem acentos: "Tupã" encontra "TUPA", "ATB – Associação Tupã Basquete"...).
  final List<String> teamKeywords;

  const CoachProfile({
    required this.name,
    required this.role,
    required this.club,
    required this.city,
    this.team = '',
    this.category = '',
    this.league = '',
    this.teamKeywords = const [],
  });

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

  /// Jogo da equipe do treinador: clube certo e categoria certa.
  bool isMyGame(LeagueGame g) => (isMyTeam(g.homeTeam) || isMyTeam(g.awayTeam)) && isMyCategory(g.competition);

  static const adrianoMiao = CoachProfile(
    name: 'Adriano Mião',
    role: 'Treinador',
    club: 'Tupã / Monstrinho',
    city: 'Tupã - SP',
    team: 'Tupã Sub-16',
    category: 'SUB 16 M',
    league: 'FPB',
    teamKeywords: ['Tupã', 'Monstrinho'],
  );
}
