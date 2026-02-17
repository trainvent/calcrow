import 'package:flutter/material.dart';

import '../core/data/di/service_locator.dart';
import '../core/data/services/auth_service.dart';
import 'theme/app_theme.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class CalcrowApp extends StatefulWidget {
  const CalcrowApp({super.key});

  @override
  State<CalcrowApp> createState() => _CalcrowAppState();
}

class _CalcrowAppState extends State<CalcrowApp> {
  bool _didCompleteOnboarding = false;

  @override
  Widget build(BuildContext context) {
    if (!ServiceLocator.isSetup) {
      return MaterialApp(
        title: 'Calcrow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _didCompleteOnboarding
            ? const HomeShell()
            : OnboardingScreen(onComplete: _completeOnboarding),
      );
    }

    return StreamBuilder<AuthSession?>(
      stream: ServiceLocator.authService.authStateChanges(),
      initialData: ServiceLocator.authService.currentSession,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data != null;
        return MaterialApp(
          title: 'Calcrow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: (isSignedIn || _didCompleteOnboarding)
              ? const HomeShell()
              : OnboardingScreen(onComplete: _completeOnboarding),
        );
      },
    );
  }

  void _completeOnboarding() {
    setState(() {
      _didCompleteOnboarding = true;
    });
  }
}
