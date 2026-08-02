import 'dart:typed_data';

import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:calcrow/core/sheet_type_logic/ods_codec.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';
import 'package:calcrow/core/theme/app_text_styles.dart';
import 'package:calcrow/features/home/editing/selection_page.dart';
import 'package:calcrow/features/home/editing/editing_pages/editing_page_base.dart';
import 'package:calcrow/features/home/sheet/sheet_preview_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart' as excel_pkg;

void main() {
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('selection page owns the selector setup surface', (tester) async {
    await _pumpWidget(
      tester,
      container,
      const MaterialApp(home: Scaffold(body: SelectionPage())),
    );
    await tester.pump();

    expect(find.text('Selector'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('selector-page-title')))
          .style,
      AppTextStyles.pageTitle,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('selector-page-title')),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('selector-app-icon')), findsOneWidget);
    expect(find.text('Opening Mode'), findsOneWidget);
    expect(find.text('Choose Document'), findsOneWidget);
    expect(find.text('Create Document'), findsOneWidget);
    expect(find.text('Editor'), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
  });

  testWidgets('embedded editor keeps surrounding bottom navigation visible', (
    tester,
  ) async {
    await _pumpWidget(tester, container, const _EmbeddedEditorHarness());
    await tester.pump();
    await tester.pump();

    expect(find.text('worklog.csv'), findsWidgets);
    expect(find.text('Current File'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.byKey(const ValueKey('document-save-status')), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.accessibility_new_rounded), findsNothing);
    expect(find.byKey(const ValueKey('editor-overflow-menu')), findsOneWidget);
    expect(find.text('Adjust'), findsNothing);
    expect(find.text('Open'), findsNothing);
    expect(find.byKey(_EmbeddedEditorHarness.bottomNavKey), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Field formats'), findsOneWidget);
    expect(find.text('Define prefills'), findsOneWidget);
    expect(find.text('Verbose mode'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    final fieldFormatsLeft = tester.getTopLeft(find.text('Field formats')).dx;
    final verboseLeft = tester.getTopLeft(find.text('Verbose mode')).dx;
    expect((fieldFormatsLeft - verboseLeft).abs(), lessThan(1));

    await tester.tap(find.byKey(const ValueKey('editor-menu-details')));
    await tester.pumpAndSettle();
    expect(find.text('Current File'), findsOneWidget);
    expect(find.text('worklog.csv - new row'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('/tmp/worklog.csv'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-menu-verbose')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Hide field types'));
    await tester.pump();
    expect(find.byIcon(Icons.accessibility_new_rounded), findsNothing);
  });

  testWidgets('editor menu can switch between XLSX worksheets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sheetData = _multiSheetXlsxData();

    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: sheetData,
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/months.xlsx',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Select Page'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-menu-select-page')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a worksheet'), findsOneWidget);
    expect(find.text('July'), findsOneWidget);
    expect(find.text('August'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'August'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Choose a worksheet'), findsNothing);
    expect(find.textContaining('Import failed'), findsNothing);
    expect(container.read(sheetPreviewProvider).sheetName, 'August');
    await _openEditorDetails(tester);
    expect(find.text('Active sheet: August'), findsOneWidget);
  });

  testWidgets('editor menu can switch between ODS worksheets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _multiSheetOdsData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/calcrow_sheet_2026.ods',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-menu-select-page')));
    await tester.pumpAndSettle();
    expect(find.text('July'), findsOneWidget);
    expect(find.text('August'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'July'));
    await tester.pumpAndSettle();
    expect(container.read(sheetPreviewProvider).sheetName, 'July');
    await _openEditorDetails(tester);
    expect(find.text('Active sheet: July'), findsOneWidget);
  });

  testWidgets('single-page XLSX can create a named page from its blueprint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _singleNonMonthXlsxData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/records.xlsx',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Select Page'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor-menu-select-page')));
    await tester.pumpAndSettle();

    expect(find.text('Records'), findsOneWidget);
    await tester.tap(find.byTooltip('Create worksheet'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, ''), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Archive');
    await tester.tap(find.widgetWithText(FilledButton, 'Create worksheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(sheetPreviewProvider).sheetName, 'Archive');
  });

  testWidgets('single-page ODS always offers Select Page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _singleNonMonthOdsData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/records.ods',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Select Page'), findsOneWidget);
  });

  testWidgets('editor back action returns to get started in place', (
    tester,
  ) async {
    await _pumpWidget(tester, container, const _EmbeddedEditorHarness());
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('editor-app-icon')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('editor-page-title')))
          .style,
      AppTextStyles.pageTitle,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('editor-page-title')))
          .style
          ?.fontSize,
      AppTextStyles.pageTitleFontSize,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('editor-page-title')),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
    final editorTitlePosition = tester.getTopLeft(
      find.byKey(const ValueKey('editor-page-title')),
    );
    final editorTitleCenter = tester.getCenter(
      find.byKey(const ValueKey('editor-page-title')),
    );
    final overflowIconCenter = tester.getCenter(
      find.byIcon(Icons.more_vert_rounded),
    );
    expect((editorTitleCenter.dy - overflowIconCenter.dy).abs(), lessThan(1));
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Selector'), findsOneWidget);
    final selectorTitlePosition = tester.getTopLeft(
      find.byKey(const ValueKey('selector-page-title')),
    );
    expect((editorTitlePosition - selectorTitlePosition).distance, lessThan(1));
    expect(find.text('Opening Mode'), findsOneWidget);
    expect(find.text('worklog.csv'), findsNothing);
    expect(find.byKey(_EmbeddedEditorHarness.bottomNavKey), findsOneWidget);
  });

  testWidgets('saving an open-ended row stays on the saved row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'steady');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await _openEditorDetails(tester);
    expect(find.textContaining('row 1'), findsOneWidget);
    expect(find.text('steady'), findsOneWidget);
    expect(find.textContaining('new row'), findsNothing);
  });

  testWidgets('autosave failure stays red and retry reports the error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _FailingSheetPersistenceService();
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: persistence,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_saveStatusIcon(tester).color, Colors.green);
    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'draft');
    await tester.pump();
    expect(_saveStatusIcon(tester).color, isNot(Colors.green));

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(persistence.attempts, 1);
    expect(_saveStatusIcon(tester).color, isNot(Colors.green));
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('document-save-status')));
    await tester.pumpAndSettle();
    expect(persistence.attempts, 2);
    expect(_saveStatusIcon(tester).color, isNot(Colors.green));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('new open-ended row warns before replacing edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'draft');
    await tester.ensureVisible(find.text('New'));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.text('Unsaved row edits'), findsOneWidget);
    expect(
      find.text('Save the current row before starting a new one?'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsWidgets);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('draft'), findsOneWidget);
  });

  testWidgets('pick row uses sheet rows without editable text columns', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _timeOnlySheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/time-only.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Pick'));
    await tester.pump();

    expect(
      find.text('Pick Row needs at least one editable text column.'),
      findsNothing,
    );
    expect(container.read(sheetPreviewRowPickProvider), isNotNull);
    expect(
      container.read(sheetPreviewRowPickProvider)!.selectableRowIndexes,
      <int>{0, 1},
    );

    container.read(sheetPreviewActionsProvider.notifier).pickRow(1);
    await tester.pump();

    await _openEditorDetails(tester);
    expect(find.textContaining('row 2'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
  });

  testWidgets('date preference unlocks dates and permits any dated row', (
    tester,
  ) async {
    container.dispose();
    container = ProviderContainer(
      overrides: [initialAllowAnyDateProvider.overrideWithValue(true)],
    );
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _pastDiarySheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/diary.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBased,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pick'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(find.textContaining('Diary can only open'), findsNothing);
    expect(
      (tester.getCenter(find.widgetWithText(TextField, 'Date')).dy -
              tester
                  .getCenter(find.byKey(const ValueKey('document-save-status')))
                  .dy)
          .abs(),
      lessThan(1),
    );

    await tester.tap(find.text('Pick'));
    await tester.pump();

    final request = container.read(sheetPreviewRowPickProvider);
    expect(request, isNotNull);
    expect(request!.selectableRowIndexes, <int>{0, 1});
    expect(request.subtitle, 'Choose any row from the sheet.');
  });

  testWidgets('namelist opening picks entries from sheet rows', (tester) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _namelistSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/people.csv',
            ),
            initialOpenMode: EditorOpenMode.textBased,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Open column entry'), findsNothing);
    expect(container.read(sheetPreviewRowPickProvider), isNotNull);
    expect(container.read(sheetPreviewRowPickProvider)!.title, 'Pick Entry');
    expect(
      container.read(sheetPreviewRowPickProvider)!.selectableRowIndexes,
      <int>{0, 1},
    );

    container.read(sheetPreviewActionsProvider.notifier).pickRow(1);
    await tester.pump();

    await _openEditorDetails(tester);
    expect(find.textContaining('row 2'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('logbook rejects cached schemas without first date field', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _cachedNonDateFirstColumnSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/non-date-first.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Cached field types do not match Logbook.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('namelist rejects cached schemas without first text field', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _cachedNonTextFirstColumnSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/non-text-first.csv',
            ),
            initialOpenMode: EditorOpenMode.textBased,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Cached field types do not match Namelist.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
    expect(container.read(sheetPreviewRowPickProvider), isNull);
  });

  testWidgets('logbook adjust keeps first field locked to date', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _worklogSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/worklog.csv',
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adjust-field-formats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('field-type-options-0-date')), findsOne);
    expect(
      find.byKey(const ValueKey('field-type-options-0-text')),
      findsNothing,
    );
  });

  testWidgets('namelist adjust keeps first field locked to text', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      container,
      MaterialApp(
        home: Scaffold(
          body: EditingPage(
            initialSheetData: _namelistSheetData(),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: '/tmp/people.csv',
            ),
            initialOpenMode: EditorOpenMode.textBased,
            sheetPersistenceService: _FakeSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    container.read(sheetPreviewActionsProvider.notifier).cancelRowPick();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adjust-field-formats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('field-type-options-0-text')), findsOne);
    expect(
      find.byKey(const ValueKey('field-type-options-0-date')),
      findsNothing,
    );
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) {
  return tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: child),
  );
}

Future<void> _openEditorDetails(WidgetTester tester) async {
  final menu = find.byKey(const ValueKey('editor-overflow-menu'));
  await tester.ensureVisible(menu);
  await tester.pump();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('editor-menu-details')));
  await tester.pumpAndSettle();
}

Icon _saveStatusIcon(WidgetTester tester) {
  return tester.widget<Icon>(
    find.descendant(
      of: find.byKey(const ValueKey('document-save-status')),
      matching: find.byType(Icon),
    ),
  );
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

SheetData _worklogSheetData() {
  return const SheetData(
    fileName: 'worklog.csv',
    path: '/tmp/worklog.csv',
    format: SheetFileFormat.csv,
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

SheetData _pastDiarySheetData() {
  final today = DateTime.now();
  String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  return SheetData(
    fileName: 'diary.csv',
    path: '/tmp/diary.csv',
    format: SheetFileFormat.csv,
    headers: const <String>['Date', 'Notes'],
    valueTypes: const <String>['date', 'text'],
    readOnlyColumns: const <bool>[false, false],
    rows: <List<String>>[
      <String>[format(today.subtract(const Duration(days: 2))), 'Earlier'],
      <String>[format(today.subtract(const Duration(days: 1))), 'Yesterday'],
    ],
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

SheetData _multiSheetXlsxData() {
  final workbook = excel_pkg.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet()!;
  workbook.rename(defaultSheet, 'July');
  final july = workbook['July'];
  final today = _todayIsoDate();
  const headers = <String>['Date', 'Notes'];
  for (var column = 0; column < headers.length; column++) {
    july
        .cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: 0,
          ),
        )
        .value = excel_pkg.TextCellValue(
      headers[column],
    );
  }
  july.cell(excel_pkg.CellIndex.indexByString('A2')).value =
      excel_pkg.TextCellValue(today);
  july.cell(excel_pkg.CellIndex.indexByString('B2')).value =
      excel_pkg.TextCellValue('July entry');
  workbook.copy('July', 'August');
  workbook['August'].cell(excel_pkg.CellIndex.indexByString('B2')).value =
      excel_pkg.TextCellValue('August entry');

  final parsed = XlsxSheetCodec.parse(
    bytes: Uint8List.fromList(workbook.encode()!),
    fileName: 'months.xlsx',
    path: '/tmp/months.xlsx',
    sheetName: 'July',
  );
  return SheetData(
    fileName: parsed.fileName,
    path: parsed.path,
    format: parsed.format,
    headers: parsed.headers,
    valueTypes: const <String>['date', 'text'],
    readOnlyColumns: parsed.readOnlyColumns,
    rows: parsed.rows,
    pendingTypeSelectionColumns: const <int>[],
    hasCachedValueTypes: true,
    headerRowIndex: parsed.headerRowIndex,
    startColumnIndex: parsed.startColumnIndex,
    xlsxSheetName: parsed.xlsxSheetName,
    workbook: parsed.workbook,
  );
}

SheetData _singleNonMonthXlsxData() {
  final workbook = excel_pkg.Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet()!;
  workbook.rename(defaultSheet, 'Records');
  final sheet = workbook['Records'];
  sheet.cell(excel_pkg.CellIndex.indexByString('A1')).value =
      excel_pkg.TextCellValue('Date');
  sheet.cell(excel_pkg.CellIndex.indexByString('B1')).value =
      excel_pkg.TextCellValue('Notes');
  sheet.cell(excel_pkg.CellIndex.indexByString('A2')).value =
      excel_pkg.TextCellValue(_todayIsoDate());
  sheet.cell(excel_pkg.CellIndex.indexByString('B2')).value =
      excel_pkg.TextCellValue('Entry');
  final parsed = XlsxSheetCodec.parse(
    bytes: Uint8List.fromList(workbook.encode()!),
    fileName: 'records.xlsx',
    path: '/tmp/records.xlsx',
    sheetName: 'Records',
  );
  return SheetData(
    fileName: parsed.fileName,
    path: parsed.path,
    format: parsed.format,
    headers: parsed.headers,
    valueTypes: const ['date', 'text'],
    readOnlyColumns: parsed.readOnlyColumns,
    rows: parsed.rows,
    hasCachedValueTypes: true,
    xlsxSheetName: parsed.xlsxSheetName,
    workbook: parsed.workbook,
  );
}

SheetData _singleNonMonthOdsData() {
  final draft = SheetData(
    fileName: 'records.ods',
    path: '/tmp/records.ods',
    format: SheetFileFormat.ods,
    headers: const ['Date', 'Notes'],
    valueTypes: const ['date', 'text'],
    readOnlyColumns: const [false, false],
    rows: <List<String>>[
      <String>[_todayIsoDate(), 'Entry'],
    ],
    xlsxSheetName: 'Records',
  );
  return OdsSheetCodec.parse(
    bytes: OdsSheetCodec.buildBytes(draft),
    fileName: draft.fileName,
    path: draft.path,
    sheetName: 'Records',
  );
}

SheetData _multiSheetOdsData() {
  final draft = SheetData(
    fileName: 'calcrow_sheet_2026.ods',
    path: '/tmp/calcrow_sheet_2026.ods',
    format: SheetFileFormat.ods,
    headers: const ['Date', 'Notes'],
    valueTypes: const ['date', 'text'],
    readOnlyColumns: const [false, false],
    rows: const [
      ['2026-07-31', 'July entry'],
    ],
    xlsxSheetName: 'July',
  );
  final created = OdsSheetCodec.createCurrentMonthSheet(
    bytes: OdsSheetCodec.buildBytes(draft),
    fileName: draft.fileName,
    path: draft.path,
    now: DateTime(2026, 8, 2),
  );
  return SheetData(
    fileName: created.fileName,
    path: created.path,
    format: created.format,
    headers: created.headers,
    valueTypes: const ['date', 'text'],
    readOnlyColumns: created.readOnlyColumns,
    rows: created.rows,
    pendingTypeSelectionColumns: const [],
    hasCachedValueTypes: true,
    xlsxSheetName: created.xlsxSheetName,
    sourceBytes: created.sourceBytes,
  );
}

SheetData _timeOnlySheetData() {
  final today = _todayIsoDate();
  return SheetData(
    fileName: 'time-only.csv',
    path: '/tmp/time-only.csv',
    format: SheetFileFormat.csv,
    headers: const <String>['Date', 'Start', 'End'],
    valueTypes: const <String>['date', 'time', 'time'],
    readOnlyColumns: const <bool>[true, false, false],
    rows: <List<String>>[
      <String>[today, '09:00', '10:00'],
      <String>[today, '11:00', '12:00'],
    ],
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

SheetData _namelistSheetData() {
  return const SheetData(
    fileName: 'people.csv',
    path: '/tmp/people.csv',
    format: SheetFileFormat.csv,
    headers: <String>['Name', 'Score'],
    valueTypes: <String>['text', 'number'],
    readOnlyColumns: <bool>[false, false],
    rows: <List<String>>[
      <String>['Alice', '7'],
      <String>['Bob', '9'],
    ],
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

SheetData _cachedNonDateFirstColumnSheetData() {
  final today = _todayIsoDate();
  return SheetData(
    fileName: 'non-date-first.csv',
    path: '/tmp/non-date-first.csv',
    format: SheetFileFormat.csv,
    headers: const <String>['Name', 'Entry Date'],
    valueTypes: const <String>['text', 'date'],
    readOnlyColumns: const <bool>[false, false],
    rows: <List<String>>[
      <String>['Bob', today],
    ],
    hasCachedValueTypes: true,
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

SheetData _cachedNonTextFirstColumnSheetData() {
  final today = _todayIsoDate();
  return SheetData(
    fileName: 'non-text-first.csv',
    path: '/tmp/non-text-first.csv',
    format: SheetFileFormat.csv,
    headers: const <String>['Entry Date', 'Name'],
    valueTypes: const <String>['date', 'text'],
    readOnlyColumns: const <bool>[false, false],
    rows: <List<String>>[
      <String>[today, 'Bob'],
    ],
    hasCachedValueTypes: true,
    csvDelimiter: ',',
    hasTypeRow: false,
    headerRowIndex: 0,
    startColumnIndex: 0,
  );
}

String _todayIsoDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _FakeSheetPersistenceService extends SheetPersistenceService {
  @override
  Future<PersistResult> persistBytes(PersistRequest request) async {
    return PersistResult(
      locationLabel: request.existingPath ?? '/tmp/worklog.csv',
      overwroteExistingFile: true,
      usedAppDocumentsFallback: false,
      savedPath: request.existingPath ?? '/tmp/worklog.csv',
      resolvedFileName: request.fileName,
    );
  }
}

class _FailingSheetPersistenceService extends SheetPersistenceService {
  int attempts = 0;

  @override
  Future<PersistResult> persistBytes(PersistRequest request) async {
    attempts += 1;
    throw StateError('Test write failed.');
  }
}
