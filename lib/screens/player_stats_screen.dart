import 'package:flutter/material.dart';

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
