import 'package:calcrow/app/widgets/select_page_dialogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns the selected compatible worksheet', (tester) async {
    String? selectedPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedPage = await showSelectPageDialogue(
                  context: context,
                  title: 'Choose a worksheet',
                  description: 'Compatible worksheets',
                  cancelLabel: 'Cancel',
                  detailsBuilder: (entryCount, headerRowNumber) =>
                      '$entryCount entries · Headers in row $headerRowNumber',
                  options: const [
                    SelectPageOption(
                      name: 'Archive 2025',
                      entryCount: 42,
                      headerRowNumber: 8,
                    ),
                  ],
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

    expect(find.text('Archive 2025'), findsOneWidget);
    expect(find.text('42 entries · Headers in row 8'), findsOneWidget);

    await tester.tap(find.text('Archive 2025'));
    await tester.pumpAndSettle();

    expect(selectedPage, 'Archive 2025');
  });

  testWidgets('plus action can return a newly created worksheet', (
    tester,
  ) async {
    String? selectedPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedPage = await showSelectPageDialogue(
                  context: context,
                  title: 'Choose a worksheet',
                  description: 'Compatible worksheets',
                  cancelLabel: 'Cancel',
                  detailsBuilder: (entryCount, headerRowNumber) => '',
                  options: const [
                    SelectPageOption(
                      name: 'April',
                      entryCount: 30,
                      headerRowNumber: 1,
                    ),
                  ],
                  createOptionTooltip: 'Create current month worksheet',
                  onCreateOption: () async => 'July',
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
    await tester.tap(find.byTooltip('Create current month worksheet'));
    await tester.pumpAndSettle();

    expect(selectedPage, 'July');
  });

  testWidgets('month setup allows blueprint reselection and renaming', (
    tester,
  ) async {
    CreateMonthSheetSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selection = await showCreateMonthSheetDialogue(
                  context: context,
                  title: 'Create monthly worksheet',
                  description: 'Review the suggested setup.',
                  blueprintLabel: 'Blueprint worksheet',
                  recommendedBlueprintLabel: 'Recommended: July',
                  newSheetNameLabel: 'New worksheet name',
                  requiredNameError: 'Enter a worksheet name.',
                  duplicateNameError: 'This name already exists.',
                  invalidNameError: 'This name is invalid.',
                  cancelLabel: 'Cancel',
                  createLabel: 'Create',
                  blueprintSheetNames: const ['June', 'July'],
                  existingSheetNames: const ['June', 'July'],
                  initialBlueprintSheetName: 'July',
                  initialNewSheetName: 'August',
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

    expect(find.text('Recommended: July'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'August'), findsOneWidget);

    await tester.tap(find.text('July').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('June').last);
    await tester.enterText(find.byType(TextFormField), 'August adjusted');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(selection?.sourceSheetName, 'June');
    expect(selection?.targetSheetName, 'August adjusted');
  });

  testWidgets('month setup rejects an existing worksheet name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCreateMonthSheetDialogue(
                context: context,
                title: 'Create monthly worksheet',
                description: 'Review the suggested setup.',
                blueprintLabel: 'Blueprint worksheet',
                recommendedBlueprintLabel: 'Recommended: July',
                newSheetNameLabel: 'New worksheet name',
                requiredNameError: 'Enter a worksheet name.',
                duplicateNameError: 'This name already exists.',
                invalidNameError: 'This name is invalid.',
                cancelLabel: 'Cancel',
                createLabel: 'Create',
                blueprintSheetNames: const ['July'],
                existingSheetNames: const ['July'],
                initialBlueprintSheetName: 'July',
                initialNewSheetName: 'August',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'july');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();

    expect(find.text('This name already exists.'), findsOneWidget);
    expect(find.text('Create monthly worksheet'), findsOneWidget);
  });
}
