class TeamContext {
  final String organizationId;
  final String teamId;
  final String displayName;
  final String seasonId;
  final int seasonYear;
  final List<String> aliases;

  const TeamContext({
    required this.organizationId,
    required this.teamId,
    required this.displayName,
    required this.seasonId,
    required this.seasonYear,
    required this.aliases,
  });

  static const tupaMonstrinho2026 = TeamContext(
    organizationId: 'org_tupa_monstrinho',
    teamId: 'team_tupa_monstrinho',
    displayName: 'Tupã / Monstrinho',
    seasonId: 'season_2026',
    seasonYear: 2026,
    aliases: [
      'Tupã',
      'Tupa',
      'Monstrinho',
      'Tupã Basquete',
      'Tupa Basquete',
    ],
  );

  bool matchesExternalName(String value) {
    final normalizedValue = normalize(value);
    return aliases.any((alias) {
      final normalizedAlias = normalize(alias);
      return normalizedValue == normalizedAlias ||
          normalizedValue.contains(normalizedAlias);
    });
  }

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
