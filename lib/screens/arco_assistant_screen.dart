import 'package:flutter/material.dart';
import '../data/mock_repository.dart';
import '../services/analytics_service.dart';
import '../services/arco_assistant_service.dart';
import '../state/app_state.dart';

class ArcoAssistantScreen extends StatefulWidget {
  const ArcoAssistantScreen({super.key});

  @override
  State<ArcoAssistantScreen> createState() => _ArcoAssistantScreenState();
}

class _ArcoAssistantScreenState extends State<ArcoAssistantScreen> {
  final controller = TextEditingController();
  ArcoAssistantAnswer? answer;

  static const presets = [
    'Qual nosso melhor quinteto?',
    'Como está nosso ataque?',
    'Como está nossa defesa?',
    'Estamos perdendo muitas posses?',
    'Como está nossa eficiência de arremesso?',
    'Qual jogador tem maior impacto?',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _ask(AppState state, String question) {
    controller.text = question;
    final latest = state.games.isNotEmpty ? state.games.first : null;
    final names = {for (final p in state.players) p.id: p.name};
    final liveLineups = latest == null
        ? const []
        : AnalyticsService.lineupsFromGame(latest, names);
    setState(() {
      answer = ArcoAssistantService.answer(
        question: question,
        games: state.games,
        players: state.players,
        lineups: liveLineups.isEmpty ? MockRepository.lineups : liveLineups,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ARCO Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Pergunte sobre os dados registrados no ARCO. Quando a amostra é baixa ou demo, o assistente avisa.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Pergunte ao ARCO',
              hintText: 'Ex.: Qual nosso melhor quinteto?',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded),
                onPressed: () {
                  final q = controller.text.trim();
                  if (q.isNotEmpty) _ask(state, q);
                },
              ),
            ),
            onSubmitted: (value) {
              final q = value.trim();
              if (q.isNotEmpty) _ask(state, q);
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((q) => ActionChip(
              label: Text(q),
              onPressed: () => _ask(state, q),
            )).toList(),
          ),
          if (answer != null) ...[
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          answer!.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        )),
                        Chip(label: Text('Confiança ${answer!.confidence}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(answer!.answer, style: const TextStyle(height: 1.45)),
                    if (answer!.evidence.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Evidências', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...answer!.evidence.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $item'),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
