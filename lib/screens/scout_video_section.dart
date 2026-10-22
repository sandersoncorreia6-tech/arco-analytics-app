import 'package:flutter/material.dart';

import '../models/game.dart';
import '../state/app_state.dart';
import '../widgets/league_widgets.dart';
import '../widgets/section_card.dart';

/// Vídeo sincronizado com o scout e clipes por filtro (jogador, ação, contexto, quarto).
class ScoutVideoSection extends StatefulWidget {
  final Game game;
  const ScoutVideoSection({super.key, required this.game});
  @override
  State<ScoutVideoSection> createState() => _ScoutVideoSectionState();
}

class _ScoutVideoSectionState extends State<ScoutVideoSection> {
  String group = 'Todos';
  String player = '';
  String tag = '';
  int period = 0;

  String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _configure(AppState state) async {
    final key = AppState.scoutVideoKey(widget.game);
    final url = TextEditingController(text: state.videoLinks[key] ?? '');
    final offset = TextEditingController(text: _clock(state.videoOffsets[key] ?? 0));
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vídeo do jogo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link do vídeo (YouTube)')),
          const SizedBox(height: 10),
          TextField(
            controller: offset,
            decoration: const InputDecoration(
              labelText: 'Minuto do vídeo em que o scout começou (mm:ss)',
              helperText: 'Ex.: 03:20 se a bola subiu aos 3min20s do vídeo',
              helperMaxLines: 2,
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () async {
              final m = RegExp(r'^(\d+)(?::(\d{1,2}))?$').firstMatch(offset.text.trim());
              final seconds = m == null ? 0 : (m.group(2) == null ? int.parse(m.group(1)!) : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!));
              await state.setScoutVideo(widget.game, url.text.trim(), seconds);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    );
    url.dispose();
    offset.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final g = widget.game;
    final names = {for (final p in state.players) p.id: p.name};
    final hasVideo = (state.videoLinks[AppState.scoutVideoKey(g)] ?? '').isNotEmpty;
    final groups = ['Todos', ...{for (final e in g.events) e.group}];
    final tags = {for (final e in g.events) if (e.tag != null) e.tag!};
    final playersInGame = {for (final e in g.events) if (e.playerId != null && names.containsKey(e.playerId)) e.playerId!: names[e.playerId]!};
    final periods = {for (final e in g.events) e.period}.toList()..sort();
    final clips = g.events.where((e) {
      if (group != 'Todos' && e.group != group) return false;
      if (player.isNotEmpty && e.playerId != player) return false;
      if (tag.isNotEmpty && e.tag != tag) return false;
      if (period != 0 && e.period != period) return false;
      return true;
    }).toList();

    return SectionCard(
      title: 'Vídeo e clipes',
      trailing: TextButton.icon(
        onPressed: () => _configure(state),
        icon: Icon(hasVideo ? Icons.edit : Icons.add_link, size: 18),
        label: Text(hasVideo ? 'Editar' : 'Vincular'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          hasVideo
              ? 'Toque numa ação para abrir o vídeo exatamente naquele momento.'
              : 'Vincule o vídeo do jogo para abrir cada jogada no momento exato.',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          DropdownButton<String>(
            value: group,
            items: [for (final x in groups) DropdownMenuItem(value: x, child: Text(x))],
            onChanged: (v) => setState(() => group = v ?? 'Todos'),
          ),
          DropdownButton<String>(
            value: playersInGame.containsKey(player) ? player : '',
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos os jogadores')),
              for (final e in playersInGame.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => player = v ?? ''),
          ),
          if (tags.isNotEmpty)
            DropdownButton<String>(
              value: tags.contains(tag) ? tag : '',
              items: [
                const DropdownMenuItem(value: '', child: Text('Qualquer contexto')),
                for (final t in tags) DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => tag = v ?? ''),
            ),
          DropdownButton<int>(
            value: periods.contains(period) ? period : 0,
            items: [
              const DropdownMenuItem(value: 0, child: Text('Jogo todo')),
              for (final p in periods) DropdownMenuItem(value: p, child: Text(p >= 5 ? 'Prorrogação' : '$pº quarto')),
            ],
            onChanged: (v) => setState(() => period = v ?? 0),
          ),
        ]),
        Text('${clips.length} clipes', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final e in clips.take(80))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(
              _clock((state.videoOffsets[AppState.scoutVideoKey(g)] ?? 0) + e.timestamp.difference(g.date).inSeconds.clamp(0, 99999)),
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
            title: Text([e.label, if (e.tag != null) e.tag!].join(' • ')),
            subtitle: Text([if (e.playerId != null) names[e.playerId] ?? '', '${e.period >= 5 ? 'PR' : '${e.period}Q'}'].where((x) => x.isNotEmpty).join(' • ')),
            trailing: Icon(hasVideo ? Icons.play_circle_outline : Icons.videocam_off_outlined),
            onTap: () {
              final link = state.videoAtEvent(g, e);
              if (link == null) {
                _configure(state);
              } else {
                openExternal(context, link);
              }
            },
          ),
      ]),
    );
  }
}
