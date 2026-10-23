import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/coach_game_record.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import 'game_detail_screen.dart';
import 'live_scout_screen.dart';
import 'new_game_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String league = 'TODOS';
  String category = 'TODAS';
  String season = 'TODAS';
  String status = 'TODOS';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final all = state.coachSeasonGames;
    final categories = <String>{'TODAS', ...all.map((g) => g.category).where((v) => v.isNotEmpty)}.toList()..sort();
    final seasons = <String>{'TODAS', ...all.map((g) => g.seasonId).where((v) => v.isNotEmpty)}.toList()..sort();

    if (!categories.contains(category)) category = 'TODAS';
    if (!seasons.contains(season)) season = 'TODAS';

    final history = all.where((g) {
      if (league != 'TODOS' && g.league != league) return false;
      if (category != 'TODAS' && g.category != category) return false;
      if (season != 'TODAS' && g.seasonId != season) return false;
      if (status == 'FINALIZADOS' && !g.isFinal) return false;
      if (status == 'PRÓXIMOS' && !g.isUpcoming) return false;
      if (status == 'AO VIVO' && !g.isLive) return false;
      return true;
    }).toList();

    final finals = all.where((g) => g.isFinal).length;
    final upcoming = all.where((g) => g.isUpcoming).length;
    final live = all.where((g) => g.isLive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jogos e temporada'),
        actions: [
          IconButton(
            onPressed: state.fpbSyncing || state.lbcSyncing ? null : state.syncAllLeagues,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar FPB e LBC',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${state.teamContext.displayName} • temporada ${state.teamContext.seasonYear} • ${state.teamContext.federativePathLabel}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(label: 'TOTAL', value: all.length),
              _SummaryChip(label: 'FINALIZADOS', value: finals),
              _SummaryChip(label: 'PRÓXIMOS', value: upcoming),
              if (live > 0) _SummaryChip(label: 'AO VIVO', value: live),
            ],
          ),
          if (state.fpbSyncing || state.lbcSyncing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _Filter(
                        label: 'Liga',
                        value: league,
                        values: const ['TODOS', 'FPB', 'LBC', 'ARCO'],
                        onChanged: (v) => setState(() => league = v),
                      ),
                      _Filter(
                        label: 'Categoria',
                        value: category,
                        values: categories,
                        onChanged: (v) => setState(() => category = v),
                      ),
                      _Filter(
                        label: 'Temporada',
                        value: season,
                        values: seasons,
                        onChanged: (v) => setState(() => season = v),
                      ),
                      _Filter(
                        label: 'Status',
                        value: status,
                        values: const ['TODOS', 'FINALIZADOS', 'PRÓXIMOS', 'AO VIVO'],
                        onChanged: (v) => setState(() => status = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (state.activeGame != null) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.sensors_rounded)),
                title: Text('AO VIVO • vs ${state.activeGame!.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore} • ${state.activeGame!.period}Q'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveScoutScreen())),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('Histórico da temporada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGameScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Scout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Nenhum jogo encontrado com estes filtros.'),
              ),
            )
          else
            ...history.map((game) => _OfficialGameCard(
              game: game,
              onTap: () => _openHistoryGame(context, state, game),
            )),
          const SizedBox(height: 22),
          const Text('Scouts analisados no ARCO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...state.games.map((g) {
            final efg = AnalyticsService.efg(fgm: g.fgm, threePm: g.threePm, fga: g.fga);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Text(g.source == 'mock' ? 'D' : 'A')),
                title: Text('vs ${g.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${g.ourScore} × ${g.opponentScore} • eFG ${efg.toStringAsFixed(1)}% • ${g.possessions} posses${g.source == 'mock' ? ' • DEMO' : ''}'),
                trailing: const Icon(Icons.analytics_outlined),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: g))),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openHistoryGame(BuildContext context, AppState state, CoachGameRecord record) async {
    final analyzed = state.analyzedGameById(record.arcoGameId);
    if (analyzed != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: analyzed)));
      return;
    }
    if (record.sourceUrl.isNotEmpty) {
      final uri = Uri.tryParse(record.sourceUrl);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Filter extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _Filter({required this.label, required this.value, required this.values, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: values.contains(value) ? value : values.first,
      hint: Text(label),
      items: values.map((v) => DropdownMenuItem(value: v, child: Text(v == 'TODAS' || v == 'TODOS' ? '$label: Todos' : v))).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  const _SummaryChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(12)),
    child: Text('$label  $value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
  );
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
        leading: CircleAvatar(child: Text(game.league.length > 4 ? game.league.substring(0, 4) : game.league, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
        title: Text('${game.homeTeam}  ${game.scoreLabel}  ${game.awayTeam}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(metadata.where((e) => e.isNotEmpty).join(' • ')),
        trailing: Icon(game.hasArcoStats ? Icons.analytics_rounded : Icons.open_in_new),
      ),
    );
  }

  static String _date(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
