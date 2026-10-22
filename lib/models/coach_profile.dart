class CoachProfile {
  final String name;
  final String role;
  final String club;
  final String city;

  const CoachProfile({
    required this.name,
    required this.role,
    required this.club,
    required this.city,
  });

  static const adrianoMiao = CoachProfile(
    name: 'Adriano Mião',
    role: 'Treinador',
    club: 'Tupã / Monstrinho',
    city: 'Tupã - SP',
  );
}
