import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../../app/presentation/web_link_opener_stub.dart'
    if (dart.library.html) '../../../../../app/presentation/web_link_opener_web.dart';
import '../../../../../core/constants/internal_constants.dart';
import '../../../../../core/data/di/service_locator.dart';
import '../../../../../core/data/services/purchases_service.dart';

class DataCollectionPage extends StatefulWidget {
  const DataCollectionPage({super.key});

  @override
  State<DataCollectionPage> createState() => _DataCollectionPageState();
}

class _DataCollectionPageState extends State<DataCollectionPage> {
  bool _isUpdatingAnalytics = false;
  bool _isUpdatingCrashReports = false;
  bool _isOpeningAdsPrivacyChoices = false;
  bool _isOpeningAdsPolicy = false;
  bool _isResettingAdsConsent = false;

  @override
  Widget build(BuildContext context) {
    final adsConsent = ServiceLocator.adsConsentService;
    final diagnostics = ServiceLocator.diagnosticsService;
    final theme = Theme.of(context);

    return StreamBuilder<EntitlementTier>(
      stream: ServiceLocator.purchasesService.entitlementStream,
      initialData: ServiceLocator.purchasesService.currentTier,
      builder: (context, snapshot) {
        final isPro =
            (snapshot.data ?? EntitlementTier.free) == EntitlementTier.pro;

        return Scaffold(
          appBar: AppBar(title: const Text('Data Collection')),
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
                        'Privacy controls',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPro
                            ? 'Choose separately whether Calcrow may collect anonymous usage analytics and technical crash or performance diagnostics.'
                            : 'Choose separately whether Calcrow may collect anonymous usage analytics, technical crash or performance diagnostics, and ad privacy preferences where supported.',
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
                          'Manage your Google ad privacy choices. This entry point must stay available after consent is collected.',
                        PrivacyOptionsRequirementStatus.notRequired =>
                          'Google does not currently require a persistent ad privacy options button on this device or region.',
                        PrivacyOptionsRequirementStatus.unknown =>
                          'Refresh ad privacy choices and review the latest Google consent options for this device.',
                      };

                      return ListTile(
                        leading: const Icon(Icons.gpp_maybe_outlined),
                        title: const Text('Ads privacy choices'),
                        subtitle: Text(subtitle),
                        trailing: _isOpeningAdsPrivacyChoices
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
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
                        title: const Text('Reset ad consent'),
                        subtitle: Text(
                          canRequestAds
                              ? 'Clear the current AdMob consent state on this device. Ads stay disabled until Google collects consent again.'
                              : 'Clear any stored AdMob consent state on this device and force the Google consent flow to ask again later.',
                        ),
                        trailing: _isResettingAdsConsent
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
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
                    title: const Text('Ads privacy policy'),
                    subtitle: const Text(
                      'Read how Calcrow and Google AdMob handle consent choices for the EEA, UK, Switzerland, and applicable US state privacy rules.',
                    ),
                    trailing: _isOpeningAdsPolicy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                      title: const Text('Usage analytics'),
                      subtitle: Text(
                        diagnostics.supportsUsageAnalytics
                            ? 'Collect anonymous usage patterns to understand which screens and flows are used.'
                            : 'Usage analytics are not available on this platform.',
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
                      title: const Text('Crash reports and performance'),
                      subtitle: Text(
                        diagnostics.supportsCrashReports
                            ? 'Send crash logs, non-fatal errors, and performance monitoring data to help analyze app failures and slow paths.'
                            : 'Crash reporting and performance monitoring are only available on supported mobile builds.',
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
                    children: const [
                      Text(
                        'Current behavior',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Both categories stay off until you explicitly enable them here. You can turn them off again at any time.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setUsageAnalyticsEnabled(bool enabled) async {
    if (_isUpdatingAnalytics) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingAnalytics = true);
    try {
      await ServiceLocator.diagnosticsService.setUsageAnalyticsEnabled(enabled);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Usage analytics enabled.' : 'Usage analytics disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update usage analytics: $error')),
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
      await ServiceLocator.diagnosticsService.setCrashReportsEnabled(enabled);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Crash reporting and performance monitoring enabled.'
                : 'Crash reporting and performance monitoring disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update crash reporting: $error')),
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
      await ServiceLocator.adsConsentService.refreshConsentInfo(
        showFormIfAvailable: false,
      );
      await ServiceLocator.adsConsentService.showPrivacyOptionsForm();
      if (!mounted) return;
      final message = ServiceLocator.adsConsentService.lastErrorMessage;
      if (message == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ad privacy choices updated.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open ad privacy choices: $message'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not refresh ad privacy choices: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningAdsPrivacyChoices = false);
      }
    }
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
              'Could not open ads privacy policy. Visit ${IConst.privacyPolicyAdsUrl} in a browser.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open ads privacy policy: $error')),
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
        title: const Text('Reset ad consent?'),
        content: const Text(
          'This clears the current Google AdMob consent state on this device. The next consent refresh may ask again before ads can be requested.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResettingAdsConsent = true);
    try {
      await ServiceLocator.adsConsentService.resetConsent();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Ad consent reset on this device.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not reset ad consent: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingAdsConsent = false);
      }
    }
  }
}
