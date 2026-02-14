import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class CsvrowApp extends StatefulWidget {
  const CsvrowApp({super.key});

  @override
  State<CsvrowApp> createState() => _CsvrowAppState();
}

class _CsvrowAppState extends State<CsvrowApp> {
  bool _didCompleteOnboarding = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSVrow',
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
