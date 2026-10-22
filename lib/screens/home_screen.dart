import 'package:flutter/material.dart';
import '../data/mock_repository.dart';
import '../services/analytics_service.dart';
import '../services/insight_engine.dart';
import '../state/app_state.dart';
import '../widgets/insight_tile.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import '../data/repositories/game_repository.dart';
import 'analyst_screen.dart';
import 'match_detail_screen.dart';
import 'games_screen.dart';
import 'live_scout_screen.dart';
import 'new_game_screen.dart';
import 'team_stats_screen.dart';
import '../widgets/stats_widgets.dart';

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
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá, ${state.coach.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Text('${state.coach.role} • ${state.coach.teamLabel}', style: const TextStyle(color: Colors.white60, fontSize: 12))
            ])),
            const CircleAvatar(child: Icon(Icons.person_outline)),
          ],
        ),
        if (state.activeGame != null) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sensors, color: Colors.redAccent),
              title: Text('Partida em andamento • ${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore}'),
              subtitle: Text('vs ${state.activeGame!.opponent} • ${state.activeGame!.periodLabel}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveScoutScreen())),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Central de decisão', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Insights do ${state.coach.team.isEmpty ? state.coach.club : state.coach.team}: o que o treinador precisa saber hoje.', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        Card(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalystScreen())),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.psychology_alt_outlined),
                  SizedBox(width: 8),
                  Expanded(child: Text('Analista ARCO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  Icon(Icons.chevron_right),
                ]),
                const SizedBox(height: 4),
                const Text('Pergunte sobre a sua equipe: onde erra, por que perdeu, o que treinar.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final q in const ['De onde minha equipe mais erra?', 'E se tivéssemos acertado os lances livres?', 'O que treinar esta semana?'])
                    ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalystScreen(initialQuestion: q))),
                    ),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            MetricCard(label: 'Off Rating', value: off.toStringAsFixed(1), helper: 'pts / 100 posses', icon: Icons.bolt_rounded),
            MetricCard(label: 'Def Rating', value: def.toStringAsFixed(1), helper: 'menor é melhor', icon: Icons.shield_outlined),
            MetricCard(
                label: 'Net Rating', value: '${net >= 0 ? '+' : ''}${net.toStringAsFixed(1)}', helper: 'saldo / 100 posses', icon: Icons.balance_rounded),
            MetricCard(label: 'Pace', value: '${game.possessions}', helper: 'posses no último jogo', icon: Icons.speed_rounded),
          ],
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGameScreen())),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Novo scout'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Jogos'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Estatísticas da minha equipe',
          child: state.myTeamSeasons.isEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    state.statsSyncing
                        ? 'Importando estatísticas da FPB/LBC...'
                        : 'Ainda não há estatísticas do ${state.coach.team.isEmpty ? state.coach.club : state.coach.team} importadas. Importe um jogo pelo link da aba Estatística/Online do site.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => showAddStatsLinkDialog(context), icon: const Icon(Icons.add_link), label: const Text('Importar jogo')),
                ])
              : Column(children: [
                  for (final t in state.myTeamSeasons)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${t.games} J • ${t.wins}V ${t.losses}D • ${f1(t.ppg)} pts • ${f1(t.perGame(t.totals.reb))} reb • ${plural(t.players.length, 'jogador', 'jogadores')}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TeamStatsScreen(teamKey: t.key))),
                    ),
                ]),
        ),
        const SizedBox(height: 14),
        Builder(builder: (context) {
          // Painel da equipe a partir do histórico completo (FPB + LBC + scout).
          final mine = state.coachGames;
          final now = DateTime.now();
          final next = GameRepository.query(mine, GameView.upcoming, const GameFilter(), now: now).firstOrNull;
          final last = GameRepository.query(mine, GameView.recent, const GameFilter(), now: now).firstOrNull;
          final rec = GameRepository.record(mine);
          void open(String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(gameId: id)));
          Widget tile(String label, CoachGame g) => ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => open(g.game.id),
                leading: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                title: Text('${g.isHome ? 'vs' : '@'} ${g.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text([if (g.game.hasScore) '${g.ourScore} × ${g.theirScore}', g.game.dateLabel, g.game.venue].where((e) => e.isNotEmpty).join(' • ')),
                trailing: const Icon(Icons.chevron_right),
              );
          return SectionCard(
            title: 'Minha equipe • ${state.coach.teamLabel}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: _MiniStat(label: 'Campanha', value: '${rec.wins}V ${rec.losses}D')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Aproveitamento', value: '${rec.pct.toStringAsFixed(0)}%')),
                const SizedBox(width: 10),
                Expanded(child: _MiniStat(label: 'Jogos', value: '${mine.length}', warning: state.feeds.any((f) => f.error != null))),
              ]),
              if (next != null) tile('Próximo', next),
              if (last != null) tile('Último', last),
              if (mine.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('Temporada ${state.coach.season.isEmpty ? now.year : state.coach.season} completa',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${mine.length} jogos em ordem de calendário', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  children: [
                    for (final g in GameRepository.query(mine, GameView.season, const GameFilter(), now: now))
                      tile(g.result.isEmpty ? (g.game.isLive ? 'Ao vivo' : 'Agenda') : g.result, g),
                  ],
                ),
              if (mine.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhum jogo da equipe ainda. O ARCO busca a FPB/LBC automaticamente.', style: TextStyle(color: Colors.white60)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesScreen())),
                  icon: const Icon(Icons.event_note),
                  label: Text('Todos os jogos da temporada (${mine.length})'),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Insights prioritários',
          child: Column(children: insights.take(3).map((e) => InsightTile(insight: e)).toList()),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;
  const _MiniStat({required this.label, required this.value, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .04), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12))),
            if (warning) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.cloud_off_outlined, size: 13, color: Colors.orangeAccent)),
          ]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ]),
      );
}
