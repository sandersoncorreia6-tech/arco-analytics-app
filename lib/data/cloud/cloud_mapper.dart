import '../../models/coach_profile.dart';
import '../../models/game.dart';
import '../../models/league_game.dart';
import '../../models/live_game_session.dart';
import '../../models/player.dart';
import 'cloud_sync.dart';

/// Converte os dados do app nas linhas das tabelas do Supabase (e de volta).
class CloudMapper {
  static String _status(LeagueGame g) => g.isLive ? 'live' : (g.isFinal || g.hasScore ? 'final' : 'scheduled');

  /// Partida da FPB/LBC da equipe do treinador (com o vídeo vinculado).
  static Map<String, dynamic> leagueGame(LeagueGame g, CoachProfile coach, String teamId, {String? videoUrl}) {
    final home = coach.isHome(g);
    return {
      if (teamId.isNotEmpty) 'team_id': teamId,
      'opponent': home ? g.awayTeam : g.homeTeam,
      'competition': g.competitionName.isNotEmpty ? g.competitionName : g.league,
      'category': g.competition,
      'round': g.round,
      'venue': g.venue,
      'scheduled_at': g.scheduledAt?.toUtc().toIso8601String(),
      'our_score': home ? g.homeScore : g.awayScore,
      'opponent_score': home ? g.awayScore : g.homeScore,
      'status': _status(g),
      'source': g.league.toLowerCase(),
      'external_id': g.id,
      'video_url': ?videoUrl,
      'box_score': {'arcoLeagueGame': g.toJson()},
    };
  }

  /// Jogo do scout encerrado (com todos os eventos, para outro aparelho reconstruir).
  static Map<String, dynamic> scoutGame(Game g, String key, CoachProfile coach, String teamId, {String? videoUrl, int? videoOffset}) => {
        if (teamId.isNotEmpty) 'team_id': teamId,
        'opponent': g.opponent,
        'competition': 'Scout ARCO',
        'category': coach.category,
        'scheduled_at': g.date.toUtc().toIso8601String(),
        'started_at': g.date.toUtc().toIso8601String(),
        'our_score': g.ourScore,
        'opponent_score': g.opponentScore,
        'status': 'final',
        'source': 'scout',
        'external_id': key,
        'video_url': ?videoUrl,
        'video_offset_seconds': ?videoOffset,
        'box_score': {'arcoGame': g.toJson()},
      };

  /// Retrato do scout em andamento (continua de onde parou em outro aparelho).
  static Map<String, dynamic> liveScout(LiveGameSession s, String key, CoachProfile coach, String teamId) => {
        if (teamId.isNotEmpty) 'team_id': teamId,
        'opponent': s.opponent,
        'competition': 'Scout ARCO',
        'category': coach.category,
        'scheduled_at': s.startedAt.toUtc().toIso8601String(),
        'started_at': s.startedAt.toUtc().toIso8601String(),
        'our_score': s.ourScore,
        'opponent_score': s.opponentScore,
        'status': 'live',
        'source': 'scout',
        'external_id': key,
        'box_score': {'arcoLive': s.toJson()},
      };

  static Map<String, dynamic> athlete(Player p, String clubId, String teamId) => {
        'id': CloudSync.stableUuid('$clubId/athlete/${p.id}'),
        if (teamId.isNotEmpty) 'team_id': teamId,
        'name': p.name,
        'number': p.number,
        'position': p.position,
        'active': true,
      };

  static Player playerFromAthlete(Map<String, dynamic> r) => Player(
        id: 'cloud_${r['id']}',
        name: (r['name'] ?? '').toString(),
        position: (r['position'] ?? '').toString(),
        number: (r['number'] as num?)?.toInt() ?? 0,
      );
}
