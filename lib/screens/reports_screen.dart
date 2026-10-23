import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/report_service.dart';
import '../state/app_state.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final report = ReportService.seasonReport(
      teamName: state.teamContext.displayName,
      games: state.games,
      players: state.players,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            tooltip: 'Copiar relatório',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Relatório copiado.')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Resumo gerado diretamente dos dados registrados no ARCO.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SelectableText(
                report,
                style: const TextStyle(fontFamily: 'monospace', height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Exportação PDF pode ser adicionada sobre este mesmo relatório sem mudar a regra de cálculo. O conteúdo já está pronto para compartilhamento com a comissão técnica.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
