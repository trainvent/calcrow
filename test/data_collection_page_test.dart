import 'package:calcrow/core/data/services/purchases_service.dart';
import 'package:calcrow/features/home/settings/data_collection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildPage({
    required EntitlementTier tier,
    required bool adsSupported,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: DataCollectionPage(
          tierOverride: tier,
          adsSupportedOverride: adsSupported,
        ),
      ),
    );
  }

  testWidgets('free users can re-enter Google ads consent', (tester) async {
    await tester.pumpWidget(
      buildPage(tier: EntitlementTier.free, adsSupported: true),
    );

    expect(find.text('Analytical'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Ad-related'), findsOneWidget);
    expect(find.text('Re-enter Google ads consent'), findsOneWidget);
    expect(
      find.text('Pro status enabled, no ad-related settings needed.'),
      findsNothing,
    );
  });

  testWidgets('Pro users see no ad consent controls', (tester) async {
    await tester.pumpWidget(
      buildPage(tier: EntitlementTier.pro, adsSupported: true),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Re-enter Google ads consent'), findsNothing);
    expect(find.text('Ads privacy choices'), findsNothing);
    expect(find.text('Reset ad consent'), findsNothing);
    expect(
      find.text('Pro status enabled, no ad-related settings needed.'),
      findsOneWidget,
    );
  });
}
