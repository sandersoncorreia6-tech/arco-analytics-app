/// Estatísticas completas de uma partida (box score, mapa de arremessos e
/// lance a lance), importadas da estatística online das ligas.

/// Linha estatística (de um jogador ou de uma equipe, em um jogo ou somada).
class StatLine {
  final int points;
  final int fgm, fga, tpm, tpa, ftm, fta;
  final int oreb, dreb, ast, tov, stl, blk, pf;
  final int plusMinus;

  /// Segundos em quadra.
  final int seconds;

  const StatLine({
    this.points = 0,
    this.fgm = 0,
    this.fga = 0,
    this.tpm = 0,
    this.tpa = 0,
    this.ftm = 0,
    this.fta = 0,
    this.oreb = 0,
    this.dreb = 0,
    this.ast = 0,
    this.tov = 0,
    this.stl = 0,
    this.blk = 0,
    this.pf = 0,
    this.plusMinus = 0,
    this.seconds = 0,
  });

  static const zero = StatLine();

  int get reb => oreb + dreb;
  int get twoPm => fgm - tpm;
  int get twoPa => fga - tpa;
  double get minutes => seconds / 60;

  /// Eficiência FIBA: (PTS + REB + AST + STL + BLK) − (arremessos errados + LL errados + TO).
  int get efficiency => points + reb + ast + stl + blk - (fga - fgm) - (fta - ftm) - tov;

  static double pct(int made, int att) => att == 0 ? 0 : made * 100 / att;
  double get fgPct => pct(fgm, fga);
  double get tpPct => pct(tpm, tpa);
  double get twoPct => pct(twoPm, twoPa);
  double get ftPct => pct(ftm, fta);
  double get efgPct => fga == 0 ? 0 : (fgm + 0.5 * tpm) * 100 / fga;
  double get tsPct {
    final d = 2 * (fga + 0.44 * fta);
    return d == 0 ? 0 : points * 100 / d;
  }

  /// Posses estimadas (fórmula padrão).
  double get possessions => fga - oreb + tov + 0.44 * fta;

  StatLine operator +(StatLine o) => StatLine(
    points: points + o.points,
    fgm: fgm + o.fgm,
    fga: fga + o.fga,
    tpm: tpm + o.tpm,
    tpa: tpa + o.tpa,
    ftm: ftm + o.ftm,
    fta: fta + o.fta,
    oreb: oreb + o.oreb,
    dreb: dreb + o.dreb,
    ast: ast + o.ast,
    tov: tov + o.tov,
    stl: stl + o.stl,
    blk: blk + o.blk,
    pf: pf + o.pf,
    plusMinus: plusMinus + o.plusMinus,
    seconds: seconds + o.seconds,
  );

  static const _keys = ['pts', 'fgm', 'fga', 'tpm', 'tpa', 'ftm', 'fta', 'oreb', 'dreb', 'ast', 'tov', 'stl', 'blk', 'pf', 'pm', 'sec'];

  List<int> get _values => [points, fgm, fga, tpm, tpa, ftm, fta, oreb, dreb, ast, tov, stl, blk, pf, plusMinus, seconds];

  Map<String, dynamic> toJson() => {for (var i = 0; i < _keys.length; i++) _keys[i]: _values[i]};

  factory StatLine.fromJson(Map<String, dynamic> m) {
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return StatLine(
      points: v('pts'),
      fgm: v('fgm'),
      fga: v('fga'),
      tpm: v('tpm'),
      tpa: v('tpa'),
      ftm: v('ftm'),
      fta: v('fta'),
      oreb: v('oreb'),
      dreb: v('dreb'),
      ast: v('ast'),
      tov: v('tov'),
      stl: v('stl'),
      blk: v('blk'),
      pf: v('pf'),
      plusMinus: v('pm'),
      seconds: v('sec'),
    );
  }
}

/// Arremesso com posição na quadra.
///
/// Coordenadas normalizadas para MEIA quadra, do ponto de vista do ataque:
/// [x] 0 → 1 da lateral esquerda à direita; [y] 0 → 1 da linha de fundo
/// (cesta) até o meio da quadra.
class ShotAttempt {
  final double x;
  final double y;
  final bool made;
  final int points;
  final int period;
  final String player;
  final String playerKey;
  final int team;
  final String subType;

  const ShotAttempt({
    required this.x,
    required this.y,
    required this.made,
    required this.points,
    this.period = 1,
    this.player = '',
    this.playerKey = '',
    this.team = 1,
    this.subType = '',
  });

  bool get isThree => points == 3;

  Map<String, dynamic> toJson() => {
    'x': double.parse(x.toStringAsFixed(4)),
    'y': double.parse(y.toStringAsFixed(4)),
    'm': made ? 1 : 0,
    'p': points,
    'per': period,
    'pl': player,
    'pk': playerKey,
    't': team,
    'st': subType,
  };

  factory ShotAttempt.fromJson(Map<String, dynamic> m) => ShotAttempt(
    x: (m['x'] as num).toDouble(),
    y: (m['y'] as num).toDouble(),
    made: m['m'] == 1,
    points: (m['p'] as num?)?.toInt() ?? 2,
    period: (m['per'] as num?)?.toInt() ?? 1,
    player: (m['pl'] as String?) ?? '',
    playerKey: (m['pk'] as String?) ?? '',
    team: (m['t'] as num?)?.toInt() ?? 1,
    subType: (m['st'] as String?) ?? '',
  );
}

class PlayerBox {
  /// Identificador do jogador dentro da equipe (nome normalizado).
  final String key;

  /// Número de cadastro na súmula eletrônica (liga o box score ao lance a lance).
  final int pno;
  final String name;
  final String number;
  final String position;
  final bool starter;
  final StatLine stats;

  const PlayerBox({
    required this.key,
    required this.name,
    this.pno = 0,
    this.number = '',
    this.position = '',
    this.starter = false,
    this.stats = StatLine.zero,
  });

  bool get played => stats.seconds > 0 || stats.fga > 0 || stats.fta > 0 || stats.reb > 0 || stats.points > 0;

  Map<String, dynamic> toJson() => {'k': key, 'pno': pno, 'n': name, 'no': number, 'pos': position, 'st': starter, 's': stats.toJson()};

  factory PlayerBox.fromJson(Map<String, dynamic> m) => PlayerBox(
    key: m['k'] as String,
    pno: (m['pno'] as num?)?.toInt() ?? 0,
    name: m['n'] as String,
    number: (m['no'] as String?) ?? '',
    position: (m['pos'] as String?) ?? '',
    starter: (m['st'] as bool?) ?? false,
    stats: StatLine.fromJson((m['s'] as Map).cast<String, dynamic>()),
  );
}

class TeamBox {
  final String name;
  final String code;
  final int score;
  final List<int> periodScores;
  final StatLine totals;
  final List<PlayerBox> players;

  /// Extras do sistema de estatística (pontos no garrafão, contra-ataque...).
  final Map<String, int> extras;

  const TeamBox({
    required this.name,
    this.code = '',
    this.score = 0,
    this.periodScores = const [],
    this.totals = StatLine.zero,
    this.players = const [],
    this.extras = const {},
  });

  Map<String, dynamic> toJson() => {
    'n': name,
    'c': code,
    's': score,
    'ps': periodScores,
    't': totals.toJson(),
    'pl': [for (final p in players) p.toJson()],
    'x': extras,
  };

  factory TeamBox.fromJson(Map<String, dynamic> m) => TeamBox(
    name: m['n'] as String,
    code: (m['c'] as String?) ?? '',
    score: (m['s'] as num?)?.toInt() ?? 0,
    periodScores: ((m['ps'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
    totals: StatLine.fromJson((m['t'] as Map).cast<String, dynamic>()),
    players: [for (final p in (m['pl'] as List?) ?? const []) PlayerBox.fromJson((p as Map).cast<String, dynamic>())],
    extras: ((m['x'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
  );
}

/// Uma ação do lance a lance.
class PlayAction {
  final int period;
  final String clock;
  final int team;
  final int pno;
  final String player;
  final String type;
  final String subType;
  final bool success;
  final String score;

  const PlayAction({
    required this.period,
    required this.clock,
    required this.team,
    this.pno = 0,
    required this.player,
    required this.type,
    this.subType = '',
    this.success = false,
    this.score = '',
  });

  /// Segundos restantes no período ("09:45" → 585).
  int get clockSeconds {
    final m = RegExp(r'^(\d+):(\d{1,2})').firstMatch(clock);
    return m == null ? 0 : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  bool get isScoring => success && (type == '2pt' || type == '3pt' || type == 'freethrow');
  int get points => !isScoring ? 0 : (type == '3pt' ? 3 : (type == '2pt' ? 2 : 1));

  /// Descrição em português.
  String get label {
    final ok = success ? 'convertido' : 'errado';
    switch (type) {
      case '2pt':
        return 'Arremesso de 2 $ok${subType.isEmpty ? '' : ' ($subType)'}';
      case '3pt':
        return 'Arremesso de 3 $ok';
      case 'freethrow':
        return 'Lance livre $ok';
      case 'rebound':
        return subType == 'offensive' ? 'Rebote ofensivo' : (subType == 'defensive' ? 'Rebote defensivo' : 'Rebote');
      case 'assist':
        return 'Assistência';
      case 'steal':
        return 'Roubo de bola';
      case 'block':
        return 'Toco';
      case 'turnover':
        return 'Erro (turnover)';
      case 'foul':
        return 'Falta${subType.isEmpty ? '' : ' ($subType)'}';
      case 'substitution':
        return subType == 'in' ? 'Entra' : (subType == 'out' ? 'Sai' : 'Substituição');
      case 'timeout':
        return 'Pedido de tempo';
      case 'jumpball':
        return 'Bola ao alto';
      case 'period':
        return subType == 'start' ? 'Início do período' : (subType == 'end' ? 'Fim do período' : 'Período');
      case 'game':
        return subType == 'end' ? 'Fim de jogo' : 'Jogo';
      default:
        return [type, subType].where((e) => e.isNotEmpty).join(' ');
    }
  }

  Map<String, dynamic> toJson() => {'p': period, 'c': clock, 't': team, 'pno': pno, 'pl': player, 'ty': type, 'st': subType, 'ok': success, 's': score};

  factory PlayAction.fromJson(Map<String, dynamic> m) => PlayAction(
    period: (m['p'] as num?)?.toInt() ?? 1,
    clock: (m['c'] as String?) ?? '',
    team: (m['t'] as num?)?.toInt() ?? 0,
    pno: (m['pno'] as num?)?.toInt() ?? 0,
    player: (m['pl'] as String?) ?? '',
    type: (m['ty'] as String?) ?? '',
    subType: (m['st'] as String?) ?? '',
    success: (m['ok'] as bool?) ?? false,
    score: (m['s'] as String?) ?? '',
  );
}

class GameBoxScore {
  /// Id da partida no sistema de estatística (ex.: FIBA LiveStats).
  final String matchId;
  final String league;
  final String sourceUrl;
  final TeamBox home;
  final TeamBox away;
  final String status;
  final int period;
  final String clock;
  final DateTime fetchedAt;
  final List<ShotAttempt> shots;
  final List<PlayAction> plays;

  const GameBoxScore({
    required this.matchId,
    required this.league,
    required this.sourceUrl,
    required this.home,
    required this.away,
    required this.status,
    required this.fetchedAt,
    this.period = 0,
    this.clock = '',
    this.shots = const [],
    this.plays = const [],
  });

  bool get isFinal => status == 'FINAL';
  bool get isLive => status == 'AO VIVO';

  TeamBox team(int t) => t == 1 ? home : away;

  Map<String, dynamic> toJson() => {
    'id': matchId,
    'lg': league,
    'url': sourceUrl,
    'h': home.toJson(),
    'a': away.toJson(),
    'st': status,
    'per': period,
    'clk': clock,
    'at': fetchedAt.toIso8601String(),
    'sh': [for (final s in shots) s.toJson()],
    'pbp': [for (final p in plays) p.toJson()],
  };

  factory GameBoxScore.fromJson(Map<String, dynamic> m) => GameBoxScore(
    matchId: m['id'] as String,
    league: (m['lg'] as String?) ?? 'FPB',
    sourceUrl: (m['url'] as String?) ?? '',
    home: TeamBox.fromJson((m['h'] as Map).cast<String, dynamic>()),
    away: TeamBox.fromJson((m['a'] as Map).cast<String, dynamic>()),
    status: (m['st'] as String?) ?? 'FINAL',
    period: (m['per'] as num?)?.toInt() ?? 0,
    clock: (m['clk'] as String?) ?? '',
    fetchedAt: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
    shots: [for (final s in (m['sh'] as List?) ?? const []) ShotAttempt.fromJson((s as Map).cast<String, dynamic>())],
    plays: [for (final p in (m['pbp'] as List?) ?? const []) PlayAction.fromJson((p as Map).cast<String, dynamic>())],
  );
}
