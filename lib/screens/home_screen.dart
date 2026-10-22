import 'package:flutter/material.dart';
import '../data/mock_repository.dart';
import '../services/analytics_service.dart';
import '../services/insight_engine.dart';
import '../state/app_state.dart';
import '../widgets/insight_tile.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import 'live_scout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final game = state.games.first;
    final off = AnalyticsService.offensiveRating(points: game.ourScore, possessions: game.possessions);
    final def = AnalyticsService.defensiveRating(opponentPoints: game.opponentScore, possessions: game.possessions);
    final net = off - def;
    final names = {for (final p in state.players) p.id: p.name};
    final liveLineups = AnalyticsService.lineupsFromGame(game, names);
    final insights = InsightEngine.build(games: state.games, players: state.players, lineups: liveLineups.isEmpty ? MockRepository.lineups : liveLineups);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.track_changes_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Olá, ${state.coach.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text('${state.coach.club} • ${state.coach.role}', style: const TextStyle(color: Colors.white60, fontSize: 12))])),
            const CircleAvatar(child: Icon(Icons.person_outline)),
          ],
        ),
        if (state.activeGame != null) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sensors, color: Colors.redAccent),
              title: Text('Partida em andamento • ${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore}'),
              subtitle: Text('vs ${state.activeGame!.opponent} • ${state.activeGame!.period}Q'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveScoutScreen())),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Central de decisão', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Insights de ${state.coach.club}: o que o treinador precisa saber hoje.', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.28,
          children: [
            MetricCard(label: 'Off Rating', value: off.toStringAsFixed(1), helper: 'pts / 100 posses', icon: Icons.bolt_rounded),
            MetricCard(label: 'Def Rating', value: def.toStringAsFixed(1), helper: 'menor é melhor', icon: Icons.shield_outlined),
            MetricCard(label: 'Net Rating', value: '${net >= 0 ? '+' : ''}${net.toStringAsFixed(1)}', helper: 'saldo / 100 posses', icon: Icons.balance_rounded),
            MetricCard(label: 'Pace', value: '${game.possessions}', helper: 'posses no último jogo', icon: Icons.speed_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Builder(builder: (context) {
          final mine = [
            ...state.fpbGames.where((g) => ('${g.homeTeam} ${g.awayTeam}'.toLowerCase().contains('tupã') || '${g.homeTeam} ${g.awayTeam}'.toLowerCase().contains('monstrinho'))),
          ];
          final lbcMine = state.lbcGames.where((g) => ('${g.homeTeam} ${g.awayTeam}'.toLowerCase().contains('tupã') || '${g.homeTeam} ${g.awayTeam}'.toLowerCase().contains('monstrinho'))).length;
          return SectionCard(
            title: 'Minha equipe nas competições',
            child: Row(children: [
              Expanded(child: _MiniStat(label: 'FPB', value: '${mine.length} jogos')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'LBC', value: '$lbcMine jogos')),
            ]),
          );
        }),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Insights prioritários',
          child: Column(children: insights.take(3).map((e) => InsightTile(insight: e)).toList()),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Último jogo',
          child: Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ARCO  ${game.ourScore}  ×  ${game.opponentScore}  ${game.opponent}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 7), Text(game.won ? 'Vitória: revise os fatores que sustentaram a vantagem.' : 'Derrota: procure os fatores que mais custaram posses.', style: const TextStyle(color: Colors.white70))])),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ],
    );
  }
}


class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    ]),
  );
}
