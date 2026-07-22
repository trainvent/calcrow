import 'package:calcrow/app/widgets/dual_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows and invokes the secondary and primary actions', (
    tester,
  ) async {
    var secondaryPressed = false;
    var primaryPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DualTextButton(
            secondaryLabel: 'Recent',
            onSecondaryPressed: () => secondaryPressed = true,
            primaryLabel: 'Open',
            onPrimaryPressed: () => primaryPressed = true,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'Recent'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open'), findsOneWidget);

    await tester.tap(find.text('Recent'));
    await tester.tap(find.text('Open'));

    expect(secondaryPressed, isTrue);
    expect(primaryPressed, isTrue);
  });

  testWidgets('supports independently disabled actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DualTextButton(
            secondaryLabel: 'Cancel',
            onSecondaryPressed: null,
            primaryLabel: 'Continue',
            onPrimaryPressed: null,
          ),
        ),
      ),
    );

    final secondary = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final primary = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );

    expect(secondary.onPressed, isNull);
    expect(primary.onPressed, isNull);
  });
}
