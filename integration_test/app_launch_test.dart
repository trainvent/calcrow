import 'package:calcrow/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches through production startup without crashing', (
    tester,
  ) async {
    await app.main();
    await tester.pumpUntilFound(find.byType(MaterialApp));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

extension _PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final end = binding.clock.fromNowBy(timeout);
    while (binding.clock.now().isBefore(end)) {
      await pump(interval);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    throw TestFailure('Timed out waiting for $finder.');
  }
}
