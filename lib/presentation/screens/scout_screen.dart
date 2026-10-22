import 'package:flutter/material.dart';
import 'package:arco_analytics/presentation/widgets/section_card.dart';

class ScoutScreen extends StatelessWidget {
  const ScoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scout do adversário')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          SectionCard(
            title: 'Identidade',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text('Ritmo: ALTO'), Text('Volume de 3PT: ALTO'), Text('Rebote ofensivo: FORTE'), Text('Turnovers sob pressão: VULNERÁVEL')],
            ),
          ),
          SizedBox(height: 14),
          SectionCard(
            title: 'Plano de jogo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('☑ Acelerar após rebote defensivo'),
                Text('☑ Forçar o armador para a esquerda'),
                Text('☑ Atacar a segunda unidade'),
                Text('☑ Meta de TOV < 12'),
                Text('☑ ORB adversário < 25%'),
              ],
            ),
          ),
          SizedBox(height: 14),
          SectionCard(
            title: 'Vantagem detectada',
            child: Text(
              'O adversário permite maior eficiência no corner direito e perde qualidade ofensiva quando o armador titular descansa.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
