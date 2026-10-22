import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import 'player_detail_screen.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Equipe', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Valor real, eficiência e impacto.', style: TextStyle(color: Colors.white60)),
            ])),
            IconButton.filledTonal(onPressed: () => _addPlayer(context, state), icon: const Icon(Icons.person_add_alt_1)),
          ],
        ),
        const SizedBox(height: 18),
        ...state.players.map((p) {
          final score = AnalyticsService.impactScore(p);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(child: Text('${p.number}')),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p.position} • ${p.points} PTS • ${p.assists} AST • ${p.rebounds} REB'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(score.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), const Text('IMPACT', style: TextStyle(fontSize: 9, color: Colors.white54))]),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: p))),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addPlayer(BuildContext context, AppState state) async {
    final name = TextEditingController();
    final number = TextEditingController();
    String position = 'PG';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Adicionar jogador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 10),
              TextField(controller: number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: position,
                decoration: const InputDecoration(labelText: 'Posição'),
                items: const ['PG', 'SG', 'SF', 'PF', 'C'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setLocalState(() => position = value ?? position),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final parsed = int.tryParse(number.text.trim());
      if (name.text.trim().isNotEmpty && parsed != null) {
        state.addPlayer(name: name.text.trim(), position: position, number: parsed);
      }
    }
    name.dispose();
    number.dispose();
  }
}
