import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
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
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
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
                          child: Text(context.l10n.privacyPolicy),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/terms-of-use/'),
                          child: Text(context.l10n.terms),
                        ),
                        TextButton(
                          onPressed: () =>
                              openSameTabUrl('/privacy-policy-ads/'),
                          child: Text(context.l10n.adsPrivacy),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/support/'),
                          child: Text(context.l10n.support),
                        ),
                        TextButton(
                          onPressed: () => openSameTabUrl('/delete-account/'),
                          child: Text(context.l10n.deleteAccount),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            context.l10n.calcrowIsDeliveredBy,
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
                            child: Text(context.l10n.trainvent),
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

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            context.l10n.calcrow,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DBCF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final copy = _HeroText(theme: theme, showCapabilities: !compact);
          final showcase = Transform.translate(
            offset: const Offset(0, 56),
            child: const _HeroShowcase(),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _BrandPill(),
                const SizedBox(height: 24),
                copy,
                const SizedBox(height: 24),
                Center(child: showcase),
              ],
            );
          }
          return Stack(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: copy,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(flex: 6, child: showcase),
                ],
              ),
              const Positioned(top: 0, left: 0, child: _BrandPill()),
            ],
          );
        },
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.theme, required this.showCapabilities});

  final ThemeData theme;
  final bool showCapabilities;

  @override
  Widget build(BuildContext context) {
    final badgeLanguage = Localizations.localeOf(context).languageCode == 'de'
        ? 'de'
        : 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6DB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            context.l10n.worklogEditor,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB45231),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.sheetManipulationOnTheGo,
          key: const ValueKey('marketing-hero-title'),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 48,
            height: 1.0,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          context
              .l10n
              .openCSVXLSXOrODSFilesEditTheFocusedRowInCoreEditorAndSaveBackToLocalOrCloudStorage,
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
                      'public/store-badges/google-play-$badgeLanguage.svg',
                      height: 56,
                    )
                  : SvgPicture.asset(
                      'assets/store-badges/google-play-$badgeLanguage.svg',
                      height: 56,
                    ),
            ),
            InkWell(
              onTap: () => openExternalUrl(MarketingLandingPage.appStoreUrl),
              child: kIsWeb
                  ? SvgPicture.network(
                      'public/store-badges/app-store-$badgeLanguage.svg',
                      height: 56,
                    )
                  : SvgPicture.asset(
                      'assets/store-badges/app-store-$badgeLanguage.svg',
                      height: 56,
                    ),
            ),
          ],
        ),
        if (showCapabilities) ...<Widget>[
          const SizedBox(height: 28),
          _HeroCapabilities(theme: theme),
        ],
      ],
    );
  }
}

class _HeroCapabilities extends StatelessWidget {
  const _HeroCapabilities({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DDD1)),
      ),
      child: Column(
        children: <Widget>[
          _CapabilityRow(
            theme: theme,
            icon: Icons.description_outlined,
            text: context.l10n.openCSVXLSXOrODS,
          ),
          const SizedBox(height: 10),
          _CapabilityRow(
            theme: theme,
            icon: Icons.filter_center_focus_rounded,
            text: context.l10n.focusedRowEditing,
          ),
          const SizedBox(height: 10),
          _CapabilityRow(
            theme: theme,
            icon: Icons.cloud_outlined,
            text: '${context.l10n.local} · Google Drive · WebDAV',
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.theme,
    required this.icon,
    required this.text,
  });

  final ThemeData theme;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6DB),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFB45231)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4C4F55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroShowcase extends StatelessWidget {
  const _HeroShowcase();

  static const _imageUrl = 'public/showcases/showcase_pro.png';
  static const _aspectRatio = 2560 / 2165;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Image.network(
          _imageUrl,
          key: const ValueKey('marketing-hero-showcase'),
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
          semanticLabel: context.l10n.calcrow,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
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
            context.l10n.desktopToMobileOptimizedToFit,
            style: textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFF6F3EE),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.focusedRowEditing,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB7C1C3),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const desktopPreview = _DesktopSheetPreview();
              const mobilePreview = _MobileSheetPreview();
              if (constraints.maxWidth < 900) {
                return const Column(
                  children: <Widget>[
                    desktopPreview,
                    SizedBox(height: 14),
                    mobilePreview,
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 7, child: desktopPreview),
                  SizedBox(width: 14),
                  Expanded(flex: 3, child: mobilePreview),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noteThisSheetIsJustAnExample,
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

class _DesktopSheetPreview extends StatelessWidget {
  const _DesktopSheetPreview();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
            values: <String>['12/05', 'Client B', '07:45', '15:30', '07:45'],
          ),
          const SizedBox(height: 10),
          const _MiniSheetRow(
            values: <String>['13/05', 'Client A', '08:00', '16:00', '08:00'],
            highlight: true,
          ),
          const SizedBox(height: 10),
          const _MiniSheetRow(
            values: <String>['14/05', 'Client C', '09:00', '17:00', '08:00'],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.l10n.focusedRowIsHighlighted,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFFB7C1C3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSheetPreview extends StatelessWidget {
  const _MobileSheetPreview();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
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
            context.l10n.mobileTwoColumnView,
            style: textTheme.titleMedium?.copyWith(
              color: const Color(0xFFF6F3EE),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
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
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _MobilePreviewCell(text: '13/05', highlighted: true),
                    SizedBox(height: 8),
                    _MobilePreviewCell(text: 'Client A', highlighted: true),
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
            context.l10n.sameRowCompactedForMobileScreens,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB7C1C3),
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
