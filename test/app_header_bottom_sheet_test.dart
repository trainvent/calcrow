import 'package:calcrow/app/widgets/app_header_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app header bottom sheet fills below the app bar and returns', (
    tester,
  ) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Page')),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppHeaderBottomSheet<int>(
                  context: context,
                  builder: (context) => AppHeaderBottomSheet(
                    key: const ValueKey('reusable-sheet'),
                    title: 'Reusable sheet',
                    closeTooltip: 'Close',
                    content: const Text('Scrollable content'),
                    footer: FilledButton(
                      onPressed: () => Navigator.of(context).pop(7),
                      child: const Text('Done'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('reusable-sheet')));
    expect(rect, const Rect.fromLTRB(0, 56, 800, 600));
    expect(find.text('Reusable sheet'), findsOneWidget);
    expect(find.text('Scrollable content'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('reusable-sheet'))).top,
      56,
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, 7);
  });

  testWidgets('app header bottom sheet accepts a custom header widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppHeaderBottomSheet<void>(
                context: context,
                builder: (context) => const AppHeaderBottomSheet(
                  closeTooltip: 'Close',
                  header: TextField(
                    decoration: InputDecoration(labelText: 'Custom header'),
                  ),
                  content: Text('Content'),
                ),
              ),
              child: const Text('Open custom'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open custom'));
    await tester.pumpAndSettle();

    expect(find.text('Custom header'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });
}
