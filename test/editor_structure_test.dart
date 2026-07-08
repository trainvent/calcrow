import 'package:calcrow/core/data/services/simple_sheet_persistence_service.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/features/home/editing/selection_page.dart';
import 'package:calcrow/features/home/editing/simple/editing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection page owns the get started setup surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SelectionPage())),
    );
    await tester.pump();

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Opening Mode'), findsOneWidget);
    expect(find.text('Choose Document'), findsOneWidget);
    expect(find.text('Create Document'), findsOneWidget);
    expect(find.text('Editor'), findsNothing);
  });

  testWidgets('embedded editor keeps surrounding bottom navigation visible', (
    tester,
  ) async {
    await tester.pumpWidget(const _EmbeddedEditorHarness());
    await tester.pump();
    await tester.pump();

    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Current File'), findsOneWidget);
    expect(find.text('Save Row'), findsOneWidget);
    expect(find.byKey(_EmbeddedEditorHarness.bottomNavKey), findsOneWidget);
  });

  testWidgets('editor back action returns to get started in place', (
    tester,
  ) async {
    await tester.pumpWidget(const _EmbeddedEditorHarness());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Opening Mode'), findsOneWidget);
    expect(find.text('Editor'), findsNothing);
    expect(find.byKey(_EmbeddedEditorHarness.bottomNavKey), findsOneWidget);
  });

  testWidgets('saving a simple open-ended row stays on the saved row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSimpleSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'steady');
    await tester.tap(find.text('Save Row'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Editing row 1 of 1'), findsOneWidget);
    expect(find.text('steady'), findsOneWidget);
    expect(find.textContaining('Editing new row at bottom'), findsNothing);
  });

  testWidgets('new simple open-ended row warns before replacing edits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSimpleSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'draft');
    await tester.tap(find.text('New Row'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved row edits'), findsOneWidget);
    expect(
      find.text('Save the current row before starting a new one?'),
      findsOneWidget,
    );
    expect(find.text('Save first'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('draft'), findsOneWidget);
  });
}

class _EmbeddedEditorHarness extends StatefulWidget {
  const _EmbeddedEditorHarness();

  static const bottomNavKey = Key('test-bottom-nav');

  @override
  State<_EmbeddedEditorHarness> createState() => _EmbeddedEditorHarnessState();
}

class _EmbeddedEditorHarnessState extends State<_EmbeddedEditorHarness> {
  bool _showEditor = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: _showEditor
              ? EditingPage(
                  initialSheetData: _worklogSheetData(),
                  initialDocumentTarget: const LocalEditorDocumentTarget(
                    existingPath: '/tmp/worklog.csv',
                  ),
                  initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
                  showBackToSelection: true,
                  onBackToSelection: () {
                    setState(() => _showEditor = false);
                  },
                )
              : const SelectionPage(),
        ),
        bottomNavigationBar: const SizedBox(
          key: _EmbeddedEditorHarness.bottomNavKey,
          height: 64,
          child: Center(child: Text('Row  Sheet  Settings')),
        ),
      ),
    );
  }
}

SimpleSheetData _worklogSheetData() {
  return const SimpleSheetData(
    fileName: 'worklog.csv',
    path: '/tmp/worklog.csv',
    format: SimpleFileFormat.csv,
    headers: <String>['Date', 'Start', 'End', 'Pause', 'Notes'],
    valueTypes: <String>['date', 'time', 'time', 'duration', 'text'],
    readOnlyColumns: <bool>[true, false, false, false, false],
    rows: <List<String>>[],
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

class _FakeSimpleSheetPersistenceService extends SimpleSheetPersistenceService {
  @override
  Future<SimplePersistResult> persistBytes(SimplePersistRequest request) async {
    return SimplePersistResult(
      locationLabel: request.existingPath ?? '/tmp/worklog.csv',
      overwroteExistingFile: true,
      usedAppDocumentsFallback: false,
      savedPath: request.existingPath ?? '/tmp/worklog.csv',
      resolvedFileName: request.fileName,
    );
  }
}
