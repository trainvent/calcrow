import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:trainvent_general/trainvent_general.dart';

import 'package:calcrow/app/presentation/web_link_opener_stub.dart'
    if (dart.library.html) 'package:calcrow/app/presentation/web_link_opener_web.dart';
import 'package:calcrow/core/constants/internal_constants.dart';
import 'package:calcrow/core/data/services/purchases_service.dart';
import 'package:calcrow/core/providers/app_providers.dart';

class DataCollectionPage extends ConsumerStatefulWidget {
  const DataCollectionPage({super.key});

  @override
  ConsumerState<DataCollectionPage> createState() => _DataCollectionPageState();
}

class _DataCollectionPageState extends ConsumerState<DataCollectionPage> {
  bool _isUpdatingAnalytics = false;
  bool _isUpdatingCrashReports = false;
  bool _isOpeningAdsPrivacyChoices = false;
  bool _isOpeningAdsPolicy = false;
  bool _isResettingAdsConsent = false;

  @override
  Widget build(BuildContext context) {
    final adsConsent = ref.read(adsConsentServiceProvider);
    final diagnostics = ref.read(diagnosticsServiceProvider);
    final theme = Theme.of(context);
    final tier =
        ref.watch(entitlementTierProvider).asData?.value ??
        ref.read(purchasesServiceProvider).currentTier;
    final isPro = tier == EntitlementTier.pro;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dataCollection)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.privacyControls,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPro
                        ? context
                              .l10n
                              .chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsAndTechnicalCrashOrPerformanceDiagnostics
                        : context
                              .l10n
                              .chooseSeparatelyWhetherCalcrowMayCollectAnonymousUsageAnalyticsTechnicalCrashOrPerformanceDiagnosticsAndAdPrivacyPreferencesWhereSupported,
                  ),
                ],
              ),
            ),
          ),
          if (!isPro && adsConsent.isSupported) ...[
            const SizedBox(height: 12),
            Card(
              child: ValueListenableBuilder<PrivacyOptionsRequirementStatus>(
                valueListenable:
                    adsConsent.privacyOptionsRequirementStatusListenable,
                builder: (context, status, _) {
                  final isRequired =
                      status == PrivacyOptionsRequirementStatus.required;
                  final subtitle = switch (status) {
                    PrivacyOptionsRequirementStatus.required =>
                      context
                          .l10n
                          .manageYourGoogleAdPrivacyChoicesThisEntryPointMustStayAvailableAfterConsentIsCollected,
                    PrivacyOptionsRequirementStatus.notRequired =>
                      context
                          .l10n
                          .googleDoesNotCurrentlyRequireAPersistentAdPrivacyOptionsButtonOnThisDeviceOrRegion,
                    PrivacyOptionsRequirementStatus.unknown =>
                      context
                          .l10n
                          .refreshAdPrivacyChoicesAndReviewTheLatestGoogleConsentOptionsForThisDevice,
                  };

                  return ListTile(
                    leading: const Icon(Icons.gpp_maybe_outlined),
                    title: Text(context.l10n.adsPrivacyChoices),
                    subtitle: Text(subtitle),
                    trailing: _isOpeningAdsPrivacyChoices
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: TriangleLoadingIndicator(
                              size: 18,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            isRequired
                                ? Icons.chevron_right_rounded
                                : Icons.refresh_rounded,
                          ),
                    onTap: _isOpeningAdsPrivacyChoices
                        ? null
                        : _openAdsPrivacyChoices,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ValueListenableBuilder<bool>(
                valueListenable: adsConsent.canRequestAdsListenable,
                builder: (context, canRequestAds, _) {
                  return ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(context.l10n.resetAdConsent),
                    subtitle: Text(
                      canRequestAds
                          ? context
                                .l10n
                                .clearTheCurrentAdMobConsentStateOnThisDeviceAdsStayDisabledUntilGoogleCollectsConsentAgain
                          : context
                                .l10n
                                .clearAnyStoredAdMobConsentStateOnThisDeviceAndForceTheGoogleConsentFlowToAskAgainLater,
                    ),
                    trailing: _isResettingAdsConsent
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: TriangleLoadingIndicator(
                              size: 18,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.restart_alt_rounded),
                    onTap: _isResettingAdsConsent ? null : _resetAdsConsent,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(context.l10n.adsPrivacyPolicy),
                subtitle: Text(
                  context
                      .l10n
                      .readHowCalcrowAndGoogleAdMobHandleConsentChoicesForTheEEAUKSwitzerlandAndApplicableUSStatePrivacyRules,
                ),
                trailing: _isOpeningAdsPolicy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: TriangleLoadingIndicator(
                          size: 18,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                onTap: _isOpeningAdsPolicy ? null : _openAdsPrivacyPolicy,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: ValueListenableBuilder<bool>(
              valueListenable: diagnostics.usageAnalyticsEnabledListenable,
              builder: (context, enabled, _) {
                return SwitchListTile(
                  secondary: const Icon(Icons.insights_outlined),
                  title: Text(context.l10n.usageAnalytics),
                  subtitle: Text(
                    diagnostics.supportsUsageAnalytics
                        ? context
                              .l10n
                              .collectAnonymousUsagePatternsToUnderstandWhichScreensAndFlowsAreUsed
                        : context
                              .l10n
                              .usageAnalyticsAreNotAvailableOnThisPlatform,
                  ),
                  value: enabled,
                  onChanged:
                      !diagnostics.supportsUsageAnalytics ||
                          _isUpdatingAnalytics
                      ? null
                      : (value) => _setUsageAnalyticsEnabled(value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ValueListenableBuilder<bool>(
              valueListenable: diagnostics.crashReportsEnabledListenable,
              builder: (context, enabled, _) {
                return SwitchListTile(
                  secondary: const Icon(Icons.health_and_safety_outlined),
                  title: Text(context.l10n.crashReportsAndPerformance),
                  subtitle: Text(
                    diagnostics.supportsCrashReports
                        ? context
                              .l10n
                              .sendCrashLogsNonFatalErrorsAndPerformanceMonitoringDataToHelpAnalyzeAppFailuresAndSlowPaths
                        : context
                              .l10n
                              .crashReportingAndPerformanceMonitoringAreOnlyAvailableOnSupportedMobileBuilds,
                  ),
                  value: enabled,
                  onChanged:
                      !diagnostics.supportsCrashReports ||
                          _isUpdatingCrashReports
                      ? null
                      : (value) => _setCrashReportsEnabled(value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.currentBehavior,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    context
                        .l10n
                        .bothCategoriesStayOffUntilYouExplicitlyEnableThemHereYouCanTurnThemOffAgainAtAnyTime,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setUsageAnalyticsEnabled(bool enabled) async {
    if (_isUpdatingAnalytics) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingAnalytics = true);
    try {
      await ref
          .read(diagnosticsServiceProvider)
          .setUsageAnalyticsEnabled(enabled);
      await _saveDiagnosticsConsentToProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? context.l10n.usageAnalyticsEnabled
                : context.l10n.usageAnalyticsDisabled,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotUpdateUsageAnalytics('$error')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAnalytics = false);
      }
    }
  }

  Future<void> _setCrashReportsEnabled(bool enabled) async {
    if (_isUpdatingCrashReports) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingCrashReports = true);
    try {
      await ref
          .read(diagnosticsServiceProvider)
          .setCrashReportsEnabled(enabled);
      await _saveDiagnosticsConsentToProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? context.l10n.crashReportingAndPerformanceMonitoringEnabled
                : context.l10n.crashReportingAndPerformanceMonitoringDisabled,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotUpdateCrashReporting('$error')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCrashReports = false);
      }
    }
  }

  Future<void> _openAdsPrivacyChoices() async {
    if (_isOpeningAdsPrivacyChoices) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isOpeningAdsPrivacyChoices = true);
    try {
      await ref
          .read(adsConsentServiceProvider)
          .refreshConsentInfo(showFormIfAvailable: false);
      await ref.read(adsConsentServiceProvider).showPrivacyOptionsForm();
      if (!mounted) return;
      final message = ref.read(adsConsentServiceProvider).lastErrorMessage;
      if (message == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.adPrivacyChoicesUpdated)),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotOpenAdPrivacyChoices(message)),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotRefreshAdPrivacyChoices('$error')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningAdsPrivacyChoices = false);
      }
    }
  }

  Future<void> _saveDiagnosticsConsentToProfile() async {
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;
    final diagnostics = ref.read(diagnosticsServiceProvider);
    await diagnostics.associateConsentWithUser(session.uid);
    await ref
        .read(userRepositoryProvider)
        .saveDiagnosticsConsent(
          uid: session.uid,
          usageAnalyticsEnabled: diagnostics.usageAnalyticsEnabled,
          crashReportsEnabled: diagnostics.crashReportsEnabled,
        );
  }

  Future<void> _openAdsPrivacyPolicy() async {
    if (_isOpeningAdsPolicy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isOpeningAdsPolicy = true);
    try {
      final opened = await openExternalUrl(IConst.privacyPolicyAdsUrl);
      if (!mounted) return;
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldNotOpenAdsPrivacyPolicyVisit(
                IConst.privacyPolicyAdsUrl,
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotOpenAdsPrivacyPolicy('$error')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningAdsPolicy = false);
      }
    }
  }

  Future<void> _resetAdsConsent() async {
    if (_isResettingAdsConsent) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.resetAdConsent2),
        content: Text(
          context
              .l10n
              .thisClearsTheCurrentGoogleAdMobConsentStateOnThisDeviceTheNextConsentRefreshMayAskAgainBeforeAdsCanBeRequested,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResettingAdsConsent = true);
    try {
      await ref.read(adsConsentServiceProvider).resetConsent();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.adConsentResetOnThisDevice)),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotResetAdConsent('$error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingAdsConsent = false);
      }
    }
  }
}
