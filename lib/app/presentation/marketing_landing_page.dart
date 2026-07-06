import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'web_link_opener_stub.dart'
    if (dart.library.html) 'web_link_opener_web.dart';

class MarketingLandingPage extends StatelessWidget {
  const MarketingLandingPage({super.key});

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=de.lemarq.calcrow';
  static const String appStoreUrl =
      'https://apps.apple.com/us/app/calcrow/id6760388420';
  static const String webClientPath = '/?app=1';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 720 ? 20.0 : 32.0;

    return Scaffold(
      body: Container(
        color: const Color(0xFFF5F1EA),
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
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TopBar(onOpenWeb: () => openSameTabUrl(webClientPath)),
                    const SizedBox(height: 28),
                    _HeroCopy(theme: theme),
                    const SizedBox(height: 18),
                    _PreviewPanel(theme: theme),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => openSameTabUrl('/privacy-policy/'),
                          child: const Text('Privacy Policy'),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/terms-of-use/'),
                          child: const Text('Terms'),
                        ),
                        TextButton(
                          onPressed: () =>
                              openSameTabUrl('/privacy-policy-ads/'),
                          child: const Text('Ads Privacy'),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/support/'),
                          child: const Text('Support'),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/delete-account/'),
                          child: const Text('Delete Account'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            'Calcrow is delivered by ',
                            style: theme.textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () =>
                                openExternalUrl('https://next.trainvent.com/'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Trainvent'),
                          ),
                        ],
                      ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/AppIcon_1024_square.png',
                  width: 14,
                  height: 14,
                  fit: BoxFit.cover,
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
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DBCF)),
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
              'worklog editor',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB45231),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sheet manipulation on the go.',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 48,
              height: 1.0,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Open CSV, XLSX, or ODS files, edit the focused row in Simple mode, and save back to local or cloud storage.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              height: 1.45,
              color: const Color(0xFF4C4F55),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              InkWell(
                onTap: () => openExternalUrl(MarketingLandingPage.playStoreUrl),
                child: kIsWeb
                    ? SvgPicture.network(
                        'public/store-badges/google-play-en.svg',
                        height: 56,
                      )
                    : SvgPicture.asset(
                        'assets/store-badges/google-play-en.svg',
                        height: 56,
                      ),
              ),
              InkWell(
                onTap: () => openExternalUrl(MarketingLandingPage.appStoreUrl),
                child: kIsWeb
                    ? SvgPicture.network(
                        'public/store-badges/app-store-en.svg',
                        height: 56,
                      )
                    : SvgPicture.asset(
                        'assets/store-badges/app-store-en.svg',
                        height: 56,
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
        color: const Color(0xFF232D2D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF334143)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Desktop to mobile, optimized to fit.',
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFF6F3EE),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Focused row editing',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB7C1C3),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF283436),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF36474B)),
            ),
            child: Column(
              children: <Widget>[
                const _MiniSheetRow(
                  values: <String>['Date', 'Project', 'Start', 'End', 'Total'],
                ),
                const SizedBox(height: 10),
                const _MiniSheetRow(
                  values: <String>[
                    '12/05',
                    'Client B',
                    '07:45',
                    '15:30',
                    '07:45',
                  ],
                ),
                const SizedBox(height: 10),
                const _MiniSheetRow(
                  values: <String>[
                    '13/05',
                    'Client A',
                    '08:00',
                    '16:00',
                    '08:00',
                  ],
                  highlight: true,
                ),
                const SizedBox(height: 10),
                const _MiniSheetRow(
                  values: <String>[
                    '14/05',
                    'Client C',
                    '09:00',
                    '17:00',
                    '08:00',
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Focused row is highlighted',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFB7C1C3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF283436),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF36474B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Mobile two-column view',
                  style: textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFF6F3EE),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 176,
                      child: Column(
                        children: const <Widget>[
                          _MobilePreviewCell(text: 'Date'),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: 'Project'),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: 'Start'),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: 'End'),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: 'Total'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 176,
                      child: Column(
                        children: const <Widget>[
                          _MobilePreviewCell(text: '13/05', highlighted: true),
                          SizedBox(height: 8),
                          _MobilePreviewCell(
                            text: 'Client A',
                            highlighted: true,
                          ),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: '08:00', highlighted: true),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: '16:00', highlighted: true),
                          SizedBox(height: 8),
                          _MobilePreviewCell(text: '08:00', highlighted: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Same row, compacted for mobile screens',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB7C1C3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Note: this sheet is just an example',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB7C1C3),
              height: 1.45,
            ),
          ),
        ],
      ),
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
                      ? const Color(0xFF3A8F61)
                      : const Color(0xFF314043),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? Colors.white : const Color(0xFFF0ECE5),
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

class _MobilePreviewCell extends StatelessWidget {
  const _MobilePreviewCell({required this.text, this.highlighted = false});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF4CAF75).withValues(alpha: 0.16)
            : const Color(0xFF1F292B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF4CAF75).withValues(alpha: 0.35)
              : const Color(0xFF36474B),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: highlighted
              ? const Color(0xFFF6F3EE)
              : const Color(0xFFDDE4E1),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
