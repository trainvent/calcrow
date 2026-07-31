import 'package:calcrow/app/presentation/monetization_choice_screen.dart';
import 'package:calcrow/core/data/services/monetization_choice_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('monetization choice is parsed conservatively', () {
    expect(monetizationChoiceFromStorage('ads'), MonetizationChoice.ads);
    expect(monetizationChoiceFromStorage('ADS'), MonetizationChoice.ads);
    expect(monetizationChoiceFromStorage('personalized'), isNull);
    expect(monetizationChoiceFromStorage(null), isNull);
  });

  test('ads choice is stored separately for each account', () async {
    await MonetizationChoiceService.save('alice', MonetizationChoice.ads);

    expect(
      await MonetizationChoiceService.read('alice'),
      MonetizationChoice.ads,
    );
    expect(await MonetizationChoiceService.read('bob'), isNull);
  });

  test('user settings read the account-level ads choice', () {
    final settings = UserSettingsData.fromMap(const <String, dynamic>{
      'monetizationChoice': 'ads',
    });

    expect(settings.monetizationChoice, MonetizationChoice.ads);
  });

  testWidgets('choice screen offers Pro and ads with privacy explanation', (
    tester,
  ) async {
    var chosePro = false;
    var choseAds = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MonetizationChoiceScreen(
          isBusy: false,
          onChoosePro: () => chosePro = true,
          onContinueWithAds: () => choseAds = true,
        ),
      ),
    );

    expect(find.text('Choose how to continue'), findsOneWidget);
    expect(find.text('Explore Pro'), findsOneWidget);
    expect(find.text('Continue with ads'), findsOneWidget);
    expect(
      find.textContaining('decline personalized advertising'),
      findsOneWidget,
    );

    await tester.tap(find.text('Explore Pro'));
    await tester.tap(find.text('Continue with ads'));

    expect(chosePro, isTrue);
    expect(choseAds, isTrue);
  });

  testWidgets('choice screen disables both actions while busy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MonetizationChoiceScreen(
          isBusy: true,
          onChoosePro: () {},
          onContinueWithAds: () {},
        ),
      ),
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('blocked free mode can review ad choices or choose Pro', (
    tester,
  ) async {
    var reviewedChoices = false;
    var chosePro = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AdConsentRequiredScreen(
          isBusy: false,
          onReviewAdChoices: () => reviewedChoices = true,
          onChoosePro: () => chosePro = true,
        ),
      ),
    );

    expect(find.text('Ad choices required for free mode'), findsOneWidget);
    expect(find.text('Review ad choices'), findsOneWidget);
    expect(find.text('Explore Pro'), findsOneWidget);

    await tester.tap(find.text('Review ad choices'));
    await tester.tap(find.text('Explore Pro'));

    expect(reviewedChoices, isTrue);
    expect(chosePro, isTrue);
  });
}
