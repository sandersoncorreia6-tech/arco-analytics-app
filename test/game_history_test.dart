import 'package:arco_analytics/data/repositories/game_repository.dart';
import 'package:arco_analytics/domain/models/coach_profile.dart';
import 'package:arco_analytics/domain/models/league_game.dart';
import 'package:arco_analytics/data/sources/league_sync_service.dart';
import 'package:arco_analytics/state/league_feed.dart';
import 'package:flutter_test/flutter_test.dart';

LeagueGame g(
  String id,
  String home,
  String away,
  DateTime? date, {
  int? hs,
  int? as_,
  String status = 'AGENDADO',
  String cat = 'SUB 16 M',
  String ext = '',
  String comp = '',
}) => LeagueGame(
  id: id,
  league: 'FPB',
  homeTeam: home,
  awayTeam: away,
  homeScore: hs,
  awayScore: as_,
  status: status,
  competition: cat,
  scheduledAt: date,
  fetchedAt: DateTime(2026, 10, 22),
  sourceUrl: 'https://fpb.com.br/online/',
  externalId: ext,
  competitionName: comp,
);

LeagueSyncResult r(List<LeagueGame> games) => LeagueSyncResult(games: games, fetchedAt: DateTime(2026, 10, 22), attempts: const []);

void main() {
  const coach = CoachProfile.adrianoMiao;

  test('temporada inteira: sincronizações sucessivas acumulam, não substituem', () {
    final feed = LeagueFeed(LeagueSource.fpb);
    // Cada leitura da FPB traz só a rodada da semana.
    for (var week = 0; week < 12; week++) {
      final day = DateTime(2026, 3, 7 + week * 7, 15);
      feed.apply(r([g('w$week', 'Tupã', 'Adversário $week', day, hs: 60 + week, as_: 50, status: 'FINAL')]));
    }
    expect(feed.games, hasLength(12));
    final mine = GameRepository(feed.games).forCoach(coach);
    expect(mine, hasLength(12));
    expect(GameRepository.query(mine, GameView.recent, const GameFilter()), hasLength(12));
    expect(GameRepository.record(mine).wins, 12);
  });

  test('atualiza placar/horário sem duplicar; jogo encerrado não volta a agendado', () {
    final feed = LeagueFeed(LeagueSource.fpb);
    final d = DateTime(2026, 10, 25, 15);
    feed.apply(r([g('x1', 'Tupã', 'Sorocaba', d)]));
    feed.apply(r([g('x1', 'Tupã', 'Sorocaba', d.add(const Duration(hours: 1)), hs: 70, as_: 65, status: 'FINAL')]));
    feed.apply(r([g('x1', 'Tupã', 'Sorocaba', null)])); // leitura parcial
    expect(feed.games, hasLength(1));
    final x = feed.games.single;
    expect(x.homeScore, 70);
    expect(x.status, 'FINAL');
    expect(x.scheduledAt, d.add(const Duration(hours: 1)));
    // Mesma partida vinda de outra página com outro id e sem categoria: não duplica.
    feed.apply(r([g('noticia-1', 'Tupã', 'Sorocaba', DateTime(2026, 10, 25), cat: '')]));
    expect(feed.games, hasLength(1));
  });

  test('equipe do treinador: categoria e temporada separam o Monstrinho Sub-13 do Sub-16', () {
    final games = [
      g('a', 'Tupã', 'Lins', DateTime(2026, 4, 1), hs: 70, as_: 60, status: 'FINAL'),
      g('b', 'Monstrinho', 'Bauru', DateTime(2026, 4, 8), hs: 50, as_: 60, status: 'FINAL', cat: 'SUB 13 M'),
      g('c', 'Marília', 'ATB – Associação Tupã Basquete', DateTime(2026, 5, 1), hs: 61, as_: 66, status: 'FINAL'),
      g('d', 'Tupã', 'Franca', DateTime(2025, 5, 1), hs: 40, as_: 66, status: 'FINAL'),
      g('e', 'Bauru', 'Lins', DateTime(2026, 5, 2)),
      g('f', 'Tupã', 'Paulistano', DateTime(2026, 11, 20)),
    ];
    final repo = GameRepository(games);
    final mine = repo.forCoach(coach);
    expect(mine.map((x) => x.game.id).toSet(), {'a', 'c', 'f'});
    expect(repo.forCoach(coach, allSeasons: true).map((x) => x.game.id).toSet(), {'a', 'c', 'd', 'f'});

    final now = DateTime(2026, 10, 22);
    expect(GameRepository.query(mine, GameView.upcoming, const GameFilter(), now: now).map((x) => x.game.id), ['f']);
    expect(GameRepository.query(mine, GameView.recent, const GameFilter(), now: now).map((x) => x.game.id), ['c', 'a']);
    expect(GameRepository.query(mine, GameView.season, const GameFilter(), now: now).map((x) => x.game.id), ['a', 'c', 'f']);

    final c = mine.firstWhere((x) => x.game.id == 'c');
    expect(c.isHome, isFalse);
    expect(c.opponent, 'Marília');
    expect(c.result, 'V');
    expect(GameRepository.query(mine, GameView.all, const GameFilter(home: false), now: now).map((x) => x.game.id), ['c']);
    expect(GameRepository.query(mine, GameView.all, const GameFilter(result: 'V'), now: now), hasLength(2));
    expect(GameRepository.query(mine, GameView.all, const GameFilter(month: 4), now: now).map((x) => x.game.id), ['a']);
    expect(GameRepository.query(mine, GameView.all, const GameFilter(opponent: 'marilia'), now: now).map((x) => x.game.id), ['c']);
  });

  test('o mesmo jogo por duas fontes vira um só, com o registro mais completo', () {
    final d = DateTime(2026, 6, 6, 10);
    final combined = GameRepository.combine([
      g('noticia', 'Tupã', 'Lins', d, hs: 70, as_: 60, status: 'FINAL'),
      g('fpb_m123', 'Tupã', 'Lins', d, hs: 70, as_: 60, status: 'FINAL', ext: '123', comp: 'SUB 16M 2026'),
    ]);
    expect(combined, hasLength(1));
    expect(combined.single.externalId, '123');
    expect(combined.single.competitionName, 'SUB 16M 2026');
  });
}
