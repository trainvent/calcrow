import 'package:calcrow/app/app.dart';
import 'package:calcrow/features/onboarding/onboarding_screen.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signed-out startup shows account-gated onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CalcrowApp()));

    expect(find.text('Track workdays in under a minute'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    expect(find.text('Choose how to continue'), findsNothing);
  });

  testWidgets('onboarding requires sign in on final page', (tester) async {
    await tester.pumpWidget(MaterialApp(home: const OnboardingScreen()));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in or create account'), findsOneWidget);
    expect(find.text('Start without account'), findsNothing);
  });

  testWidgets('changing the app language rebuilds the interface', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [effectiveLanguageCodeProvider.overrideWithValue('de')],
        child: const CalcrowApp(),
      ),
    );

    expect(
      find.text('Arbeitstage in weniger als einer Minute erfassen'),
      findsOneWidget,
    );
  });

  testWidgets('uses the selected light, dark, or system theme mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
        child: const CalcrowApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.brightness, Brightness.dark);
    expect(app.theme?.brightness, Brightness.light);
  });
}
