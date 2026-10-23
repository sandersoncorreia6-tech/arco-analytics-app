import 'package:flutter/material.dart';
import '../services/advanced_analytics_service.dart';
import '../state/app_state.dart';
import 'game_plan_screen.dart';

class OpponentsScreen extends StatelessWidget {
  const OpponentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final reports = AdvancedAnalyticsService.opponents(state.games);

    return Scaffold(
      appBar: AppBar(title: const Text('Adversários')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Perfis calculados a partir dos jogos registrados. Quanto maior a amostra, maior a confiança do plano de jogo.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Ainda não há adversários com dados de scout.'),
              ),
            )
          else
            ...reports.map((report) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
                title: Text(report.opponent, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(
                  '${report.summary.games} jogo(s) • retrospecto ${report.record} • Net ${report.summary.netRating >= 0 ? '+' : ''}${report.summary.netRating.toStringAsFixed(1)} • confiança ${report.summary.sampleConfidence}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GamePlanScreen(report: report)),
                ),
              ),
            )),
        ],
      ),
    );
  }
}
