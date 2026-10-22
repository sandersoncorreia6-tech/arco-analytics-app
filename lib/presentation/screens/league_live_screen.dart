import 'package:flutter/material.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/state/league_feed.dart';
import 'package:arco_analytics/presentation/widgets/league_widgets.dart';

/// Jogos de uma liga (FPB ou LBC), com status de sincronização e ferramentas.
class LeagueLiveScreen extends StatelessWidget {
  final String league;
  const LeagueLiveScreen({super.key, required this.league});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final LeagueFeed feed = state.feeds.firstWhere((f) => f.league == league);
    return Scaffold(
      appBar: AppBar(title: Text('${feed.league} • jogos')),
      body: RefreshIndicator(
        onRefresh: () => state.syncLeague(feed),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            LeagueStatusCard(feed: feed),
            const SizedBox(height: 6),
            if (feed.games.isEmpty) ...[
              const SizedBox(height: 30),
              const Icon(Icons.event_busy_outlined, size: 52, color: Colors.white30),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  feed.syncing ? 'Buscando jogos da ${feed.league}...' : 'Nenhum jogo da ${feed.league} disponível ainda.',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () => showPasteGamesDialog(context, feed),
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Colar jogos manualmente'),
                ),
              ),
            ] else
              ...feed.games.map((g) => LeagueGameTile(game: g, showLeague: false)),
          ],
        ),
      ),
    );
  }
}
