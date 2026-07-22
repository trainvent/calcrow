import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/features/home/editing/define_prefills_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cancel warns before discarding the configuration', (
    tester,
  ) async {
    List<DocumentPrefill>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context)
                    .push<List<DocumentPrefill>>(
                      MaterialPageRoute(
                        builder: (context) => const DefinePrefillsPage(
                          headers: <String>['Date', 'Notes'],
                          valueTypes: <String>['date', 'text'],
                        ),
                      ),
                    );
              },
              child: const Text('Open prefills'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open prefills'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create Document'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel document configuration?'), findsOneWidget);
    expect(
      find.text(
        'All configuration will be lost. Are you sure you want to return to Selection?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Define prefills'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Open prefills'), findsOneWidget);
    expect(result, isNull);
  });
}
