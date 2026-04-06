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
        home: _AdsConsentHost(
          enabled: !_showMarketingLanding(),
          child: _DiagnosticsConsentHost(
            enabled: !_showMarketingLanding(),
            child: _AppEntry(
              didCompleteOnboarding: _didCompleteOnboarding,
              onCompleteOnboarding: _completeOnboarding,
            ),
          ),
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
          home: _AdsConsentHost(
            enabled: !_showMarketingLanding(),
            child: _DiagnosticsConsentHost(
              enabled: !_showMarketingLanding(),
              child: _AppEntry(
                isSignedIn: isSignedIn,
                didCompleteOnboarding: _didCompleteOnboarding,
                onCompleteOnboarding: _completeOnboarding,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _showMarketingLanding() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    final path = uri.path.trim();
    final wantsApp = uri.queryParameters['app'] == '1' || uri.fragment == '/app';
    if (wantsApp) return false;
    return path.isEmpty || path == '/';
  }

  void _completeOnboarding() {
    setState(() {
      _didCompleteOnboarding = true;
    });
  }
}

class _AdsConsentHost extends StatefulWidget {
  const _AdsConsentHost({
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<_AdsConsentHost> createState() => _AdsConsentHostState();
}

class _AdsConsentHostState extends State<_AdsConsentHost> {
  bool _hasChecked = false;
  bool _isRefreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRefreshAdsConsent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _maybeRefreshAdsConsent() async {
    if (!mounted || !widget.enabled || !ServiceLocator.isSetup) return;
    if (_hasChecked || _isRefreshing) return;

    final adsConsent = ServiceLocator.adsConsentService;
    if (!adsConsent.isSupported) {
      _hasChecked = true;
      return;
    }

    _hasChecked = true;
    _isRefreshing = true;
    try {
      await adsConsent.refreshConsentInfo();
    } catch (_) {
      // Keep app startup resilient if UMP is unavailable.
    } finally {
      _isRefreshing = false;
    }
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

class _DiagnosticsConsentHost extends StatefulWidget {
  const _DiagnosticsConsentHost({
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  State<_DiagnosticsConsentHost> createState() => _DiagnosticsConsentHostState();
}

class _DiagnosticsConsentHostState extends State<_DiagnosticsConsentHost> {
  bool _hasChecked = false;
  bool _isShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowDiagnosticsConsent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _maybeShowDiagnosticsConsent() async {
    if (!mounted || !widget.enabled || !ServiceLocator.isSetup) return;
    if (_hasChecked || _isShowing) return;

    final diagnostics = ServiceLocator.diagnosticsService;
    if (!diagnostics.needsConsentPrompt) {
      _hasChecked = true;
      return;
    }

    _hasChecked = true;
    _isShowing = true;

    final result = await showModalBottomSheet<_DiagnosticsConsentResult>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _DiagnosticsConsentSheet(),
    );

    _isShowing = false;
    if (result == null) return;

    await diagnostics.saveConsentChoices(
      usageAnalyticsEnabled: result.usageAnalyticsEnabled,
      crashReportsEnabled: result.crashReportsEnabled,
    );
  }
}

class _DiagnosticsConsentSheet extends StatefulWidget {
  const _DiagnosticsConsentSheet();

  @override
  State<_DiagnosticsConsentSheet> createState() =>
      _DiagnosticsConsentSheetState();
}

class _DiagnosticsConsentSheetState extends State<_DiagnosticsConsentSheet> {
  bool _usageAnalyticsEnabled = false;
  bool _crashReportsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final diagnostics = ServiceLocator.diagnosticsService;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help Improve Calcrow',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics. You can change both later in Settings.',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.insights_outlined),
              title: const Text('Usage analytics'),
              subtitle: const Text(
                'Anonymous usage patterns to understand which screens and flows are used.',
              ),
              value: _usageAnalyticsEnabled,
              onChanged: diagnostics.supportsUsageAnalytics
                  ? (value) {
                      setState(() {
                        _usageAnalyticsEnabled = value;
                      });
                    }
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Crash reports and performance'),
              subtitle: const Text(
                'Crash logs, non-fatal errors, and performance monitoring to diagnose failures and slow paths.',
              ),
              value: _crashReportsEnabled,
              onChanged: diagnostics.supportsCrashReports
                  ? (value) {
                      setState(() {
                        _crashReportsEnabled = value;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        const _DiagnosticsConsentResult(
                          usageAnalyticsEnabled: false,
                          crashReportsEnabled: false,
                        ),
                      );
                    },
                    child: const Text('Keep Off'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _DiagnosticsConsentResult(
                          usageAnalyticsEnabled: _usageAnalyticsEnabled,
                          crashReportsEnabled: _crashReportsEnabled,
                        ),
                      );
                    },
                    child: const Text('Save Choices'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsConsentResult {
  const _DiagnosticsConsentResult({
    required this.usageAnalyticsEnabled,
    required this.crashReportsEnabled,
  });

  final bool usageAnalyticsEnabled;
  final bool crashReportsEnabled;
}
