import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/play_event.dart';

class LocalGameStore {
  static const _key = 'arco_real_games_v1';

  Future<List<Game>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => _gameFromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Game> games) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(games.map(_gameToJson).toList());
    await prefs.setString(_key, encoded);
  }

  Map<String, dynamic> _gameToJson(Game game) => {
        'id': game.id,
        'teamId': game.teamId,
        'seasonId': game.seasonId,
        'competition': game.competition,
        'category': game.category,
        'venue': game.venue,
        'source': game.source,
        'sourceUrl': game.sourceUrl,
        'isHome': game.isHome,
        'opponent': game.opponent,
        'date': game.date.toIso8601String(),
        'ourScore': game.ourScore,
        'opponentScore': game.opponentScore,
        'possessions': game.possessions,
        'fgm': game.fgm,
        'fga': game.fga,
        'threePm': game.threePm,
        'threePa': game.threePa,
        'ftm': game.ftm,
        'fta': game.fta,
        'turnovers': game.turnovers,
        'offensiveRebounds': game.offensiveRebounds,
        'availableOffensiveRebounds': game.availableOffensiveRebounds,
        'opponentPoints': game.opponentPoints,
        'playerStats': game.playerStats.map(
          (playerId, stat) => MapEntry(playerId, _statToJson(stat)),
        ),
        'events': game.events.map(_eventToJson).toList(),
      };

  Game _gameFromJson(Map<String, dynamic> json) {
    final rawStats = (json['playerStats'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final rawEvents = json['events'] as List<dynamic>? ?? const [];

    return Game(
      id: json['id']?.toString() ?? '',
      teamId: json['teamId']?.toString() ?? '',
      seasonId: json['seasonId']?.toString() ?? '',
      competition: json['competition']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      venue: json['venue']?.toString() ?? '',
      source: json['source']?.toString() ?? 'arco',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      isHome: json['isHome'] as bool? ?? true,
      opponent: json['opponent']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      ourScore: _int(json['ourScore']),
      opponentScore: _int(json['opponentScore']),
      possessions: _int(json['possessions'], fallback: 1),
      fgm: _int(json['fgm']),
      fga: _int(json['fga']),
      threePm: _int(json['threePm']),
      threePa: _int(json['threePa']),
      ftm: _int(json['ftm']),
      fta: _int(json['fta']),
      turnovers: _int(json['turnovers']),
      offensiveRebounds: _int(json['offensiveRebounds']),
      availableOffensiveRebounds:
          _int(json['availableOffensiveRebounds'], fallback: 1),
      opponentPoints: _int(json['opponentPoints']),
      playerStats: rawStats.map(
        (playerId, raw) => MapEntry(
          playerId,
          _statFromJson((raw as Map).cast<String, dynamic>()),
        ),
      ),
      events: rawEvents
          .whereType<Map>()
          .map((raw) => _eventFromJson(raw.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> _statToJson(PlayerStatLine stat) => {
        'points': stat.points,
        'assists': stat.assists,
        'offensiveRebounds': stat.offensiveRebounds,
        'defensiveRebounds': stat.defensiveRebounds,
        'steals': stat.steals,
        'blocks': stat.blocks,
        'turnovers': stat.turnovers,
        'fouls': stat.fouls,
        'fgm': stat.fgm,
        'fga': stat.fga,
        'threePm': stat.threePm,
        'threePa': stat.threePa,
        'ftm': stat.ftm,
        'fta': stat.fta,
      };

  PlayerStatLine _statFromJson(Map<String, dynamic> json) => PlayerStatLine(
        points: _int(json['points']),
        assists: _int(json['assists']),
        offensiveRebounds: _int(json['offensiveRebounds']),
        defensiveRebounds: _int(json['defensiveRebounds']),
        steals: _int(json['steals']),
        blocks: _int(json['blocks']),
        turnovers: _int(json['turnovers']),
        fouls: _int(json['fouls']),
        fgm: _int(json['fgm']),
        fga: _int(json['fga']),
        threePm: _int(json['threePm']),
        threePa: _int(json['threePa']),
        ftm: _int(json['ftm']),
        fta: _int(json['fta']),
      );

  Map<String, dynamic> _eventToJson(PlayEvent event) => {
        'type': event.type.name,
        'playerId': event.playerId,
        'period': event.period,
        'timestamp': event.timestamp.toIso8601String(),
        'lineupIds': event.lineupIds,
        'shotX': event.shotX,
        'shotY': event.shotY,
      };

  PlayEvent _eventFromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    final type = PlayEventType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => PlayEventType.turnover,
    );

    return PlayEvent(
      type: type,
      playerId: json['playerId']?.toString(),
      period: _int(json['period'], fallback: 1),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      lineupIds: (json['lineupIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      shotX: (json['shotX'] as num?)?.toDouble(),
      shotY: (json['shotY'] as num?)?.toDouble(),
    );
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
