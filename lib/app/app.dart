import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/data/di/service_locator.dart';
import '../core/data/services/auth_service.dart';
import '../core/data/services/purchases_service.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'presentation/marketing_landing_page.dart';
import 'theme/app_theme.dart';

class CalcrowApp extends StatefulWidget {
  const CalcrowApp({super.key});

  @override
  State<CalcrowApp> createState() => _CalcrowAppState();
}

class _CalcrowAppState extends State<CalcrowApp> {
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
      await PurchasesService.instance.syncAppUser(
        session?.uid,
        email: session?.email,
      );
      await PurchasesService.instance.refreshCustomerInfo();
    });
    _entitlementSubscription = PurchasesService.instance.entitlementStream
        .listen((tier) async {
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
        onGenerateTitle: (context) => context.l10n.calcrow,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _WebSelectionHost(child: const MarketingLandingPage()),
      );
    }

    if (!ServiceLocator.isSetup) {
      return MaterialApp(
        onGenerateTitle: (context) => context.l10n.calcrow,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _AdsConsentHost(
          enabled: !_showMarketingLanding(),
          child: _WebSelectionHost(
            child: _DiagnosticsConsentHost(
              enabled: !_showMarketingLanding(),
              child: _AppEntry(isSignedIn: false),
            ),
          ),
        ),
      );
    }

    return _buildMaterialApp(child: const _AuthGate());
  }

  Widget _buildMaterialApp({required Widget child}) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.calcrow,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _AdsConsentHost(
        enabled: !_showMarketingLanding(),
        child: _WebSelectionHost(
          child: _DiagnosticsConsentHost(
            enabled: !_showMarketingLanding(),
            child: child,
          ),
        ),
      ),
    );
  }

  static const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  bool _showMarketingLanding() {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    final path = uri.path.trim();
    final wantsApp =
        uri.queryParameters['app'] == '1' || uri.fragment == '/app';
    if (wantsApp) return false;
    return path.isEmpty || path == '/';
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: ServiceLocator.authService.authStateChanges(),
      initialData: ServiceLocator.authService.currentSession,
      builder: (context, snapshot) {
        final session = snapshot.data;
        if (session == null) {
          return const _AppEntry(isSignedIn: false);
        }
        if (session.emailVerified) {
          return const _AppEntry(isSignedIn: true);
        }

        return StreamBuilder<bool>(
          stream: ServiceLocator.dbService.watchUserEmailVerified(session.uid),
          initialData: false,
          builder: (context, verificationSnapshot) {
            final isSignedIn = verificationSnapshot.data ?? false;
            return _AppEntry(isSignedIn: isSignedIn);
          },
        );
      },
    );
  }
}

class _WebSelectionHost extends StatelessWidget {
  const _WebSelectionHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return SelectionArea(child: child);
  }
}

class _AdsConsentHost extends StatefulWidget {
  const _AdsConsentHost({required this.child, required this.enabled});

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
  const _AppEntry({required this.isSignedIn});

  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    if (isSignedIn) {
      return const HomeShell();
    }
    return const OnboardingScreen();
  }
}

class _DiagnosticsConsentHost extends StatefulWidget {
  const _DiagnosticsConsentHost({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_DiagnosticsConsentHost> createState() =>
      _DiagnosticsConsentHostState();
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
              context.l10n.helpImproveCalcrow,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context
                  .l10n
                  .chooseWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnosticsYouCanChangeBothLaterInSettings,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.insights_outlined),
              title: Text(context.l10n.usageAnalytics),
              subtitle: Text(
                context
                    .l10n
                    .anonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed,
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
              title: Text(context.l10n.crashReportsAndPerformance),
              subtitle: Text(
                context
                    .l10n
                    .crashLogsNonFatalErrorsAndPerformanceMonitoringToDiagnoseFailuresAndSlowPaths,
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
                    child: Text(context.l10n.keepOff),
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
                    child: Text(context.l10n.saveChoices),
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
