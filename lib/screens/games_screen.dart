import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/coach_game_record.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import 'game_detail_screen.dart';
import 'live_scout_screen.dart';
import 'new_game_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final history = state.coachSeasonGames;
    final finals = history.where((g) => g.isFinal).length;
    final upcoming = history.where((g) => g.isUpcoming).length;
    final live = history.where((g) => g.isLive).length;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jogos',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.teamContext.displayName} • temporada ${state.teamContext.seasonYear} • ${state.teamContext.federativePathLabel}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewGameScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Novo scout'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Temporada da equipe',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.fpbSyncing || state.lbcSyncing
                          ? null
                          : state.syncAllLeagues,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Atualizar FPB e LBC',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SummaryChip(label: 'TOTAL', value: history.length),
                    _SummaryChip(label: 'FINALIZADOS', value: finals),
                    _SummaryChip(label: 'PRÓXIMOS', value: upcoming),
                    if (live > 0) _SummaryChip(label: 'AO VIVO', value: live),
                  ],
                ),
                if (state.fpbSyncing || state.lbcSyncing) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        if (state.activeGame != null) ...[
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.sensors_rounded),
              ),
              title: Text(
                'AO VIVO • vs ${state.activeGame!.opponent}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore} • ${state.activeGame!.period}Q',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LiveScoutScreen()),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'Histórico completo da temporada',
          subtitle:
              'Jogos identificados para a equipe nas fontes FPB, LBC e no scout do ARCO.',
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nenhum jogo oficial da equipe foi identificado ainda.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Os 3 jogos de demonstração não são mais tratados como o histórico da temporada. Atualize FPB/LBC para buscar partidas reais.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.syncAllLeagues,
                    icon: const Icon(Icons.sync),
                    label: const Text('Atualizar fontes'),
                  ),
                ],
              ),
            ),
          )
        else
          ...history.map(
            (game) => _OfficialGameCard(
              game: game,
              onTap: () => _openHistoryGame(context, state, game),
            ),
          ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Jogos analisados no ARCO',
          subtitle:
              'Scouts com estatísticas detalhadas. Itens marcados como DEMO servem apenas para demonstração.',
        ),
        const SizedBox(height: 10),
        ...state.games.map((g) {
          final efg = AnalyticsService.efg(
            fgm: g.fgm,
            threePm: g.threePm,
            fga: g.fga,
          );
          final tov = AnalyticsService.turnoverPct(
            turnovers: g.turnovers,
            possessions: g.possessions,
          );
          final isDemo = g.source == 'mock';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GameDetailScreen(game: g)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'vs ${g.opponent}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (isDemo)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(label: Text('DEMO')),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (g.won
                                    ? Colors.greenAccent
                                    : Colors.redAccent)
                                .withOpacity(.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            g.won ? 'VITÓRIA' : 'DERROTA',
                            style: TextStyle(
                              color: g.won
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${g.ourScore} × ${g.opponentScore}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('eFG ${efg.toStringAsFixed(1)}%'),
                        Text('TOV ${tov.toStringAsFixed(1)}%'),
                        Text('${g.possessions} posses'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openHistoryGame(
    BuildContext context,
    AppState state,
    CoachGameRecord record,
  ) async {
    final analyzed = state.analyzedGameById(record.arcoGameId);
    if (analyzed != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GameDetailScreen(game: analyzed)),
      );
      return;
    }

    if (record.sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(record.sourceUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label  $value',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class _OfficialGameCard extends StatelessWidget {
  final CoachGameRecord game;
  final VoidCallback onTap;

  const _OfficialGameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (game.category.isNotEmpty) game.category,
      game.status,
      if (game.scheduledAt != null) _date(game.scheduledAt!),
      if (game.hasArcoStats) 'SCOUT ARCO',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(
            game.league.length > 4 ? game.league.substring(0, 4) : game.league,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          '${game.homeTeam}  ${game.scoreLabel}  ${game.awayTeam}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(metadata.where((e) => e.isNotEmpty).join(' • ')),
        trailing: Icon(
          game.hasArcoStats ? Icons.analytics_rounded : Icons.open_in_new,
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
