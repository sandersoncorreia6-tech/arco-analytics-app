import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'access_control_screen.dart';
import 'arco_assistant_screen.dart';
import 'games_screen.dart';
import 'opponents_screen.dart';
import 'reports_screen.dart';

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
          subtitle: Text('${state.coach.role} • ${state.coach.club}\n${state.coach.city}\n${state.teamContext.federativePathLabel}'),
          isThreeLine: true,
        )),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Jogos e temporada'),
            subtitle: const Text('Histórico completo, scouts e calendário da equipe'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Adversários e Game Plan'),
            subtitle: const Text('Perfil calculado, amostra e plano de jogo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpponentsScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.auto_awesome_rounded),
            title: const Text('ARCO Assistant'),
            subtitle: const Text('Pergunte usando os dados reais registrados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArcoAssistantScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Relatórios'),
            subtitle: const Text('Resumo pós-jogo e comissão técnica'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Acesso e permissões'),
            subtitle: const Text('Admin, treinador, analista e atleta'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccessControlScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            subtitle: const Text('Encerrar sessão'),
            onTap: state.logout,
          ),
        ])),
      ],
    );
  }
}
