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
import '../models/box_score.dart';
import '../analysis/scout_adapter.dart';
import '../services/fiba_livestats.dart';
import '../services/league_sync_service.dart';
import '../services/source_fetcher.dart';
import '../services/stats_aggregator.dart';
import '../services/stats_sync_service.dart';
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

  /// Segundo do vídeo em que começa o scout de cada jogo (chave = [scoutVideoKey]).
  final Map<String, int> videoOffsets = {};

  static String scoutVideoKey(Game g) => 'scout_${g.date.millisecondsSinceEpoch}';

  final List<Player> players = [...MockRepository.players];
  final List<Game> games = [...MockRepository.games];
  LiveGameSession? activeGame;

  // ---- Estatísticas completas (FIBA LiveStats) ----
  final StatsSyncService _statsService = StatsSyncService();

  /// Box scores por id de partida.
  final Map<String, GameBoxScore> boxScores = {};

  /// Partidas conhecidas (id → liga): descobertas nas páginas ou adicionadas por link.
  final Map<String, String> knownMatches = {};

  /// Último erro por partida (id → mensagem).
  final Map<String, String> statsErrors = {};
  final Map<String, DateTime> _statsErrorAt = {};
  bool statsSyncing = false;
  DateTime? statsLastSyncAt;
  Map<String, TeamSeason>? _seasons;

  static const _boxScoresKey = 'arco_boxscores_v1';
  static const _knownMatchesKey = 'arco_known_matches_v1';
  static const _maxStoredGames = 150;

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
      _restoreStats(prefs);
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
    // Partidas ao vivo: estatística atualizada a cada ~30 s.
    final last = statsLastSyncAt;
    if (boxScores.values.any((g) => g.isLive) && (last == null || now.difference(last).inSeconds >= 30)) {
      syncStats(silent: true);
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
      if (_registerMatches(result.matchIds, feed.league)) unawaited(syncStats(silent: true));
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

  // ---------------------------------------------------------------- Estatísticas

  /// Temporada de cada equipe (somatório de todas as partidas importadas).
  Map<String, TeamSeason> get teamSeasons => _seasons ??= StatsAggregator.build(analysisGames);

  /// Jogos usados nas análises: estatística online + jogos do Scout ao vivo,
  /// do mais antigo para o mais recente.
  List<GameBoxScore> get analysisGames {
    final scouted = [
      for (final g in games)
        if (g.events.isNotEmpty) ScoutAdapter.toBoxScore(g, teamName: coach.club, roster: players),
    ];
    final online = boxScores.values.toList()..sort((a, b) => a.matchId.compareTo(b.matchId));
    return [...online, ...scouted]..sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
  }

  /// Equipes do treinador logado (ex.: todas as categorias do Tupã).
  List<TeamSeason> get myTeamSeasons => teamSeasons.values.where((t) => coach.isMyTeam(t.name)).toList()
    ..sort((a, b) => b.games.compareTo(a.games));

  List<GameBoxScore> get boxScoreList => boxScores.values.toList()
    ..sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      return (int.tryParse(b.matchId) ?? 0).compareTo(int.tryParse(a.matchId) ?? 0);
    });

  bool _registerMatches(Iterable<String> ids, String league) {
    var added = false;
    for (final id in ids) {
      if (knownMatches.containsKey(id)) continue;
      knownMatches[id] = league;
      added = true;
    }
    return added || boxScores.values.any((g) => g.isLive);
  }

  /// Baixa as partidas novas e atualiza as que estão ao vivo.
  Future<void> syncStats({bool silent = false, bool retryErrors = false}) async {
    if (statsSyncing) return;
    final now = DateTime.now();
    final pending = <String, String>{};
    for (final e in knownMatches.entries) {
      final cached = boxScores[e.key];
      final errorAt = _statsErrorAt[e.key];
      if (!retryErrors && errorAt != null && now.difference(errorAt).inMinutes < 30) continue;
      final stale = cached != null && !cached.isFinal && now.difference(cached.fetchedAt).inSeconds >= 25;
      if (cached == null || stale) pending[e.key] = e.value;
      if (pending.length >= 40) break;
    }
    if (pending.isEmpty) return;
    statsSyncing = true;
    if (!silent) notifyListeners();
    try {
      final results = await _statsService.fetchMany(pending);
      for (final r in results.entries) {
        final value = r.value;
        if (value is GameBoxScore) {
          boxScores[r.key] = value;
          statsErrors.remove(r.key);
          _statsErrorAt.remove(r.key);
        } else {
          statsErrors[r.key] = value.toString();
          _statsErrorAt[r.key] = now;
        }
      }
      _seasons = null;
      statsLastSyncAt = DateTime.now();
      await _saveStats();
    } finally {
      statsSyncing = false;
      notifyListeners();
    }
  }

  /// Importa uma partida pelo link da estatística online (ou só o número).
  /// Retorna `null` em caso de sucesso, ou a mensagem de erro.
  Future<String?> addStatsLink(String input, {String league = 'FPB'}) async {
    final id = FibaLiveStats.matchIdFromInput(input);
    if (id == null) return 'Não encontrei o número da partida no link. Abra o jogo na aba Estatística/Online e copie o endereço da página.';
    knownMatches[id] = league;
    try {
      boxScores[id] = await _statsService.fetch(id, league: league);
      statsErrors.remove(id);
      _seasons = null;
      await _saveStats();
      return null;
    } catch (e) {
      statsErrors[id] = SourceFetcher.describe(e);
      await _saveStats();
      return statsErrors[id];
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeBoxScore(String matchId) async {
    boxScores.remove(matchId);
    knownMatches.remove(matchId);
    statsErrors.remove(matchId);
    _seasons = null;
    await _saveStats();
    notifyListeners();
  }

  /// Substitui o elenco da aba Equipe pelos jogadores reais de uma equipe importada.
  Future<int> importRosterFrom(TeamSeason team) async {
    final roster = team.roster;
    if (roster.isEmpty) return 0;
    players
      ..clear()
      ..addAll([
        for (final p in roster)
          Player(
            id: 'site_${team.key}_${p.key}'.replaceAll(' ', '_'),
            name: p.name,
            position: p.position.isEmpty ? '-' : p.position,
            number: int.tryParse(p.number) ?? 0,
            games: p.games,
            points: p.ppg.round(),
            assists: p.apg.round(),
            rebounds: p.rpg.round(),
            steals: p.perGame(p.totals.stl).round(),
            blocks: p.perGame(p.totals.blk).round(),
            turnovers: p.perGame(p.totals.tov).round(),
            fgm: p.totals.fgm,
            fga: p.totals.fga,
            threePm: p.totals.tpm,
            threePa: p.totals.tpa,
            ftm: p.totals.ftm,
            fta: p.totals.fta,
          ),
      ]);
    notifyListeners();
    await _saveTeam();
    return roster.length;
  }

  void _restoreStats(SharedPreferences prefs) {
    final known = prefs.getString(_knownMatchesKey);
    if (known != null) {
      knownMatches.addAll((jsonDecode(known) as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    }
    final raw = prefs.getString(_boxScoresKey);
    if (raw == null) return;
    for (final item in jsonDecode(raw) as List) {
      try {
        final g = GameBoxScore.fromJson((item as Map).cast<String, dynamic>());
        boxScores[g.matchId] = g;
      } catch (_) {
        // Partida ilegível: será baixada de novo.
      }
    }
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    var list = boxScoreList;
    if (list.length > _maxStoredGames) list = list.sublist(0, _maxStoredGames);
    await prefs.setString(_boxScoresKey, jsonEncode([for (final g in list) g.toJson()]));
    await prefs.setString(_knownMatchesKey, jsonEncode(knownMatches));
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
    final offsets = prefs.getString('game_video_offsets_v1');
    if (offsets != null) {
      try {
        videoOffsets.addAll((jsonDecode(offsets) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
      } catch (_) {}
    }
    final raw = prefs.getString('game_video_links_v1');
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      videoLinks
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(k, v.toString())));
    } catch (_) {}
  }

  Future<void> setScoutVideo(Game g, String url, int offsetSeconds) async {
    final key = scoutVideoKey(g);
    videoOffsets[key] = offsetSeconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('game_video_offsets_v1', jsonEncode(videoOffsets));
    await setVideoLink(key, url);
  }

  /// Link do vídeo posicionado no momento de uma ação do scout.
  String? videoAtEvent(Game g, PlayEvent e) {
    final url = videoLinks[scoutVideoKey(g)];
    if (url == null || url.isEmpty) return null;
    final start = g.date; // início do scout (= início do jogo no vídeo + offset)
    final seconds = (videoOffsets[scoutVideoKey(g)] ?? 0) + e.timestamp.difference(start).inSeconds;
    return videoUrlAt(url, seconds < 0 ? 0 : seconds);
  }

  /// YouTube aceita `t=123s`; outros players aceitam o fragmento `#t=123`.
  static String videoUrlAt(String url, int seconds) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.toLowerCase();
    if (host.contains('youtu')) {
      final q = Map<String, String>.from(uri.queryParameters)..['t'] = '${seconds}s';
      return uri.replace(queryParameters: q).toString();
    }
    return uri.replace(fragment: 't=$seconds').toString();
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
    _seasons = null;
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

  /// `true` enquanto o elenco é o de demonstração (nenhum jogador real cadastrado ou importado).
  bool get demoRoster => players.isNotEmpty && players.every((p) => MockRepository.players.any((m) => m.id == p.id));

  void removePlayer(String id) {
    players.removeWhere((p) => p.id == id);
    notifyListeners();
    _saveTeam();
  }

  void clearDemoRoster() {
    players.removeWhere((p) => MockRepository.players.any((m) => m.id == p.id));
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

  /// Contexto tático aplicado à próxima ação registrada no scout.
  String? pendingTag;

  void setPendingTag(String? tag) {
    pendingTag = pendingTag == tag ? null : tag;
    notifyListeners();
  }

  void addEvent(PlayEventType type, {String? playerId}) {
    final game = activeGame;
    if (game == null || game.finished) return;
    final tag = pendingTag;
    pendingTag = null;
    final id = playerId ?? game.selectedPlayerId;

    if (type == PlayEventType.opponentOne ||
        type == PlayEventType.opponentTwo ||
        type == PlayEventType.opponentThree) {
      final points = type == PlayEventType.opponentOne ? 1 : (type == PlayEventType.opponentTwo ? 2 : 3);
      game.opponentScore += points;
      game.events.add(PlayEvent(type: type, period: game.period, timestamp: DateTime.now(), lineupIds: List<String>.from(game.lineupIds), tag: tag));
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
    game.events.add(PlayEvent(type: type, playerId: id, period: game.period, timestamp: DateTime.now(), lineupIds: List<String>.from(game.lineupIds), tag: tag));
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
    _seasons = null;
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
