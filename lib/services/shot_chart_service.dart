import '../models/game.dart';
import '../models/play_event.dart';
import '../models/shot.dart';

class ShotChartService {
  static List<Shot> fromGame(Game game) {
    return fromEvents(game.events);
  }

  static List<Shot> fromEvents(List<PlayEvent> events) {
    return events
        .where((event) => event.isShot && event.hasShotLocation)
        .map(
          (event) => Shot(
            x: event.shotX!.clamp(0.0, 1.0).toDouble(),
            y: event.shotY!.clamp(0.0, 1.0).toDouble(),
            made: event.shotMade,
            points: event.shotPoints,
            player: event.playerId ?? '',
          ),
        )
        .toList();
  }
}
