import '../models/game.dart';
import '../models/lineup.dart';
import '../models/player.dart';
import 'advanced_analytics_service.dart';
import 'analytics_service.dart';
import 'insight_engine.dart';

class ReportService {
  static String seasonReport({
    required String teamName,
    required List<Game> games,
    required List<Player> players,
  }) {
    final summary = AdvancedAnalyticsService.summarize(games);
    final latest = AdvancedAnalyticsService.preferredSample(games);
    final names = {for (final p in players) p.id: p.name};
    final lineups = latest.isEmpty
        ? <Lineup>[]
        : AnalyticsService.lineupsFromGame(latest.first, names);
    final insights = InsightEngine.build(
      games: games,
      players: players,
      lineups: lineups,
    );

    final buffer = StringBuffer();
    buffer.writeln('ARCO ANALYTICS — RELATÓRIO DA TEMPORADA');
    buffer.writeln(teamName);
    buffer.writeln();
    buffer.writeln('AMOSTRA');
    buffer.writeln('${summary.games} jogos • ${summary.possessions} posses • confiança ${summary.sampleConfidence}');
    if (summary.usesDemoData) buffer.writeln('ATENÇÃO: amostra demonstrativa.');
    buffer.writeln();
    buffer.writeln('RESULTADOS');
    buffer.writeln('Retrospecto: ${summary.wins}-${summary.losses} (${summary.winPct.toStringAsFixed(1)}%)');
    buffer.writeln('Pontos feitos: ${summary.avgPointsFor.toStringAsFixed(1)} por jogo');
    buffer.writeln('Pontos sofridos: ${summary.avgPointsAgainst.toStringAsFixed(1)} por jogo');
    buffer.writeln();
    buffer.writeln('EFICIÊNCIA');
    buffer.writeln('ORtg: ${summary.offensiveRating.toStringAsFixed(1)}');
    buffer.writeln('DRtg: ${summary.defensiveRating.toStringAsFixed(1)}');
    buffer.writeln('Net Rating: ${summary.netRating >= 0 ? '+' : ''}${summary.netRating.toStringAsFixed(1)}');
    buffer.writeln('eFG%: ${summary.efg.toStringAsFixed(1)}%');
    buffer.writeln('TOV%: ${summary.turnoverPct.toStringAsFixed(1)}%');
    buffer.writeln('ORB%: ${summary.offensiveReboundPct.toStringAsFixed(1)}%');
    buffer.writeln('FT Rate: ${summary.freeThrowRate.toStringAsFixed(1)}%');
    buffer.writeln();
    buffer.writeln('INSIGHTS');
    if (insights.isEmpty) {
      buffer.writeln('Amostra ainda insuficiente para gerar insights.');
    } else {
      for (final insight in insights) {
        buffer.writeln('• ${insight.title}: ${insight.evidence}');
      }
    }
    buffer.writeln();
    buffer.writeln('Regra ARCO: Dado → Contexto → Insight → Decisão.');
    return buffer.toString();
  }
}
