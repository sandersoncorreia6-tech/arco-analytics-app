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

  /// Aplica o resultado da sincronização sem descartar jogos importados
  /// manualmente e sem apagar o cache quando a página veio vazia.
  void apply(LeagueSyncResult result) {
    lastSyncAt = result.fetchedAt;
    lastAttempts = result.attempts;
    error = null;
    warning = result.warning;
    if (result.games.isEmpty) return;
    final manual = games.where((g) => g.manual && !result.games.any((r) => r.id == g.id));
    final merged = [...result.games, ...manual];
    games
      ..clear()
      ..addAll(merged);
    sort();
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
