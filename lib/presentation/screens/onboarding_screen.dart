import 'package:flutter/material.dart';

import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/screens/my_team_screen.dart';

/// Primeiro acesso: criar clube → equipe/categoria → temporada.
/// Depois o treinador cadastra jogadores (aba Elenco) e inicia o scout.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final club = TextEditingController();
  final city = TextEditingController();
  final team = TextEditingController();
  final keywords = TextEditingController();
  final season = TextEditingController(text: DateTime.now().year.toString());
  String category = 'SUB 16 M';
  String? error;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [club, city, team, keywords, season]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    InputDecoration d(String label, [String? help]) =>
        InputDecoration(labelText: label, helperText: help, helperMaxLines: 3, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo ao ARCO'),
        actions: [TextButton(onPressed: state.logout, child: const Text('Sair'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Vamos montar o seu ambiente', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Clube → categoria → temporada. Depois: elenco, jogos e scout.', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 20),
              TextField(controller: club, decoration: d('Clube / organização', 'Ex.: Tupã / Monstrinho')),
              const SizedBox(height: 12),
              TextField(controller: city, decoration: d('Cidade')),
              const SizedBox(height: 12),
              TextField(controller: team, decoration: d('Nome da equipe', 'Ex.: Tupã Sub-16')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: d('Categoria'),
                items: [for (final c in MyTeamScreenCategories.all) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(controller: season, keyboardType: TextInputType.number, decoration: d('Temporada')),
              const SizedBox(height: 12),
              TextField(
                controller: keywords,
                decoration: d('Como a equipe aparece nas tabelas da FPB/LBC', 'Palavras separadas por vírgula. Ex.: Tupã, Monstrinho, ATB'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        if (club.text.trim().isEmpty || team.text.trim().isEmpty) {
                          setState(() => error = 'Informe o clube e a equipe.');
                          return;
                        }
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        final words = keywords.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        final result = await state.cloudCreateClub(
                          club: club.text.trim(),
                          city: city.text.trim(),
                          team: team.text.trim(),
                          category: category,
                          season: season.text.trim(),
                          keywords: words.isEmpty ? [club.text.split('/').first.trim()] : words,
                        );
                        if (mounted)
                          setState(() {
                            busy = false;
                            error = result;
                          });
                      },
                icon: const Icon(Icons.check),
                label: const Padding(padding: EdgeInsets.all(12), child: Text('Criar meu ambiente')),
              ),
              const SizedBox(height: 10),
              const Text(
                'Foi convidado por outro treinador? Peça para ele adicionar seu e-mail à comissão do clube e entre de novo.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
