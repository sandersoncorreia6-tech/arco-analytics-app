import 'package:flutter/material.dart';

import '../analysis/analyst.dart';
import '../analysis/reports.dart';
import '../analysis/season_analysis.dart';
import '../services/stats_aggregator.dart';
import '../state/app_state.dart';
import 'report_screen.dart';

class _Message {
  final bool fromCoach;
  final String text;
  final List<String> suggestions;
  const _Message(this.fromCoach, this.text, [this.suggestions = const []]);
}

/// Analista ARCO: o treinador pergunta, o ARCO responde com números e recomendações.
class AnalystScreen extends StatefulWidget {
  final String? initialQuestion;
  const AnalystScreen({super.key, this.initialQuestion});
  @override
  State<AnalystScreen> createState() => _AnalystScreenState();
}

class _AnalystScreenState extends State<AnalystScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Message>[];
  String? _teamKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      final state = AppScope.of(context);
      _messages.add(_Message(
        false,
        'Olá, ${state.coach.name.split(' ').first}! Sou o Analista ARCO. Pergunte sobre a sua equipe — por exemplo, '
        'de onde o time mais erra, por que perdeu o último jogo ou o que treinar.',
        ArcoAnalyst.suggestions,
      ));
      if (widget.initialQuestion != null) _ask(widget.initialQuestion!);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ArcoAnalyst _analyst(AppState state) {
    final mine = state.myTeamSeasons;
    final selected = mine.where((t) => t.key == _teamKey).toList();
    return ArcoAnalyst(teams: state.teamSeasons, myTeams: [...selected, ...mine.where((t) => t.key != _teamKey)]);
  }

  void _ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
    final reply = _analyst(AppScope.of(context)).answer(q);
    setState(() {
      _messages.add(_Message(true, q));
      _messages.add(_Message(false, reply.text, reply.suggestions));
    });
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = state.myTeamSeasons;
    final current = _analyst(state).team;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analista ARCO'),
        actions: [
          if (current != null)
            IconButton(
              tooltip: 'Relatório da temporada',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(report: Reports.season(SeasonAnalysis(current))))),
            ),
        ],
      ),
      body: Column(children: [
        if (mine.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String>(
              initialValue: current?.key,
              decoration: const InputDecoration(labelText: 'Equipe analisada', border: OutlineInputBorder(), isDense: true),
              items: [for (final TeamSeason t in mine) DropdownMenuItem(value: t.key, child: Text('${t.name} (${t.games} jogos)'))],
              onChanged: (v) => setState(() => _teamKey = v),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final scheme = Theme.of(context).colorScheme;
              return Column(crossAxisAlignment: m.fromCoach ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: BoxDecoration(
                    color: m.fromCoach ? scheme.primary.withValues(alpha: .25) : Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(m.text, style: const TextStyle(height: 1.35)),
                ),
                if (!m.fromCoach && m.suggestions.isNotEmpty && i == _messages.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final s in m.suggestions) ActionChip(label: Text(s, style: const TextStyle(fontSize: 12)), onPressed: () => _ask(s)),
                    ]),
                  ),
              ]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: const InputDecoration(hintText: 'Pergunte ao Analista...', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: () => _ask(_input.text), icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
