import 'package:flutter/material.dart';
import '../models/play_event.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import 'game_detail_screen.dart';

class LiveScoutScreen extends StatelessWidget {
  const LiveScoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final game = state.activeGame;
    if (game == null) {
      return const Scaffold(body: Center(child: Text('Nenhuma partida ativa.')));
    }

    final selected = state.players.where((p) => p.id == game.selectedPlayerId).toList();
    final selectedName = selected.isEmpty ? 'Selecione um jogador' : selected.first.name;
    final efg = AnalyticsService.efg(fgm: game.fgm, threePm: game.threePm, fga: game.fga);
    final tov = AnalyticsService.turnoverPct(turnovers: game.turnovers, possessions: game.estimatedPossessions.round());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scout ao vivo'),
        actions: [
          IconButton(onPressed: game.events.isEmpty ? null : state.undoLastEvent, icon: const Icon(Icons.undo_rounded), tooltip: 'Desfazer último evento'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('ARCO  ${game.ourScore}  ×  ${game.opponentScore}  ${game.opponent}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1Q')),
                      ButtonSegment(value: 2, label: Text('2Q')),
                      ButtonSegment(value: 3, label: Text('3Q')),
                      ButtonSegment(value: 4, label: Text('4Q')),
                      ButtonSegment(value: 5, label: Text('PR')),
                    ],
                    selected: {game.period},
                    onSelectionChanged: (value) => state.setPeriod(value.first),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      Text('eFG ${efg.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70)),
                      Text('TOV ${tov.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70)),
                      Text('Posses ~${game.estimatedPossessions.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Jogador da ação',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.players.where((p) => game.lineupIds.contains(p.id)).map((p) => ChoiceChip(
                    label: Text('#${p.number} ${p.name.split(' ').first}'),
                    selected: p.id == game.selectedPlayerId,
                    onSelected: (_) => state.selectPlayer(p.id),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Contexto da próxima ação (opcional)',
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in PlayEvent.tags)
                ChoiceChip(label: Text(t), selected: state.pendingTag == t, onSelected: (_) => state.setPendingTag(t)),
            ]),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Arremesso',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: [
                _eventButton(context, state, '2PT ✓', Icons.add_circle_outline, PlayEventType.twoMade),
                _eventButton(context, state, '2PT ✕', Icons.cancel_outlined, PlayEventType.twoMiss),
                _eventButton(context, state, '3PT ✓', Icons.add_circle_outline, PlayEventType.threeMade),
                _eventButton(context, state, '3PT ✕', Icons.cancel_outlined, PlayEventType.threeMiss),
                _eventButton(context, state, 'LL ✓', Icons.check, PlayEventType.freeThrowMade),
                _eventButton(context, state, 'LL ✕', Icons.close, PlayEventType.freeThrowMiss),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Outras ações',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _small(state, 'AST', PlayEventType.assist),
                _small(state, 'REB O', PlayEventType.offensiveRebound),
                _small(state, 'REB D', PlayEventType.defensiveRebound),
                _small(state, 'STL', PlayEventType.steal),
                _small(state, 'BLK', PlayEventType.block),
                _small(state, 'TOV', PlayEventType.turnover),
                _small(state, 'FALTA', PlayEventType.foul),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Pontos do adversário',
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => state.addEvent(PlayEventType.opponentOne), child: const Text('+1'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => state.addEvent(PlayEventType.opponentTwo), child: const Text('+2'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => state.addEvent(PlayEventType.opponentThree), child: const Text('+3'))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'Quem está em quadra',
            child: Column(
              children: state.players.map((p) {
                final on = game.lineupIds.contains(p.id);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  title: Text('#${p.number} ${p.name}'),
                  subtitle: Text(p.position),
                  onChanged: (value) {
                    if (value == null) return;
                    state.changeLineup(p.id, value);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final shouldFinish = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Encerrar partida?'),
                  content: const Text('O jogo será salvo no histórico e os indicadores pós-jogo serão calculados.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Encerrar')),
                  ],
                ),
              );
              if (shouldFinish != true || !context.mounted) return;
              final finished = state.finishGame();
              if (finished == null || !context.mounted) return;
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameDetailScreen(game: finished)));
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('ENCERRAR PARTIDA')),
          ),
        ],
      ),
    );
  }

  Widget _eventButton(BuildContext context, AppState state, String label, IconData icon, PlayEventType type) {
    return FilledButton.tonalIcon(onPressed: () => state.addEvent(type), icon: Icon(icon), label: Text(label));
  }

  Widget _small(AppState state, String label, PlayEventType type) {
    return ActionChip(label: Text(label), onPressed: () => state.addEvent(type));
  }
}
