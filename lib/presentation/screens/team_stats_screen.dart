import 'package:flutter/material.dart';

import 'package:arco_analytics/domain/analysis/reports.dart';
import 'package:arco_analytics/domain/analysis/sample_size.dart';
import 'package:arco_analytics/domain/analysis/season_analysis.dart';
import 'package:arco_analytics/domain/services/stats_aggregator.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/widgets/court_shot_chart.dart';
import 'package:arco_analytics/presentation/widgets/section_card.dart';
import 'package:arco_analytics/presentation/widgets/stats_widgets.dart';
import 'package:arco_analytics/presentation/screens/box_score_screen.dart';
import 'package:arco_analytics/presentation/screens/player_stats_screen.dart';
import 'package:arco_analytics/presentation/screens/report_screen.dart';

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
    if (t == null)
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Equipe sem estatísticas importadas.')),
      );
    final g = t.games;
    final l = t.totals;
    final roster = t.roster;
    final mine = state.coach.isMyTeam(t.name);
    final shots = shooter.isEmpty ? t.shots : t.shots.where((s) => s.playerKey == shooter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          IconButton(
            tooltip: mine ? 'Relatório da temporada' : 'Relatório pré-jogo do adversário',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ReportScreen(report: mine ? Reports.season(SeasonAnalysis(t)) : Reports.preGame(OpponentReport(t))))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('${t.leagues.join(' / ')} • ${plural(g, 'jogo', 'jogos')} • ${t.wins}V ${t.losses}D', style: const TextStyle(color: Colors.white60)),
          if (!mine) ...[
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(report: Reports.preGame(OpponentReport(t))))),
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Relatório pré-jogo deste adversário'),
            ),
          ],
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
                const DropdownMenuItem(
                  value: '',
                  child: Text('Equipe toda', overflow: TextOverflow.ellipsis),
                ),
                for (final p in roster)
                  DropdownMenuItem(
                    value: p.key,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerStatsScreen(teamKey: t.key, playerKey: p.key),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final season = SeasonAnalysis(t);
              final qs = season.quarterAverages();
              final lineups = season.lineups().where((l) => l.minutes >= 2).toList()..sort((a, b) => b.plusMinus.compareTo(a.plusMinus));
              return Column(
                children: [
                  if (qs.isNotEmpty)
                    SectionCard(
                      title: 'Por quarto (média por jogo)',
                      child: Column(
                        children: [
                          for (final q in qs)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(width: 90, child: Text(q.$1)),
                                  Expanded(child: Text('${f1(q.$2)} × ${f1(q.$3)}')),
                                  Text(
                                    '${q.$2 >= q.$3 ? '+' : ''}${f1(q.$2 - q.$3)}',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: q.$2 >= q.$3 ? Colors.greenAccent : Colors.redAccent),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (lineups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'Formações (quintetos)',
                      subtitle: 'Saldo de pontos, minutos juntos e eficiência por 100 posses',
                      child: Column(
                        children: [
                          for (final (i, l) in lineups.take(8).indexed)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                              title: Text(l.names.join(' – '), style: const TextStyle(fontSize: 13)),
                              subtitle: Text(
                                '${f1(l.minutes)} min • ataque ${f1(l.offRating)} • defesa ${f1(l.defRating)} • ${l.sample.label}',
                                style: TextStyle(color: l.sample == SampleLevel.low ? Colors.white38 : null),
                              ),
                              trailing: Text(
                                '${l.plusMinus >= 0 ? '+' : ''}${l.plusMinus}',
                                style: TextStyle(fontWeight: FontWeight.w900, color: l.plusMinus >= 0 ? Colors.greenAccent : Colors.redAccent),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Jogos',
            child: Column(
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
