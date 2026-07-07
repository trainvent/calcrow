import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calcrow/core/sheet_type_logic/csv_codec.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_logic.dart';
import 'package:calcrow/core/sheet_type_logic/simple_type_hint_cache.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';

import 'support/sheet_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('Simple type logic', () {
    test('Integer and Float labels map to distinct numeric types', () {
      expect(SimpleSheetLogic.normalizeTypeLabel('Integer'), 'int');
      expect(SimpleSheetLogic.normalizeTypeLabel('Float'), 'float');
      expect(SimpleSheetLogic.isIntegerType('Integer'), isTrue);
      expect(SimpleSheetLogic.isIntegerType('Float'), isFalse);
      expect(SimpleSheetLogic.isDecimalType('Integer'), isFalse);
      expect(SimpleSheetLogic.isDecimalType('Float'), isTrue);
      expect(SimpleSheetLogic.normalizeTypeLabel('boolean'), 'boolean');
      expect(SimpleSheetLogic.looksLikeBooleanValue('TRUE'), isTrue);
      expect(SimpleSheetLogic.looksLikeBooleanValue('FALSE'), isTrue);
      expect(SimpleSheetLogic.looksLikeBooleanValue('yes'), isFalse);
    });
  });

  group('CSV codec', () {
    test('CSV parse/build roundtrip preserves schema and rows', () async {
      final parsed = await parseCsv(
        'name,date,notes\n'
        'text,date,text\n'
        'Alice,2026-01-01,hello\n',
      );

      expect(parsed.headers, ['name', 'date', 'notes']);
      expect(parsed.valueTypes, ['text', 'date', 'text']);
      expect(parsed.hasTypeRow, isTrue);
      expect(parsed.rows, [
        ['Alice', '2026-01-01', 'hello'],
      ]);

      final updated = copySheetData(
        parsed,
        rows: <List<String>>[
          ...parsed.rows,
          <String>['Bob', '2026-01-02', 'world'],
        ],
      );

      final reparsed = await parseCsvBytes(CsvSheetCodec.buildBytes(updated));

      expect(reparsed.headers, ['name', 'date', 'notes']);
      expect(reparsed.valueTypes, ['text', 'date', 'text']);
      expect(reparsed.rows, [
        ['Alice', '2026-01-01', 'hello'],
        ['Bob', '2026-01-02', 'world'],
      ]);
    });

    test(
      'CSV with headers only can be parsed and persisted with first row',
      () async {
        final parsed = await parseCsv('Date,Hours,Notes\n');

        expect(parsed.headers, ['Date', 'Hours', 'Notes']);
        expect(parsed.valueTypes, ['date', 'Float', 'text']);
        expect(parsed.rows, isEmpty);

        final updated = copySheetData(
          parsed,
          rows: const <List<String>>[
            <String>['2026-05-11', '8', 'first row'],
          ],
        );

        final reparsed = await parseCsvBytes(CsvSheetCodec.buildBytes(updated));

        expect(reparsed.headers, ['Date', 'Hours', 'Notes']);
        expect(reparsed.rows, [
          ['2026-05-11', '8', 'first row'],
        ]);
      },
    );

    test(
      'CSV preserves delimiter and quotes cells that contain delimiters',
      () async {
        final parsed = await parseCsv(
          'Date;Hours;Notes\n'
          'date;Float;text\n'
          '2026-05-11;8;plain\n',
        );

        expect(parsed.csvDelimiter, ';');

        final updated = copySheetData(
          parsed,
          rows: const <List<String>>[
            <String>['2026-05-11', '8', 'contains; delimiter'],
            <String>['2026-05-12', '7.5', 'contains "quote"'],
          ],
        );

        final encoded = String.fromCharCodes(CsvSheetCodec.buildBytes(updated));
        expect(encoded, contains('"contains; delimiter"'));
        expect(encoded, contains('"contains ""quote"""'));

        final reparsed = await parseCsvBytes(CsvSheetCodec.buildBytes(updated));
        expect(reparsed.csvDelimiter, ';');
        expect(reparsed.rows, [
          ['2026-05-11', '8', 'contains; delimiter'],
          ['2026-05-12', '7.5', 'contains "quote"'],
        ]);
      },
    );

    test('CSV boolean fields preserve TRUE and FALSE values', () async {
      final parsed = await parseCsv(
        'Date;RSVP;Notes\n'
        'date;boolean;text\n'
        '2026-05-11;TRUE;confirmed\n'
        '2026-05-12;FALSE;declined\n',
      );

      expect(parsed.valueTypes, ['date', 'boolean', 'text']);
      expect(parsed.rows, [
        ['2026-05-11', 'TRUE', 'confirmed'],
        ['2026-05-12', 'FALSE', 'declined'],
      ]);

      final reparsed = await parseCsvBytes(CsvSheetCodec.buildBytes(parsed));
      expect(reparsed.valueTypes, ['date', 'boolean', 'text']);
      expect(reparsed.rows, parsed.rows);
    });
  });

  group('XLSX codec', () {
    test(
      'XLSX with headers only can be parsed and persisted with first row',
      () {
        final parsed = parseXlsx(
          buildWorkbookBytes([
            ['name', 'date', 'notes'],
          ]),
        );

        expect(parsed.headers, ['name', 'date', 'notes']);
        expect(parsed.rows, isEmpty);

        final updated = copySheetData(
          parsed,
          rows: const <List<String>>[
            <String>['Bob', '2026-01-02', 'first row'],
          ],
        );

        final reparsed = parseXlsx(XlsxSheetCodec.buildBytes(updated));

        expect(reparsed.headers, ['name', 'date', 'notes']);
        expect(reparsed.rows, [
          ['Bob', '2026-01-02', 'first row'],
        ]);
      },
    );

    test('XLSX roundtrip preserves edited rows and inferred value types', () {
      final parsed = parseXlsx(
        buildWorkbookBytes([
          ['name', 'date', 'hours'],
          ['text', 'date', 'Float'],
          ['Alice', '2026-01-01', '8'],
        ]),
      );

      expect(parsed.headers, ['name', 'date', 'hours']);
      expect(parsed.valueTypes, ['text', 'date', 'int']);
      expect(parsed.rows, [
        ['Alice', '2026-01-01', '8'],
      ]);

      final updated = copySheetData(
        parsed,
        rows: const <List<String>>[
          <String>['Alice', '2026-01-01', '8.5'],
          <String>['Bob', '2026-01-02', '7'],
        ],
      );

      final reparsed = parseXlsx(XlsxSheetCodec.buildBytes(updated));

      expect(reparsed.headers, ['name', 'date', 'hours']);
      expect(reparsed.valueTypes, ['text', 'date', 'Float']);
      expect(reparsed.rows, [
        ['Alice', '2026-01-01', '8.5'],
        ['Bob', '2026-01-02', '7'],
      ]);
    });

    test('XLSX date rows are not mistaken for header labels', () {
      final parsed = parseXlsx(
        buildWorkbookBytes([
          ['Date', 'Start', 'End', 'Pause', 'Notes'],
          ['46210', '13:15:00', '17:25:00', '00:15:00', 'first'],
          ['2026-07-07', '09:00:00', '12:00:00', '00:10:00', 'second'],
        ]),
      );

      expect(parsed.headers, ['Date', 'Start', 'End', 'Pause', 'Notes']);
      expect(parsed.rows, [
        ['46210', '13:15:00', '17:25:00', '00:15:00', 'first'],
        ['2026-07-07', '09:00:00', '12:00:00', '00:10:00', 'second'],
      ]);
    });

    test('XLSX can be built from a fresh simple document draft', () {
      final workbook = excel_pkg.Excel.createExcel();
      final draft = SimpleSheetData(
        fileName: 'fresh.xlsx',
        path: null,
        format: SimpleFileFormat.xlsx,
        headers: const <String>['Date', 'Start', 'End', 'Notes'],
        valueTypes: const <String>['date', 'time', 'time', 'text'],
        readOnlyColumns: List<bool>.filled(4, false),
        rows: const <List<String>>[],
        workbook: workbook,
      );

      final parsed = parseXlsx(XlsxSheetCodec.buildBytes(draft));

      expect(parsed.headers, ['Date', 'Start', 'End', 'Notes']);
      expect(parsed.rows, isEmpty);
      expect(parsed.workbook, isNotNull);
    });

    test('XLSX parse reuses confirmed cached field types', () async {
      await SimpleTypeHintCache.rememberCsvTypes(
        fileName: 'cached.xlsx',
        path: '/tmp/cached.xlsx',
        valueTypes: const <String>['text', 'date', 'Float'],
      );

      final parsed = await SimpleSheetFileService.parse(
        bytes: buildWorkbookBytes([
          ['name', 'date', 'hours'],
        ]),
        fileName: 'cached.xlsx',
        path: '/tmp/cached.xlsx',
      );

      expect(parsed.valueTypes, ['text', 'date', 'Float']);
      expect(parsed.pendingTypeSelectionColumns, isEmpty);
    });

    test('XLSX boolean fields roundtrip as TRUE and FALSE', () {
      final draft = SimpleSheetData(
        fileName: 'guestlist.xlsx',
        path: null,
        format: SimpleFileFormat.xlsx,
        headers: const <String>['Date', 'RSVP', 'Notes'],
        valueTypes: const <String>['date', 'boolean', 'text'],
        readOnlyColumns: List<bool>.filled(3, false),
        rows: const <List<String>>[
          <String>['2026-05-11', 'TRUE', 'confirmed'],
          <String>['2026-05-12', 'FALSE', 'declined'],
        ],
        workbook: excel_pkg.Excel.createExcel(),
      );

      final reparsed = parseXlsx(XlsxSheetCodec.buildBytes(draft));

      expect(reparsed.valueTypes, ['date', 'boolean', 'text']);
      expect(reparsed.rows, [
        ['2026-05-11', 'TRUE', 'confirmed'],
        ['2026-05-12', 'FALSE', 'declined'],
      ]);
    });
  });
}

Future<SimpleSheetData> parseCsv(String content) {
  return parseCsvBytes(utf8Bytes(content));
}

Future<SimpleSheetData> parseCsvBytes(Uint8List bytes) {
  return CsvSheetCodec.parse(
    bytes: bytes,
    fileName: 'sample.csv',
    path: '/tmp/sample.csv',
  );
}

Uint8List buildWorkbookBytes(List<List<String>> rows) {
  final workbook = excel_pkg.Excel.createExcel();
  final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
  final sheet = workbook[sheetName];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    for (
      var columnIndex = 0;
      columnIndex < rows[rowIndex].length;
      columnIndex++
    ) {
      sheet
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: columnIndex,
              rowIndex: rowIndex,
            ),
          )
          .value = excel_pkg.TextCellValue(
        rows[rowIndex][columnIndex],
      );
    }
  }

  final encoded = workbook.encode();
  expect(encoded, isNotNull);
  return Uint8List.fromList(encoded!);
}

SimpleSheetData parseXlsx(Uint8List bytes) {
  return XlsxSheetCodec.parse(
    bytes: bytes,
    fileName: 'sample.xlsx',
    path: '/tmp/sample.xlsx',
  );
}
