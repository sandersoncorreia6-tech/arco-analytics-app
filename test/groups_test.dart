import 'package:arco_analytics/domain/analysis/lineups.dart';
import 'package:flutter_test/flutter_test.dart';

LineupStat l(List<String> names, int seconds, int pf, int pa) {
  final keys = [for (final n in names) n.toLowerCase()];
  return LineupStat(keys, names)
    ..seconds = seconds
    ..pointsFor = pf
    ..pointsAgainst = pa
    ..offPossessions = seconds / 30
    ..defPossessions = seconds / 30;
}

void main() {
  final lineups = [
    l(['A', 'B', 'C', 'D', 'E'], 600, 30, 18), // +12
    l(['A', 'F', 'G', 'D', 'E'], 660, 20, 20), // 0
    l(['H', 'B', 'C', 'F', 'G'], 300, 8, 14), // -6
  ];

  test('duplas e trios somam os quintetos', () {
    final duos = Groups.of(lineups, 2);
    final bc = duos.firstWhere((g) => g.keys.join() == 'bc');
    expect(bc.seconds, 900);
    expect(bc.plusMinus, 6);
    expect(Groups.of(lineups, 3).first.plusMinus, 12);
  });

  test('frase de impacto com contexto', () {
    final s = Groups.impactSentence(lineups, 'a')!;
    expect(s, startsWith('O time teve saldo de +12 com A em quadra durante 21 minutos.'));
    expect(s, contains('A maior diferença aconteceu quando jogou com B e C (+12 em 10 min juntos)'));
    expect(s, contains('AMOSTRA'));
  });
}
