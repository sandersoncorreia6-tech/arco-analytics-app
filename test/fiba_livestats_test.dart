import 'dart:io';

import 'package:arco_analytics/data/sources/fiba_livestats.dart';
import 'package:arco_analytics/domain/services/stats_aggregator.dart';
import 'package:arco_analytics/presentation/widgets/court_shot_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = File('test/fixtures/fiba_livestats_data.json').readAsStringSync();

  test('lê equipes, jogadores, períodos e extras do data.json', () {
    final g = FibaLiveStats.parse(body, matchId: '2512345', league: 'FPB');
    expect(g.status, 'FINAL');
    expect(g.home.name, 'Associação Tupã Basquete');
    expect(g.home.code, 'ATB');
    expect(g.home.score, 72);
    expect(g.away.score, 65);
    expect(g.home.periodScores, [20, 15, 18, 19]);
    expect(g.home.extras['paint'], 30);
    expect(g.home.totals.reb, 35);
    expect(g.home.totals.possessions, closeTo(60 - 10 + 12 + 0.44 * 16, .001));

    final pedro = g.home.players.first;
    expect(pedro.name, 'Pedro Almeida');
    expect(pedro.number, '7');
    expect(pedro.starter, isTrue);
    expect(pedro.stats.points, 22);
    expect(pedro.stats.seconds, 31 * 60 + 20);
    expect(pedro.stats.tpm, 3);
    expect(pedro.stats.plusMinus, 9);
    expect(g.home.players.firstWhere((p) => p.name == 'João da Silva').played, isFalse);
  });

  test('arremessos normalizados para meia quadra e lance a lance', () {
    final g = FibaLiveStats.parse(body, matchId: '2512345', league: 'FPB');
    expect(g.shots, hasLength(4));
    final layup = g.shots.first;
    expect(layup.made, isTrue);
    expect(layup.points, 2);
    expect(layup.player, 'Pedro Almeida');
    expect(layup.y, closeTo(.12, .001));
    expect(layup.x, closeTo(.5, .001));
    expect(zoneOf(layup), ShotZone.rim);
    // Arremesso na cesta oposta é espelhado para a mesma meia quadra.
    final other = g.shots[2];
    expect(other.y, closeTo(.12, .001));
    expect(other.x, closeTo(.52, .001));
    expect(zoneOf(g.shots[1]), ShotZone.aboveBreak3);

    expect(g.plays.first.label, 'Fim de jogo');
    expect(g.plays[1].label, 'Lance livre convertido');
    expect(g.plays[1].score, '72-65');
    expect(g.plays[2].label, 'Rebote defensivo');
  });

  test('agrega temporada por equipe e jogador', () {
    final g1 = FibaLiveStats.parse(body, matchId: '1', league: 'FPB');
    final g2 = FibaLiveStats.parse(body, matchId: '2', league: 'FPB');
    final seasons = StatsAggregator.build([g1, g2]);
    final tupa = seasons[StatsAggregator.teamKey('Associação Tupã Basquete')]!;
    expect(tupa.games, 2);
    expect(tupa.wins, 2);
    expect(tupa.ppg, 72);
    expect(tupa.oppPpg, 65);
    expect(tupa.players, hasLength(2)); // quem não jogou fica de fora
    final pedro = tupa.roster.first;
    expect(pedro.name, 'Pedro Almeida');
    expect(pedro.games, 2);
    expect(pedro.ppg, 22);
    expect(pedro.shots, hasLength(4));
    expect(pedro.log, hasLength(2));
    expect(seasons[StatsAggregator.teamKey('Marília')]!.losses, 2);
  });

  test('encontra ids de partida em links e páginas', () {
    const html = '''
      <a href="https://fibalivestats.dcd.shared.geniussports.com/u/FPB/2512345/">Estatística</a>
      <iframe src="https://hosted.dcd.shared.geniussports.com/FPB/pt/competition/40000/match/2512346/boxscore"></iframe>
      <script>var url = "https://fibalivestats.dcd.shared.geniussports.com/data/2512347/data.json";</script>''';
    expect(FibaLiveStats.findMatchIds(html), {'2512345', '2512346', '2512347'});
    expect(FibaLiveStats.matchIdFromInput('https://www.fibalivestats.com/u/FPB/2512348/bs.html'), '2512348');
    expect(FibaLiveStats.matchIdFromInput(' 2512349 '), '2512349');
    expect(FibaLiveStats.matchIdFromInput('https://fpb.com.br/online/'), isNull);
  });

  test('json que não é de partida gera erro claro', () {
    expect(() => FibaLiveStats.parse('{"ok":true}', matchId: '1', league: 'FPB'), throwsFormatException);
  });
}
