import 'package:flutter/material.dart';

import '../../auth/presentation/sign_in_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      title: 'Track workdays in under a minute',
      body:
          'Calcrow gives you one clean daily editor so you update logs fast on your phone.',
      icon: Icons.checklist_rounded,
    ),
    _OnboardingPage(
      title: 'Import or create monthly CSV instantly',
      body:
          'Bring an existing file or generate a full month table with your preferred date style.',
      icon: Icons.table_chart_rounded,
    ),
    _OnboardingPage(
      title: 'Keep data local, sync when you choose',
      body:
          'Start offline. Later connect account sync and backups without changing your workflow.',
      icon: Icons.cloud_done_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAuthSheet() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SignInSheet(),
    );
    if (!mounted) return;
    if (done ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in. You can continue using the app.')),
      );
    }
  }

  void _continueWithoutAccount() {
    widget.onComplete();
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _continueWithoutAccount,
                    child: const Text('Skip for now'),
                  ),
                ),
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
                    child: const Text('Continue'),
                  ),
                if (isLast)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _continueWithoutAccount,
                          child: const Text('Start without account'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _openAuthSheet,
                        child: const Text('Sign in or create account'),
                      ),
                    ],
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
              Text(page.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(page.body, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
