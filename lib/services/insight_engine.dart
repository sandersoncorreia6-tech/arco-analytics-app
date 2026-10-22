import '../models/game.dart';
import '../models/insight.dart';
import '../models/lineup.dart';
import '../models/player.dart';
import 'analytics_service.dart';

class InsightEngine {
  static List<Insight> build({
    required List<Game> games,
    required List<Player> players,
    required List<Lineup> lineups,
  }) {
    final result = <Insight>[];
    if (games.isNotEmpty) {
      final latest = games.first;
      final efg = AnalyticsService.efg(fgm: latest.fgm, threePm: latest.threePm, fga: latest.fga);
      final tov = AnalyticsService.turnoverPct(turnovers: latest.turnovers, possessions: latest.possessions);
      if (tov > 18) {
        result.add(Insight(
          title: 'Turnovers estão custando posses',
          description: 'O último jogo terminou acima da faixa de controle recomendada para o nosso modelo inicial.',
          level: InsightLevel.warning,
          evidence: 'TOV% ${tov.toStringAsFixed(1)}% • ${latest.turnovers} desperdícios',
        ));
      } else {
        result.add(Insight(
          title: 'Boa proteção da posse',
          description: 'A equipe conseguiu manter os desperdícios sob controle no último jogo.',
          level: InsightLevel.positive,
          evidence: 'TOV% ${tov.toStringAsFixed(1)}%',
        ));
      }
      result.add(Insight(
        title: efg >= 52 ? 'Eficiência de arremesso favorável' : 'Seleção de arremessos merece revisão',
        description: efg >= 52
            ? 'O valor dos arremessos convertidos ficou em uma faixa eficiente.'
            : 'O eFG% indica que o time precisa gerar finalizações de maior valor ou converter melhor as atuais.',
        level: efg >= 52 ? InsightLevel.positive : InsightLevel.warning,
        evidence: 'eFG% ${efg.toStringAsFixed(1)}%',
      ));
    }

    if (games.length >= 3) {
      final fast = games.where((g) => g.possessions >= 74).toList();
      final slow = games.where((g) => g.possessions < 74).toList();
      if (fast.isNotEmpty && slow.isNotEmpty) {
        final fastWin = fast.where((g) => g.won).length / fast.length;
        final slowWin = slow.where((g) => g.won).length / slow.length;
        if ((fastWin - slowWin).abs() >= .20) {
          final fastBetter = fastWin > slowWin;
          result.add(Insight(
            title: fastBetter ? 'Ritmo alto está associado a mais vitórias' : 'Ritmo controlado está associado a mais vitórias',
            description: 'A amostra ainda é pequena, mas já existe um padrão útil para acompanhar na preparação do jogo.',
            level: InsightLevel.neutral,
            evidence: '${(fastWin * 100).toStringAsFixed(0)}% vitórias em 74+ posses vs ${(slowWin * 100).toStringAsFixed(0)}% abaixo de 74',
          ));
        }
      }
    }

    if (players.isNotEmpty) {
      final ranked = [...players]..sort((a, b) => AnalyticsService.onOffNet(b).compareTo(AnalyticsService.onOffNet(a)));
      final p = ranked.first;
      final onOff = AnalyticsService.onOffNet(p);
      if (onOff > 4) {
        result.add(Insight(
          title: 'Valor oculto: ${p.name}',
          description: 'O impacto coletivo em quadra é maior do que uma leitura baseada somente em pontos poderia mostrar.',
          level: InsightLevel.positive,
          evidence: 'On/Off líquido ${onOff >= 0 ? '+' : ''}${onOff.toStringAsFixed(1)}',
        ));
      }
    }

    if (lineups.isNotEmpty) {
      final ranked = [...lineups]..sort((a, b) => b.netRating.compareTo(a.netRating));
      final best = ranked.first;
      result.add(Insight(
        title: 'Melhor combinação na amostra atual',
        description: best.players.join(' • '),
        level: InsightLevel.positive,
        evidence: '${best.netRating >= 0 ? '+' : ''}${best.netRating.toStringAsFixed(1)} Net Rating • ${best.possessions} posses • confiança ${AnalyticsService.sampleConfidence(best.possessions)}',
      ));
    }

    return result.take(6).toList();
  }
}
