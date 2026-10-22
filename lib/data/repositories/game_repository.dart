import 'package:arco_analytics/domain/models/coach_profile.dart';
import 'package:arco_analytics/domain/models/game.dart';
import 'package:arco_analytics/domain/models/league_game.dart';
import 'package:arco_analytics/data/sources/schedule_parser.dart';

/// Visões da área "Jogos" do treinador.
enum GameView { upcoming, recent, all, season }

extension GameViewLabel on GameView {
  String get label => switch (this) {
    GameView.upcoming => 'Próximos',
    GameView.recent => 'Últimos',
    GameView.all => 'Todos',
    GameView.season => 'Temporada',
  };
}

/// Filtros combináveis da lista de jogos. Campos nulos/vazios = sem filtro.
class GameFilter {
  final String season;
  final String category;
  final String competition;
  final int? month;

  /// `true` = mandante, `false` = visitante (do ponto de vista do treinador).
  final bool? home;

  /// 'V' vitória, 'D' derrota.
  final String result;
  final String opponent;

  const GameFilter({this.season = '', this.category = '', this.competition = '', this.month, this.home, this.result = '', this.opponent = ''});

  bool get isEmpty => season.isEmpty && category.isEmpty && competition.isEmpty && month == null && home == null && result.isEmpty && opponent.isEmpty;

  GameFilter copyWith({
    String? season,
    String? category,
    String? competition,
    int? month,
    bool clearMonth = false,
    bool? home,
    bool clearHome = false,
    String? result,
    String? opponent,
  }) => GameFilter(
    season: season ?? this.season,
    category: category ?? this.category,
    competition: competition ?? this.competition,
    month: clearMonth ? null : (month ?? this.month),
    home: clearHome ? null : (home ?? this.home),
    result: result ?? this.result,
    opponent: opponent ?? this.opponent,
  );
}

/// Partida vista pelo treinador: mandante/visitante, adversário e resultado.
class CoachGame {
  final LeagueGame game;
  final bool isHome;
  const CoachGame(this.game, this.isHome);

  String get opponent => isHome ? game.awayTeam : game.homeTeam;
  int? get ourScore => isHome ? game.homeScore : game.awayScore;
  int? get theirScore => isHome ? game.awayScore : game.homeScore;

  /// 'V', 'D', 'E' ou '' (sem placar).
  String get result {
    if (!game.hasScore || !(game.isFinal || game.league == 'SCOUT')) return '';
    final us = ourScore!, them = theirScore!;
    return us > them ? 'V' : (us < them ? 'D' : 'E');
  }
}

/// Histórico completo de jogos: junta todas as fontes, sem duplicar, e
/// responde às consultas da área do treinador.
///
/// Fonte única de verdade para listas de jogos — as telas não filtram dados
/// diretamente. Quando a nuvem (Supabase) estiver ligada, esta classe passa a
/// ler/gravar a tabela `games`, sem mudar as telas.
class GameRepository {
  GameRepository(Iterable<LeagueGame> games) : all = combine(games);

  final List<LeagueGame> all;

  /// Remove duplicatas entre fontes (o mesmo jogo pela tabela da FPB e por uma
  /// notícia), preferindo o registro com mais informação.
  static List<LeagueGame> combine(Iterable<LeagueGame> games) {
    final byKey = <String, LeagueGame>{};
    final byId = <String, String>{};
    for (final g in games) {
      final key = _key(g);
      final existing = byId[g.id] ?? (byKey.containsKey(key) ? key : null);
      if (existing != null && byKey[existing] != null) {
        final a = byKey[existing]!;
        byKey[existing] = _richness(g) > _richness(a) ? g.mergeNewer(a) : a.mergeNewer(g);
      } else {
        byKey[key] = g;
        byId[g.id] = key;
      }
    }
    return byKey.values.toList();
  }

  static String _key(LeagueGame g) {
    final d = g.scheduledAt;
    if (d == null) return 'id:${g.id}';
    return '${ScheduleParser.normalize(g.homeTeam)}|${ScheduleParser.normalize(g.awayTeam)}|${g.categoryId}|${d.year}-${d.month}-${d.day}';
  }

  static int _richness(LeagueGame g) =>
      (g.externalId.isNotEmpty ? 4 : 0) + (g.competitionId.isNotEmpty ? 2 : 0) + (g.hasScore ? 1 : 0) + (g.venue.isNotEmpty ? 1 : 0);

  /// Todos os jogos da equipe do treinador (clube + categoria + temporada).
  List<CoachGame> forCoach(CoachProfile coach, {bool allSeasons = false}) {
    final c = allSeasons ? coach.copyWith(season: '') : coach;
    return [
      for (final g in all)
        if (c.isMyGame(g) || (g.league == 'SCOUT' && c.isMySeason(g))) CoachGame(g, g.league == 'SCOUT' || c.isHome(g)),
    ];
  }

  /// Consulta da área "Jogos".
  static List<CoachGame> query(List<CoachGame> games, GameView view, GameFilter f, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final today = DateTime(t.year, t.month, t.day);
    bool upcoming(CoachGame g) =>
        g.game.isLive || (!g.game.isFinal && !g.game.hasScore && (g.game.scheduledAt == null || !g.game.scheduledAt!.isBefore(today)));

    final opp = ScheduleParser.normalize(f.opponent);
    final list = games.where((g) {
      final x = g.game;
      if (f.season.isNotEmpty && x.season != f.season) return false;
      if (f.category.isNotEmpty && x.categoryId != LeagueGame.categoryIdOf(f.category)) return false;
      if (f.competition.isNotEmpty && x.competitionName != f.competition && x.league != f.competition) return false;
      if (f.month != null && x.scheduledAt?.month != f.month) return false;
      if (f.home != null && g.isHome != f.home) return false;
      if (f.result.isNotEmpty && g.result != f.result) return false;
      if (opp.isNotEmpty && !ScheduleParser.normalize(g.opponent).contains(opp)) return false;
      return switch (view) {
        GameView.upcoming => upcoming(g),
        GameView.recent => !upcoming(g),
        GameView.all || GameView.season => true,
      };
    }).toList();

    int byDate(CoachGame a, CoachGame b, {required bool asc}) {
      final da = a.game.scheduledAt, db = b.game.scheduledAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return asc ? da.compareTo(db) : db.compareTo(da);
    }

    switch (view) {
      case GameView.upcoming:
      case GameView.season:
        list.sort((a, b) => byDate(a, b, asc: true)); // calendário em ordem
      case GameView.recent:
      case GameView.all:
        list.sort((a, b) => byDate(a, b, asc: false)); // mais recentes primeiro
    }
    return list;
  }

  /// Campanha: jogos, vitórias, derrotas e aproveitamento.
  static ({int played, int wins, int losses, double pct, int pointsFor, int pointsAgainst}) record(List<CoachGame> games) {
    var w = 0, l = 0, pf = 0, pa = 0;
    for (final g in games) {
      final r = g.result;
      if (r.isEmpty) continue;
      if (r == 'V') w++;
      if (r == 'D') l++;
      pf += g.ourScore ?? 0;
      pa += g.theirScore ?? 0;
    }
    final played = w + l + games.where((g) => g.result == 'E').length;
    return (played: played, wins: w, losses: l, pct: played == 0 ? 0 : w * 100 / played, pointsFor: pf, pointsAgainst: pa);
  }

  /// Converte um jogo do scout ao vivo em registro de partida.
  static LeagueGame fromScout(Game g, CoachProfile coach, String id) => LeagueGame(
    id: id,
    league: 'SCOUT',
    homeTeam: coach.team.isEmpty ? coach.club : coach.team,
    awayTeam: g.opponent,
    homeScore: g.ourScore,
    awayScore: g.opponentScore,
    competition: coach.category,
    status: 'FINAL',
    scheduledAt: g.date,
    fetchedAt: g.date,
    sourceUrl: '',
    seasonId: g.date.year.toString(),
    competitionName: 'Scout ARCO',
  );
}
