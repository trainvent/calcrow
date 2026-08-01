import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';

import 'package:calcrow/features/auth/sign_in_sheet.dart';
import 'package:calcrow/features/auth/auth_choice_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      id: _OnboardingPageId.fastTracking,
      icon: Icons.checklist_rounded,
    ),
    _OnboardingPage(
      id: _OnboardingPageId.monthlyCsv,
      icon: Icons.table_chart_rounded,
    ),
    _OnboardingPage(
      id: _OnboardingPageId.localFirst,
      icon: Icons.cloud_done_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAuthSheet() async {
    final choice = await showAuthChoiceSheet(context);
    if (!mounted) return;
    if (choice == null) return;
    if (choice == AuthEntryChoice.google) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signedInWelcomeToCalcrow)),
      );
      return;
    }
    final done = await showSignInSheet<bool>(
      context,
      initialMode: choice == AuthEntryChoice.register
          ? AuthSheetMode.register
          : AuthSheetMode.signIn,
    );
    if (!mounted) return;
    if (done ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signedInWelcomeToCalcrow)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBE2D6), Color(0xFFF6F4EF), Color(0xFFD8EEE9)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                const SizedBox(height: 44),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemCount: _pages.length,
                    itemBuilder: (_, pageIndex) =>
                        _OnboardingCard(page: _pages[pageIndex]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (dotIndex) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _index == dotIndex ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: _index == dotIndex
                            ? theme.colorScheme.primary
                            : const Color(0xFFD7CBBE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!isLast)
                  OutlinedButton(
                    onPressed: () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Text(context.l10n.continueLabel),
                  ),
                if (isLast)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openAuthSheet,
                      child: Text(context.l10n.signInOrCreateAccount),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  page.icon,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                page.title(context.l10n),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(page.body(context.l10n), style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({required this.id, required this.icon});

  final _OnboardingPageId id;
  final IconData icon;

  String title(AppLocalizations localizations) => switch (id) {
    _OnboardingPageId.fastTracking => localizations.trackWorkdaysInUnderAMinute,
    _OnboardingPageId.monthlyCsv =>
      localizations.importOrCreateMonthlyCSVInstantly,
    _OnboardingPageId.localFirst =>
      localizations.keepDataLocalSyncWhenYouChoose,
  };

  String body(AppLocalizations localizations) => switch (id) {
    _OnboardingPageId.fastTracking =>
      localizations
          .calcrowGivesYouOneCleanDailyEditorSoYouUpdateLogsFastOnYourPhone,
    _OnboardingPageId.monthlyCsv =>
      localizations
          .bringAnExistingFileOrGenerateAFullMonthTableWithYourPreferredDateStyle,
    _OnboardingPageId.localFirst =>
      localizations
          .startOfflineLaterConnectAccountSyncAndBackupsWithoutChangingYourWorkflow,
  };
}

enum _OnboardingPageId { fastTracking, monthlyCsv, localFirst }
