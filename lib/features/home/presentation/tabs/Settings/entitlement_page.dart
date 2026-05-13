import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/data/di/service_locator.dart';
import '../../../../../core/data/services/purchases_service.dart';
import '../../../../../core/data/services/user_repository.dart';

class EntitlementPage extends StatefulWidget {
  const EntitlementPage({super.key});

  @override
  State<EntitlementPage> createState() => _EntitlementPageState();
}

class _EntitlementPageState extends State<EntitlementPage> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final session = ServiceLocator.authService.currentSession;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Entitlement')),
      body: session == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sign in first to manage subscriptions.'),
              ),
            )
          : StreamBuilder<UserSettingsData>(
              stream: ServiceLocator.userRepository.watchUserSettings(session.uid),
              builder: (context, snapshot) {
                final settings = snapshot.data;
                final isPro = settings?.isPro == true;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPro ? 'Pro active' : 'Free plan',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPro
                                  ? 'Your RevenueCat entitlement is active.'
                                  : 'Open the paywall to buy monthly or yearly access.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isBusy || kIsWeb ? null : _openPaywall,
                      child: Text(isPro ? 'Change plan' : 'Open paywall'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isBusy || kIsWeb ? null : _restorePurchases,
                      child: const Text('Restore purchases'),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'RevenueCat paywalls are not supported on web builds.',
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _openPaywall() async {
    setState(() => _isBusy = true);
    try {
      final success = await PurchasesService.instance.presentPaywall();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Paywall closed.' : 'Could not open paywall.',
          ),
        ),
      );
    } on PurchasesServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isBusy = true);
    try {
      await PurchasesService.instance.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Purchases restored.')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}
