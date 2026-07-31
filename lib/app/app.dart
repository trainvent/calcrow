import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/di/service_locator.dart';
import '../core/data/services/monetization_choice_service.dart';
import '../core/data/services/purchases_service.dart';
import '../core/data/services/user_repository.dart';
import '../core/providers/app_providers.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'presentation/marketing_landing_page.dart';
import 'presentation/monetization_choice_screen.dart';
import '../core/theme/app_theme.dart';

class CalcrowApp extends ConsumerWidget {
  const CalcrowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ServiceLocator.isSetup) {
      ref.watch(appServiceCoordinatorProvider);
    }
    return _buildForLocale(
      ref.watch(effectiveLocaleProvider),
      ref.watch(effectiveThemeModeProvider),
    );
  }

  Widget _buildForLocale(Locale? locale, ThemeMode themeMode) {
    if (_showMarketingLanding()) {
      return MaterialApp(
        locale: locale,
        onGenerateTitle: (context) => context.l10n.calcrow,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
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
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: _WebSelectionHost(child: const _AppEntry(isSignedIn: false)),
      );
    }

    return _buildMaterialApp(
      locale: locale,
      themeMode: themeMode,
      child: const _AuthGate(),
    );
  }

  Widget _buildMaterialApp({
    required Locale? locale,
    required ThemeMode themeMode,
    required Widget child,
  }) {
    return MaterialApp(
      locale: locale,
      onGenerateTitle: (context) => context.l10n.calcrow,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: _WebSelectionHost(child: child),
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
      return _PostAuthMonetizationGate(
        uid: session.uid,
        email: session.email,
        child: const _DiagnosticsConsentHost(
          enabled: true,
          child: _AppEntry(isSignedIn: true),
        ),
      );
    }

    final verificationState = ref.watch(emailVerifiedProvider(session.uid));
    if (verificationState.isLoading) {
      return const Scaffold();
    }
    if (verificationState.asData?.value != true) {
      return const _AppEntry(isSignedIn: false);
    }
    return _PostAuthMonetizationGate(
      uid: session.uid,
      email: session.email,
      child: const _DiagnosticsConsentHost(
        enabled: true,
        child: _AppEntry(isSignedIn: true),
      ),
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

class _PostAuthMonetizationGate extends ConsumerStatefulWidget {
  const _PostAuthMonetizationGate({
    required this.uid,
    required this.email,
    required this.child,
  });

  final String uid;
  final String email;
  final Widget child;

  @override
  ConsumerState<_PostAuthMonetizationGate> createState() =>
      _PostAuthMonetizationGateState();
}

class _PostAuthMonetizationGateState
    extends ConsumerState<_PostAuthMonetizationGate> {
  bool _isLoadingLocalChoice = true;
  bool _hasLocalAdsChoice = false;
  bool _isHandlingChoice = false;
  bool _hasScheduledConsentRefresh = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocalChoice();
  }

  @override
  void didUpdateWidget(_PostAuthMonetizationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid == widget.uid) return;
    _isLoadingLocalChoice = true;
    _hasLocalAdsChoice = false;
    _isHandlingChoice = false;
    _hasScheduledConsentRefresh = false;
    _errorMessage = null;
    _loadLocalChoice();
  }

  @override
  Widget build(BuildContext context) {
    final adsConsent = ref.watch(adsConsentServiceProvider);
    if (!adsConsent.isSupported) return widget.child;

    final purchases = ref.watch(purchasesServiceProvider);
    final tier =
        ref.watch(entitlementTierProvider).asData?.value ??
        purchases.currentTier;
    final remoteSettings = ref.watch(userSettingsProvider(widget.uid));

    return ValueListenableBuilder<bool>(
      valueListenable: purchases.isReadyListenable,
      builder: (context, purchasesReady, _) {
        if (_isLoadingLocalChoice || !purchasesReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (tier == EntitlementTier.pro) return widget.child;

        final remoteChoice = remoteSettings.asData?.value.monetizationChoice;
        final choseAds =
            _hasLocalAdsChoice || remoteChoice == MonetizationChoice.ads;
        if (choseAds) {
          if (!_hasLocalAdsChoice) {
            _hasLocalAdsChoice = true;
            unawaited(
              MonetizationChoiceService.save(
                widget.uid,
                MonetizationChoice.ads,
              ),
            );
          }
          _scheduleConsentRefresh();
          return widget.child;
        }

        return MonetizationChoiceScreen(
          isBusy: _isHandlingChoice,
          errorMessage: _errorMessage,
          onChoosePro: _choosePro,
          onContinueWithAds: _continueWithAds,
        );
      },
    );
  }

  Future<void> _loadLocalChoice() async {
    final choice = await MonetizationChoiceService.read(widget.uid);
    if (!mounted) return;
    setState(() {
      _hasLocalAdsChoice = choice == MonetizationChoice.ads;
      _isLoadingLocalChoice = false;
    });
  }

  Future<void> _choosePro() async {
    if (_isHandlingChoice) return;
    setState(() {
      _isHandlingChoice = true;
      _errorMessage = null;
    });
    final purchases = ref.read(purchasesServiceProvider);
    try {
      await purchases.syncAppUser(widget.uid, email: widget.email);
      await purchases.presentPaywall();
      await purchases.refreshCustomerInfo();
      if (mounted) setState(() {});
    } on PurchasesServiceException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.localizedMessage(context.l10n));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              context.l10n.purchasesAreUnavailableRightNowPleaseTryAgainLater,
        );
      }
    } finally {
      if (mounted) setState(() => _isHandlingChoice = false);
    }
  }

  Future<void> _continueWithAds() async {
    if (_isHandlingChoice) return;
    setState(() {
      _isHandlingChoice = true;
      _errorMessage = null;
    });
    try {
      await MonetizationChoiceService.save(widget.uid, MonetizationChoice.ads);
      try {
        await ref
            .read(userRepositoryProvider)
            .setMonetizationChoice(
              uid: widget.uid,
              choice: MonetizationChoice.ads,
            );
      } catch (_) {
        // The device choice remains valid while account sync is unavailable.
      }

      _hasScheduledConsentRefresh = true;
      final adsConsent = ref.read(adsConsentServiceProvider);
      await adsConsent.init();
      try {
        await adsConsent.refreshConsentInfo();
      } catch (_) {
        // The app remains available; ads stay off until consent can refresh.
      }
      if (mounted) setState(() => _hasLocalAdsChoice = true);
    } finally {
      if (mounted) setState(() => _isHandlingChoice = false);
    }
  }

  void _scheduleConsentRefresh() {
    if (_hasScheduledConsentRefresh) return;
    _hasScheduledConsentRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final adsConsent = ref.read(adsConsentServiceProvider);
      await adsConsent.init();
      try {
        await adsConsent.refreshConsentInfo();
      } catch (_) {
        // Consent failures keep ads disabled without blocking the app.
      }
    });
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
    final session = ref.watch(authSessionProvider).asData?.value;
    final isVerified =
        session != null &&
        (session.emailVerified ||
            (ref.watch(emailVerifiedProvider(session.uid)).asData?.value ??
                false));

    ref.listen(authSessionProvider, (previous, next) {
      final previousUid = previous?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;
      if (previousUid == nextUid) return;
      _hasChecked = false;
      if (nextUid == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowDiagnosticsConsent();
      });
    });

    if (session != null && isVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowDiagnosticsConsent();
      });
    }
    return widget.child;
  }

  Future<void> _maybeShowDiagnosticsConsent() async {
    if (!mounted || !widget.enabled || !ServiceLocator.isSetup) return;
    if (_hasChecked || _isChecking || _isShowing) return;

    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;
    final isVerified =
        session.emailVerified ||
        (ref.read(emailVerifiedProvider(session.uid)).asData?.value ?? false);
    if (!isVerified) return;

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
