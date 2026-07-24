import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/di/service_locator.dart';
import '../core/data/services/user_repository.dart';
import '../core/providers/app_providers.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'presentation/marketing_landing_page.dart';
import '../core/theme/app_theme.dart';

class CalcrowApp extends ConsumerWidget {
  const CalcrowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ServiceLocator.isSetup) {
      ref.watch(appServiceCoordinatorProvider);
    }
    return _buildForLocale(ref.watch(effectiveLocaleProvider));
  }

  Widget _buildForLocale(Locale? locale) {
    if (_showMarketingLanding()) {
      return MaterialApp(
        locale: locale,
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
        locale: locale,
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

    return _buildMaterialApp(locale: locale, child: const _AuthGate());
  }

  Widget _buildMaterialApp({required Locale? locale, required Widget child}) {
    return MaterialApp(
      locale: locale,
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

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(authSessionProvider);
    final session = sessionState.asData?.value;
    if (sessionState.isLoading && session == null) {
      return const Scaffold();
    }
    if (session == null) {
      return const _AppEntry(isSignedIn: false);
    }
    if (session.emailVerified) {
      return const _AppEntry(isSignedIn: true);
    }

    final verificationState = ref.watch(emailVerifiedProvider(session.uid));
    if (verificationState.isLoading) {
      return const Scaffold();
    }
    return _AppEntry(isSignedIn: verificationState.asData?.value ?? false);
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

class _AdsConsentHost extends ConsumerStatefulWidget {
  const _AdsConsentHost({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<_AdsConsentHost> createState() => _AdsConsentHostState();
}

class _AdsConsentHostState extends ConsumerState<_AdsConsentHost> {
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

    final adsConsent = ref.read(adsConsentServiceProvider);
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

class _DiagnosticsConsentHost extends ConsumerStatefulWidget {
  const _DiagnosticsConsentHost({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<_DiagnosticsConsentHost> createState() =>
      _DiagnosticsConsentHostState();
}

class _DiagnosticsConsentHostState
    extends ConsumerState<_DiagnosticsConsentHost> {
  bool _hasChecked = false;
  bool _isChecking = false;
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
    ref.listen(authSessionProvider, (previous, next) {
      if (next.asData?.value == null) return;
      _hasChecked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowDiagnosticsConsent();
      });
    });
    return widget.child;
  }

  Future<void> _maybeShowDiagnosticsConsent() async {
    if (!mounted || !widget.enabled || !ServiceLocator.isSetup) return;
    if (_hasChecked || _isChecking || _isShowing) return;

    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;

    _isChecking = true;
    final diagnostics = ref.read(diagnosticsServiceProvider);
    try {
      await diagnostics.init();
      if (!mounted) return;

      UserSettingsData settings;
      try {
        settings = await ref
            .read(userRepositoryProvider)
            .getUserSettings(session.uid);
      } catch (_) {
        // Never ask again merely because the profile could not be reached.
        _hasChecked = true;
        return;
      }
      if (!mounted) return;

      if (settings.diagnosticsConsentCompleted) {
        await diagnostics.saveConsentChoices(
          usageAnalyticsEnabled: settings.usageAnalyticsEnabled,
          crashReportsEnabled: settings.crashReportsEnabled,
        );
        await diagnostics.associateConsentWithUser(session.uid);
        _hasChecked = true;
        return;
      }

      if (diagnostics.hasConsentForUser(session.uid)) {
        _hasChecked = true;
        await diagnostics.associateConsentWithUser(session.uid);
        try {
          await ref
              .read(userRepositoryProvider)
              .saveDiagnosticsConsent(
                uid: session.uid,
                usageAnalyticsEnabled: diagnostics.usageAnalyticsEnabled,
                crashReportsEnabled: diagnostics.crashReportsEnabled,
              );
        } catch (_) {
          // Keep the local choice and retry profile migration next launch.
        }
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
      await diagnostics.associateConsentWithUser(session.uid);
      try {
        await ref
            .read(userRepositoryProvider)
            .saveDiagnosticsConsent(
              uid: session.uid,
              usageAnalyticsEnabled: result.usageAnalyticsEnabled,
              crashReportsEnabled: result.crashReportsEnabled,
            );
      } catch (_) {
        // The local completion flag still prevents a repeated prompt.
      }
    } finally {
      _isChecking = false;
      _isShowing = false;
    }
  }
}

class _DiagnosticsConsentSheet extends ConsumerStatefulWidget {
  const _DiagnosticsConsentSheet();

  @override
  ConsumerState<_DiagnosticsConsentSheet> createState() =>
      _DiagnosticsConsentSheetState();
}

class _DiagnosticsConsentSheetState
    extends ConsumerState<_DiagnosticsConsentSheet> {
  bool _usageAnalyticsEnabled = false;
  bool _crashReportsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final diagnostics = ref.read(diagnosticsServiceProvider);
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
