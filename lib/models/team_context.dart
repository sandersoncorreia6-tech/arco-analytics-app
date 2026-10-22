import 'federation_context.dart';

class TeamContext {
  final String organizationId;
  final String teamId;
  final String displayName;
  final String seasonId;
  final int seasonYear;
  final List<String> aliases;
  final FederativeLink federativeLink;

  const TeamContext({
    required this.organizationId,
    required this.teamId,
    required this.displayName,
    required this.seasonId,
    required this.seasonYear,
    required this.aliases,
    required this.federativeLink,
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
      'ATB - Associação Tupã Basquete',
      'ATB Associação Tupã Basquete',
      'F.R. Tupã',
      'FR Tupã',
      'Indians Tupã Basquete',
    ],
    federativeLink: FederativeLink.tupaFpb,
  );

  bool matchesExternalName(String value) {
    final normalizedValue = normalize(value);

    final knownNames = <String>[
      ...aliases,
      ...federativeLink.externalIdentities.map((e) => e.officialName),
    ];

    return knownNames.any((alias) {
      final normalizedAlias = normalize(alias);
      return normalizedValue == normalizedAlias ||
          normalizedValue.contains(normalizedAlias) ||
          normalizedAlias.contains(normalizedValue);
    });
  }

  String get federativePathLabel => 'CBB → FPB';

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
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
