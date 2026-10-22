import 'package:flutter/material.dart';

import '../data/repositories/game_repository.dart';
import '../state/app_state.dart';
import '../widgets/league_widgets.dart';
import 'league_live_screen.dart';
import 'live_scout_screen.dart';
import 'match_detail_screen.dart';
import 'new_game_screen.dart';

const _months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

/// Área "Jogos" do treinador: histórico completo da equipe (clube + categoria
/// + temporada), sem limite de quantidade, com visões e filtros.
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});
  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameView view = GameView.recent;
  GameFilter filter = const GameFilter();
  bool allSeasons = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = state.gameRepository.forCoach(state.coach, allSeasons: allSeasons || view == GameView.all);
    final list = GameRepository.query(mine, view, filter);
    final rec = GameRepository.record(mine.where((g) => g.game.season == (state.coach.season.isEmpty ? g.game.season : state.coach.season)).toList());

    return Scaffold(
      appBar: AppBar(
        title: Text('Jogos • ${state.coach.team.isEmpty ? state.coach.club : state.coach.team}'),
        actions: [
          IconButton(
            tooltip: 'Atualizar FPB/LBC',
            onPressed: state.feeds.any((f) => f.syncing) ? null : state.syncAllLeagues,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGameScreen())),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Novo scout'),
      ),
      body: RefreshIndicator(
        onRefresh: state.syncAllLeagues,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.activeGame != null)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.sensors_rounded)),
                  title: Text('AO VIVO • vs ${state.activeGame!.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${state.activeGame!.ourScore} × ${state.activeGame!.opponentScore} • ${state.activeGame!.periodLabel}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveScoutScreen())),
                ),
              ),
            _Campaign(record: rec, season: state.coach.season, category: state.coach.category),
            const SizedBox(height: 10),
            SegmentedButton<GameView>(
              segments: [for (final v in GameView.values) ButtonSegment(value: v, label: Text(v.label))],
              selected: {view},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => view = v.first),
            ),
            const SizedBox(height: 8),
            _FilterBar(
              games: mine,
              filter: filter,
              onChanged: (f) => setState(() => filter = f),
            ),
            if (state.feeds.any((f) => f.syncing)) const Padding(padding: EdgeInsets.only(top: 6), child: LinearProgressIndicator()),
            const SizedBox(height: 6),
            Text(
              '${gamesFound(list.length)}${view == GameView.season && state.coach.season.isNotEmpty ? ' na temporada ${state.coach.season}' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (list.isEmpty) _Empty(view: view, hasAny: mine.isNotEmpty),
            for (final g in list) _CoachGameTile(g: g),
            const SizedBox(height: 12),
            for (final feed in state.feeds)
              LeagueStatusCard(
                feed: feed,
                onOpen: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeagueLiveScreen(league: feed.league))),
              ),
          ],
        ),
      ),
    );
  }

  static String gamesFound(int n) => n == 1 ? '1 jogo' : '$n jogos';
}

class _Campaign extends StatelessWidget {
  final ({int played, int wins, int losses, double pct, int pointsFor, int pointsAgainst}) record;
  final String season;
  final String category;
  const _Campaign({required this.record, required this.season, required this.category});

  @override
  Widget build(BuildContext context) {
    final r = record;
    Widget stat(String label, String value, [Color? color]) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Campanha ${[category, season].where((e) => e.isNotEmpty).join(' • ')}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(children: [
            stat('JOGOS', '${r.played}'),
            stat('VITÓRIAS', '${r.wins}', Colors.greenAccent),
            stat('DERROTAS', '${r.losses}', Colors.redAccent),
            stat('APROV.', '${r.pct.toStringAsFixed(0)}%'),
          ]),
          if (r.played > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Média ${(r.pointsFor / r.played).toStringAsFixed(1)} pontos feitos × ${(r.pointsAgainst / r.played).toStringAsFixed(1)} sofridos',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<CoachGame> games;
  final GameFilter filter;
  final ValueChanged<GameFilter> onChanged;
  const _FilterBar({required this.games, required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final seasons = {for (final g in games) if (g.game.season.isNotEmpty) g.game.season}.toList()..sort((a, b) => b.compareTo(a));
    final categories = {for (final g in games) if (g.game.competition.isNotEmpty) g.game.competition}.toList()..sort();
    final competitions = {for (final g in games) g.game.competitionName.isNotEmpty ? g.game.competitionName : g.game.league}.toList()..sort();
    final months = {for (final g in games) if (g.game.scheduledAt != null) g.game.scheduledAt!.month}.toList()..sort();

    Widget menu<T>(String label, T? value, List<(T?, String)> options, ValueChanged<T?> set) => PopupMenuButton<(T?, String)>(
          onSelected: (o) => set(o.$1),
          itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o, child: Text(o.$2))],
          child: Chip(
            label: Text(value == null || value == '' ? label : options.firstWhere((o) => o.$1 == value, orElse: () => (value, '$value')).$2),
            avatar: Icon(Icons.filter_list, size: 16, color: value == null || value == '' ? null : Theme.of(context).colorScheme.primary),
          ),
        );

    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (seasons.length > 1)
        menu<String>('Temporada', filter.season, [(null, 'Todas'), for (final s in seasons) (s, s)], (v) => onChanged(filter.copyWith(season: v ?? ''))),
      if (categories.length > 1)
        menu<String>('Categoria', filter.category, [(null, 'Todas'), for (final c in categories) (c, c)], (v) => onChanged(filter.copyWith(category: v ?? ''))),
      if (competitions.length > 1)
        menu<String>('Competição', filter.competition, [(null, 'Todas'), for (final c in competitions) (c, c)], (v) => onChanged(filter.copyWith(competition: v ?? ''))),
      menu<int>('Mês', filter.month, [(null, 'Todos'), for (final m in months) (m, _months[m - 1])],
          (v) => onChanged(v == null ? filter.copyWith(clearMonth: true) : filter.copyWith(month: v))),
      menu<bool>('Mando', filter.home, [(null, 'Casa e fora'), (true, 'Mandante'), (false, 'Visitante')],
          (v) => onChanged(v == null ? filter.copyWith(clearHome: true) : filter.copyWith(home: v))),
      menu<String>('Resultado', filter.result, [(null, 'Todos'), ('V', 'Vitórias'), ('D', 'Derrotas')], (v) => onChanged(filter.copyWith(result: v ?? ''))),
      SizedBox(
        width: 150,
        child: TextField(
          decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 18), hintText: 'Adversário', border: OutlineInputBorder()),
          onChanged: (v) => onChanged(filter.copyWith(opponent: v)),
        ),
      ),
      if (!filter.isEmpty) TextButton(onPressed: () => onChanged(const GameFilter()), child: const Text('Limpar')),
    ]);
  }
}

class _CoachGameTile extends StatelessWidget {
  final CoachGame g;
  const _CoachGameTile({required this.g});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final x = g.game;
    final r = g.result;
    final color = r == 'V' ? Colors.greenAccent : (r == 'D' ? Colors.redAccent : (x.isLive ? Colors.redAccent : Colors.lightBlueAccent));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchDetailScreen(gameId: x.id))),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .18),
          child: Text(r.isNotEmpty ? r : (x.isLive ? '●' : '•'), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ),
        title: Text('${g.isHome ? 'vs' : '@'} ${g.opponent}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          [
            if (x.hasScore) '${g.ourScore} × ${g.theirScore}' else x.status,
            x.dateLabel,
            x.competitionName.isNotEmpty ? x.competitionName : x.league,
            if (x.venue.isNotEmpty) x.venue,
          ].where((e) => e.isNotEmpty).join(' • '),
        ),
        trailing: state.videoLinks.containsKey(x.id) ? const Icon(Icons.play_circle_fill) : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final GameView view;
  final bool hasAny;
  const _Empty({required this.view, required this.hasAny});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          hasAny
              ? (view == GameView.upcoming ? 'Nenhum jogo futuro encontrado com estes filtros.' : 'Nenhum jogo encontrado com estes filtros.')
              : 'Ainda não há jogos de ${state.coach.teamLabel}. O ARCO busca a FPB/LBC automaticamente; '
                  'confira "Mais → Minha equipe" (nome, categoria e temporada) ou registre um jogo no scout.',
        ),
      ),
    );
  }
}
