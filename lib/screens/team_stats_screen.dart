import 'package:flutter/material.dart';

import '../services/stats_aggregator.dart';
import '../state/app_state.dart';
import '../widgets/court_shot_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/stats_widgets.dart';
import 'box_score_screen.dart';
import 'player_stats_screen.dart';

/// Temporada de uma equipe: médias, four factors, elenco, mapa de arremessos e jogos.
class TeamStatsScreen extends StatefulWidget {
  final String teamKey;
  const TeamStatsScreen({super.key, required this.teamKey});

  @override
  State<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends State<TeamStatsScreen> {
  String shooter = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final TeamSeason? t = state.teamSeasons[widget.teamKey];
    if (t == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Equipe sem estatísticas importadas.')));
    final g = t.games;
    final l = t.totals;
    final roster = t.roster;
    final mine = state.coach.isMyTeam(t.name);
    final shots = shooter.isEmpty ? t.shots : t.shots.where((s) => s.playerKey == shooter).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.name)),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text('${t.leagues.join(' / ')} • ${plural(g, 'jogo', 'jogos')} • ${t.wins}V ${t.losses}D',
            style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Médias por jogo',
          child: StatTiles([
            ('PTS', f1(t.ppg)),
            ('SOFRE', f1(t.oppPpg)),
            ('REB', f1(t.perGame(l.reb))),
            ('AST', f1(t.perGame(l.ast))),
            ('ROB', f1(t.perGame(l.stl))),
            ('TOC', f1(t.perGame(l.blk))),
            ('ERR', f1(t.perGame(l.tov))),
            ('FG', pct(l.fgPct)),
            ('3P', pct(l.tpPct)),
            ('LL', pct(l.ftPct)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Eficiência (por 100 posses)',
          child: StatTiles([
            ('ATAQUE', f1(t.offRating)),
            ('DEFESA', f1(t.defRating)),
            ('SALDO', '${t.netRating >= 0 ? '+' : ''}${f1(t.netRating)}'),
            ('RITMO', f1(t.pace)),
            ('eFG', pct(l.efgPct)),
            ('TS', pct(l.tsPct)),
            ('TOV%', pct(t.tovPct)),
            ('REB OF%', pct(t.orbPct)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Mapa de arremessos',
          trailing: DropdownButton<String>(
            value: roster.any((p) => p.key == shooter) ? shooter : '',
            underline: const SizedBox(),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('Equipe toda', overflow: TextOverflow.ellipsis)),
              for (final p in roster) DropdownMenuItem(value: p.key, child: Text(p.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => shooter = v ?? ''),
          ),
          child: t.shots.isEmpty
              ? const Text('Sem posições de arremesso nas partidas importadas.', style: TextStyle(color: Colors.white60))
              : CourtShotChart(shots: shots),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Elenco • médias por jogo',
          trailing: mine
              ? TextButton.icon(
                  onPressed: () async {
                    final n = await state.importRosterFrom(t);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n jogadores copiados para a aba Equipe.')));
                    }
                  },
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Usar na aba Equipe'),
                )
              : null,
          child: PlayerStatsTable(
            averages: true,
            rows: [
              for (final p in roster)
                StatRow(
                  number: p.number,
                  name: p.name,
                  line: p.totals,
                  games: p.games,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlayerStatsScreen(teamKey: t.key, playerKey: p.key),
                  )),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Jogos',
          child: Column(children: [
            for (final game in t.gameList)
              () {
                final side = StatsAggregator.teamKey(game.home.name) == t.key ? 1 : 2;
                final us = game.team(side), them = game.team(side == 1 ? 2 : 1);
                final won = us.score > them.score;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: (game.isFinal ? (won ? Colors.green : Colors.red) : Colors.orange).withValues(alpha: .2),
                    child: Text(game.isFinal ? (won ? 'V' : 'D') : '•', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text('${side == 1 ? 'vs' : '@'} ${them.name}'),
                  subtitle: Text('${us.score} × ${them.score} • ${game.isLive ? 'AO VIVO' : game.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoxScoreScreen(matchId: game.matchId))),
                );
              }(),
          ]),
        ),
      ]),
    );
  }
}
