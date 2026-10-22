import 'package:arco_analytics/data/mock_repository.dart';
import 'package:arco_analytics/models/coach_profile.dart';
import 'package:arco_analytics/models/game.dart';
import 'package:arco_analytics/models/league_game.dart';
import 'package:arco_analytics/models/live_game_session.dart';
import 'package:arco_analytics/models/play_event.dart';
import 'package:arco_analytics/models/player.dart';
import 'package:arco_analytics/services/league_sync_service.dart';
import 'package:arco_analytics/state/league_feed.dart';
import 'package:flutter_test/flutter_test.dart';

LeagueGame _game(String id, {bool manual = false, String status = 'AGENDADO'}) => LeagueGame(
      id: id,
      league: 'FPB',
      homeTeam: 'Tupã',
      awayTeam: 'Time $id',
      status: status,
      fetchedAt: DateTime(2026, 10, 22),
      sourceUrl: 'https://fpb.com.br/online/',
      manual: manual,
    );

void main() {
  test('jogador, jogo e scout ao vivo sobrevivem à serialização', () {
    final player = Player.fromJson(MockRepository.players.first.toJson());
    expect(player.name, 'Lucas Silva');
    expect(player.onCourtOffRating, 116.4);

    final stats = PlayerGameStats()
      ..points = 12
      ..threePm = 2;
    final live = LiveGameSession(
      opponent: 'Marília',
      startedAt: DateTime(2026, 10, 22, 19),
      lineupIds: ['p1', 'p2', 'p3', 'p4', 'p5'],
      period: 5,
      ourScore: 80,
      opponentScore: 78,
      selectedPlayerId: 'p1',
      events: [PlayEvent(type: PlayEventType.threeMade, playerId: 'p1', period: 5, timestamp: DateTime(2026, 10, 22, 21), lineupIds: const ['p1'])],
      playerStats: {'p1': stats},
    );
    final restored = LiveGameSession.fromJson(live.toJson());
    expect(restored.periodLabel, 'Prorrogação');
    expect(restored.ourScore, 80);
    expect(restored.events.single.type, PlayEventType.threeMade);
    expect(restored.playerStats['p1']!.points, 12);
    expect(restored.playerStats['p1']!.threePm, 2);

    final game = Game.fromJson(Game(
      opponent: 'Lins',
      date: DateTime(2026, 10, 1),
      ourScore: 70,
      opponentScore: 60,
      possessions: 70,
      fgm: 25,
      fga: 60,
      threePm: 8,
      threePa: 20,
      ftm: 12,
      fta: 15,
      turnovers: 10,
      offensiveRebounds: 9,
      availableOffensiveRebounds: 35,
      opponentPoints: 60,
      playerStats: const {'p1': PlayerStatLine(points: 20, assists: 5)},
      events: restored.events,
    ).toJson());
    expect(game.won, isTrue);
    expect(game.playerStats['p1']!.assists, 5);
    expect(game.events, hasLength(1));
  });

  test('evento de tipo desconhecido não quebra a leitura', () {
    expect(PlayEvent.fromJson({'type': 'tipoFuturo', 'period': 1}), isNull);
  });

  test('sincronização vazia não apaga cache e preserva jogos manuais', () {
    final feed = LeagueFeed(LeagueSource.fpb);
    feed.games.addAll([_game('a'), _game('m', manual: true)]);

    feed.apply(LeagueSyncResult(games: const [], fetchedAt: DateTime(2026, 10, 22), attempts: const [], warning: 'vazio'));
    expect(feed.games.map((g) => g.id), containsAll(['a', 'm']));
    expect(feed.warning, 'vazio');

    feed.apply(LeagueSyncResult(games: [_game('b', status: 'AO VIVO')], fetchedAt: DateTime(2026, 10, 22), attempts: const []));
    expect(feed.games.map((g) => g.id).toList(), ['b', 'm']);
    expect(feed.hasLive, isTrue);
    expect(feed.refreshInterval, const Duration(seconds: 30));
    expect(feed.warning, isNull);
  });

  test('jogo de liga é serializado com id e marcação manual', () {
    final g = LeagueGame.fromJson(_game('x', manual: true).toJson(), league: 'FPB', fallbackUrl: '');
    expect(g.id, 'x');
    expect(g.manual, isTrue);
  });

  test('identifica a equipe do treinador sem depender de acentos', () {
    const coach = CoachProfile.adrianoMiao;
    expect(coach.isMyTeam('TUPA BASQUETE'), isTrue);
    expect(coach.isMyTeam('Monstrinho/Tupã Sub 15'), isTrue);
    expect(coach.isMyTeam('Tupãzinho FC'), isFalse);
    expect(coach.isMyTeam('Marília'), isFalse);
  });

  test('páginas extras só do domínio da liga', () {
    expect(LeagueSource.lbc.acceptsUrl(Uri.parse('https://www.lbc.org.br/tabela/sub-17')), isTrue);
    expect(LeagueSource.lbc.acceptsUrl(Uri.parse('https://lbc.org.br/jogos')), isTrue);
    expect(LeagueSource.lbc.acceptsUrl(Uri.parse('https://evil.com/?lbc.org.br')), isFalse);
    expect(LeagueSource.lbc.acceptsUrl(Uri.parse('https://fakelbc.org.br/')), isFalse);
  });
}
