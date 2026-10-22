import 'package:flutter/material.dart';

import '../data/repositories/game_repository.dart';
import '../models/league_game.dart';
import '../state/app_state.dart';
import '../widgets/league_widgets.dart';
import '../widgets/section_card.dart';
import 'box_score_screen.dart';
import 'game_detail_screen.dart';

/// Página da partida: ficha completa, vídeo, página oficial, estatística e scout.
class MatchDetailScreen extends StatefulWidget {
  final String gameId;
  const MatchDetailScreen({super.key, required this.gameId});
  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool loadingStats = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = state.gameRepository.all.where((x) => x.id == widget.gameId).firstOrNull;
    if (g == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Partida não encontrada.')));
    final view = CoachGame(g, g.league == 'SCOUT' || state.coach.isHome(g));
    final video = state.videoLinks[g.id] ?? '';
    final scout = g.league == 'SCOUT' ? state.scoutGameById(g.id) : null;
    final hasStats = g.externalId.isNotEmpty && state.boxScores.containsKey(g.externalId);

    Widget row(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54))),
              Expanded(child: Text(value)),
            ]),
          );

    return Scaffold(
      appBar: AppBar(title: Text('${view.isHome ? 'vs' : '@'} ${view.opponent}')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(g.homeTeam, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(g.hasScore ? '${g.homeScore} × ${g.awayScore}' : '—', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Expanded(child: Text(g.awayTeam, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 6),
              Text([g.status, if (view.result.isNotEmpty) (view.result == 'V' ? 'VITÓRIA' : view.result == 'D' ? 'DERROTA' : 'EMPATE')].join(' • '),
                  style: TextStyle(color: view.result == 'V' ? Colors.greenAccent : (view.result == 'D' ? Colors.redAccent : Colors.white60))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => video.isEmpty ? showVideoDialog(context, g) : openExternal(context, video),
          icon: Icon(video.isEmpty ? Icons.video_call_outlined : Icons.play_circle_fill),
          label: Text(video.isEmpty ? 'Adicionar vídeo do jogo' : 'Assistir ao jogo'),
        ),
        if (video.isNotEmpty)
          TextButton.icon(onPressed: () => showVideoDialog(context, g), icon: const Icon(Icons.edit, size: 18), label: const Text('Trocar vídeo')),
        const SizedBox(height: 6),
        if (scout != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameDetailScreen(game: scout))),
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Scout, vídeo sincronizado e relatório'),
          ),
        if (g.externalId.isNotEmpty)
          OutlinedButton.icon(
            onPressed: loadingStats
                ? null
                : () async {
                    if (!hasStats) {
                      setState(() => loadingStats = true);
                      final error = await state.addStatsLink(g.externalId, league: g.league);
                      if (!context.mounted) return;
                      setState(() => loadingStats = false);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                    }
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoxScoreScreen(matchId: g.externalId)));
                  },
            icon: loadingStats
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.leaderboard_outlined),
            label: Text(hasStats ? 'Estatística completa e mapa de arremessos' : 'Baixar estatística completa'),
          ),
        if (g.sourceUrl.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => openExternal(context, g.sourceUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Página oficial'),
          ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Ficha da partida',
          child: Column(children: [
            row('Data', g.dateLabel),
            row('Competição', g.competitionName.isNotEmpty ? g.competitionName : g.league),
            row('Categoria', g.competition),
            row('Temporada', g.season),
            row('Rodada', g.round),
            row('Local', g.venue),
            row('Mandante', g.homeTeam),
            row('Visitante', g.awayTeam),
            row('Fonte', _sourceLabel(g)),
            row('Atualizado', '${g.fetchedAt.day.toString().padLeft(2, '0')}/${g.fetchedAt.month.toString().padLeft(2, '0')} ${hhmm(g.fetchedAt)}'),
          ]),
        ),
        const SizedBox(height: 10),
        ExpansionTile(
          title: const Text('Identificadores', style: TextStyle(fontSize: 13)),
          children: [
            row('gameId', g.id),
            row('competitionId', g.competitionId),
            row('seasonId', g.season),
            row('categoryId', g.categoryId),
            row('teamId', state.coach.teamId),
            row('coachId', state.coach.id),
            row('equipe casa', g.homeTeamId),
            row('equipe fora', g.awayTeamId),
            row('estatística', g.externalId),
          ],
        ),
      ]),
    );
  }

  static String _sourceLabel(LeagueGame g) => switch (g.league) {
        'SCOUT' => 'Scout do ARCO',
        'FPB' => g.externalId.isNotEmpty ? 'FPB • estatística online' : 'FPB',
        'LBC' => 'LBC',
        _ => g.manual ? '${g.league} • importado manualmente' : g.league,
      };
}
