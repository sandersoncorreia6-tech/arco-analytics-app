import 'package:flutter/material.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/screens/live_scout_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nova partida')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Crie a partida e inicie o scout em tempo real.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Adversário',
              hintText: 'Ex.: Franca Sub-20',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shield_outlined),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quinteto inicial sugerido', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...state.players
                      .take(5)
                      .map((p) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Text('#${p.number} ${p.name} • ${p.position}'))),
                  const SizedBox(height: 4),
                  const Text('Você poderá alterar quem está em quadra durante o jogo.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              final ok = state.startGame(controller.text);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o adversário e tenha pelo menos 5 jogadores cadastrados.')));
                return;
              }
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LiveScoutScreen()));
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('INICIAR SCOUT')),
          ),
        ],
      ),
    );
  }
}
