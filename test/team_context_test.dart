import 'package:flutter_test/flutter_test.dart';
import 'package:arco_analytics/models/team_context.dart';

void main() {
  test('Tupã reconhece identidades oficiais da FPB', () {
    const team = TeamContext.tupaMonstrinho2026;
    expect(team.matchesExternalName('ATB - ASSOCIAÇÃO TUPÃ BASQUETE'), isTrue);
    expect(team.matchesExternalName('F.R. TUPÃ'), isTrue);
    expect(team.matchesExternalName('Tupã Basquete'), isTrue);
  });

  test('não associa outro clube por engano', () {
    const team = TeamContext.tupaMonstrinho2026;
    expect(team.matchesExternalName('Bauru Basket'), isFalse);
    expect(team.matchesExternalName('Sesi Franca'), isFalse);
  });
}
