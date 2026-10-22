import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_repository.dart';
import '../models/game.dart';
import '../models/coach_profile.dart';
import '../models/coach_game_record.dart';
import '../models/team_context.dart';
import '../models/lbc_game.dart';
import '../models/fpb_game.dart';
import '../models/live_game_session.dart';
import '../models/play_event.dart';
import '../models/player.dart';
import '../services/fpb_live_service.dart';
import '../services/lbc_live_service.dart';
import '../services/coach_schedule_service.dart';

class AppState extends ChangeNotifier {
  AppState() {
    _restoreCoachSession();
    _restoreVideoLinks();
    _restoreFpbCache();
    _restoreLbcCache();
    syncFpbNow();
    syncLbcNow();
    _fpbTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncFpbNow(silent: true));
    _lbcTimer = Timer.periodic(const Duration(seconds: 60), (_) => syncLbcNow(silent: true));
  }

  final FpbLiveService _fpbService = FpbLiveService();
  final LbcLiveService _lbcService = LbcLiveService();
  final CoachScheduleService _coachScheduleService = const CoachScheduleService();
  final TeamContext teamContext = TeamContext.tupaMonstrinho2026;
  Timer? _fpbTimer;
  Timer? _lbcTimer;

  bool loggedIn = false;
  CoachProfile coach = CoachProfile.adrianoMiao;
  final Map<String, String> videoLinks = {};

  final List<LbcGameSnapshot> lbcGames = [];
  bool lbcSyncing = false;
  DateTime? lbcLastSyncAt;
  String? lbcError;
  final List<FpbGameSnapshot> fpbGames = [];
  bool fpbSyncing = false;
  DateTime? fpbLastSyncAt;
  String? fpbError;

  final List<Player> players = [...MockRepository.players];
  final List<Game> games = [...MockRepository.games];
  LiveGameSession? activeGame;

  List<CoachGameRecord> get coachSeasonGames => _coachScheduleService.build(
        team: teamContext,
        fpbGames: fpbGames,
        lbcGames: lbcGames,
        analyzedGames: games,
      );

  Game? analyzedGameById(String? gameId) {
    if (gameId == null || gameId.isEmpty) return null;
    for (final game in games) {
      if (game.id == gameId) return game;
    }
    return null;
  }



  Future<void> syncFpbNow({bool silent = false}) async {
    if (fpbSyncing) return;
    fpbSyncing = true;
    if (!silent) notifyListeners();
    try {
      final result = await _fpbService.fetchOnlineGames();
      fpbGames
        ..clear()
        ..addAll(result.games);
      fpbLastSyncAt = result.fetchedAt;
      fpbError = result.warning;
      await _saveFpbCache();
    } catch (e) {
      fpbError = 'Não foi possível atualizar a FPB agora. Exibindo o último snapshot disponível. ($e)';
    } finally {
      fpbSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _restoreFpbCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('fpb_snapshot_v1');
    final synced = prefs.getString('fpb_last_sync_v1');
    if (synced != null) fpbLastSyncAt = DateTime.tryParse(synced);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      fpbGames
        ..clear()
        ..addAll(data.map((item) {
          final m = item as Map<String, dynamic>;
          return FpbGameSnapshot(
            id: m['id'] as String,
            homeTeam: m['homeTeam'] as String,
            awayTeam: m['awayTeam'] as String,
            homeScore: m['homeScore'] as int?,
            awayScore: m['awayScore'] as int?,
            competition: (m['competition'] as String?) ?? '',
            venue: (m['venue'] as String?) ?? '',
            status: (m['status'] as String?) ?? 'AGENDADO',
            scheduledAt: m['scheduledAt'] == null ? null : DateTime.tryParse(m['scheduledAt'] as String),
            fetchedAt: DateTime.tryParse(m['fetchedAt'] as String? ?? '') ?? DateTime.now(),
            sourceUrl: (m['sourceUrl'] as String?) ?? FpbLiveService.onlineUrl,
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveFpbCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = fpbGames.map((g) => {
      'id': g.id,
      'homeTeam': g.homeTeam,
      'awayTeam': g.awayTeam,
      'homeScore': g.homeScore,
      'awayScore': g.awayScore,
      'competition': g.competition,
      'venue': g.venue,
      'status': g.status,
      'scheduledAt': g.scheduledAt?.toIso8601String(),
      'fetchedAt': g.fetchedAt.toIso8601String(),
      'sourceUrl': g.sourceUrl,
    }).toList();
    await prefs.setString('fpb_snapshot_v1', jsonEncode(data));
    if (fpbLastSyncAt != null) await prefs.setString('fpb_last_sync_v1', fpbLastSyncAt!.toIso8601String());
  }

  @override
  void dispose() {
    _fpbTimer?.cancel();
    _lbcTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreCoachSession() async {
    final prefs = await SharedPreferences.getInstance();
    loggedIn = prefs.getBool('coach_logged_in_v1') ?? false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final ok = normalized == 'adriano.miao@arco.app' && password == 'ARCO-DEMO';
    if (!ok) return false;
    loggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coach_logged_in_v1', true);
    notifyListeners();
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

  Future<void> _restoreVideoLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('game_video_links_v1');
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      videoLinks
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(k, v.toString())));
      notifyListeners();
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

  Future<void> syncAllLeagues() async {
    await Future.wait([syncFpbNow(), syncLbcNow()]);
  }

  Future<void> syncLbcNow({bool silent = false}) async {
    if (lbcSyncing) return;
    lbcSyncing = true;
    if (!silent) notifyListeners();
    try {
      final result = await _lbcService.fetchGames();
      lbcGames
        ..clear()
        ..addAll(result.games);
      lbcLastSyncAt = result.fetchedAt;
      lbcError = result.warning;
      await _saveLbcCache();
    } catch (e) {
      lbcError = 'Não foi possível atualizar a LBC agora. Exibindo o último snapshot disponível. ($e)';
    } finally {
      lbcSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _restoreLbcCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lbc_snapshot_v1');
    final synced = prefs.getString('lbc_last_sync_v1');
    if (synced != null) lbcLastSyncAt = DateTime.tryParse(synced);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      lbcGames
        ..clear()
        ..addAll(data.map((item) {
          final m = item as Map<String, dynamic>;
          return LbcGameSnapshot(
            id: m['id'] as String,
            homeTeam: m['homeTeam'] as String,
            awayTeam: m['awayTeam'] as String,
            homeScore: m['homeScore'] as int?,
            awayScore: m['awayScore'] as int?,
            competition: (m['competition'] as String?) ?? '',
            status: (m['status'] as String?) ?? 'AGENDADO',
            scheduledAt: m['scheduledAt'] == null ? null : DateTime.tryParse(m['scheduledAt'] as String),
            fetchedAt: DateTime.tryParse(m['fetchedAt'] as String? ?? '') ?? DateTime.now(),
            sourceUrl: (m['sourceUrl'] as String?) ?? LbcLiveService.officialUrl,
          );
        }));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveLbcCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = lbcGames.map((g) => {
      'id': g.id,
      'homeTeam': g.homeTeam,
      'awayTeam': g.awayTeam,
      'homeScore': g.homeScore,
      'awayScore': g.awayScore,
      'competition': g.competition,
      'status': g.status,
      'scheduledAt': g.scheduledAt?.toIso8601String(),
      'fetchedAt': g.fetchedAt.toIso8601String(),
      'sourceUrl': g.sourceUrl,
    }).toList();
    await prefs.setString('lbc_snapshot_v1', jsonEncode(data));
    if (lbcLastSyncAt != null) await prefs.setString('lbc_last_sync_v1', lbcLastSyncAt!.toIso8601String());
  }

  void addPlayer({required String name, required String position, required int number}) {
    players.add(Player(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      position: position,
      number: number,
    ));
    notifyListeners();
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
    notifyListeners();
    return true;
  }

  void selectPlayer(String playerId) {
    final game = activeGame;
    if (game == null) return;
    game.selectedPlayerId = playerId;
    notifyListeners();
  }

  void setPeriod(int period) {
    final game = activeGame;
    if (game == null) return;
    game.period = period < 1 ? 1 : (period > 4 ? 4 : period);
    notifyListeners();
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
    notifyListeners();
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
      notifyListeners();
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
    notifyListeners();
  }

  void undoLastEvent() {
    final game = activeGame;
    if (game == null || game.events.isEmpty) return;
    final event = game.events.removeLast();
    _reverseEvent(game, event);
    notifyListeners();
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
    final possessions = live.estimatedPossessions.round().clamp(1, 999) as int;
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
      id: 'game_${live.startedAt.microsecondsSinceEpoch}',
      teamId: teamContext.teamId,
      seasonId: teamContext.seasonId,
      competition: 'ARCO',
      source: 'arco',
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
      availableOffensiveRebounds: (live.fga - live.fgm + live.offensiveRebounds).clamp(1, 999) as int,
      opponentPoints: live.opponentScore,
      playerStats: statLines,
      events: List<PlayEvent>.from(live.events),
    );
    games.insert(0, game);
    activeGame = null;
    notifyListeners();
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
