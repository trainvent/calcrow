import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:trainvent_general/trainvent_general.dart';

class MonetizationChoiceScreen extends StatelessWidget {
  const MonetizationChoiceScreen({
    super.key,
    required this.isBusy,
    required this.onChoosePro,
    required this.onContinueWithAds,
    this.errorMessage,
  });

  final bool isBusy;
  final VoidCallback onChoosePro;
  final VoidCallback onContinueWithAds;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.chooseHowToContinue,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.chooseProOrAdsDescription,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: isBusy ? null : onChoosePro,
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: Text(context.l10n.explorePro),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : onContinueWithAds,
                        icon: const Icon(Icons.ad_units_outlined),
                        label: Text(context.l10n.continueWithAds),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.adPrivacyChoiceDoesNotLimitAppAccess,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      if (isBusy) ...[
                        const SizedBox(height: 20),
                        const Center(child: TriangleLoadingIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdConsentRequiredScreen extends StatelessWidget {
  const AdConsentRequiredScreen({
    super.key,
    required this.isBusy,
    required this.onReviewAdChoices,
    required this.onChoosePro,
    this.errorMessage,
  });

  final bool isBusy;
  final VoidCallback onReviewAdChoices;
  final VoidCallback onChoosePro;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.adChoicesRequiredForFreeMode,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context
                            .l10n
                            .enableNecessaryAdChoicesOrChooseProDescription,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: isBusy ? null : onReviewAdChoices,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(context.l10n.reviewAdChoices),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : onChoosePro,
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: Text(context.l10n.explorePro),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      if (isBusy) ...[
                        const SizedBox(height: 20),
                        const Center(child: TriangleLoadingIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
