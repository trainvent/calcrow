import 'package:calcrow/features/home/editing/simple/create_doc_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('template picker preconfigures the create document form', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();

    expect(find.text('Bruce Lee Workout'), findsOneWidget);
    expect(find.text('Guestlist'), findsOneWidget);
    expect(
      find.text('Names, contacts, and RSVP status for an event.'),
      findsOneWidget,
    );
    expect(find.textContaining('more'), findsNothing);

    await tester.tap(find.text('Guestlist'));
    await tester.pumpAndSettle();

    expect(find.text('Invited on'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('RSVP'), findsOneWidget);
  });
}
