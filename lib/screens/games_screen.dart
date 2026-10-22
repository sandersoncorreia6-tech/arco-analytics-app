import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import '../widgets/league_widgets.dart';
import 'game_detail_screen.dart';
import 'live_scout_screen.dart';
import 'league_live_screen.dart';
import 'new_game_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Jogos e scout')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Scout, histórico e leitura pós-jogo.', style: TextStyle(color: Colors.white60))),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGameScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Novo'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final feed in state.feeds)
            LeagueStatusCard(
              feed: feed,
              onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeagueLiveScreen(league: feed.league))),
            ),
          if (state.activeGame != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.sensors_rounded)),
                title: Text('AO VIVO • vs ${state.activeGame!.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore} • ${state.activeGame!.periodLabel}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveScoutScreen())),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...state.games.map((g) {
            final efg = AnalyticsService.efg(fgm: g.fgm, threePm: g.threePm, fga: g.fga);
            final tov = AnalyticsService.turnoverPct(turnovers: g.turnovers, possessions: g.possessions);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text('vs ${g.opponent}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                                color: (g.won ? Colors.greenAccent : Colors.redAccent).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                            child: Text(g.won ? 'VITÓRIA' : 'DERROTA',
                                style: TextStyle(color: g.won ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 11))),
                      ]),
                      const SizedBox(height: 10),
                      Text('${g.ourScore} × ${g.opponentScore}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [Text('eFG ${efg.toStringAsFixed(1)}%'), Text('TOV ${tov.toStringAsFixed(1)}%'), Text('${g.possessions} posses')]),
                    ],
                  ),
                ),
              ),
            );
          })
        ],
      ),
    );
  }
}
