import 'package:flutter/material.dart';
import '../services/auth_gateway.dart';
import '../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool submitting = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cloud = AuthConfiguration.cloudConfigured;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.track_changes_rounded, size: 54),
                    const SizedBox(height: 14),
                    const Text('ARCO Analytics', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('Área do treinador', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (cloud ? Colors.greenAccent : Colors.orangeAccent).withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        cloud
                            ? 'Autenticação em nuvem configurada.'
                            : 'Modo demonstração. O login real será ativado quando o backend for configurado no build.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cloud ? Colors.greenAccent : Colors.orangeAccent),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: !cloud || submitting ? null : () async {
                        setState(() { submitting = true; error = null; });
                        final ok = await state.login(email.text, password.text);
                        if (!mounted) return;
                        setState(() {
                          submitting = false;
                          if (!ok) error = state.lastAuthError ?? 'Não foi possível entrar.';
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Text(submitting ? 'Entrando...' : 'Entrar'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: state.loginAsAdrianoDemo,
                      icon: const Icon(Icons.sports_basketball),
                      label: const Text('Entrar como Adriano Mião (demo)'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'A sessão demo é local e serve para apresentação e testes. Nenhuma senha real é armazenada no código.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
