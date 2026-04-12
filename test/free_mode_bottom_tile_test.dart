import 'package:calcrow/core/data/services/purchases_service.dart';
import 'package:calcrow/features/home/presentation/free_mode_bottom_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required EntitlementTier tier,
    bool isWeb = false,
    bool adsSupported = false,
    String bannerAdUnitId = '',
    bool canRequestAds = false,
    WidgetBuilder? bannerContentBuilder,
    VoidCallback? onUpgradeTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: FreeModeBottomTile(
          tier: tier,
          isWebOverride: isWeb,
          adsSupportedOverride: adsSupported,
          bannerAdUnitIdOverride: bannerAdUnitId,
          canRequestAdsListenable: ValueNotifier<bool>(canRequestAds),
          bannerContentBuilder: bannerContentBuilder,
          onUpgradeTap: onUpgradeTap,
        ),
      ),
    );
  }

  testWidgets(
    'free user on supported mobile with ads enabled shows banner area',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(
          tier: EntitlementTier.free,
          adsSupported: true,
          bannerAdUnitId: 'test-banner-id',
          canRequestAds: true,
          bannerContentBuilder: (_) =>
              const SizedBox(key: Key('test-banner'), height: 50, width: 320),
        ),
      );

      expect(find.byKey(const Key('test-banner')), findsOneWidget);
      expect(
        find.text('Upgrade to remove this slot and unlock Pro.'),
        findsNothing,
      );
    },
  );

  testWidgets('pro user does not show the monetization area', (tester) async {
    await tester.pumpWidget(buildSubject(tier: EntitlementTier.pro));

    expect(find.text('Free plan'), findsNothing);
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets('web build shows promo fallback instead of ad banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        tier: EntitlementTier.free,
        isWeb: true,
        adsSupported: true,
        bannerAdUnitId: 'test-banner-id',
        canRequestAds: true,
      ),
    );

    expect(find.text('Free plan'), findsOneWidget);
    expect(
      find.text('Upgrade to remove this slot and unlock Pro.'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('free user falls back gracefully when ads cannot be requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        tier: EntitlementTier.free,
        adsSupported: true,
        bannerAdUnitId: 'test-banner-id',
        canRequestAds: false,
      ),
    );

    expect(find.text('Free plan'), findsOneWidget);
    expect(
      find.text('Upgrade to remove this slot and unlock Pro.'),
      findsOneWidget,
    );
  });

  testWidgets('promo tile triggers upgrade action when enabled', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      buildSubject(
        tier: EntitlementTier.free,
        onUpgradeTap: () {
          tapped = true;
        },
      ),
    );

    await tester.tap(find.text('Upgrade'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
