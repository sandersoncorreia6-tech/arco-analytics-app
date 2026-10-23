import 'package:flutter_test/flutter_test.dart';
import 'package:arco_analytics/models/game.dart';
import 'package:arco_analytics/services/arco_assistant_service.dart';

void main() {
  test('Assistant sinaliza turnovers altos com evidência', () {
    final game = Game(
      id: 'g1',
      teamId: 'team_tupa_monstrinho',
      seasonId: 'season_2026',
      competition: 'FPB',
      category: 'SUB-16',
      source: 'arco',
      opponent: 'Franca',
      date: DateTime(2026, 10, 1),
      ourScore: 70,
      opponentScore: 72,
      possessions: 60,
      fgm: 24,
      fga: 55,
      threePm: 7,
      threePa: 20,
      ftm: 15,
      fta: 20,
      turnovers: 14,
      offensiveRebounds: 8,
      availableOffensiveRebounds: 25,
      opponentPoints: 72,
    );

    final answer = ArcoAssistantService.answer(
      question: 'Estamos perdendo muitas posses?',
      games: [game],
      players: const [],
      lineups: const [],
    );

    expect(answer.title.toLowerCase(), contains('perdas'));
    expect(answer.evidence.join(' '), contains('TOV'));
  });
}
