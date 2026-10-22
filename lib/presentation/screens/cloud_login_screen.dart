import 'package:flutter/material.dart';

import 'package:arco_analytics/state/app_state.dart';

/// Login real (Supabase): entrar, criar conta e recuperar senha.
class CloudLoginScreen extends StatefulWidget {
  const CloudLoginScreen({super.key});
  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

enum _Mode { signIn, signUp, recover }

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  _Mode mode = _Mode.signIn;
  String? message;
  bool error = false;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    setState(() {
      busy = true;
      message = null;
    });
    final result = switch (mode) {
      _Mode.signIn => await state.cloudSignIn(email.text, password.text),
      _Mode.signUp => await state.cloudSignUp(name.text, email.text, password.text),
      _Mode.recover => await state.cloudRecover(email.text),
    };
    if (!mounted) return;
    setState(() {
      busy = false;
      if (mode == _Mode.recover && result == null) {
        message = 'Enviamos um link para redefinir a senha. Confira seu e-mail.';
        error = false;
      } else {
        message = result;
        error = result != null && !result.startsWith('Conta criada');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    InputDecoration d(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder());
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
                    const SizedBox(height: 10),
                    const Text(
                      'ARCO Analytics',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'Dado. Contexto. Insight. Decisão.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<_Mode>(
                      segments: const [
                        ButtonSegment(value: _Mode.signIn, label: Text('Entrar')),
                        ButtonSegment(value: _Mode.signUp, label: Text('Criar conta')),
                      ],
                      selected: {mode == _Mode.recover ? _Mode.signIn : mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => setState(() {
                        mode = v.first;
                        message = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (mode == _Mode.signUp) ...[
                      TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: d('Nome completo', Icons.person_outline)),
                      const SizedBox(height: 12),
                    ],
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: d('E-mail', Icons.alternate_email)),
                    if (mode != _Mode.recover) ...[
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true, decoration: d('Senha', Icons.lock_outline), onSubmitted: (_) => _submit(state)),
                    ],
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(message!, style: TextStyle(color: error ? Colors.redAccent : Colors.greenAccent)),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : () => _submit(state),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(switch (mode) {
                                _Mode.signIn => 'Entrar',
                                _Mode.signUp => 'Criar conta',
                                _Mode.recover => 'Enviar link de recuperação',
                              }),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        mode = mode == _Mode.recover ? _Mode.signIn : _Mode.recover;
                        message = null;
                      }),
                      child: Text(mode == _Mode.recover ? 'Voltar para o login' : 'Esqueci a senha'),
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
