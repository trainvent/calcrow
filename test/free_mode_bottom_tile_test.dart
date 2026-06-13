import 'package:calcrow/core/data/services/purchases_service.dart';
import 'package:calcrow/features/home/presentation/free_mode_bottom_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/widget_test_harness.dart';

void main() {
  const promoTitle = 'Free plan';
  const promoCopy = 'Upgrade to remove this slot and unlock Pro.';
  const upgradeButton = 'Upgrade';

  Widget buildTile({
    required EntitlementTier tier,
    bool isWeb = false,
    bool adsSupported = false,
    String bannerAdUnitId = '',
    bool canRequestAds = false,
    WidgetBuilder? bannerContentBuilder,
    VoidCallback? onUpgradeTap,
  }) => materialTestAppWithBottomBar(
    FreeModeBottomTile(
      tier: tier,
      isWebOverride: isWeb,
      adsSupportedOverride: adsSupported,
      bannerAdUnitIdOverride: bannerAdUnitId,
      canRequestAdsListenable: ValueNotifier<bool>(canRequestAds),
      bannerContentBuilder: bannerContentBuilder,
      onUpgradeTap: onUpgradeTap,
    ),
  );

  Future<void> pumpFreeTile(
    WidgetTester tester, {
    bool isWeb = false,
    bool adsSupported = false,
    String bannerAdUnitId = '',
    bool canRequestAds = false,
    WidgetBuilder? bannerContentBuilder,
    VoidCallback? onUpgradeTap,
  }) {
    return tester.pumpWidget(
      buildTile(
        tier: EntitlementTier.free,
        isWeb: isWeb,
        adsSupported: adsSupported,
        bannerAdUnitId: bannerAdUnitId,
        canRequestAds: canRequestAds,
        bannerContentBuilder: bannerContentBuilder,
        onUpgradeTap: onUpgradeTap,
      ),
    );
  }

  testWidgets(
    'free user on supported mobile with ads enabled shows banner area',
    (tester) async {
      await pumpFreeTile(
        tester,
        adsSupported: true,
        bannerAdUnitId: 'test-banner-id',
        canRequestAds: true,
        bannerContentBuilder: (_) =>
            const SizedBox(key: Key('test-banner'), height: 50, width: 320),
      );

      expect(find.byKey(const Key('test-banner')), findsOneWidget);
      expect(find.text(promoCopy), findsNothing);
    },
  );

  testWidgets('pro user does not show the monetization area', (tester) async {
    await tester.pumpWidget(buildTile(tier: EntitlementTier.pro));

    expect(find.text(promoTitle), findsNothing);
    expect(find.text(upgradeButton), findsNothing);
  });

  testWidgets('web build shows disabled promo fallback instead of ad banner', (
    tester,
  ) async {
    await pumpFreeTile(
      tester,
      isWeb: true,
      adsSupported: true,
      bannerAdUnitId: 'test-banner-id',
      canRequestAds: true,
    );

    expect(find.text(promoTitle), findsOneWidget);
    expect(find.text(promoCopy), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
  });

  testWidgets('free user falls back gracefully when ads cannot be requested', (
    tester,
  ) async {
    await pumpFreeTile(
      tester,
      adsSupported: true,
      bannerAdUnitId: 'test-banner-id',
      canRequestAds: false,
    );

    expect(find.text(promoTitle), findsOneWidget);
    expect(find.text(promoCopy), findsOneWidget);
  });

  testWidgets('missing ad configuration falls back to enabled promo tile', (
    tester,
  ) async {
    await pumpFreeTile(tester, adsSupported: true, canRequestAds: true);

    expect(find.text(promoTitle), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isTrue,
    );
  });

  testWidgets('promo tile triggers upgrade action when enabled', (
    tester,
  ) async {
    var tapped = false;
    await pumpFreeTile(
      tester,
      onUpgradeTap: () {
        tapped = true;
      },
    );

    await tester.tap(find.text(upgradeButton));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
