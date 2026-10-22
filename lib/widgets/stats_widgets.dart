import 'package:flutter/material.dart';

import '../models/box_score.dart';
import '../state/app_state.dart';

String f1(double v) => v.toStringAsFixed(1);
String pct(double v) => '${v.toStringAsFixed(0)}%';
String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
String mins(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Grade de números com rótulo (PTS, REB, FG%...).
class StatTiles extends StatelessWidget {
  final List<(String, String)> items;
  const StatTiles(this.items, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, value) in items)
            Container(
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                FittedBox(child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
        ],
      );
}

/// Uma linha da tabela de jogadores.
class StatRow {
  final String number;
  final String name;
  final bool starter;
  final StatLine line;

  /// Jogos (temporada) — `null` em box score de uma partida.
  final int? games;
  final VoidCallback? onTap;
  const StatRow({required this.number, required this.name, required this.line, this.starter = false, this.games, this.onTap});
}

/// Tabela de jogadores com rolagem horizontal (box score ou médias).
class PlayerStatsTable extends StatelessWidget {
  final List<StatRow> rows;
  final StatLine? totals;

  /// `true`: mostra médias por jogo (temporada); `false`: números da partida.
  final bool averages;
  const PlayerStatsTable({super.key, required this.rows, this.totals, this.averages = false});

  @override
  Widget build(BuildContext context) {
    String v(int value, int? games) => averages && games != null && games > 0 ? f1(value / games) : '$value';
    String m(StatLine l, int? games) => averages && games != null && games > 0 ? f1(l.minutes / games) : mins(l.seconds);
    String shoot(int made, int att, int? games) =>
        averages ? (att == 0 ? '-' : pct(StatLine.pct(made, att))) : '$made/$att';

    List<DataCell> cells(StatLine l, int? g) => [
          if (averages) DataCell(Text('${g ?? 0}')),
          DataCell(Text(m(l, g))),
          DataCell(Text(v(l.points, g), style: const TextStyle(fontWeight: FontWeight.w800))),
          DataCell(Text(v(l.reb, g))),
          DataCell(Text(v(l.ast, g))),
          DataCell(Text(v(l.stl, g))),
          DataCell(Text(v(l.blk, g))),
          DataCell(Text(v(l.tov, g))),
          DataCell(Text(shoot(l.fgm, l.fga, g))),
          DataCell(Text(shoot(l.tpm, l.tpa, g))),
          DataCell(Text(shoot(l.ftm, l.fta, g))),
          DataCell(Text(v(l.oreb, g))),
          DataCell(Text(v(l.dreb, g))),
          DataCell(Text(v(l.pf, g))),
          if (!averages) DataCell(Text('${l.plusMinus > 0 ? '+' : ''}${l.plusMinus}')),
          DataCell(Text(v(l.efficiency, g))),
        ];

    final columns = [
      '#',
      'Jogador',
      if (averages) 'J',
      'MIN',
      'PTS',
      'REB',
      'AST',
      'ROB',
      'TOC',
      'ERR',
      averages ? 'FG%' : 'FG',
      averages ? '3P%' : '3P',
      averages ? 'LL%' : 'LL',
      'RO',
      'RD',
      'FLT',
      if (!averages) '+/-',
      'EFI',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        horizontalMargin: 8,
        headingRowHeight: 34,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 40,
        headingTextStyle: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
        dataTextStyle: const TextStyle(fontSize: 13),
        columns: [for (final c in columns) DataColumn(label: Text(c), numeric: c != 'Jogador' && c != '#')],
        rows: [
          for (final r in rows)
            DataRow(
              onSelectChanged: r.onTap == null ? null : (_) => r.onTap!(),
              cells: [
                DataCell(Text(r.number)),
                DataCell(Text(r.starter ? '${r.name} *' : r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                ...cells(r.line, r.games),
              ],
            ),
          if (totals != null)
            DataRow(
              color: WidgetStatePropertyAll(Colors.white.withValues(alpha: .04)),
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('Equipe', style: TextStyle(fontWeight: FontWeight.w800))),
                ...cells(totals!, null),
              ],
            ),
        ],
      ),
    );
  }
}

/// Importa uma partida pelo link da aba Estatística/Online.
Future<void> showAddStatsLinkDialog(BuildContext context) async {
  final state = AppScope.of(context);
  final controller = TextEditingController();
  var league = 'FPB';
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: const Text('Importar estatística de um jogo'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'No site da liga, abra o jogo na aba Estatística / Online, copie o endereço da página e cole aqui '
              '(ou só o número da partida).',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'https://...', errorText: error, errorMaxLines: 4),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'FPB', label: Text('FPB')), ButtonSegment(value: 'LBC', label: Text('LBC'))],
              selected: {league},
              onSelectionChanged: (v) => setLocal(() => league = v.first),
            ),
            if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setLocal(() {
                      busy = true;
                      error = null;
                    });
                    final result = await state.addStatsLink(controller.text, league: league);
                    if (!dialogContext.mounted) return;
                    if (result == null) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estatísticas do jogo importadas.')));
                    } else {
                      setLocal(() {
                        busy = false;
                        error = result;
                      });
                    }
                  },
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}
