import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game.dart';
import '../models/play_event.dart';
import '../services/analytics_service.dart';
import '../services/shot_chart_service.dart';
import '../state/app_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import '../widgets/shot_chart.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final names = {for (final p in state.players) p.id: p.name};
    final lineups = AnalyticsService.lineupsFromGame(game, names);
    final shots = ShotChartService.fromGame(game);
    final videoUrl = state.videoLinks[game.id] ?? '';
    final off = AnalyticsService.offensiveRating(points: game.ourScore, possessions: game.possessions);
    final def = AnalyticsService.defensiveRating(opponentPoints: game.opponentScore, possessions: game.possessions);
    final efg = AnalyticsService.efg(fgm: game.fgm, threePm: game.threePm, fga: game.fga);
    final tov = AnalyticsService.turnoverPct(turnovers: game.turnovers, possessions: game.possessions);
    final orb = AnalyticsService.offensiveReboundPct(offensiveRebounds: game.offensiveRebounds, available: game.availableOffensiveRebounds);
    final ftRate = game.fga == 0 ? 0.0 : (game.fta / game.fga) * 100;

    final reasons = <String>[];
    if (tov <= 14) reasons.add('✅ Controle de bola: TOV% em ${tov.toStringAsFixed(1)}%.');
    if (efg >= 52) reasons.add('✅ Boa qualidade de arremesso: eFG% de ${efg.toStringAsFixed(1)}%.');
    if (orb >= 30) reasons.add('✅ Pressão no rebote ofensivo: ${orb.toStringAsFixed(1)}%.');
    if (tov > 18) reasons.add('⚠ Turnovers altos: ${tov.toStringAsFixed(1)}% das posses estimadas.');
    if (efg < 48) reasons.add('⚠ Eficiência de arremesso baixa: eFG% de ${efg.toStringAsFixed(1)}%.');
    if (reasons.isEmpty) reasons.add('ℹ Jogo equilibrado nos indicadores básicos; amplie a amostra para ganhar confiança.');

    return Scaffold(
      appBar: AppBar(title: Text('vs ${game.opponent}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Center(
            child: Column(
              children: [
                Text('${game.ourScore} × ${game.opponentScore}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                Text(game.won ? 'VITÓRIA' : 'DERROTA', style: TextStyle(color: game.won ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.28,
            children: [
              MetricCard(label: 'Off Rating', value: off.toStringAsFixed(1), icon: Icons.bolt_rounded),
              MetricCard(label: 'Def Rating', value: def.toStringAsFixed(1), icon: Icons.shield_outlined),
              MetricCard(label: 'eFG%', value: '${efg.toStringAsFixed(1)}%', icon: Icons.gps_fixed),
              MetricCard(label: 'TOV%', value: '${tov.toStringAsFixed(1)}%', icon: Icons.error_outline),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Leitura do ARCO',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: reasons.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(e))).toList()),
          ),
          if (game.playerStats.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Box score registrado',
              child: Column(
                children: game.playerStats.entries.map((entry) {
                  final s = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(child: Text(names[entry.key] ?? entry.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${s.points} PTS  ${s.rebounds} REB  ${s.assists} AST', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
          if (lineups.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Lineups capturados pelo scout',
              child: Column(
                children: lineups.take(5).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.players.join(' • '), style: const TextStyle(fontSize: 12)),
                      Text('${l.possessions} posses estimadas • confiança ${AnalyticsService.sampleConfidence(l.possessions)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ])),
                    Text('${l.netRating >= 0 ? '+' : ''}${l.netRating.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.w900, color: l.netRating >= 0 ? Colors.greenAccent : Colors.redAccent)),
                  ]),
                )).toList(),
              ),
            ),
          ],
          if (shots.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Shot chart do jogo',
              trailing: Text(
                '${shots.length} arremessos localizados',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              child: ShotChart(shots: shots),
            ),
          ],
          if (game.events.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Timeline do jogo',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          videoUrl.isEmpty
                              ? 'Vincule um vídeo para abrir cada evento no momento correspondente.'
                              : 'Vídeo vinculado: toque em um evento para abrir no tempo aproximado.',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _videoDialog(context, state, videoUrl),
                        icon: const Icon(Icons.ondemand_video),
                        label: Text(videoUrl.isEmpty ? 'Vincular' : 'Editar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...game.events.reversed.take(30).map((event) {
                    final elapsed = event.timestamp
                        .difference(game.date)
                        .inSeconds
                        .clamp(0, 999999)
                        .toInt();
                    final player = event.playerId == null ? '' : (names[event.playerId] ?? event.playerId!);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 16, child: Text('${event.period}Q', style: const TextStyle(fontSize: 10))),
                      title: Text(_eventLabel(event.type)),
                      subtitle: Text([_clock(elapsed), if (player.isNotEmpty) player].join(' • ')),
                      trailing: videoUrl.isEmpty ? null : const Icon(Icons.play_arrow_rounded),
                      onTap: videoUrl.isEmpty ? null : () => _openVideoAt(videoUrl, elapsed),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Four Factors disponíveis',
            child: Column(
              children: [
                _row('eFG%', '${efg.toStringAsFixed(1)}%'),
                _row('TOV%', '${tov.toStringAsFixed(1)}%'),
                _row('ORB%', '${orb.toStringAsFixed(1)}%'),
                _row('FT Rate', '${ftRate.toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _videoDialog(BuildContext context, AppState state, String current) async {
    final controller = TextEditingController(text: current);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vídeo do jogo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Link do YouTube',
            hintText: 'https://youtube.com/...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await state.setVideoLink(game.id, controller.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openVideoAt(String url, int seconds) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return;
    final query = Map<String, String>.from(parsed.queryParameters);
    query['t'] = '${seconds}s';
    final timed = parsed.replace(queryParameters: query);
    await launchUrl(timed, mode: LaunchMode.externalApplication);
  }

  String _clock(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _eventLabel(PlayEventType type) {
    switch (type) {
      case PlayEventType.twoMade: return '2 pontos convertido';
      case PlayEventType.twoMiss: return '2 pontos errado';
      case PlayEventType.threeMade: return '3 pontos convertido';
      case PlayEventType.threeMiss: return '3 pontos errado';
      case PlayEventType.freeThrowMade: return 'Lance livre convertido';
      case PlayEventType.freeThrowMiss: return 'Lance livre errado';
      case PlayEventType.assist: return 'Assistência';
      case PlayEventType.offensiveRebound: return 'Rebote ofensivo';
      case PlayEventType.defensiveRebound: return 'Rebote defensivo';
      case PlayEventType.steal: return 'Roubo';
      case PlayEventType.block: return 'Toco';
      case PlayEventType.turnover: return 'Turnover';
      case PlayEventType.foul: return 'Falta';
      case PlayEventType.opponentOne: return '+1 adversário';
      case PlayEventType.opponentTwo: return '+2 adversário';
      case PlayEventType.opponentThree: return '+3 adversário';
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}
