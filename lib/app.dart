import 'package:flutter/material.dart';
import 'package:arco_analytics/presentation/screens/login_screen.dart';
import 'package:arco_analytics/presentation/screens/onboarding_screen.dart';
import 'package:arco_analytics/presentation/screens/root_shell.dart';
import 'package:arco_analytics/state/app_state.dart';
import 'package:arco_analytics/presentation/theme/arco_theme.dart';

class ArcoApp extends StatefulWidget {
  const ArcoApp({super.key});

  @override
  State<ArcoApp> createState() => _ArcoAppState();
}

class _ArcoAppState extends State<ArcoApp> {
  final AppState state = AppState();

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ARCO Analytics',
          theme: ArcoTheme.dark,
          home: !state.ready
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : !state.loggedIn
              ? const LoginScreen()
              : state.cloud.enabled && state.cloud.club == null
              ? const OnboardingScreen()
              : const RootShell(),
        ),
      ),
    );
  }
}
