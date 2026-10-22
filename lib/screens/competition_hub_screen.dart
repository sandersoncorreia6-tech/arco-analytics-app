import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_state.dart';

class CompetitionHubScreen extends StatefulWidget {
  const CompetitionHubScreen({super.key});
  @override
  State<CompetitionHubScreen> createState() => _CompetitionHubScreenState();
}

class _CompetitionHubScreenState extends State<CompetitionHubScreen> {
  String league = 'TODOS';
  String category = 'TODAS';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rows = <_GameRow>[
      ...state.fpbGames.map((g) => _GameRow('FPB', g.id, g.homeTeam, g.awayTeam, g.scoreLabel, g.competition, g.status, g.scheduledAt, g.sourceUrl)),
      ...state.lbcGames.map((g) => _GameRow('LBC', g.id, g.homeTeam, g.awayTeam, g.scoreLabel, g.competition, g.status, g.scheduledAt, g.sourceUrl)),
    ];
    final categories = <String>{'TODAS', ...rows.map((e) => e.category).where((e) => e.isNotEmpty)}.toList()..sort();
    final filtered = rows.where((g) {
      if (league != 'TODOS' && g.league != league) return false;
      if (category != 'TODAS' && g.category != category) return false;
      if (query.isNotEmpty && !('${g.home} ${g.away}'.toLowerCase().contains(query.toLowerCase()))) return false;
      return true;
    }).toList();

    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Competições', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('FPB + LBC em uma agenda única.', style: TextStyle(color: Colors.white60)),
        ])),
        IconButton(onPressed: state.syncAllLeagues, icon: const Icon(Icons.refresh_rounded), tooltip: 'Atualizar'),
      ]),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar equipe...', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        DropdownButton<String>(value: league, items: const ['TODOS','FPB','LBC'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => league = v!)),
        DropdownButton<String>(value: categories.contains(category) ? category : 'TODAS', items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => category = v!)),
      ]),
      const SizedBox(height: 10),
      if (state.fpbSyncing || state.lbcSyncing) const LinearProgressIndicator(),
      if (state.lbcError != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('LBC: ${state.lbcError}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
      if (filtered.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhum jogo encontrado neste filtro. Atualize as fontes ou altere os filtros.'))),
      ...filtered.map((g) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(child: Text(g.league, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
          title: Text('${g.home}  ${g.score}  ${g.away}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text([g.category, g.status, g.dateLabel].where((e) => e.isNotEmpty).join(' • ')),
          trailing: IconButton(icon: Icon(state.videoLinks.containsKey(g.id) ? Icons.play_circle_fill : Icons.video_library_outlined), onPressed: () => _videoDialog(context, state, g)),
          onTap: () => _gameSheet(context, state, g),
        ),
      )),
    ]);
  }

  Future<void> _gameSheet(BuildContext context, AppState state, _GameRow g) async {
    await showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${g.home} × ${g.away}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('${g.league} • ${g.category} • ${g.status}'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: () { Navigator.pop(context); _videoDialog(context, state, g); }, icon: const Icon(Icons.ondemand_video), label: Text(state.videoLinks.containsKey(g.id) ? 'Assistir / editar vídeo' : 'Adicionar vídeo do YouTube')),
        OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(g.sourceUrl), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('Abrir fonte oficial')),
      ]),
    ));
  }

  Future<void> _videoDialog(BuildContext context, AppState state, _GameRow g) async {
    final controller = TextEditingController(text: state.videoLinks[g.id] ?? '');
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Vídeo do jogo'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Link do YouTube', hintText: 'https://youtube.com/...')),
      actions: [
        if ((state.videoLinks[g.id] ?? '').isNotEmpty) TextButton(onPressed: () => launchUrl(Uri.parse(state.videoLinks[g.id]!), mode: LaunchMode.externalApplication), child: const Text('ASSISTIR')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        FilledButton(onPressed: () async { await state.setVideoLink(g.id, controller.text.trim()); if (context.mounted) Navigator.pop(context); }, child: const Text('SALVAR')),
      ],
    ));
    controller.dispose();
  }
}

class _GameRow {
  final String league,id,home,away,score,category,status,sourceUrl;
  final DateTime? date;
  _GameRow(this.league,this.id,this.home,this.away,this.score,this.category,this.status,this.date,this.sourceUrl);
  String get dateLabel => date == null ? '' : '${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}';
}
