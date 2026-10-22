import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'reports_screen.dart';
import 'scout_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Mais', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(state.coach.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${state.coach.role} • ${state.coach.club}\n${state.coach.city}'),
          isThreeLine: true,
        )),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Scout do adversário'), subtitle: const Text('Perfil, vulnerabilidades e plano de jogo'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScoutScreen()))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Relatórios'), subtitle: const Text('Resumo pós-jogo e comissão técnica'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen()))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), subtitle: const Text('Encerrar sessão local'), onTap: state.logout),
        ])),
      ],
    );
  }
}
