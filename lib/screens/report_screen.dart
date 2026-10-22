import 'package:flutter/material.dart';

import '../analysis/reports.dart';
import '../services/report_export.dart';

/// Relatório (pré-jogo, pós-jogo ou temporada) com PDF e compartilhamento.
class ReportScreen extends StatelessWidget {
  final ArcoReport report;
  const ReportScreen({super.key, required this.report});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível concluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        actions: [
          IconButton(tooltip: 'Imprimir / salvar PDF', icon: const Icon(Icons.print_outlined), onPressed: () => _run(context, () => ReportExport.printPdf(report))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Text(report.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(report.subtitle, style: const TextStyle(color: Colors.white60)),
        for (final s in report.sections.where((s) => s.lines.isNotEmpty))
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.heading, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 6),
                for (final l in s.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('•  '),
                      Expanded(child: Text(l)),
                    ]),
                  ),
              ]),
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _run(context, () => ReportExport.shareText(report)),
                icon: const Icon(Icons.share),
                label: const Text('WhatsApp / texto'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _run(context, () => ReportExport.sharePdf(report)),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
