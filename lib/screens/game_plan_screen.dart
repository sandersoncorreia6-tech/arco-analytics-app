import 'package:flutter/material.dart';
import '../services/advanced_analytics_service.dart';
import '../state/app_state.dart';

class GamePlanScreen extends StatelessWidget {
  final OpponentReport report;

  const GamePlanScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final team = AdvancedAnalyticsService.summarize(state.games);
    final plan = AdvancedAnalyticsService.buildGamePlan(team: team, opponent: report);

    return Scaffold(
      appBar: AppBar(title: Text('Game Plan • ${report.opponent}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.opponent, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric(label: 'JOGOS', value: '${report.summary.games}'),
                      _Metric(label: 'RETROSPECTO', value: report.record),
                      _Metric(label: 'PF', value: report.summary.avgPointsFor.toStringAsFixed(1)),
                      _Metric(label: 'PS', value: report.summary.avgPointsAgainst.toStringAsFixed(1)),
                      _Metric(label: 'NET', value: '${report.summary.netRating >= 0 ? '+' : ''}${report.summary.netRating.toStringAsFixed(1)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Confiança da amostra: ${report.summary.sampleConfidence}', style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plano de jogo sugerido', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 12),
                  ...plan.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'O Game Plan é uma recomendação analítica, não uma certeza. O ARCO mostra a confiança da amostra para evitar conclusões fortes com poucos jogos ou posses.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
