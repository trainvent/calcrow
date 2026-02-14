import 'package:valrow/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding is shown at startup', (tester) async {
    await tester.pumpWidget(const CalcrowApp());

    expect(find.text('Track workdays in under a minute'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
