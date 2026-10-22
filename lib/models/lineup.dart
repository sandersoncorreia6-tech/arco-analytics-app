class Lineup {
  final String name;
  final List<String> players;
  final int possessions;
  final double offensiveRating;
  final double defensiveRating;

  const Lineup({
    required this.name,
    required this.players,
    required this.possessions,
    required this.offensiveRating,
    required this.defensiveRating,
  });

  double get netRating => offensiveRating - defensiveRating;
}
