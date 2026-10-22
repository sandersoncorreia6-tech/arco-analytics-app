import 'dart:convert';
import 'dart:io';

import 'package:arco_analytics/domain/analysis/analyst.dart';
import 'package:arco_analytics/domain/analysis/game_analysis.dart';
import 'package:arco_analytics/domain/analysis/lineups.dart';
import 'package:arco_analytics/domain/analysis/reports.dart';
import 'package:arco_analytics/domain/analysis/scout_adapter.dart';
import 'package:arco_analytics/domain/analysis/season_analysis.dart';
import 'package:arco_analytics/data/demo/mock_repository.dart';
import 'package:arco_analytics/domain/models/game.dart';
import 'package:arco_analytics/domain/models/play_event.dart';
import 'package:arco_analytics/data/sources/fiba_livestats.dart';
import 'package:arco_analytics/services/report_export.dart';
import 'package:arco_analytics/domain/services/stats_aggregator.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Partida do fixture com placar e lances livres alterados: Tupã perde por 2
/// errando muitos lances livres.
String _closeLoss() {
  final data = jsonDecode(File('test/fixtures/fiba_livestats_data.json').readAsStringSync()) as Map<String, dynamic>;
  final t1 = data['tm']['1'] as Map<String, dynamic>;
  t1['score'] = 63;
  t1['full_score'] = 63;
  t1['tot_sFreeThrowsMade'] = 3;
  t1['tot_sFreeThrowsAttempted'] = 16;
  t1['p4_score'] = 8;
  return jsonEncode(data);
}

void main() {
  final win = FibaLiveStats.parse(File('test/fixtures/fiba_livestats_data.json').readAsStringSync(), matchId: '1', league: 'FPB');
  final loss = FibaLiveStats.parse(_closeLoss(), matchId: '2', league: 'FPB');

  test('e se: lances livres viram a derrota', () {
    final a = GameAnalysis(loss, 1);
    expect(a.margin, -2);
    final ft = a.whatIfs().firstWhere((w) => w.title == 'Lances livres');
    expect(ft.extraPoints, 9); // 75% de 16 = 12; fez 3
    expect(ft.flipsResult, isTrue);
    expect(ft.detail, contains('teria VENCIDO por 7'));
    expect(a.trainingPlan().first, contains('Lances livres'));
    expect(a.decisiveFactor(), isNotNull);
  });

  test('pior quarto e destaque no pós-jogo', () {
    final a = GameAnalysis(loss, 1);
    final f = a.findings();
    expect(f.any((x) => x.title == 'Pior período: 4º quarto'), isTrue);
    expect(f.any((x) => x.title == 'Destaque: Pedro Almeida'), isTrue);
    final r = Reports.postGame(a);
    expect(r.toPlainText(), contains('Recomendações para o próximo treino'));
  });

  test('temporada: derrota que viraria com lances livres e quartos', () {
    final team = StatsAggregator.build([win, loss])[StatsAggregator.teamKey('Associação Tupã Basquete')]!;
    final s = SeasonAnalysis(team);
    expect(s.lossesFlippedByFreeThrows(), hasLength(1));
    expect(s.findings().any((f) => f.title.startsWith('Lances livres custaram 1 vitória')), isTrue);
    expect(s.quarterAverages(), hasLength(4));
  });

  test('analista responde perguntas do treinador', () {
    final teams = StatsAggregator.build([win, loss]);
    final mine = teams[StatsAggregator.teamKey('Associação Tupã Basquete')]!;
    final analyst = ArcoAnalyst(teams: teams, myTeams: [mine]);

    expect(analyst.answer('De onde minha equipe mais erra?').text, contains('Onde mais erra'));
    expect(analyst.answer('e se tivéssemos acertado os lances livres?').text, contains('teria VENCIDO'));
    expect(analyst.answer('Por que perdemos o último jogo?').text, contains('Derrota por 2'));
    expect(analyst.answer('em qual quarto o time mais cai').text, contains('mais cai no'));
    expect(analyst.answer('O que treinar esta semana?').text, contains('Prioridades'));
    expect(analyst.answer('como está o Pedro?').text, contains('Pedro Almeida'));
    expect(analyst.answer('relatório do adversário Marília').text, contains('Relatório de Marília'));
    expect(analyst.answer('quem são os destaques').text, contains('Pontos:'));
    expect(ArcoAnalyst(teams: const {}, myTeams: const []).answer('oi').text, contains('Ainda não tenho jogos'));
  });

  test('quintetos reconstruídos pelas substituições do lance a lance', () {
    final data = jsonDecode(File('test/fixtures/fiba_livestats_data.json').readAsStringSync()) as Map<String, dynamic>;
    final pl = data['tm']['1']['pl'] as Map<String, dynamic>;
    Map<String, dynamic> extra(String first, String last) => {
      ...pl['1'] as Map<String, dynamic>,
      'firstName': first,
      'familyName': last,
      'starter': 1,
      'sMinutes': '20:00',
    };
    pl['5'] = extra('ANA', 'UM');
    pl['6'] = extra('BIA', 'DOIS');
    pl['7'] = extra('CAIO', 'TRES');
    (pl['3'] as Map<String, dynamic>)['starter'] = 0;
    // Cronológico (o data.json vem invertido): 2 pts com o quinteto inicial, troca 7→3, 3 pts do adversário.
    data['pbp'] = [
      {'gt': '05:00', 'period': 1, 'tno': 2, 'pno': 4, 'actionType': '3pt', 'success': 1},
      {'gt': '08:00', 'period': 1, 'tno': 1, 'pno': 3, 'actionType': 'substitution', 'subType': 'in'},
      {'gt': '08:00', 'period': 1, 'tno': 1, 'pno': 7, 'actionType': 'substitution', 'subType': 'out'},
      {'gt': '09:00', 'period': 1, 'tno': 1, 'pno': 1, 'actionType': '2pt', 'success': 1},
      {'gt': '10:00', 'period': 1, 'tno': 0, 'actionType': 'period', 'subType': 'start'},
    ];
    final g = FibaLiveStats.parse(jsonEncode(data), matchId: '9', league: 'FPB');
    final lineups = LineupBuilder.forGame(g, 1)..sort((a, b) => b.seconds.compareTo(a.seconds));
    expect(lineups, hasLength(2));
    final first = lineups.firstWhere((l) => l.names.contains('Caio Tres'));
    expect(first.pointsFor, 2);
    expect(first.seconds, 120);
    final second = lineups.firstWhere((l) => l.names.contains('João da Silva'));
    expect(second.pointsAgainst, 3);
    expect(second.seconds, 180);
  });

  test('scout do ARCO vira box score analisável', () {
    final start = DateTime(2026, 10, 20, 19);
    final game = Game(
      opponent: 'Lins',
      date: start,
      ourScore: 5,
      opponentScore: 3,
      possessions: 4,
      fgm: 2,
      fga: 3,
      threePm: 1,
      threePa: 1,
      ftm: 0,
      fta: 0,
      turnovers: 1,
      offensiveRebounds: 0,
      availableOffensiveRebounds: 1,
      opponentPoints: 3,
      playerStats: const {'p1': PlayerStatLine(points: 5, fgm: 2, fga: 3, threePm: 1, threePa: 1, turnovers: 1)},
      events: [
        PlayEvent(type: PlayEventType.twoMade, playerId: 'p1', period: 1, timestamp: start.add(const Duration(seconds: 30))),
        PlayEvent(type: PlayEventType.opponentThree, period: 2, timestamp: start.add(const Duration(minutes: 12))),
        PlayEvent(type: PlayEventType.threeMade, playerId: 'p1', period: 2, timestamp: start.add(const Duration(minutes: 13)), tag: 'Transição'),
      ],
    );
    final box = ScoutAdapter.toBoxScore(game, teamName: 'Tupã / Monstrinho', roster: MockRepository.players);
    expect(box.home.periodScores.take(2), [2, 3]);
    expect(box.away.periodScores.take(2), [0, 3]);
    expect(box.home.players.single.name, 'Lucas Silva');
    expect(box.plays.first.type, '3pt'); // mais recente primeiro, como no data.json
    expect(Reports.postGame(GameAnalysis(box, 1)).title, contains('Tupã / Monstrinho 5 × 3 Lins'));
  });

  test('link do vídeo no momento exato', () {
    expect(AppState.videoUrlAt('https://www.youtube.com/watch?v=abc', 125), 'https://www.youtube.com/watch?v=abc&t=125s');
    expect(AppState.videoUrlAt('https://youtu.be/abc', 7), 'https://youtu.be/abc?t=7s');
    expect(AppState.videoUrlAt('https://cdn.site/jogo.mp4', 60), 'https://cdn.site/jogo.mp4#t=60');
  });

  test('PDF do relatório é gerado', () async {
    final bytes = await ReportExport.pdf(Reports.postGame(GameAnalysis(loss, 1)));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
