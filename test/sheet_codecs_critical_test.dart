import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter_test/flutter_test.dart';

import 'package:calcrow/core/sheet_type_logic/csv_codec.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';

import 'support/sheet_test_helpers.dart';

void main() {
  group('CSV codec', () {
    test('CSV parse/build roundtrip preserves schema and rows', () {
      final parsed = parseCsv(
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

      final reparsed = parseCsvBytes(CsvSheetCodec.buildBytes(updated));

      expect(reparsed.headers, ['name', 'date', 'notes']);
      expect(reparsed.valueTypes, ['text', 'date', 'text']);
      expect(reparsed.rows, [
        ['Alice', '2026-01-01', 'hello'],
        ['Bob', '2026-01-02', 'world'],
      ]);
    });

    test(
      'CSV with headers only can be parsed and persisted with first row',
      () {
        final parsed = parseCsv('Date,Hours,Notes\n');

        expect(parsed.headers, ['Date', 'Hours', 'Notes']);
        expect(parsed.valueTypes, ['date', 'decimal', 'text']);
        expect(parsed.rows, isEmpty);

        final updated = copySheetData(
          parsed,
          rows: const <List<String>>[
            <String>['2026-05-11', '8', 'first row'],
          ],
        );

        final reparsed = parseCsvBytes(CsvSheetCodec.buildBytes(updated));

        expect(reparsed.headers, ['Date', 'Hours', 'Notes']);
        expect(reparsed.rows, [
          ['2026-05-11', '8', 'first row'],
        ]);
      },
    );

    test(
      'CSV preserves delimiter and quotes cells that contain delimiters',
      () {
        final parsed = parseCsv(
          'Date;Hours;Notes\n'
          'date;decimal;text\n'
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

        final reparsed = parseCsvBytes(CsvSheetCodec.buildBytes(updated));
        expect(reparsed.csvDelimiter, ';');
        expect(reparsed.rows, [
          ['2026-05-11', '8', 'contains; delimiter'],
          ['2026-05-12', '7.5', 'contains "quote"'],
        ]);
      },
    );
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
          ['text', 'date', 'decimal'],
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
      expect(reparsed.valueTypes, ['text', 'date', 'decimal']);
      expect(reparsed.rows, [
        ['Alice', '2026-01-01', '8.5'],
        ['Bob', '2026-01-02', '7'],
      ]);
    });
  });
}

SimpleSheetData parseCsv(String content) {
  return parseCsvBytes(utf8Bytes(content));
}

SimpleSheetData parseCsvBytes(Uint8List bytes) {
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
