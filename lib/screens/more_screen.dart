import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../config/app_config.dart';
import '../models/league_game.dart';
import '../widgets/league_widgets.dart';
import 'games_screen.dart';
import 'insights_screen.dart';
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
          ListTile(leading: const Icon(Icons.sports_basketball_outlined), title: const Text('Jogos e scout ao vivo'), subtitle: const Text('Nova partida, histórico e pós-jogo'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesScreen()))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.lightbulb_outline), title: const Text('Insights'), subtitle: const Text('Leituras automáticas para decisão'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Insights')), body: const InsightsScreen())))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Scout do adversário'), subtitle: const Text('Perfil, vulnerabilidades e plano de jogo'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScoutScreen()))),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Relatórios'), subtitle: const Text('Resumo pós-jogo e comissão técnica'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsScreen()))),
          const Divider(height: 1),
          for (final feed in state.feeds) ...[
            ListTile(leading: const Icon(Icons.network_check), title: Text('Diagnóstico de conexão ${feed.league}'), subtitle: Text(feed.error ?? feed.warning ?? 'OK • ${gamesCount(feed.games.length)} • ${lastSyncLabel(feed)}', maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => showDiagnosticsSheet(context, feed)),
            const Divider(height: 1),
          ],
          ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), subtitle: const Text('Encerrar sessão local'), onTap: state.logout),
        ])),
        const SizedBox(height: 18),
        const Center(child: Text('${AppConfig.appName} v${AppConfig.versionName} (${AppConfig.versionCode})', style: TextStyle(color: Colors.white38, fontSize: 12))),
      ],
    );
  }
}
