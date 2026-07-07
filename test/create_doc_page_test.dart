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

    expect(find.text('Workout like Bruce Lee'), findsOneWidget);
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

  testWidgets('Bruce Lee template uses exercise-specific weight fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout like Bruce Lee'));
    await tester.pumpAndSettle();

    expect(find.text('Run km'), findsOneWidget);
    expect(find.text('Clean and Press weight'), findsOneWidget);
    expect(find.text('Barbell Curl weight'), findsOneWidget);
    expect(find.text('Behind-the-neck Press weight'), findsOneWidget);
    expect(find.text('Upright Row weight'), findsOneWidget);
    expect(find.text('Barbell Squat weight'), findsOneWidget);
    expect(find.text('Barbell Row weight'), findsOneWidget);
    expect(find.text('Barbell Bench Press weight'), findsOneWidget);
    expect(find.text('Barbell Pullover weight'), findsOneWidget);
    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Exercise'), findsNothing);
    expect(find.text('Added weight'), findsNothing);
  });
}
