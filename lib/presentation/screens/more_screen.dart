import 'package:flutter/material.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/config/app_config.dart';
import 'package:arco_analytics/domain/models/league_game.dart';
import 'package:arco_analytics/presentation/widgets/league_widgets.dart';
import 'package:arco_analytics/presentation/screens/analyst_screen.dart';
import 'package:arco_analytics/presentation/screens/analytics_screen.dart';
import 'package:arco_analytics/presentation/screens/my_team_screen.dart';
import 'package:arco_analytics/presentation/screens/games_screen.dart';
import 'package:arco_analytics/presentation/screens/insights_screen.dart';
import 'package:arco_analytics/presentation/screens/reports_screen.dart';
import 'package:arco_analytics/presentation/screens/scout_screen.dart';

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
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(state.coach.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${state.coach.role} • ${state.coach.teamLabel}\n${state.coach.club} • ${state.coach.city}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(state.cloud.ready ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                title: const Text('Nuvem e backup'),
                subtitle: Text(
                  !state.cloud.enabled
                      ? 'Modo local: dados só neste aparelho (configure o Supabase para sincronizar)'
                      : state.cloud.ready
                      ? '${state.cloud.club!.clubName} • ${state.cloud.outbox.isEmpty ? 'tudo sincronizado' : '${state.cloud.outbox.length} pendente(s) — envio automático'}'
                            '${state.cloud.lastError == null ? '' : '\n${state.cloud.lastError}'}'
                      : 'Entre na sua conta para sincronizar',
                ),
                isThreeLine: state.cloud.lastError != null,
                trailing: state.cloud.ready ? const Icon(Icons.sync) : null,
                onTap: !state.cloud.ready
                    ? null
                    : () async {
                        final sent = await state.syncCloudNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.cloud.lastError ?? 'Sincronizado ($sent envio(s)).')));
                        }
                      },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Minha equipe'),
                subtitle: Text('${state.coach.teamLabel} • ${state.coach.category} • temporada ${state.coach.season.isEmpty ? 'todas' : state.coach.season}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyTeamScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('Analytics'),
                subtitle: const Text('Mapa de arremessos, formações e four factors'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Analytics')),
                      body: const AnalyticsScreen(),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.sports_basketball_outlined),
                title: const Text('Jogos e scout ao vivo'),
                subtitle: const Text('Nova partida, histórico e pós-jogo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.psychology_alt_outlined),
                title: const Text('Analista ARCO'),
                subtitle: const Text('Perguntas, simulações e plano de treino'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalystScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Insights'),
                subtitle: const Text('Leituras automáticas para decisão'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Insights')),
                      body: const InsightsScreen(),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Scout do adversário'),
                subtitle: const Text('Perfil, vulnerabilidades e plano de jogo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScoutScreen())),
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
              for (final feed in state.feeds) ...[
                ListTile(
                  leading: const Icon(Icons.network_check),
                  title: Text('Diagnóstico de conexão ${feed.league}'),
                  subtitle: Text(
                    feed.error ?? feed.warning ?? 'OK • ${gamesCount(feed.games.length)} • ${lastSyncLabel(feed)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => showDiagnosticsSheet(context, feed),
                ),
                const Divider(height: 1),
              ],
              ListTile(leading: const Icon(Icons.logout), title: const Text('Sair'), subtitle: const Text('Encerrar sessão local'), onTap: state.logout),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('${AppConfig.appName} v${AppConfig.versionName} (${AppConfig.versionCode})', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ],
    );
  }
}
