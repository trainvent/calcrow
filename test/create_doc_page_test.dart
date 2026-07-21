import 'package:calcrow/features/home/editing/create_doc_page.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plain create setup defaults to CSV without sheet separation', (
    tester,
  ) async {
    DocumentDraft? result;
    await _pumpDraftHost(tester, onDraft: (draft) => result = draft);

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.fileName, 'calcrow_sheet.csv');
    expect(result?.format, SheetFileFormat.csv);
    expect(result?.xlsxSheetName, isNull);
  });

  testWidgets('monthly XLSX setup uses current month sheet and year filename', (
    tester,
  ) async {
    DocumentDraft? result;
    await _pumpDraftHost(
      tester,
      onDraft: (draft) => result = draft,
      initialSetup: CreateDocInitialSetup(
        separation: LogbookSeparation.monthly,
        createdAt: DateTime(2026, 7, 11),
      ),
    );

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();

    expect(find.text('CSV'), findsNothing);
    expect(find.text('XLSX'), findsOneWidget);
    expect(_fileNameSuffix(tester), '_2026.xlsx');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.fileName, 'calcrow_sheet_2026.xlsx');
    expect(result?.format, SheetFileFormat.xlsx);
    expect(result?.xlsxSheetName, 'July');
  });

  testWidgets('yearly setup defaults to a single-year CSV', (tester) async {
    DocumentDraft? result;
    await _pumpDraftHost(
      tester,
      onDraft: (draft) => result = draft,
      initialSetup: CreateDocInitialSetup(
        separation: LogbookSeparation.yearly,
        createdAt: DateTime(2026, 7, 11),
      ),
    );

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();
    expect(_fileNameSuffix(tester), '_2026.csv');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.fileName, 'calcrow_sheet_2026.csv');
    expect(result?.format, SheetFileFormat.csv);
    expect(result?.xlsxSheetName, isNull);
  });

  testWidgets('yearly setup can use XLSX for year sheets', (tester) async {
    DocumentDraft? result;
    await _pumpDraftHost(
      tester,
      onDraft: (draft) => result = draft,
      initialSetup: CreateDocInitialSetup(
        separation: LogbookSeparation.yearly,
        createdAt: DateTime(2026, 7, 11),
      ),
    );

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('XLSX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.fileName, 'calcrow_sheet.xlsx');
    expect(result?.format, SheetFileFormat.xlsx);
    expect(result?.xlsxSheetName, '2026');
  });

  testWidgets('monthly setup can use ODS for month sheets', (tester) async {
    DocumentDraft? result;
    await _pumpDraftHost(
      tester,
      onDraft: (draft) => result = draft,
      initialSetup: CreateDocInitialSetup(
        separation: LogbookSeparation.monthly,
        createdAt: DateTime(2026, 7, 11),
      ),
    );

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ODS'));
    await tester.pumpAndSettle();

    expect(_fileNameSuffix(tester), '_2026.ods');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.fileName, 'calcrow_sheet_2026.ods');
    expect(result?.format, SheetFileFormat.ods);
    expect(result?.xlsxSheetName, 'July');
  });

  testWidgets('template picker preconfigures the create document form', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();

    expect(find.text('Workout like Bruce Lee'), findsOneWidget);
    expect(find.text('Triathlon Training Tracker Plus'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(
      find.text('Track swim, bike, run, and strength work in one row.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Every template starts with Date'),
      findsOneWidget,
    );
    expect(find.textContaining('more'), findsNothing);

    await _chooseTemplate(tester, 'triathlon_training_tracker_plus');

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Run km'), findsOneWidget);
    expect(find.text('Swim km'), findsOneWidget);
    expect(find.text('Bike km'), findsOneWidget);
    expect(find.text('Pull-ups'), findsOneWidget);
    expect(find.text('Push-ups'), findsOneWidget);
    expect(find.text('Squats'), findsOneWidget);
  });

  testWidgets('template picker groups templates into categories', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();

    expect(find.text('Sports'), findsOneWidget);
    await _scrollTemplateIntoView(tester, 'Work');
    expect(find.text('Work'), findsOneWidget);
    await _scrollTemplateIntoView(tester, 'Other');
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('template tile expands on tap and only its arrow selects it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();

    final description = find.text(
      'Track training sessions without turning the sheet into a fitness app.',
    );
    expect(tester.widget<Text>(description).maxLines, 1);

    await tester.tap(find.text('Workout like Bruce Lee'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.widget<Text>(description).maxLines, isNull);
    expect(
      find.byKey(const ValueKey('expanded-template-fields-bruce_lee_workout')),
      findsOneWidget,
    );
    expect(find.text('Barbell Pullover weight'), findsOneWidget);

    await _chooseTemplate(tester, 'bruce_lee_workout');
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Bruce Lee template uses exercise-specific weight fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await _chooseTemplate(tester, 'bruce_lee_workout');

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

  testWidgets('Dynamic Workout Tracker uses flexible workout fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dynamic Workout Tracker'));
    await tester.pumpAndSettle();
    await _chooseTemplate(tester, 'dynamic_workout_tracker');

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Exercize'), findsOneWidget);
    expect(find.text('Distance / Repetitions'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('duration'), findsOneWidget);
  });

  testWidgets('dynamic workout can define a weekday multi-field prefill', (
    tester,
  ) async {
    DocumentDraft? result;
    await _pumpDraftHost(tester, onDraft: (draft) => result = draft);

    await tester.tap(find.text('Open creator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dynamic Workout Tracker'));
    await tester.pumpAndSettle();
    await _chooseTemplate(tester, 'dynamic_workout_tracker');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Define prefills'), findsOneWidget);
    await tester.tap(find.text('Add prefill'));
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(
      find.byKey(const ValueKey('prefill-editor-sheet')),
    );
    expect(sheetRect.left, 0);
    expect(sheetRect.right, 800);
    expect(sheetRect.top, 56);

    expect(_textFieldWithLabel('Date'), findsNothing);
    await tester.enterText(_textFieldWithLabel('Prefill name'), 'Daily jog');
    await tester.enterText(_textFieldWithLabel('Exercize'), 'Jog');
    await tester.enterText(
      _textFieldWithLabel('Distance / Repetitions'),
      '12km',
    );
    expect(find.widgetWithText(TextField, 'Hours'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Minutes'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '30');
    final toggleAllDays = find.byKey(
      const ValueKey('weekday-picker-toggle-all'),
    );
    await tester.ensureVisible(toggleAllDays);
    await tester.pumpAndSettle();
    await tester.tap(toggleAllDays);
    await tester.ensureVisible(find.text('Wed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wed'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Daily jog'), findsOneWidget);
    expect(find.textContaining('Distance / Repetitions: 12km'), findsOneWidget);
    await tester.tap(find.text('Create Document'));
    await tester.pumpAndSettle();

    expect(result?.prefills, hasLength(1));
    expect(result?.prefills.single.name, 'Daily jog');
    expect(result?.prefills.single.values['Exercize'], 'Jog');
    expect(result?.prefills.single.values['Distance / Repetitions'], '12km');
    expect(result?.prefills.single.values['Duration'], '01:30:00');
    expect(result?.prefills.single.weekdays, <int>{DateTime.wednesday});
  });

  testWidgets('Triathlon template tracks endurance and strength fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateDocPage()));

    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    await _chooseTemplate(tester, 'triathlon_training_tracker_plus');

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
    await _scrollTemplateIntoView(tester, 'Customer Service');
    await _chooseTemplate(tester, 'customer_service');

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Workhours'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('money (USD)'), findsOneWidget);
    expect(find.text('Currency'), findsNothing);
    expect(find.text('Work done'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
}

Future<void> _scrollTemplateIntoView(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find
        .descendant(of: find.byType(Dialog), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseTemplate(WidgetTester tester, String fileName) async {
  await tester.tap(find.byKey(ValueKey('select-template-$fileName')));
  await tester.pumpAndSettle();
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

String? _fileNameSuffix(WidgetTester tester) {
  final field = tester.widget<TextField>(find.byType(TextField).first);
  return field.decoration?.suffixText;
}

Future<void> _pumpDraftHost(
  WidgetTester tester, {
  required ValueChanged<DocumentDraft?> onDraft,
  CreateDocInitialSetup? initialSetup,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final draft = await Navigator.of(context).push<DocumentDraft>(
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateDocPage(initialSetup: initialSetup),
                    ),
                  );
                  onDraft(draft);
                },
                child: const Text('Open creator'),
              ),
            ),
          );
        },
      ),
    ),
  );
}
