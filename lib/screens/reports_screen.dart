import 'package:flutter/material.dart';
import '../widgets/section_card.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          SectionCard(title: 'Pós-jogo', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.summarize_outlined), title: Text('ARCO 82 × 75 Franca B'), subtitle: Text('Resumo de decisão, Four Factors, lineups e alertas'), trailing: Icon(Icons.chevron_right))),
          SizedBox(height: 14),
          SectionCard(title: 'Próxima etapa', child: Text('Exportação em PDF, compartilhamento com a comissão técnica e relatórios automáticos por atleta serão conectados ao banco de dados real.', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
