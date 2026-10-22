import 'package:arco_analytics/analysis/sample_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('poucos minutos nunca viram conclusão forte', () {
    expect(SampleSize.of(minutes: 2, possessions: 4, games: 1), SampleLevel.low);
    expect(SampleSize.of(minutes: 18, possessions: 38, games: 1), SampleLevel.low);
    expect(SampleSize.of(minutes: 20, possessions: 45, games: 3), SampleLevel.medium);
    expect(SampleSize.of(minutes: 60, possessions: 130, games: 2), SampleLevel.medium); // 2 jogos limitam o teto
    expect(SampleSize.of(minutes: 60, possessions: 130, games: 6), SampleLevel.high);
    expect(SampleLevel.low.label, 'AMOSTRA BAIXA');
  });
}
