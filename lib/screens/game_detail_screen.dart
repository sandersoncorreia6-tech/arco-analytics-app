import 'package:flutter/material.dart';
import '../analysis/game_analysis.dart';
import '../analysis/reports.dart';
import '../analysis/scout_adapter.dart';
import '../models/game.dart';
import '../services/analytics_service.dart';
import '../state/app_state.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';
import 'report_screen.dart';
import 'scout_video_section.dart';

class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final names = {for (final p in state.players) p.id: p.name};
    final lineups = AnalyticsService.lineupsFromGame(game, names);
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
      appBar: AppBar(title: Text('vs ${game.opponent}'), actions: [
        IconButton(
          tooltip: 'Relatório pós-jogo',
          icon: const Icon(Icons.description_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReportScreen(
              report: Reports.postGame(GameAnalysis(ScoutAdapter.toBoxScore(game, teamName: state.coach.team.isEmpty ? state.coach.club : state.coach.team, roster: state.players), 1)),
            ),
          )),
        ),
      ]),
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
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReportScreen(
                report: Reports.postGame(GameAnalysis(ScoutAdapter.toBoxScore(game, teamName: state.coach.team.isEmpty ? state.coach.club : state.coach.team, roster: state.players), 1)),
              ),
            )),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('Relatório pós-jogo do Analista ARCO'),
          ),
          if (game.events.isNotEmpty) ...[const SizedBox(height: 12), ScoutVideoSection(game: game)],
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.15,
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

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}
