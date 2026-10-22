import '../services/schedule_parser.dart';

class CoachProfile {
  final String name;
  final String role;
  final String club;
  final String city;

  /// Termos que identificam a equipe do treinador nas tabelas das ligas
  /// (comparação sem acentos: "Tupã" encontra "TUPA", "Tupã/SP"...).
  final List<String> teamKeywords;

  const CoachProfile({
    required this.name,
    required this.role,
    required this.club,
    required this.city,
    this.teamKeywords = const [],
  });

  bool isMyTeam(String teamName) {
    final normalized = ' ${ScheduleParser.normalize(teamName)} ';
    return teamKeywords.any((k) => normalized.contains(' ${ScheduleParser.normalize(k)} '));
  }

  static const adrianoMiao = CoachProfile(
    name: 'Adriano Mião',
    role: 'Treinador',
    club: 'Tupã / Monstrinho',
    city: 'Tupã - SP',
    teamKeywords: ['Tupã', 'Monstrinho'],
  );
}
