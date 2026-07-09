import 'package:calcrow/features/home/editing/create_doc_page.dart';
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
    expect(find.text('Triathlon Training Tracker Plus'), findsOneWidget);
    expect(
      find.text('Track swim, bike, run, and strength work in one row.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Every template starts with Date'),
      findsOneWidget,
    );
    expect(find.textContaining('more'), findsNothing);

    await tester.tap(find.text('Triathlon Training Tracker Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Run km'), findsOneWidget);
    expect(find.text('Swim km'), findsOneWidget);
    expect(find.text('Bike km'), findsOneWidget);
    expect(find.text('Pull-ups'), findsOneWidget);
    expect(find.text('Push-ups'), findsOneWidget);
    expect(find.text('Squats'), findsOneWidget);
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

  testWidgets('Triathlon template tracks endurance and strength fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triathlon Training Tracker Plus'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Run km'), findsOneWidget);
    expect(find.text('Swim km'), findsOneWidget);
    expect(find.text('Bike km'), findsOneWidget);
    expect(find.text('Pull-ups'), findsOneWidget);
    expect(find.text('Push-ups'), findsOneWidget);
    expect(find.text('Squats'), findsOneWidget);
    expect(find.text('float'), findsNWidgets(3));
    expect(find.text('integer'), findsNWidgets(3));
  });

  testWidgets('Customer Service template preconfigures service fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer Service'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Workhours'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Work done'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
}
