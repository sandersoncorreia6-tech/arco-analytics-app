import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'cloud_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'adriano.miao@arco.app');
  final password = TextEditingController(text: 'ARCO-DEMO');
  String? error;

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Nuvem configurada: login real. Sem ela: modo local de demonstração.
    if (state.cloud.enabled) return const CloudLoginScreen();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.track_changes_rounded, size: 54),
                  const SizedBox(height: 14),
                  const Text('ARCO Analytics', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Área do treinador', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 24),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final ok = await state.login(email.text, password.text);
                      if (!ok && mounted) setState(() => error = 'Login de demonstração inválido.');
                    },
                    child: const Padding(padding: EdgeInsets.all(13), child: Text('Entrar')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.loginAsAdrianoDemo,
                    icon: const Icon(Icons.sports_basketball),
                    label: const Text('Entrar como Adriano Mião (demo)'),
                  ),
                  const SizedBox(height: 14),
                  const Text('Conta local de demonstração. Em produção, substituir por autenticação segura em nuvem.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
