import 'package:flutter/material.dart';
import '../models/league_game.dart';
import '../state/app_state.dart';
import '../state/league_feed.dart';
import '../widgets/league_widgets.dart';
import 'league_live_screen.dart';

class CompetitionHubScreen extends StatefulWidget {
  const CompetitionHubScreen({super.key});
  @override
  State<CompetitionHubScreen> createState() => _CompetitionHubScreenState();
}

class _CompetitionHubScreenState extends State<CompetitionHubScreen> {
  String league = 'TODOS';
  String category = 'TODAS';
  String query = '';
  bool onlyMine = false;
  bool onlyLive = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rows = <LeagueGame>[for (final f in state.feeds) ...f.games];
    final categories = <String>{'TODAS', ...rows.map((e) => e.competition).where((e) => e.isNotEmpty)}.toList()..sort();
    final q = query.trim().toLowerCase();
    final filtered = rows.where((g) {
      if (league != 'TODOS' && g.league != league) return false;
      if (category != 'TODAS' && g.competition != category) return false;
      if (onlyMine && !state.coach.isMyGame(g)) return false;
      if (onlyLive && !g.isLive) return false;
      if (q.isNotEmpty && !'${g.homeTeam} ${g.awayTeam} ${g.venue}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList()
      ..sort(LeagueFeed.compareGames);

    return RefreshIndicator(
      onRefresh: state.syncAllLeagues,
      child: ListView(padding: const EdgeInsets.all(18), physics: const AlwaysScrollableScrollPhysics(), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Competições', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('FPB + LBC em uma agenda única.', style: TextStyle(color: Colors.white60)),
            ]),
          ),
          IconButton(
            onPressed: state.feeds.any((f) => f.syncing) ? null : state.syncAllLeagues,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar tudo',
          ),
        ]),
        const SizedBox(height: 14),
        for (final feed in state.feeds)
          LeagueStatusCard(
            feed: feed,
            onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeagueLiveScreen(league: feed.league))),
          ),
        const SizedBox(height: 6),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar equipe ou ginásio...', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String>(
            value: league,
            items: const ['TODOS', 'FPB', 'LBC'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => league = v!),
          ),
          DropdownButton<String>(
            value: categories.contains(category) ? category : 'TODAS',
            items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => category = v!),
          ),
          FilterChip(label: Text('Minha equipe (${state.coach.team.isEmpty ? state.coach.club : state.coach.team})'), selected: onlyMine, onSelected: (v) => setState(() => onlyMine = v)),
          FilterChip(label: const Text('Ao vivo'), selected: onlyLive, onSelected: (v) => setState(() => onlyLive = v)),
        ]),
        const SizedBox(height: 10),
        if (state.feeds.any((f) => f.syncing)) const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(rows.isEmpty
                  ? 'Ainda não há jogos. Atualize as fontes ou use "Colar jogos" no menu ⋮ de cada liga.'
                  : 'Nenhum jogo encontrado neste filtro.'),
            ),
          ),
        ...filtered.map((g) => LeagueGameTile(game: g)),
      ]),
    );
  }
}
