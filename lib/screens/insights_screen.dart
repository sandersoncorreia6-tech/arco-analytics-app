import 'package:flutter/material.dart';
import '../data/mock_repository.dart';
import '../services/insight_engine.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import '../widgets/insight_tile.dart';
import '../widgets/section_card.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final latest = state.games.first;
    final names = {for (final p in state.players) p.id: p.name};
    final recorded = AnalyticsService.lineupsFromGame(latest, names);
    final insights = InsightEngine.build(games: state.games, players: state.players, lineups: recorded.isEmpty ? MockRepository.lineups : recorded);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Dado → contexto → insight → decisão.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        SectionCard(title: 'Descobertas do sistema', child: Column(children: insights.map((e) => InsightTile(insight: e)).toList())),
        const SizedBox(height: 14),
        const SectionCard(
          title: 'Como o motor pensa',
          child: Text(
            'O MVP já cruza eficiência de arremesso, turnovers, ritmo, resultados, impacto On/Off e lineups. As conclusões são acompanhadas por evidência e tamanho da amostra para evitar que uma sequência curta vire uma falsa certeza.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        const SizedBox(height: 14),
        const SectionCard(
          title: 'Pergunte ao ARCO',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Próxima camada de IA', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 10),
            Text('• Por que estamos perdendo no quarto período?\n• Qual é nossa melhor formação defensiva?\n• Quem deveria dividir mais minutos com Rafael?\n• Onde o próximo adversário é mais vulnerável?', style: TextStyle(color: Colors.white70, height: 1.6)),
            SizedBox(height: 14),
            TextField(enabled: false, decoration: InputDecoration(hintText: 'IA será conectada depois do banco de dados real', prefixIcon: Icon(Icons.auto_awesome), border: OutlineInputBorder())),
          ]),
        ),
      ],
    );
  }
}
