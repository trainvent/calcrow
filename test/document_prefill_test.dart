import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/core/prefills/document_prefill_cache.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/features/home/editing/editing_pages/editing_page_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('prefill serialization preserves values and weekday availability', () {
    const prefill = DocumentPrefill(
      name: 'Intervals',
      values: <String, String>{'Exercize': 'Intervals', 'Duration': '45'},
      weekdays: <int>{DateTime.wednesday},
    );

    final decoded = DocumentPrefill.fromMap(prefill.toMap());

    expect(decoded?.name, 'Intervals');
    expect(decoded?.values['Duration'], '45');
    expect(decoded?.isAvailableOn(DateTime(2026, 7, 22)), isTrue);
    expect(decoded?.isAvailableOn(DateTime(2026, 7, 23)), isFalse);
  });

  test('filename cache key is stable across case and surrounding spaces', () {
    expect(
      documentPrefillKey(' Dynamic_Workout.XLSX '),
      documentPrefillKey('dynamic_workout.xlsx'),
    );
  });

  test(
    'filename lookup migrates a prefill from an old Android SAF key',
    () async {
      const fileName = 'dynamic_workout_tracker.xlsx';
      await DocumentPrefillCache.write(
        localPrefillDocumentKey(
          'content://provider/tree/primary%3ADocuments%2F$fileName',
        ),
        const <DocumentPrefill>[
          DocumentPrefill(
            name: 'Morning jog',
            values: <String, String>{'Exercize': 'Running'},
          ),
        ],
      );

      final prefills = await DocumentPrefillCache.readForFileName(
        fileName,
        legacyDocumentKeys: const <String>[
          'local:content://provider/document/another-id',
        ],
      );

      expect(prefills.single.name, 'Morning jog');
      expect(
        await DocumentPrefillCache.read(documentPrefillKey(fileName)),
        hasLength(1),
      );
    },
  );

  testWidgets('simple editor shows matching prefills and applies all values', (
    tester,
  ) async {
    const path = '/tmp/dynamic_workout_tracker.csv';
    final unavailableWeekday = (DateTime.now().weekday % 7) + 1;
    await DocumentPrefillCache.write(
      localPrefillDocumentKey(path),
      <DocumentPrefill>[
        const DocumentPrefill(
          name: 'Daily jog',
          values: <String, String>{
            'Exercize': 'Jog',
            'Distance / Repetitions': '12km',
          },
        ),
        DocumentPrefill(
          name: 'Intervals',
          values: const <String, String>{'Exercize': 'Intervals'},
          weekdays: <int>{unavailableWeekday},
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EditingPage(
            initialSheetData: const SheetData(
              fileName: 'dynamic_workout_tracker.csv',
              path: path,
              format: SheetFileFormat.csv,
              headers: <String>[
                'Date',
                'Exercize',
                'Distance / Repetitions',
                'Duration',
                'Notes',
              ],
              valueTypes: <String>['date', 'text', 'text', 'duration', 'text'],
              readOnlyColumns: <bool>[false, false, false, false, false],
              rows: <List<String>>[],
              csvDelimiter: ',',
              hasTypeRow: false,
              headerRowIndex: 0,
              startColumnIndex: 0,
            ),
            initialDocumentTarget: const LocalEditorDocumentTarget(
              existingPath: path,
            ),
            initialOpenMode: EditorOpenMode.dateBasedOpenEnd,
            sheetPersistenceService: _NoopSheetPersistenceService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily jog'), findsOneWidget);
    expect(find.text('Intervals'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(
      find.text('Choose an option to fill its saved values into this row.'),
      findsNothing,
    );
    final labelCenter = tester.getCenter(find.text('Prefill'));
    final optionCenter = tester.getCenter(find.text('Daily jog'));
    expect((labelCenter.dy - optionCenter.dy).abs(), lessThan(8));
    final prefillButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('document-prefill-Daily jog')),
    );
    final clearButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('clear-document-input-fields')),
    );
    final clearCenter = tester.getCenter(
      find.byKey(const ValueKey('clear-document-input-fields')),
    );
    final saveCenter = tester.getCenter(
      find.byKey(const ValueKey('document-save-status')),
    );
    expect(prefillButton.style?.backgroundColor, isNull);
    expect(clearButton.style?.backgroundColor, isNull);
    expect((clearCenter.dy - saveCenter.dy).abs(), lessThan(1));
    expect(saveCenter.dx, greaterThan(clearCenter.dx));
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.byIcon(Icons.brush_outlined), findsNothing);
    await tester.tap(find.byKey(const ValueKey('document-prefill-Daily jog')));
    await tester.pump();

    expect(_fieldValue(tester, 'Exercize'), 'Jog');
    expect(_fieldValue(tester, 'Distance / Repetitions'), '12km');

    final dateBeforeClearing = _fieldValue(tester, 'Date');
    await tester.tap(find.byKey(const ValueKey('clear-document-input-fields')));
    await tester.pump();

    expect(_fieldValue(tester, 'Date'), dateBeforeClearing);
    expect(_fieldValue(tester, 'Exercize'), isEmpty);
    expect(_fieldValue(tester, 'Distance / Repetitions'), isEmpty);

    await tester.tap(find.byKey(const ValueKey('editor-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adjust-prefills')));
    await tester.pumpAndSettle();

    expect(find.text('Define prefills'), findsOneWidget);
    expect(find.text('Daily jog'), findsOneWidget);
    expect(find.text('Intervals'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete prefill').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Delete prefill').first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Daily jog'), findsNothing);
    expect(find.text('Prefill'), findsNothing);
    expect(
      await DocumentPrefillCache.read(
        documentPrefillKey('dynamic_workout_tracker.csv'),
      ),
      isEmpty,
    );
  });
}

String _fieldValue(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
  );
  return field.controller?.text ?? '';
}

class _NoopSheetPersistenceService extends SheetPersistenceService {}
