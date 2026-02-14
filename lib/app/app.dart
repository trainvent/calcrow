import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: 'Calcrow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _didCompleteOnboarding
          ? const HomeShell()
          : OnboardingScreen(onComplete: _completeOnboarding),
    );
  }

  void _completeOnboarding() {
    setState(() {
      _didCompleteOnboarding = true;
    });
  }
}
