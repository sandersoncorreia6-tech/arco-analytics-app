import 'package:flutter/material.dart';
import '../data/mock_repository.dart';
import '../services/advanced_analytics_service.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import '../widgets/shot_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final summary = AdvancedAnalyticsService.summarize(state.games);
    final sample = AdvancedAnalyticsService.preferredSample(state.games);
    final latest = sample.isEmpty ? null : ([...sample]..sort((a, b) => b.date.compareTo(a.date))).first;
    final recent = sample.length <= 3 ? sample : ([...sample]..sort((a, b) => b.date.compareTo(a.date))).take(3).toList();
    final recentSummary = AdvancedAnalyticsService.summarize(recent);
    final names = {for (final p in state.players) p.id: p.name};
    final recorded = latest == null ? const [] : AnalyticsService.lineupsFromGame(latest, names);
    final lineups = recorded.isNotEmpty ? recorded : ([...MockRepository.lineups]..sort((a, b) => b.netRating.compareTo(a.netRating)));

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Analytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          summary.usesDemoData
              ? 'Amostra demonstrativa até existir scout real suficiente.'
              : '${summary.games} jogos • ${summary.possessions} posses • confiança ${summary.sampleConfidence}',
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.28,
          children: [
            MetricCard(label: 'ORtg', value: summary.offensiveRating.toStringAsFixed(1), helper: 'pts / 100 posses', icon: Icons.bolt_rounded),
            MetricCard(label: 'DRtg', value: summary.defensiveRating.toStringAsFixed(1), helper: 'menor é melhor', icon: Icons.shield_outlined),
            MetricCard(label: 'Net Rating', value: '${summary.netRating >= 0 ? '+' : ''}${summary.netRating.toStringAsFixed(1)}', helper: 'saldo / 100 posses', icon: Icons.balance_rounded),
            MetricCard(label: 'eFG%', value: '${summary.efg.toStringAsFixed(1)}%', helper: 'eficiência de arremesso', icon: Icons.gps_fixed),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Four Factors • temporada',
          child: Column(children: [
            _Factor(label: 'eFG%', value: summary.efg, helper: 'valor dos arremessos'),
            _Factor(label: 'TOV%', value: summary.turnoverPct, helper: 'posses desperdiçadas'),
            _Factor(label: 'ORB%', value: summary.offensiveReboundPct, helper: 'segundas chances'),
            _Factor(label: 'FT Rate', value: summary.freeThrowRate, helper: 'pressão na linha'),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Últimos 3 × temporada',
          child: Column(children: [
            _Compare(label: 'Net Rating', recent: recentSummary.netRating, season: summary.netRating),
            _Compare(label: 'eFG%', recent: recentSummary.efg, season: summary.efg),
            _Compare(label: 'TOV%', recent: recentSummary.turnoverPct, season: summary.turnoverPct, lowerIsBetter: true),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: recorded.isNotEmpty ? 'Lineup Analytics • scout real' : 'Lineup Analytics • demo',
          child: Column(children: lineups.take(8).map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.players.join(' • '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text('${l.possessions} posses • confiança ${AnalyticsService.sampleConfidence(l.possessions)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
              Text('${l.netRating >= 0 ? '+' : ''}${l.netRating.toStringAsFixed(1)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: l.netRating >= 0 ? Colors.greenAccent : Colors.redAccent)),
            ]),
          )).toList()),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Shot chart',
          trailing: const Text('coordenadas demo', style: TextStyle(color: Colors.white54, fontSize: 12)),
          child: ShotChart(shots: MockRepository.shots),
        ),
      ],
    );
  }
}

class _Factor extends StatelessWidget {
  final String label;
  final double value;
  final String helper;
  const _Factor({required this.label, required this.value, required this.helper});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      SizedBox(width: 72, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
      Expanded(child: Text(helper, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
    ]),
  );
}

class _Compare extends StatelessWidget {
  final String label;
  final double recent;
  final double season;
  final bool lowerIsBetter;
  const _Compare({required this.label, required this.recent, required this.season, this.lowerIsBetter = false});
  @override
  Widget build(BuildContext context) {
    final diff = recent - season;
    final good = lowerIsBetter ? diff <= 0 : diff >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text('3 jogos ${recent.toStringAsFixed(1)}'),
        const SizedBox(width: 12),
        Text('temp. ${season.toStringAsFixed(1)}'),
        const SizedBox(width: 8),
        Icon(good ? Icons.trending_up : Icons.trending_down, size: 18, color: good ? Colors.greenAccent : Colors.orangeAccent),
      ]),
    );
  }
}
