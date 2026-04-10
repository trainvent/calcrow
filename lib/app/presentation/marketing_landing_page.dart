import 'package:flutter/material.dart';

import 'web_link_opener_stub.dart'
    if (dart.library.html) 'web_link_opener_web.dart';

class MarketingLandingPage extends StatelessWidget {
  const MarketingLandingPage({super.key});

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=de.lemarq.calcrow';
  static const String appStoreUrl = '';
  static const String webClientPath = '/?app=1';

  bool get _hasAppStoreUrl => appStoreUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 720 ? 20.0 : 32.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF7E8D6),
              Color(0xFFF5F1EA),
              Color(0xFFE4F0EA),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _TopBar(onOpenWeb: () => openSameTabUrl(webClientPath)),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: width < 900 ? 860 : 560,
                          child: _HeroCopy(theme: theme),
                        ),
                        SizedBox(
                          width: width < 900 ? 860 : 560,
                          child: _PreviewPanel(theme: theme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: <Widget>[
                        _StoreCard(
                          title: 'Play Store',
                          subtitle:
                              'Install Calcrow on Android phones and tablets.',
                          badge: 'Android',
                          accent: const Color(0xFF1F8F68),
                          actionLabel: 'Download for Android',
                          onTap: () => openExternalUrl(playStoreUrl),
                        ),
                        _StoreCard(
                          title: 'App Store',
                          subtitle: _hasAppStoreUrl
                              ? 'Get the iPhone version from the App Store.'
                              : 'Add your App Store listing URL here before launch.',
                          badge: 'iPhone',
                          accent: const Color(0xFF2B5FD9),
                          actionLabel: _hasAppStoreUrl
                              ? 'Download for iPhone'
                              : 'Coming soon',
                          onTap: _hasAppStoreUrl
                              ? () => openExternalUrl(appStoreUrl)
                              : null,
                        ),
                        _StoreCard(
                          title: 'Web Client',
                          subtitle:
                              'Open Calcrow directly in the browser and start editing.',
                          badge: 'Browser',
                          accent: const Color(0xFFE36A44),
                          actionLabel: 'Open web client',
                          onTap: () => openSameTabUrl(webClientPath),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: const <Widget>[
                        _FeaturePill(
                          title: 'Open CSV, XLSX, ODS',
                          text:
                              'Bring existing timesheets in without converting them first.',
                        ),
                        _FeaturePill(
                          title: 'Simple daily editor',
                          text:
                              'Update the important fields fast and keep formulas intact.',
                        ),
                        _FeaturePill(
                          title: 'Save back out',
                          text:
                              'Download updated files from the browser when you are done.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => openSameTabUrl('/privacy-policy/'),
                          child: const Text('Privacy Policy'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              openSameTabUrl('/privacy-policy-ads/'),
                          child: const Text('Ads Privacy'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => openSameTabUrl('/support/'),
                          child: const Text('Support'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => openSameTabUrl('/delete-account/'),
                          child: const Text('Delete Account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onOpenWeb});

  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE4D8C9)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE36A44),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Calcrow',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(onPressed: onOpenWeb, child: const Text('Open app')),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFE6D9CB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6DB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Clean worklog editing',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB45231),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Fill Sheets on the go.',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 56,
              height: 0.96,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Open your existing files, update daily hours in a focused editor, and keep the export flow simple across phone and browser.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              color: const Color(0xFF4C4F55),
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ElevatedButton(
                onPressed: () =>
                    openSameTabUrl(MarketingLandingPage.webClientPath),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Open web client'),
                ),
              ),
              OutlinedButton(
                onPressed: () =>
                    openExternalUrl(MarketingLandingPage.playStoreUrl),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Android download'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final textTheme = theme.textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2628),
        borderRadius: BorderRadius.circular(36),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 38,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'One app, three ways in.',
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFF6F3EE),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 18),
          const _FlowStep(
            number: '01',
            title: 'Install on Android',
            text:
                'Keep Calcrow on hand for quick daily updates during the workday.',
          ),
          const SizedBox(height: 12),
          const _FlowStep(
            number: '02',
            title: 'Launch in the browser',
            text:
                'Open the web client when you want the same editor on a larger screen.',
          ),
          const SizedBox(height: 12),
          const _FlowStep(
            number: '03',
            title: 'Export cleanly',
            text:
                'Save finished files back out after making changes in simple mode.',
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF263235),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF36474B)),
            ),
            child: Column(
              children: const <Widget>[
                _MiniSheetRow(
                  values: <String>['Date', 'Start', 'End', 'Total'],
                ),
                SizedBox(height: 10),
                _MiniSheetRow(
                  values: <String>['13/03', '08:05', '16:32', '08:27'],
                ),
                SizedBox(height: 10),
                _MiniSheetRow(
                  values: <String>['14/03', '07:58', '16:14', '08:16'],
                ),
                SizedBox(height: 10),
                _MiniSheetRow(
                  values: <String>['Sum', ' ', ' ', '16:43'],
                  highlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE36A44),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF6F3EE),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(color: Color(0xFFB7C1C3), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniSheetRow extends StatelessWidget {
  const _MiniSheetRow({required this.values, this.highlight = false});

  final List<String> values;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values
          .map(
            (value) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: highlight
                      ? const Color(0xFFE36A44)
                      : const Color(0xFF314043),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? Colors.white : const Color(0xFFF4F1EB),
                    fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Color accent;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5D9CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontFamily: 'Georgia'),
          ),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text(
                actionLabel,
                style: TextStyle(
                  color: onTap == null ? const Color(0xFF9A938B) : accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                onTap == null ? Icons.lock_clock_rounded : Icons.arrow_forward,
                color: onTap == null ? const Color(0xFF9A938B) : accent,
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: card,
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5D9CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }
}
