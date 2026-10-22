import '../models/league_game.dart';
import '../services/league_sync_service.dart';

/// Estado de sincronização de uma competição (FPB, LBC...).
class LeagueFeed {
  LeagueFeed(this.source) : service = LeagueSyncService(source);

  final LeagueSource source;
  final LeagueSyncService service;

  final List<LeagueGame> games = [];

  /// Páginas extras do mesmo site cadastradas pelo treinador (ex.: tabela da categoria).
  final List<String> extraPages = [];

  bool syncing = false;
  DateTime? lastSyncAt;
  DateTime? lastAttemptAt;

  /// Erro da última tentativa (rede, HTTP...). Os jogos em cache continuam visíveis.
  String? error;

  /// A fonte respondeu, mas nada foi interpretado.
  String? warning;

  List<SourceAttempt> lastAttempts = const [];

  String get league => source.league;
  bool get hasLive => games.any((g) => g.isLive);
  bool get healthy => error == null && warning == null;

  /// Ao vivo: 30 s. Sem jogos ao vivo: 3 min (economiza bateria e dados).
  Duration get refreshInterval => hasLive ? const Duration(seconds: 30) : const Duration(minutes: 3);

  bool isDue(DateTime now) => lastAttemptAt == null || now.difference(lastAttemptAt!) >= refreshInterval;

  String get cacheKey => '${league.toLowerCase()}_snapshot_v2';
  String get syncKey => '${league.toLowerCase()}_last_sync_v2';
  String get pagesKey => '${league.toLowerCase()}_extra_pages_v1';

  /// Aplica o resultado da sincronização como HISTÓRICO: jogos novos entram,
  /// jogos conhecidos são atualizados (placar, horário, status) e nenhum jogo
  /// antigo é descartado — as páginas da liga mostram só a rodada/notícias
  /// recentes, e substituir a lista fazia a temporada "encolher".
  void apply(LeagueSyncResult result) {
    lastSyncAt = result.fetchedAt;
    lastAttempts = result.attempts;
    error = null;
    warning = result.warning;
    upsert(result.games);
  }

  /// Insere/atualiza por gameId; reconhece o mesmo jogo vindo de outra página
  /// (mesmas equipes no mesmo dia) para não duplicar.
  void upsert(Iterable<LeagueGame> incoming) {
    final byId = {for (final g in games) g.id: g};
    final byMatchup = {for (final g in games) _matchupKey(g): g.id};
    for (final n in incoming) {
      var existingId = byId.containsKey(n.id) ? n.id : byMatchup[_matchupKey(n)];
      // Fonte sem categoria (ex.: notícia): casa com o único jogo das mesmas
      // equipes no mesmo dia. Em fins de semana com várias categorias do mesmo
      // confronto não há casamento único, e o jogo entra separado.
      if (existingId == null && n.categoryId.isEmpty && n.scheduledAt != null) {
        final loose = _matchupKey(n).replaceFirst('||', '|');
        final same = byId.values.where((g) => _matchupKey(g).replaceFirst('|${g.categoryId}|', '|') == loose).toList();
        if (same.length == 1) existingId = same.first.id;
      }
      if (existingId != null && byId[existingId] != null) {
        byId[existingId] = byId[existingId]!.mergeNewer(n);
      } else {
        byId[n.id] = n;
        byMatchup[_matchupKey(n)] = n.id;
      }
    }
    games
      ..clear()
      ..addAll(byId.values);
    sort();
  }

  static String _matchupKey(LeagueGame g) {
    String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9à-ÿ]'), '');
    final d = g.scheduledAt;
    final day = d == null ? 'sem-data:${g.id}' : '${d.year}-${d.month}-${d.day}';
    return '${n(g.homeTeam)}|${n(g.awayTeam)}|${g.categoryId}|$day';
  }

  void sort() => games.sort(compareGames);

  /// Ao vivo → próximos (mais cedo primeiro) → resultados (mais recentes primeiro) → sem data.
  static int compareGames(LeagueGame a, LeagueGame b) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int bucket(LeagueGame g) {
      if (g.isLive) return 0;
      final d = g.scheduledAt;
      if (d == null) return 3;
      return d.isBefore(today) || (g.hasScore && !d.isAfter(now)) ? 2 : 1;
    }

    final ba = bucket(a), bb = bucket(b);
    if (ba != bb) return ba.compareTo(bb);
    if (ba == 1) return a.scheduledAt!.compareTo(b.scheduledAt!);
    if (ba == 2) return b.scheduledAt!.compareTo(a.scheduledAt!);
    return '${a.league}${a.homeTeam}'.compareTo('${b.league}${b.homeTeam}');
  }
}
