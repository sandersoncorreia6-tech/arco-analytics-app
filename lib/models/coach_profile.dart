class CoachProfile {
  final String id;
  final String organizationId;
  final String primaryTeamId;
  final String name;
  final String role;
  final String club;
  final String city;

  const CoachProfile({
    this.id = '',
    this.organizationId = '',
    this.primaryTeamId = '',
    required this.name,
    required this.role,
    required this.club,
    required this.city,
  });

  static const adrianoMiao = CoachProfile(
    id: 'coach_adriano_miao',
    organizationId: 'org_tupa_monstrinho',
    primaryTeamId: 'team_tupa_monstrinho',
    name: 'Adriano Mião',
    role: 'Treinador',
    club: 'Tupã / Monstrinho',
    city: 'Tupã - SP',
  );
}
