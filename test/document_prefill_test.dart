import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/core/prefills/document_prefill_cache.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/features/home/editing/editing_pages/editing_page_base.dart';
import 'package:flutter/material.dart';
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
      MaterialApp(
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
            readOnlyColumns: <bool>[true, false, false, false, false],
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
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily jog'), findsOneWidget);
    expect(find.text('Intervals'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('document-prefill-Daily jog')));
    await tester.pump();

    expect(_fieldValue(tester, 'Exercize'), 'Jog');
    expect(_fieldValue(tester, 'Distance / Repetitions'), '12km');
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
