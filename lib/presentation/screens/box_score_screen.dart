import 'package:flutter/material.dart';

import 'package:arco_analytics/domain/analysis/game_analysis.dart';
import 'package:arco_analytics/domain/analysis/reports.dart';
import 'package:arco_analytics/domain/models/box_score.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/widgets/court_shot_chart.dart';
import 'package:arco_analytics/presentation/widgets/league_widgets.dart';
import 'package:arco_analytics/presentation/widgets/stats_widgets.dart';
import 'package:arco_analytics/presentation/screens/report_screen.dart';

/// Estatística completa de uma partida: placar por período, box score das
/// duas equipes, mapa de arremessos e lance a lance.
class BoxScoreScreen extends StatelessWidget {
  final String matchId;
  const BoxScoreScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.boxScores[matchId];
    if (g == null) return const Scaffold(body: Center(child: Text('Partida não encontrada.')));
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${g.home.code.isNotEmpty ? g.home.code : g.home.name} × ${g.away.code.isNotEmpty ? g.away.code : g.away.name}'),
          actions: [
            IconButton(
              tooltip: 'Análise pós-jogo',
              icon: const Icon(Icons.psychology_alt_outlined),
              onPressed: () {
                final side = state.coach.isMyTeam(g.away.name) && !state.coach.isMyTeam(g.home.name) ? 2 : 1;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(report: Reports.postGame(GameAnalysis(g, side)))));
              },
            ),
            IconButton(tooltip: 'Abrir no site', onPressed: () => openExternal(context, g.sourceUrl), icon: const Icon(Icons.open_in_new)),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: g.home.name),
              Tab(text: g.away.name),
              const Tab(text: 'Arremessos'),
              const Tab(text: 'Lance a lance'),
            ],
          ),
        ),
        body: Column(
          children: [
            _Header(game: g),
            Expanded(
              child: TabBarView(
                children: [
                  _TeamTab(game: g, team: 1),
                  _TeamTab(game: g, team: 2),
                  _ShotsTab(game: g),
                  _PlaysTab(game: g),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final GameBoxScore game;
  const _Header({required this.game});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final periods = [g.home.periodScores.length, g.away.periodScores.length].reduce((a, b) => a > b ? a : b);
    String label(int i) => i < 4 ? '${i + 1}Q' : 'P${i - 3}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.home.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('${g.home.score} × ${g.away.score}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                Expanded(
                  child: Text(
                    g.away.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [g.league, g.isLive ? 'AO VIVO • ${g.period}º período ${g.clock}' : g.status, 'atualizado ${hhmm(g.fetchedAt)}'].join(' • '),
              style: TextStyle(color: g.isLive ? Colors.redAccent : Colors.white54, fontSize: 12),
            ),
            if (periods > 0) ...[
              const SizedBox(height: 8),
              Table(
                defaultColumnWidth: const FlexColumnWidth(),
                columnWidths: const {0: FlexColumnWidth(2.2)},
                children: [
                  TableRow(
                    children: [
                      const SizedBox(),
                      for (var i = 0; i < periods; i++)
                        Text(
                          label(i),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                  for (final t in [g.home, g.away])
                    TableRow(
                      children: [
                        Text(t.code.isNotEmpty ? t.code : t.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        for (var i = 0; i < periods; i++)
                          Text(i < t.periodScores.length ? '${t.periodScores[i]}' : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  final GameBoxScore game;
  final int team;
  const _TeamTab({required this.game, required this.team});

  @override
  Widget build(BuildContext context) {
    final t = game.team(team);
    final l = t.totals;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        StatTiles([
          ('PTS', '${t.score}'),
          ('REB', '${l.reb}'),
          ('AST', '${l.ast}'),
          ('FG', pct(l.fgPct)),
          ('3P', pct(l.tpPct)),
          ('LL', pct(l.ftPct)),
          ('ERR', '${l.tov}'),
          ('ROB', '${l.stl}'),
          ('eFG', pct(l.efgPct)),
          ('POSSES', l.possessions.toStringAsFixed(0)),
        ]),
        if (t.extras.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final e in {
                'paint': 'Pontos no garrafão',
                'fastBreak': 'Contra-ataque',
                'secondChance': '2ª chance',
                'fromTurnovers': 'Após erro do adversário',
                'bench': 'Banco',
              }.entries)
                if (t.extras[e.key] != null) Text('${e.value}: ${t.extras[e.key]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: PlayerStatsTable(
            rows: [for (final p in t.players.where((p) => p.played || p.starter)) StatRow(number: p.number, name: p.name, starter: p.starter, line: p.stats)],
            totals: l,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('* titular • FG/3P/LL = convertidos/tentados • EFI = eficiência', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ),
      ],
    );
  }
}

class _ShotsTab extends StatefulWidget {
  final GameBoxScore game;
  const _ShotsTab({required this.game});
  @override
  State<_ShotsTab> createState() => _ShotsTabState();
}

class _ShotsTabState extends State<_ShotsTab> {
  int team = 1;
  String player = '';
  int period = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final teamShots = g.shots.where((s) => s.team == team).toList();
    final players = <String, String>{for (final s in teamShots) s.playerKey: s.player};
    final shots = teamShots.where((s) => (player.isEmpty || s.playerKey == player) && (period == 0 || s.period == period)).toList();
    final maxPeriod = g.shots.fold<int>(4, (m, s) => s.period > m ? s.period : m);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 1, label: Text(g.home.code.isNotEmpty ? g.home.code : g.home.name, overflow: TextOverflow.ellipsis)),
            ButtonSegment(value: 2, label: Text(g.away.code.isNotEmpty ? g.away.code : g.away.name, overflow: TextOverflow.ellipsis)),
          ],
          selected: {team},
          onSelectionChanged: (v) => setState(() {
            team = v.first;
            player = '';
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            DropdownButton<String>(
              value: players.containsKey(player) ? player : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos os jogadores')),
                for (final e in players.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => player = v ?? ''),
            ),
            DropdownButton<int>(
              value: period,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Jogo todo')),
                for (var i = 1; i <= maxPeriod; i++) DropdownMenuItem(value: i, child: Text(i <= 4 ? '$iº período' : 'Prorrogação ${i - 4}')),
              ],
              onChanged: (v) => setState(() => period = v ?? 0),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (g.shots.isEmpty)
          const Card(
            child: Padding(padding: EdgeInsets.all(16), child: Text('Esta partida não tem posições de arremesso registradas na estatística online.')),
          )
        else
          CourtShotChart(shots: shots),
      ],
    );
  }
}

class _PlaysTab extends StatelessWidget {
  final GameBoxScore game;
  const _PlaysTab({required this.game});

  @override
  Widget build(BuildContext context) {
    final plays = game.plays.where((p) => p.type != 'substitution').toList();
    if (plays.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('Sem lance a lance para esta partida.')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: plays.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = plays[i];
        final team = p.team == 0 ? '' : (game.team(p.team).code.isNotEmpty ? game.team(p.team).code : game.team(p.team).name);
        final scoring = (p.type == '2pt' || p.type == '3pt' || p.type == 'freethrow') && p.success;
        return ListTile(
          dense: true,
          leading: SizedBox(
            width: 52,
            child: Text(
              '${p.period}º\n${p.clock}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
          title: Text(p.label, style: TextStyle(fontWeight: scoring ? FontWeight.w800 : FontWeight.w500)),
          subtitle: Text([team, p.player].where((e) => e.isNotEmpty).join(' • ')),
          trailing: p.score.isEmpty ? null : Text(p.score, style: const TextStyle(fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}
