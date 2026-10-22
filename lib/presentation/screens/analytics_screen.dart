import 'package:flutter/material.dart';
import 'package:arco_analytics/data/demo/mock_repository.dart';
import 'package:arco_analytics/domain/services/analytics_service.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/widgets/section_card.dart';
import 'package:arco_analytics/presentation/widgets/court_shot_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final game = state.games.first;
    final names = {for (final p in state.players) p.id: p.name};
    final recorded = AnalyticsService.lineupsFromGame(game, names);
    final lineups = recorded.isNotEmpty ? recorded : ([...MockRepository.lineups]..sort((a, b) => b.netRating.compareTo(a.netRating)));
    final usingDemoLineups = recorded.isEmpty;
    final efg = AnalyticsService.efg(fgm: game.fgm, threePm: game.threePm, fga: game.fga);
    final tov = AnalyticsService.turnoverPct(turnovers: game.turnovers, possessions: game.possessions);
    final orb = AnalyticsService.offensiveReboundPct(offensiveRebounds: game.offensiveRebounds, available: game.availableOffensiveRebounds);
    final ftRate = game.fga == 0 ? 0.0 : (game.fta / game.fga) * 100;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Analytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Descubra por que o time ganha ou perde.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        Builder(
          builder: (context) {
            // Mapa real da equipe do treinador quando houver estatística importada.
            final mine = state.myTeamSeasons.where((t) => t.shots.isNotEmpty).toList();
            final team = mine.isEmpty ? null : mine.first;
            return SectionCard(
              title: 'Mapa de arremessos',
              subtitle: team == null ? 'Amostra demo — importe jogos na aba Stats para ver o mapa real' : '${team.name} • ${team.games} jogos',
              child: CourtShotChart(shots: team?.shots ?? MockRepository.shots),
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: usingDemoLineups ? 'Lineup Analytics • demo' : 'Lineup Analytics • scout real',
          child: Column(
            children: lineups
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(l.players.join(' • '), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(
                                '${l.possessions} posses • confiança ${AnalyticsService.sampleConfidence(l.possessions)}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${l.netRating >= 0 ? '+' : ''}${l.netRating.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: l.netRating >= 0 ? Colors.greenAccent : Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Four Factors • último jogo',
          child: Column(
            children: [
              _Factor(label: 'eFG%', value: efg, helper: 'valor dos arremessos'),
              _Factor(label: 'TOV%', value: tov, helper: 'posses desperdiçadas', lowerIsBetter: true),
              _Factor(label: 'ORB%', value: orb, helper: 'segundas chances'),
              _Factor(label: 'FT Rate', value: ftRate, helper: 'pressão na linha'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Factor extends StatelessWidget {
  final String label;
  final double value;
  final String helper;
  final bool lowerIsBetter;
  const _Factor({required this.label, required this.value, required this.helper, this.lowerIsBetter = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: Text(helper, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ],
      ),
    );
  }
}
