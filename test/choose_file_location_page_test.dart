import 'dart:async';

import 'package:calcrow/features/home/editing/choose_file_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns the selected file location', (tester) async {
    CreateDestination? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<CreateDestination>(
                  MaterialPageRoute(
                    builder: (context) => const ChooseFileLocationPage(),
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

    expect(find.text('Choose File Location'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);

    await tester.tap(find.text('Local'));
    await tester.pumpAndSettle();

    expect(result, CreateDestination.local);
  });

  testWidgets('can hide the local destination', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChooseFileLocationPage(showLocal: false)),
    );

    expect(find.text('Local'), findsNothing);
    expect(find.text('Cloud'), findsOneWidget);
  });

  testWidgets('stays visible while the selected location flow is running', (
    tester,
  ) async {
    final pendingSelection = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) => ChooseFileLocationPage(
                    onSelected: (_) => pendingSelection.future,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local'));
    await tester.pump();

    expect(find.text('Choose File Location'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingSelection.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Choose File Location'), findsNothing);
  });

  testWidgets('returns to location choices when a follow-up is canceled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) =>
                      ChooseFileLocationPage(onSelected: (_) async => false),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud'));
    await tester.pumpAndSettle();

    expect(find.text('Choose File Location'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
