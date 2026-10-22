import 'package:flutter/material.dart';

import '../analysis/season_analysis.dart';
import '../state/app_state.dart';
import '../widgets/court_shot_chart.dart';
import '../widgets/section_card.dart';
import '../widgets/stats_widgets.dart';
import 'box_score_screen.dart';

/// Temporada de um jogador: médias, aproveitamento, mapa de arremessos e jogo a jogo.
class PlayerStatsScreen extends StatelessWidget {
  final String teamKey;
  final String playerKey;
  const PlayerStatsScreen({super.key, required this.teamKey, required this.playerKey});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.teamSeasons[teamKey]?.players[playerKey];
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Jogador sem estatísticas importadas.')));
    final l = p.totals;
    final team = state.teamSeasons[teamKey];
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Text(
          [if (p.number.isNotEmpty) '#${p.number}', if (p.position.isNotEmpty) p.position, p.teamName, '${p.games} jogos', '${p.starts} como titular']
              .join(' • '),
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Médias por jogo',
          child: StatTiles([
            ('PTS', f1(p.ppg)),
            ('REB', f1(p.rpg)),
            ('AST', f1(p.apg)),
            ('MIN', f1(p.mpg)),
            ('ROB', f1(p.perGame(l.stl))),
            ('TOC', f1(p.perGame(l.blk))),
            ('ERR', f1(p.perGame(l.tov))),
            ('EFI', f1(p.effPerGame)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Aproveitamento (temporada)',
          child: StatTiles([
            ('FG', '${l.fgm}/${l.fga}'),
            ('FG%', pct(l.fgPct)),
            ('2P%', pct(l.twoPct)),
            ('3P', '${l.tpm}/${l.tpa}'),
            ('3P%', pct(l.tpPct)),
            ('LL%', pct(l.ftPct)),
            ('eFG', pct(l.efgPct)),
            ('TS', pct(l.tsPct)),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Avançadas',
          child: StatTiles([
            ('AST/ERR', l.tov == 0 ? '${l.ast}' : (l.ast / l.tov).toStringAsFixed(1)),
            if (team != null && usageRate(p, team) != null) ('USG%', pct(usageRate(p, team)!)),
            ('PTS/ARR', l.fga + 0.44 * l.fta == 0 ? '-' : (l.points / (l.fga + 0.44 * l.fta)).toStringAsFixed(2)),
            ('+/-', '${l.plusMinus >= 0 ? '+' : ''}${l.plusMinus}'),
            ('REB OF', f1(p.perGame(l.oreb))),
            ('FLT', f1(p.perGame(l.pf))),
          ]),
        ),
        if (p.log.length >= 2) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Evolução (pontos por jogo)',
            subtitle: 'Últimos ${p.log.length > 10 ? 10 : p.log.length} jogos • média da temporada ${f1(p.ppg)}',
            child: _EvolutionBars(values: [for (final e in (p.log.length > 10 ? p.log.sublist(p.log.length - 10) : p.log)) e.box.stats.points]),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Mapa de arremessos',
          child: p.shots.isEmpty
              ? const Text('Sem posições de arremesso registradas.', style: TextStyle(color: Colors.white60))
              : CourtShotChart(shots: p.shots),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Jogo a jogo',
          child: Column(children: [
            for (final e in p.log)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('vs ${e.opponent}'),
                subtitle: Text(
                  '${e.box.stats.points} PTS • ${e.box.stats.reb} REB • ${e.box.stats.ast} AST • '
                  '${e.box.stats.fgm}/${e.box.stats.fga} FG • ${mins(e.box.stats.seconds)} min',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoxScoreScreen(matchId: e.game.matchId))),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _EvolutionBars extends StatelessWidget {
  final List<int> values;
  const _EvolutionBars({required this.values});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(1, (m, v) => v > m ? v : m);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 120,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final v in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$v', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 2),
                Container(height: 90 * v / max + 2, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              ]),
            ),
          ),
      ]),
    );
  }
}
