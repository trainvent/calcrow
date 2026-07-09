import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calcrow/core/sheet_type_logic/csv_codec.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/type_hint_cache.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';

import 'support/sheet_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('Sheet type logic', () {
    test('Integer and Float labels map to distinct numeric types', () {
      expect(FieldTypeGuesser.normalizeTypeLabel('Integer'), 'int');
      expect(FieldTypeGuesser.normalizeTypeLabel('float'), 'float');
      expect(FieldTypeGuesser.isIntegerType('Integer'), isTrue);
      expect(FieldTypeGuesser.isIntegerType('float'), isFalse);
      expect(FieldTypeGuesser.isDecimalType('Integer'), isFalse);
      expect(FieldTypeGuesser.isDecimalType('float'), isTrue);
      expect(FieldTypeGuesser.normalizeTypeLabel('boolean'), 'boolean');
      expect(FieldTypeGuesser.looksLikeBooleanValue('TRUE'), isTrue);
      expect(FieldTypeGuesser.looksLikeBooleanValue('FALSE'), isTrue);
      expect(FieldTypeGuesser.looksLikeBooleanValue('yes'), isFalse);
    });

    test('header guesses use field-aware tokens', () {
      expect(FieldTypeGuesser.typeFromHeader('Date'), 'date');
      expect(FieldTypeGuesser.typeFromHeader('Entry Date'), 'date');
      expect(FieldTypeGuesser.typeFromHeader('Endurance'), isNull);
      expect(FieldTypeGuesser.typeFromHeader('Hours'), 'float');
      expect(FieldTypeGuesser.typeFromHeader('Sets'), 'int');
      expect(FieldTypeGuesser.typeFromHeader('RSVP'), 'boolean');
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
        expect(parsed.valueTypes, ['date', 'float', 'text']);
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
          ['text', 'date', 'float'],
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
      expect(reparsed.valueTypes, ['text', 'date', 'float']);
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

    test('XLSX can be built from a fresh sheet draft', () {
      final workbook = excel_pkg.Excel.createExcel();
      final draft = SheetData(
        fileName: 'fresh.xlsx',
        path: null,
        format: SheetFileFormat.xlsx,
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
      await TypeHintCache.rememberCsvTypes(
        fileName: 'cached.xlsx',
        path: '/tmp/cached.xlsx',
        valueTypes: const <String>['text', 'date', 'float'],
      );

      final parsed = await SheetFileService.parse(
        bytes: buildWorkbookBytes([
          ['name', 'date', 'hours'],
        ]),
        fileName: 'cached.xlsx',
        path: '/tmp/cached.xlsx',
      );

      expect(parsed.valueTypes, ['text', 'date', 'float']);
      expect(parsed.pendingTypeSelectionColumns, isEmpty);
    });

    test('XLSX boolean fields roundtrip as TRUE and FALSE', () {
      final draft = SheetData(
        fileName: 'guestlist.xlsx',
        path: null,
        format: SheetFileFormat.xlsx,
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

Future<SheetData> parseCsv(String content) {
  return parseCsvBytes(utf8Bytes(content));
}

Future<SheetData> parseCsvBytes(Uint8List bytes) {
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

SheetData parseXlsx(Uint8List bytes) {
  return XlsxSheetCodec.parse(
    bytes: bytes,
    fileName: 'sample.xlsx',
    path: '/tmp/sample.xlsx',
  );
}
