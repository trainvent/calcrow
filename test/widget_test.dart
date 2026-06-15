import 'package:calcrow/app/app.dart';
import 'package:calcrow/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest startup shows onboarding before entering the app', (
    tester,
  ) async {
    await tester.pumpWidget(const CalcrowApp());

    expect(find.text('Track workdays in under a minute'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('onboarding skip action completes onboarding', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () {
            completed = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    expect(completed, isTrue);
  });
}
