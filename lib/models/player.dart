class Player {
  final String id;
  final String name;
  final String position;
  final int number;
  final int points;
  final int assists;
  final int rebounds;
  final int steals;
  final int blocks;
  final int turnovers;
  final int fgm;
  final int fga;
  final int threePm;
  final int threePa;
  final int ftm;
  final int fta;
  final double onCourtOffRating;
  final double onCourtDefRating;
  final double offCourtOffRating;
  final double offCourtDefRating;

  const Player({
    required this.id,
    required this.name,
    required this.position,
    required this.number,
    this.points = 0,
    this.assists = 0,
    this.rebounds = 0,
    this.steals = 0,
    this.blocks = 0,
    this.turnovers = 0,
    this.fgm = 0,
    this.fga = 0,
    this.threePm = 0,
    this.threePa = 0,
    this.ftm = 0,
    this.fta = 0,
    this.onCourtOffRating = 100,
    this.onCourtDefRating = 100,
    this.offCourtOffRating = 100,
    this.offCourtDefRating = 100,
  });
}
