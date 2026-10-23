import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/analytics_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class PlayerDetailScreen extends StatelessWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final impact = AnalyticsService.impactScore(player);
    final efg = AnalyticsService.efg(fgm: player.fgm, threePm: player.threePm, fga: player.fga);
    final ts = AnalyticsService.trueShooting(points: player.points, fga: player.fga, fta: player.fta);
    final onOff = AnalyticsService.onOffNet(player);

    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(children: [CircleAvatar(radius: 28, child: Text('${player.number}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(player.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), Text('${player.position} • #${player.number}', style: const TextStyle(color: Colors.white60))])), Text(impact.toStringAsFixed(0), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 20),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3, children: [
            MetricCard(label: 'eFG%', value: '${efg.toStringAsFixed(1)}%', icon: Icons.gps_fixed),
            MetricCard(label: 'TS%', value: '${ts.toStringAsFixed(1)}%', icon: Icons.track_changes),
            MetricCard(label: 'On/Off', value: '${onOff >= 0 ? '+' : ''}${onOff.toStringAsFixed(1)}', icon: Icons.swap_vert_circle_outlined),
            MetricCard(label: 'AST/TO', value: player.turnovers == 0 ? '${player.assists}.0' : (player.assists / player.turnovers).toStringAsFixed(1), icon: Icons.hub_outlined),
          ]),
          const SizedBox(height: 14),
          SectionCard(title: 'Leitura do ARCO', child: Text(onOff > 10 ? 'O impacto coletivo deste atleta é superior ao que seu volume de pontos sugere. Priorize lineups em que ele compartilha a criação sem elevar turnovers.' : 'O atleta produz números individuais, mas o impacto coletivo precisa ser acompanhado em amostras maiores e por combinação de lineup.', style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
