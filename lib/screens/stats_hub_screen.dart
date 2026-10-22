import 'package:flutter/material.dart';

import '../services/stats_aggregator.dart';
import '../state/app_state.dart';
import '../widgets/league_widgets.dart';
import '../widgets/stats_widgets.dart';
import 'box_score_screen.dart';
import 'player_stats_screen.dart';
import 'team_stats_screen.dart';

enum _PlayerSort { points, rebounds, assists, efficiency, threes, steals }

extension on _PlayerSort {
  String get label => switch (this) {
        _PlayerSort.points => 'Pontos',
        _PlayerSort.rebounds => 'Rebotes',
        _PlayerSort.assists => 'Assistências',
        _PlayerSort.efficiency => 'Eficiência',
        _PlayerSort.threes => 'Bolas de 3',
        _PlayerSort.steals => 'Roubos',
      };

  double value(PlayerSeason p) => switch (this) {
        _PlayerSort.points => p.ppg,
        _PlayerSort.rebounds => p.rpg,
        _PlayerSort.assists => p.apg,
        _PlayerSort.efficiency => p.effPerGame,
        _PlayerSort.threes => p.perGame(p.totals.tpm),
        _PlayerSort.steals => p.perGame(p.totals.stl),
      };
}

/// Estatísticas completas importadas da aba Estatística/Online das ligas:
/// todas as equipes, todos os jogadores e todas as partidas.
class StatsHubScreen extends StatefulWidget {
  const StatsHubScreen({super.key});
  @override
  State<StatsHubScreen> createState() => _StatsHubScreenState();
}

class _StatsHubScreenState extends State<StatsHubScreen> {
  int tab = 0;
  String query = '';
  bool onlyMine = false;
  _PlayerSort sort = _PlayerSort.points;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final teams = state.teamSeasons.values.toList();
    final games = state.boxScoreList;
    final q = query.trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async {
        await state.syncAllLeagues();
        await state.syncStats(retryErrors: true);
      },
      child: ListView(padding: const EdgeInsets.all(18), physics: const AlwaysScrollableScrollPhysics(), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Estatísticas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                [
                  plural(teams.length, 'equipe', 'equipes'),
                  plural(teams.fold<int>(0, (s, t) => s + t.players.length), 'jogador', 'jogadores'),
                  plural(games.length, 'jogo', 'jogos'),
                ].join(' • '),
                style: const TextStyle(color: Colors.white60),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Importar jogo pelo link',
            onPressed: () => showAddStatsLinkDialog(context),
            icon: const Icon(Icons.add_link),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: state.statsSyncing
                ? null
                : () async {
                    await state.syncAllLeagues();
                    await state.syncStats(retryErrors: true);
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        if (state.statsSyncing || state.feeds.any((f) => f.syncing)) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        const SizedBox(height: 12),
        if (state.myTeamSeasons.isNotEmpty) ...[
          Text('Minha equipe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final t in state.myTeamSeasons) _TeamTile(team: t, highlight: true),
          const SizedBox(height: 10),
        ],
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Equipes')),
            ButtonSegment(value: 1, label: Text('Jogadores')),
            ButtonSegment(value: 2, label: Text('Jogos')),
          ],
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tab == 1 ? 'Buscar jogador ou equipe...' : 'Buscar equipe...',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (games.isEmpty) _EmptyState(errors: state.statsErrors.length, known: state.knownMatches.length),
        if (tab == 0) ...[
          for (final t in (teams.where((t) => q.isEmpty || t.name.toLowerCase().contains(q)).toList()
            ..sort((a, b) => b.netRating.compareTo(a.netRating))))
            _TeamTile(team: t),
        ],
        if (tab == 1) ...[
          Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<_PlayerSort>(
              value: sort,
              items: [for (final s in _PlayerSort.values) DropdownMenuItem(value: s, child: Text('Líderes em ${s.label.toLowerCase()}'))],
              onChanged: (v) => setState(() => sort = v ?? sort),
            ),
            FilterChip(label: const Text('Só minha equipe'), selected: onlyMine, onSelected: (v) => setState(() => onlyMine = v)),
          ]),
          ...() {
            final players = [
              for (final t in teams)
                for (final p in t.players.values)
                  if ((!onlyMine || state.coach.isMyTeam(t.name)) &&
                      (q.isEmpty || p.name.toLowerCase().contains(q) || t.name.toLowerCase().contains(q)))
                    p,
            ]..sort((a, b) => sort.value(b).compareTo(sort.value(a)));
            return [
              for (var i = 0; i < players.length && i < 150; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(players[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${players[i].teamName} • ${players[i].games} J • ${f1(players[i].ppg)} PTS • ${f1(players[i].rpg)} REB • ${f1(players[i].apg)} AST',
                    ),
                    trailing: Text(f1(sort.value(players[i])), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlayerStatsScreen(teamKey: players[i].teamKey, playerKey: players[i].key),
                    )),
                  ),
                ),
            ];
          }(),
        ],
        if (tab == 2) ...[
          for (final g in games.where((g) => q.isEmpty || '${g.home.name} ${g.away.name}'.toLowerCase().contains(q)))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${g.home.name}  ${g.home.score} × ${g.away.score}  ${g.away.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${g.league} • ${g.isLive ? 'AO VIVO ${g.period}º ${g.clock}' : g.status} • ${g.shots.length} arremessos mapeados',
                    style: TextStyle(color: g.isLive ? Colors.redAccent : null)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoxScoreScreen(matchId: g.matchId))),
                onLongPress: () => _confirmRemove(context, state, g.matchId),
              ),
            ),
          if (state.statsErrors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: Text('${state.statsErrors.length} partidas não puderam ser baixadas'),
              children: [
                for (final e in state.statsErrors.entries)
                  ListTile(dense: true, title: Text('Partida ${e.key}'), subtitle: Text(e.value)),
              ],
            ),
          ],
        ],
      ]),
    );
  }

  Future<void> _confirmRemove(BuildContext context, AppState state, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remover partida?'),
        content: const Text('As estatísticas deste jogo deixam de entrar nas médias.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('REMOVER')),
        ],
      ),
    );
    if (ok == true) await state.removeBoxScore(id);
  }
}

class _TeamTile extends StatelessWidget {
  final TeamSeason team;
  final bool highlight;
  const _TeamTile({required this.team, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final t = team;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: .6)),
            )
          : null,
      child: ListTile(
        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${t.games} J • ${t.wins}V ${t.losses}D • ${f1(t.ppg)} pts • sofre ${f1(t.oppPpg)} • ${plural(t.players.length, 'jogador', 'jogadores')}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${t.netRating >= 0 ? '+' : ''}${f1(t.netRating)}',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: t.netRating >= 0 ? Colors.greenAccent : Colors.redAccent)),
          const Text('SALDO/100', style: TextStyle(fontSize: 9, color: Colors.white54)),
        ]),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamStatsScreen(teamKey: t.key))),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int errors;
  final int known;
  const _EmptyState({required this.errors, required this.known});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Nenhuma estatística importada ainda', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            known == 0
                ? 'O ARCO procura automaticamente os jogos com estatística online nas páginas da FPB/LBC. '
                    'Se nenhum aparecer, importe pelo link: abra o jogo na aba Estatística/Online do site, copie o endereço e toque em "Importar jogo".'
                : '$known partidas encontradas; ${errors > 0 ? '$errors com erro ao baixar.' : 'baixando...'}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: () => showAddStatsLinkDialog(context), icon: const Icon(Icons.add_link), label: const Text('Importar jogo')),
            OutlinedButton.icon(
              onPressed: () => showDiagnosticsSheet(context, state.fpb),
              icon: const Icon(Icons.network_check),
              label: const Text('Diagnóstico FPB'),
            ),
          ]),
        ]),
      ),
    );
  }
}
