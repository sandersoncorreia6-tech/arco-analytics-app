import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_repository.dart';
import '../models/game.dart';
import '../models/coach_profile.dart';
import '../models/league_game.dart';
import '../models/live_game_session.dart';
import '../models/play_event.dart';
import '../models/player.dart';
import '../services/league_sync_service.dart';
import '../services/source_fetcher.dart';
import 'league_feed.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  final LeagueFeed fpb = LeagueFeed(LeagueSource.fpb);
  final LeagueFeed lbc = LeagueFeed(LeagueSource.lbc);
  List<LeagueFeed> get feeds => [fpb, lbc];

  Timer? _ticker;
  bool _foreground = true;
  bool ready = false;

  bool loggedIn = false;
  CoachProfile coach = CoachProfile.adrianoMiao;
  final Map<String, String> videoLinks = {};

  final List<Player> players = [...MockRepository.players];
  final List<Game> games = [...MockRepository.games];
  LiveGameSession? activeGame;

  static const _playersKey = 'arco_players_v1';
  static const _gamesKey = 'arco_games_v1';
  static const _activeGameKey = 'arco_active_game_v1';

  Future<void> _init() async {
    // Restaura tudo antes da primeira sincronização, para que o cache antigo
    // nunca sobrescreva dados recém-baixados.
    try {
      final prefs = await SharedPreferences.getInstance();
      _restoreCoachSession(prefs);
      _restoreVideoLinks(prefs);
      _restoreTeam(prefs);
      for (final feed in feeds) {
        _restoreFeed(prefs, feed);
      }
    } catch (_) {
      // Armazenamento indisponível (ex.: navegador em modo privado): segue sem cache.
    } finally {
      ready = true;
      notifyListeners();
    }
    await syncAllLeagues(silent: true);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  void _tick() {
    if (!_foreground) return;
    final now = DateTime.now();
    for (final feed in feeds) {
      if (feed.isDue(now)) syncLeague(feed, silent: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Ao voltar para o app, atualiza o que estiver vencido imediatamente.
    if (_foreground) _tick();
  }

  // ---------------------------------------------------------------- Competições

  Future<void> syncAllLeagues({bool silent = false}) async {
    await Future.wait(feeds.map((f) => syncLeague(f, silent: silent)));
  }

  Future<void> syncLeague(LeagueFeed feed, {bool silent = false}) async {
    if (feed.syncing) return;
    feed.syncing = true;
    feed.lastAttemptAt = DateTime.now();
    if (!silent) notifyListeners();
    try {
      final result = await feed.service.fetch(extraPages: feed.extraPages);
      feed.apply(result);
      await _saveFeed(feed);
    } catch (e) {
      feed.error = SourceFetcher.describe(e);
      feed.lastAttempts = e is LeagueSyncException ? e.attempts : const [];
    } finally {
      feed.syncing = false;
      notifyListeners();
    }
  }

  /// Importa jogos colados pelo treinador. Retorna quantos foram reconhecidos.
  Future<int> importPastedGames(LeagueFeed feed, String text) async {
    final parsed = feed.service.parsePasted(text);
    if (parsed.isEmpty) return 0;
    final ids = parsed.map((g) => g.id).toSet();
    feed.games
      ..removeWhere((g) => ids.contains(g.id))
      ..addAll(parsed);
    feed.sort();
    await _saveFeed(feed);
    notifyListeners();
    return parsed.length;
  }

  Future<void> removeManualGames(LeagueFeed feed) async {
    feed.games.removeWhere((g) => g.manual);
    await _saveFeed(feed);
    notifyListeners();
  }

  Future<void> setExtraPages(LeagueFeed feed, List<String> urls) async {
    feed.extraPages
      ..clear()
      ..addAll(urls.map((u) => u.trim()).where((u) => u.isNotEmpty));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(feed.pagesKey, feed.extraPages);
    notifyListeners();
    await syncLeague(feed);
  }

  /// Jogos da equipe do treinador logado (sem diferenciar acentos).
  List<LeagueGame> myTeamGames(LeagueFeed feed) =>
      feed.games.where((g) => coach.isMyTeam(g.homeTeam) || coach.isMyTeam(g.awayTeam)).toList();

  void _restoreFeed(SharedPreferences prefs, LeagueFeed feed) {
    final synced = prefs.getString(feed.syncKey);
    if (synced != null) feed.lastSyncAt = DateTime.tryParse(synced);
    feed.extraPages
      ..clear()
      ..addAll(prefs.getStringList(feed.pagesKey) ?? const []);
    final raw = prefs.getString(feed.cacheKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      feed.games
        ..clear()
        ..addAll(data.map((item) => LeagueGame.fromJson(
              (item as Map).cast<String, dynamic>(),
              league: feed.league,
              fallbackUrl: feed.source.officialUrl,
            )));
      feed.sort();
    } catch (_) {
      // Cache corrompido ou de versão incompatível: será refeito na próxima sincronização.
    }
  }

  Future<void> _saveFeed(LeagueFeed feed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(feed.cacheKey, jsonEncode([for (final g in feed.games) g.toJson()]));
    if (feed.lastSyncAt != null) await prefs.setString(feed.syncKey, feed.lastSyncAt!.toIso8601String());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- Sessão

  void _restoreCoachSession(SharedPreferences prefs) {
    loggedIn = prefs.getBool('coach_logged_in_v1') ?? false;
  }

  Future<bool> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final ok = normalized == 'adriano.miao@arco.app' && password == 'ARCO-DEMO';
    if (!ok) return false;
    await loginAsAdrianoDemo();
    return true;
  }

  Future<void> loginAsAdrianoDemo() async {
    loggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_logged_in_v1', true);
    notifyListeners();
  }

  Future<void> logout() async {
    loggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_logged_in_v1', false);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Vídeos

  void _restoreVideoLinks(SharedPreferences prefs) {
    final raw = prefs.getString('game_video_links_v1');
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      videoLinks
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {}
  }

  Future<void> setVideoLink(String gameId, String url) async {
    if (url.isEmpty) {
      videoLinks.remove(gameId);
    } else {
      videoLinks[gameId] = url;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('game_video_links_v1', jsonEncode(videoLinks));
    notifyListeners();
  }

  // ---------------------------------------------------------------- Equipe e jogos

  void _restoreTeam(SharedPreferences prefs) {
    try {
      final rawPlayers = prefs.getString(_playersKey);
      if (rawPlayers != null) {
        final list = (jsonDecode(rawPlayers) as List).map((e) => Player.fromJson((e as Map).cast<String, dynamic>())).toList();
        players
          ..clear()
          ..addAll(list);
      }
      final rawGames = prefs.getString(_gamesKey);
      if (rawGames != null) {
        final list = (jsonDecode(rawGames) as List).map((e) => Game.fromJson((e as Map).cast<String, dynamic>())).toList();
        games
          ..clear()
          ..addAll(list);
      }
      final rawActive = prefs.getString(_activeGameKey);
      if (rawActive != null) {
        activeGame = LiveGameSession.fromJson((jsonDecode(rawActive) as Map).cast<String, dynamic>());
      }
    } catch (_) {
      // Dados locais ilegíveis: mantém a base de demonstração.
    }
  }

  Future<void> _saveTeam() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playersKey, jsonEncode([for (final p in players) p.toJson()]));
    await prefs.setString(_gamesKey, jsonEncode([for (final g in games) g.toJson()]));
    await _saveActiveGame(prefs);
  }

  Future<void> _saveActiveGame([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    final game = activeGame;
    if (game == null) {
      await prefs.remove(_activeGameKey);
    } else {
      await prefs.setString(_activeGameKey, jsonEncode(game.toJson()));
    }
  }

  /// Notifica a interface e grava o scout em andamento (sobrevive a o app fechar).
  void _liveChanged() {
    notifyListeners();
    _saveActiveGame();
  }

  void addPlayer({required String name, required String position, required int number}) {
    players.add(Player(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      position: position,
      number: number,
    ));
    notifyListeners();
    _saveTeam();
  }

  bool startGame(String opponent) {
    if (opponent.trim().isEmpty || players.length < 5) return false;
    final starters = players.take(5).map((p) => p.id).toList();
    activeGame = LiveGameSession(
      opponent: opponent.trim(),
      startedAt: DateTime.now(),
      lineupIds: starters,
      selectedPlayerId: starters.first,
    );
    _liveChanged();
    return true;
  }

  void selectPlayer(String playerId) {
    final game = activeGame;
    if (game == null) return;
    game.selectedPlayerId = playerId;
    _liveChanged();
  }

  void setPeriod(int period) {
    final game = activeGame;
    if (game == null) return;
    game.period = period.clamp(1, 5); // 5 = prorrogação
    _liveChanged();
  }

  void changeLineup(String playerId, bool onCourt) {
    final game = activeGame;
    if (game == null) return;
    if (onCourt) {
      if (game.lineupIds.length >= 5 || game.lineupIds.contains(playerId)) return;
      game.lineupIds.add(playerId);
    } else {
      game.lineupIds.remove(playerId);
      if (game.selectedPlayerId == playerId) {
        game.selectedPlayerId = game.lineupIds.isEmpty ? null : game.lineupIds.first;
      }
    }
    _liveChanged();
  }

  void addEvent(PlayEventType type, {String? playerId}) {
    final game = activeGame;
    if (game == null || game.finished) return;
    final id = playerId ?? game.selectedPlayerId;

    if (type == PlayEventType.opponentOne ||
        type == PlayEventType.opponentTwo ||
        type == PlayEventType.opponentThree) {
      final points = type == PlayEventType.opponentOne ? 1 : (type == PlayEventType.opponentTwo ? 2 : 3);
      game.opponentScore += points;
      game.events.add(PlayEvent(type: type, period: game.period, timestamp: DateTime.now(), lineupIds: List<String>.from(game.lineupIds)));
      _liveChanged();
      return;
    }

    if (id == null) return;
    final stat = game.playerStats.putIfAbsent(id, PlayerGameStats.new);
    switch (type) {
      case PlayEventType.twoMade:
        stat.points += 2; stat.fgm++; stat.fga++; game.ourScore += 2;
        break;
      case PlayEventType.twoMiss:
        stat.fga++;
        break;
      case PlayEventType.threeMade:
        stat.points += 3; stat.fgm++; stat.fga++; stat.threePm++; stat.threePa++; game.ourScore += 3;
        break;
      case PlayEventType.threeMiss:
        stat.fga++; stat.threePa++;
        break;
      case PlayEventType.freeThrowMade:
        stat.points++; stat.ftm++; stat.fta++; game.ourScore++;
        break;
      case PlayEventType.freeThrowMiss:
        stat.fta++;
        break;
      case PlayEventType.assist:
        stat.assists++;
        break;
      case PlayEventType.offensiveRebound:
        stat.offensiveRebounds++;
        break;
      case PlayEventType.defensiveRebound:
        stat.defensiveRebounds++;
        break;
      case PlayEventType.steal:
        stat.steals++;
        break;
      case PlayEventType.block:
        stat.blocks++;
        break;
      case PlayEventType.turnover:
        stat.turnovers++;
        break;
      case PlayEventType.foul:
        stat.fouls++;
        break;
      case PlayEventType.opponentOne:
      case PlayEventType.opponentTwo:
      case PlayEventType.opponentThree:
        break;
    }
    game.events.add(PlayEvent(type: type, playerId: id, period: game.period, timestamp: DateTime.now(), lineupIds: List<String>.from(game.lineupIds)));
    _liveChanged();
  }

  void undoLastEvent() {
    final game = activeGame;
    if (game == null || game.events.isEmpty) return;
    final event = game.events.removeLast();
    _reverseEvent(game, event);
    _liveChanged();
  }

  void _reverseEvent(LiveGameSession game, PlayEvent event) {
    if (event.type == PlayEventType.opponentOne || event.type == PlayEventType.opponentTwo || event.type == PlayEventType.opponentThree) {
      game.opponentScore -= event.type == PlayEventType.opponentOne ? 1 : (event.type == PlayEventType.opponentTwo ? 2 : 3);
      return;
    }
    final stat = game.playerStats[event.playerId];
    if (stat == null) return;
    switch (event.type) {
      case PlayEventType.twoMade:
        stat.points -= 2; stat.fgm--; stat.fga--; game.ourScore -= 2;
        break;
      case PlayEventType.twoMiss:
        stat.fga--;
        break;
      case PlayEventType.threeMade:
        stat.points -= 3; stat.fgm--; stat.fga--; stat.threePm--; stat.threePa--; game.ourScore -= 3;
        break;
      case PlayEventType.threeMiss:
        stat.fga--; stat.threePa--;
        break;
      case PlayEventType.freeThrowMade:
        stat.points--; stat.ftm--; stat.fta--; game.ourScore--;
        break;
      case PlayEventType.freeThrowMiss:
        stat.fta--;
        break;
      case PlayEventType.assist:
        stat.assists--;
        break;
      case PlayEventType.offensiveRebound:
        stat.offensiveRebounds--;
        break;
      case PlayEventType.defensiveRebound:
        stat.defensiveRebounds--;
        break;
      case PlayEventType.steal:
        stat.steals--;
        break;
      case PlayEventType.block:
        stat.blocks--;
        break;
      case PlayEventType.turnover:
        stat.turnovers--;
        break;
      case PlayEventType.foul:
        stat.fouls--;
        break;
      case PlayEventType.opponentOne:
      case PlayEventType.opponentTwo:
      case PlayEventType.opponentThree:
        break;
    }
  }

  Game? finishGame() {
    final live = activeGame;
    if (live == null) return null;
    live.finished = true;
    final possessions = live.estimatedPossessions.round().clamp(1, 999);
    final statLines = <String, PlayerStatLine>{
      for (final entry in live.playerStats.entries)
        entry.key: PlayerStatLine(
          points: entry.value.points,
          assists: entry.value.assists,
          offensiveRebounds: entry.value.offensiveRebounds,
          defensiveRebounds: entry.value.defensiveRebounds,
          steals: entry.value.steals,
          blocks: entry.value.blocks,
          turnovers: entry.value.turnovers,
          fouls: entry.value.fouls,
          fgm: entry.value.fgm,
          fga: entry.value.fga,
          threePm: entry.value.threePm,
          threePa: entry.value.threePa,
          ftm: entry.value.ftm,
          fta: entry.value.fta,
        ),
    };
    final game = Game(
      opponent: live.opponent,
      date: live.startedAt,
      ourScore: live.ourScore,
      opponentScore: live.opponentScore,
      possessions: possessions,
      fgm: live.fgm,
      fga: live.fga,
      threePm: live.threePm,
      threePa: live.threePa,
      ftm: live.ftm,
      fta: live.fta,
      turnovers: live.turnovers,
      offensiveRebounds: live.offensiveRebounds,
      availableOffensiveRebounds: (live.fga - live.fgm).clamp(1, 999),
      opponentPoints: live.opponentScore,
      playerStats: statLines,
      events: List<PlayEvent>.from(live.events),
    );
    games.insert(0, game);
    activeGame = null;
    notifyListeners();
    _saveTeam();
    return game;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({Key? key, required AppState state, required Widget child}) : super(key: key, notifier: state, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
