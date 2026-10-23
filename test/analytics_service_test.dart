import 'package:flutter_test/flutter_test.dart';
import 'package:arco_analytics/services/analytics_service.dart';
import 'package:arco_analytics/services/advanced_analytics_service.dart';
import 'package:arco_analytics/models/game.dart';

Game game({
  String source = 'arco',
  int score = 80,
  int opp = 70,
  int possessions = 70,
  int fgm = 30,
  int fga = 60,
  int threes = 10,
  int fta = 20,
  int tov = 8,
  int orb = 12,
}) =>
    Game(
      id: 'g1',
      teamId: 'team_tupa_monstrinho',
      seasonId: 'season_2026',
      competition: 'FPB',
      category: 'SUB-16',
      source: source,
      opponent: 'Bauru',
      date: DateTime(2026, 10, 1),
      ourScore: score,
      opponentScore: opp,
      possessions: possessions,
      fgm: fgm,
      fga: fga,
      threePm: threes,
      threePa: 25,
      ftm: 10,
      fta: fta,
      turnovers: tov,
      offensiveRebounds: orb,
      availableOffensiveRebounds: 30,
      opponentPoints: opp,
    );

void main() {
  test('eFG calcula valor dos arremessos de três', () {
    final value = AnalyticsService.efg(fgm: 30, threePm: 10, fga: 60);
    expect(value, closeTo(58.333, 0.01));
  });

  test('resumo de temporada prefere jogos reais a mocks', () {
    final summary = AdvancedAnalyticsService.summarize([
      game(source: 'mock', score: 100),
      game(source: 'arco', score: 80),
    ]);
    expect(summary.games, 1);
    expect(summary.pointsFor, 80);
    expect(summary.usesDemoData, isFalse);
  });

  test('confiança aumenta com número de posses', () {
    expect(AnalyticsService.sampleConfidence(50), 'BAIXA');
    expect(AnalyticsService.sampleConfidence(150), 'MÉDIA');
    expect(AnalyticsService.sampleConfidence(350), 'ALTA');
  });
}
