import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Cadastro da equipe acompanhada pelo treinador (organização, equipe,
/// categoria, temporada, competição). Substitui o que antes era fixo no código.
class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});
  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  late final TextEditingController name, club, city, team, keywords, season, competitions;
  late String category;
  late String league;

  static const categories = [
    'SUB 12 M', 'SUB 13 M', 'SUB 14 M', 'SUB 15 M', 'SUB 16 M', 'SUB 17 M', 'SUB 18 M', 'SUB 19 M', 'ADULTO M',
    'SUB 12 F', 'SUB 13 F', 'SUB 14 F', 'SUB 15 F', 'SUB 16 F', 'SUB 17 F', 'SUB 18 F', 'SUB 19 F', 'ADULTO F',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context).coach;
    name = TextEditingController(text: c.name);
    club = TextEditingController(text: c.club);
    city = TextEditingController(text: c.city);
    team = TextEditingController(text: c.team);
    keywords = TextEditingController(text: c.teamKeywords.join(', '));
    season = TextEditingController(text: c.season);
    competitions = TextEditingController(text: c.competitionIds.join('\n'));
    category = categories.contains(c.category) ? c.category : 'SUB 16 M';
    league = c.league.isEmpty ? 'FPB' : c.league;
  }

  @override
  void dispose() {
    for (final c in [name, club, city, team, keywords, season, competitions]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    InputDecoration d(String label, [String? help]) => InputDecoration(labelText: label, helperText: help, helperMaxLines: 3, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(title: const Text('Minha equipe')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: d('Treinador')),
        const SizedBox(height: 12),
        TextField(controller: club, decoration: d('Clube / organização')),
        const SizedBox(height: 12),
        TextField(controller: city, decoration: d('Cidade')),
        const SizedBox(height: 12),
        TextField(controller: team, decoration: d('Nome da equipe', 'Ex.: Tupã Sub-16')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: d('Categoria'),
          items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => category = v ?? category),
        ),
        const SizedBox(height: 12),
        TextField(controller: season, keyboardType: TextInputType.number, decoration: d('Temporada', 'Ex.: 2026. Deixe vazio para todas.')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: league,
          decoration: d('Competição principal'),
          items: const [DropdownMenuItem(value: 'FPB', child: Text('FPB')), DropdownMenuItem(value: 'LBC', child: Text('LBC'))],
          onChanged: (v) => setState(() => league = v ?? league),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: keywords,
          decoration: d('Como a equipe aparece nas tabelas', 'Palavras separadas por vírgula, sem diferenciar acentos. Ex.: Tupã, Monstrinho, ATB'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: competitions,
          minLines: 2,
          maxLines: 4,
          decoration: d('Competições na estatística online (opcional)',
              'Link ou número da competição na aba Estatísticas → Online da FPB (ex.: SUB 16M 2026). Um por linha.'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            await state.updateCoach(state.coach.copyWith(
              name: name.text.trim(),
              club: club.text.trim(),
              city: city.text.trim(),
              team: team.text.trim(),
              category: category,
              season: season.text.trim(),
              league: league,
              teamKeywords: keywords.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              competitionIds: competitions.text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList(),
            ));
            state.syncAllLeagues();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save),
          label: const Text('Salvar e atualizar jogos'),
        ),
      ]),
    );
  }
}
