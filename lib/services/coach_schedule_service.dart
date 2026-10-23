import '../models/coach_game_record.dart';
import '../models/fpb_game.dart';
import '../models/game.dart';
import '../models/lbc_game.dart';
import '../models/team_context.dart';

class CoachScheduleService {
  const CoachScheduleService();

  List<CoachGameRecord> build({
    required TeamContext team,
    required List<FpbGameSnapshot> fpbGames,
    required List<LbcGameSnapshot> lbcGames,
    required List<Game> analyzedGames,
  }) {
    final records = <CoachGameRecord>[];

    for (final game in fpbGames) {
      final record = _fromFpb(team, game);
      if (record != null) records.add(record);
    }

    for (final game in lbcGames) {
      final record = _fromLbc(team, game);
      if (record != null) records.add(record);
    }

    final deduplicated = <String, CoachGameRecord>{};
    for (final record in records) {
      deduplicated[_officialKey(record)] = record;
    }

    final merged = deduplicated.values.toList();

    for (final game in analyzedGames) {
      if (game.source == 'mock') continue;

      final existingIndex = merged.indexWhere(
        (record) => _matchesAnalyzedGame(record, game),
      );

      if (existingIndex >= 0) {
        merged[existingIndex] = merged[existingIndex].copyWith(
          hasArcoStats: true,
          arcoGameId: game.id,
        );
        continue;
      }

      merged.add(_fromArco(team, game));
    }

    merged.sort((a, b) {
      final aDate = a.scheduledAt;
      final bDate = b.scheduledAt;
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return merged;
  }

  CoachGameRecord? _fromFpb(TeamContext team, FpbGameSnapshot game) {
    final homeMatches = team.matchesExternalName(game.homeTeam);
    final awayMatches = team.matchesExternalName(game.awayTeam);
    if (!homeMatches && !awayMatches) return null;

    return CoachGameRecord(
      id: 'fpb:${game.id}',
      source: CoachGameSource.fpb,
      teamId: team.teamId,
      seasonId: _seasonId(team, game.scheduledAt),
      league: 'FPB',
      category: game.competition,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      opponent: homeMatches ? game.awayTeam : game.homeTeam,
      trackedTeamIsHome: homeMatches,
      homeScore: game.homeScore,
      awayScore: game.awayScore,
      scheduledAt: game.scheduledAt,
      status: game.status,
      venue: game.venue,
      sourceUrl: game.sourceUrl,
    );
  }

  CoachGameRecord? _fromLbc(TeamContext team, LbcGameSnapshot game) {
    final homeMatches = team.matchesExternalName(game.homeTeam);
    final awayMatches = team.matchesExternalName(game.awayTeam);
    if (!homeMatches && !awayMatches) return null;

    return CoachGameRecord(
      id: 'lbc:${game.id}',
      source: CoachGameSource.lbc,
      teamId: team.teamId,
      seasonId: _seasonId(team, game.scheduledAt),
      league: 'LBC',
      category: game.competition,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      opponent: homeMatches ? game.awayTeam : game.homeTeam,
      trackedTeamIsHome: homeMatches,
      homeScore: game.homeScore,
      awayScore: game.awayScore,
      scheduledAt: game.scheduledAt,
      status: game.status,
      sourceUrl: game.sourceUrl,
    );
  }

  CoachGameRecord _fromArco(TeamContext team, Game game) {
    final isHome = game.isHome;
    final fallbackId = game.date.microsecondsSinceEpoch.toString();
    return CoachGameRecord(
      id: 'arco:${game.id.isEmpty ? fallbackId : game.id}',
      source: CoachGameSource.arco,
      teamId: game.teamId.isEmpty ? team.teamId : game.teamId,
      seasonId: game.seasonId.isEmpty ? _seasonId(team, game.date) : game.seasonId,
      league: game.competition.isEmpty ? 'ARCO' : game.competition,
      category: game.category,
      homeTeam: isHome ? team.displayName : game.opponent,
      awayTeam: isHome ? game.opponent : team.displayName,
      opponent: game.opponent,
      trackedTeamIsHome: isHome,
      homeScore: isHome ? game.ourScore : game.opponentScore,
      awayScore: isHome ? game.opponentScore : game.ourScore,
      scheduledAt: game.date,
      status: 'FINAL',
      venue: game.venue,
      sourceUrl: game.sourceUrl,
      hasArcoStats: true,
      arcoGameId: game.id,
    );
  }

  bool _matchesAnalyzedGame(CoachGameRecord record, Game game) {
    if (record.scheduledAt == null) return false;
    final sameDate = record.scheduledAt!.year == game.date.year &&
        record.scheduledAt!.month == game.date.month &&
        record.scheduledAt!.day == game.date.day;
    if (!sameDate) return false;

    final officialOpponent = TeamContext.normalize(record.opponent);
    final analyzedOpponent = TeamContext.normalize(game.opponent);
    return officialOpponent == analyzedOpponent ||
        officialOpponent.contains(analyzedOpponent) ||
        analyzedOpponent.contains(officialOpponent);
  }

  String _officialKey(CoachGameRecord record) {
    final date = record.scheduledAt;
    final dateKey = date == null
        ? 'unknown'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return [
      record.league,
      dateKey,
      TeamContext.normalize(record.homeTeam),
      TeamContext.normalize(record.awayTeam),
    ].join('|');
  }

  String _seasonId(TeamContext team, DateTime? date) {
    final year = date?.year ?? team.seasonYear;
    return year == team.seasonYear ? team.seasonId : 'season_$year';
  }
}
