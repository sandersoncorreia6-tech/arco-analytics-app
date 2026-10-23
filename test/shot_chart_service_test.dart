import 'package:flutter_test/flutter_test.dart';
import 'package:arco_analytics/models/play_event.dart';
import 'package:arco_analytics/services/shot_chart_service.dart';

void main() {
  test('shot chart usa apenas arremessos com coordenadas', () {
    final events = [
      PlayEvent(
        type: PlayEventType.threeMade,
        period: 1,
        timestamp: DateTime(2026, 10, 1),
        playerId: 'p1',
        shotX: 0.25,
        shotY: 0.4,
      ),
      PlayEvent(
        type: PlayEventType.assist,
        period: 1,
        timestamp: DateTime(2026, 10, 1),
        playerId: 'p2',
      ),
      PlayEvent(
        type: PlayEventType.twoMiss,
        period: 1,
        timestamp: DateTime(2026, 10, 1),
        playerId: 'p3',
      ),
    ];

    final shots = ShotChartService.fromEvents(events);
    expect(shots, hasLength(1));
    expect(shots.first.points, 3);
    expect(shots.first.made, isTrue);
    expect(shots.first.x, 0.25);
  });
}
