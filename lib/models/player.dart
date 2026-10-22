class Player {
  final String id;
  final String name;
  final String position;
  final int number;

  /// Jogos que compõem os arremessos (fgm/fga/ftm/fta são totais desses jogos;
  /// pontos, rebotes etc. já são médias por jogo).
  final int games;
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
    this.games = 1,
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'number': number,
        'games': games,
        'points': points,
        'assists': assists,
        'rebounds': rebounds,
        'steals': steals,
        'blocks': blocks,
        'turnovers': turnovers,
        'fgm': fgm,
        'fga': fga,
        'threePm': threePm,
        'threePa': threePa,
        'ftm': ftm,
        'fta': fta,
        'onCourtOffRating': onCourtOffRating,
        'onCourtDefRating': onCourtDefRating,
        'offCourtOffRating': offCourtOffRating,
        'offCourtDefRating': offCourtDefRating,
      };

  factory Player.fromJson(Map<String, dynamic> m) => Player(
        id: m['id'] as String,
        name: m['name'] as String,
        position: (m['position'] as String?) ?? 'PG',
        number: (m['number'] as num?)?.toInt() ?? 0,
        games: (m['games'] as num?)?.toInt() ?? 1,
        points: (m['points'] as num?)?.toInt() ?? 0,
        assists: (m['assists'] as num?)?.toInt() ?? 0,
        rebounds: (m['rebounds'] as num?)?.toInt() ?? 0,
        steals: (m['steals'] as num?)?.toInt() ?? 0,
        blocks: (m['blocks'] as num?)?.toInt() ?? 0,
        turnovers: (m['turnovers'] as num?)?.toInt() ?? 0,
        fgm: (m['fgm'] as num?)?.toInt() ?? 0,
        fga: (m['fga'] as num?)?.toInt() ?? 0,
        threePm: (m['threePm'] as num?)?.toInt() ?? 0,
        threePa: (m['threePa'] as num?)?.toInt() ?? 0,
        ftm: (m['ftm'] as num?)?.toInt() ?? 0,
        fta: (m['fta'] as num?)?.toInt() ?? 0,
        onCourtOffRating: (m['onCourtOffRating'] as num?)?.toDouble() ?? 100,
        onCourtDefRating: (m['onCourtDefRating'] as num?)?.toDouble() ?? 100,
        offCourtOffRating: (m['offCourtOffRating'] as num?)?.toDouble() ?? 100,
        offCourtDefRating: (m['offCourtDefRating'] as num?)?.toDouble() ?? 100,
      );
}
