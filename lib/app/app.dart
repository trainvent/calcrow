import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/data/di/service_locator.dart';
import '../core/data/services/auth_service.dart';
import '../core/data/services/purchases_service.dart';
import 'presentation/marketing_landing_page.dart';
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
  StreamSubscription<AuthSession?>? _authSubscription;
  StreamSubscription<EntitlementTier>? _entitlementSubscription;
  String? _currentRevenueCatUid;

  @override
  void initState() {
    super.initState();
    if (!ServiceLocator.isSetup) {
      return;
    }
    _currentRevenueCatUid = ServiceLocator.authService.currentSession?.uid;
    _authSubscription = ServiceLocator.authService.authStateChanges().listen((
      session,
    ) async {
      _currentRevenueCatUid = session?.uid;
      await PurchasesService.instance.syncAppUser(session?.uid);
      await PurchasesService.instance.refreshCustomerInfo();
    });
    _entitlementSubscription = PurchasesService.instance.entitlementStream.listen((
      tier,
    ) async {
      final uid = _currentRevenueCatUid;
      if (uid == null) return;
      await ServiceLocator.userRepository.setIsPro(
        uid: uid,
        isPro: tier == EntitlementTier.pro,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _entitlementSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showMarketingLanding()) {
      return MaterialApp(
        title: 'Calcrow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MarketingLandingPage(),
      );
    }

    if (!ServiceLocator.isSetup) {
      return MaterialApp(
        title: 'Calcrow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _AppEntry(
          didCompleteOnboarding: _didCompleteOnboarding,
          onCompleteOnboarding: _completeOnboarding,
        ),
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
          home: _AppEntry(
            isSignedIn: isSignedIn,
            didCompleteOnboarding: _didCompleteOnboarding,
            onCompleteOnboarding: _completeOnboarding,
          ),
        );
      },
    );
  }

  bool _showMarketingLanding() {
    if (!kIsWeb) return false;
    final path = Uri.base.path.trim();
    return path.isEmpty || path == '/';
  }

  void _completeOnboarding() {
    setState(() {
      _didCompleteOnboarding = true;
    });
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry({
    required this.didCompleteOnboarding,
    required this.onCompleteOnboarding,
    this.isSignedIn = false,
  });

  final bool isSignedIn;
  final bool didCompleteOnboarding;
  final VoidCallback onCompleteOnboarding;

  @override
  Widget build(BuildContext context) {
    if (isSignedIn || didCompleteOnboarding) {
      return const HomeShell();
    }
    return OnboardingScreen(onComplete: onCompleteOnboarding);
  }
}
