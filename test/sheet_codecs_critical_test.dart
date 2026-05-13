import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter_test/flutter_test.dart';

import 'package:calcrow/core/sheet_type_logic/csv_codec.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';

void main() {
  group('Critical sheet codec flows', () {
    test('CSV parse/build roundtrip preserves schema and rows', () {
      final sourceBytes = Uint8List.fromList(
        utf8.encode(
          'name,date,notes\n'
          'text,date,text\n'
          'Alice,2026-01-01,hello\n',
        ),
      );

      final parsed = CsvSheetCodec.parse(
        bytes: sourceBytes,
        fileName: 'sample.csv',
        path: '/tmp/sample.csv',
      );

      expect(parsed.headers, ['name', 'date', 'notes']);
      expect(parsed.rows.length, 1);

      final updated = SimpleSheetData(
        fileName: parsed.fileName,
        path: parsed.path,
        format: parsed.format,
        headers: parsed.headers,
        valueTypes: parsed.valueTypes,
        readOnlyColumns: parsed.readOnlyColumns,
        rows: <List<String>>[
          ...parsed.rows,
          <String>['Bob', '2026-01-02', 'world'],
        ],
        pendingTypeSelectionColumns: parsed.pendingTypeSelectionColumns,
        csvDelimiter: parsed.csvDelimiter,
        hasTypeRow: parsed.hasTypeRow,
        headerRowIndex: parsed.headerRowIndex,
        startColumnIndex: parsed.startColumnIndex,
        sourceBytes: parsed.sourceBytes,
      );

      final rebuilt = CsvSheetCodec.buildBytes(updated);
      final reparsed = CsvSheetCodec.parse(
        bytes: rebuilt,
        fileName: 'sample.csv',
        path: '/tmp/sample.csv',
      );

      expect(reparsed.headers, ['name', 'date', 'notes']);
      expect(reparsed.rows.length, 2);
      expect(reparsed.rows[0], ['Alice', '2026-01-01', 'hello']);
      expect(reparsed.rows[1], ['Bob', '2026-01-02', 'world']);
    });

    test(
      'CSV with headers only can be parsed and persisted with first row',
      () {
        final sourceBytes = Uint8List.fromList(
          utf8.encode('Date,Hours,Notes\n'),
        );

        final parsed = CsvSheetCodec.parse(
          bytes: sourceBytes,
          fileName: 'open_end.csv',
          path: '/tmp/open_end.csv',
        );

        expect(parsed.headers, ['Date', 'Hours', 'Notes']);
        expect(parsed.valueTypes, ['date', 'decimal', 'text']);
        expect(parsed.rows, isEmpty);

        final updated = SimpleSheetData(
          fileName: parsed.fileName,
          path: parsed.path,
          format: parsed.format,
          headers: parsed.headers,
          valueTypes: parsed.valueTypes,
          readOnlyColumns: parsed.readOnlyColumns,
          rows: const <List<String>>[
            <String>['2026-05-11', '8', 'first row'],
          ],
          pendingTypeSelectionColumns: parsed.pendingTypeSelectionColumns,
          csvDelimiter: parsed.csvDelimiter,
          hasTypeRow: parsed.hasTypeRow,
          headerRowIndex: parsed.headerRowIndex,
          startColumnIndex: parsed.startColumnIndex,
          sourceBytes: parsed.sourceBytes,
        );

        final rebuilt = CsvSheetCodec.buildBytes(updated);
        final reparsed = CsvSheetCodec.parse(
          bytes: rebuilt,
          fileName: 'open_end.csv',
          path: '/tmp/open_end.csv',
        );

        expect(reparsed.headers, ['Date', 'Hours', 'Notes']);
        expect(reparsed.rows, [
          ['2026-05-11', '8', 'first row'],
        ]);
      },
    );

    test(
      'XLSX with headers only can be parsed and persisted with first row',
      () {
        final workbook = excel_pkg.Excel.createExcel();
        final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
        final sheet = workbook[sheetName];
        sheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
            )
            .value = excel_pkg.TextCellValue(
          'name',
        );
        sheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0),
            )
            .value = excel_pkg.TextCellValue(
          'date',
        );
        sheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0),
            )
            .value = excel_pkg.TextCellValue(
          'notes',
        );

        final encoded = workbook.encode();
        expect(encoded, isNotNull);
        final sourceBytes = Uint8List.fromList(encoded!);

        final parsed = XlsxSheetCodec.parse(
          bytes: sourceBytes,
          fileName: 'sample.xlsx',
          path: '/tmp/sample.xlsx',
        );

        expect(parsed.headers, ['name', 'date', 'notes']);
        expect(parsed.rows, isEmpty);

        final updated = SimpleSheetData(
          fileName: parsed.fileName,
          path: parsed.path,
          format: parsed.format,
          headers: parsed.headers,
          valueTypes: parsed.valueTypes,
          readOnlyColumns: parsed.readOnlyColumns,
          rows: const <List<String>>[
            <String>['Bob', '2026-01-02', 'first row'],
          ],
          pendingTypeSelectionColumns: parsed.pendingTypeSelectionColumns,
          hasTypeRow: parsed.hasTypeRow,
          headerRowIndex: parsed.headerRowIndex,
          startColumnIndex: parsed.startColumnIndex,
          xlsxSheetName: parsed.xlsxSheetName,
          workbook: parsed.workbook,
        );

        final rebuilt = XlsxSheetCodec.buildBytes(updated);
        final reparsed = XlsxSheetCodec.parse(
          bytes: rebuilt,
          fileName: 'sample.xlsx',
          path: '/tmp/sample.xlsx',
        );

        expect(reparsed.headers, ['name', 'date', 'notes']);
        expect(reparsed.rows.length, 1);
        expect(reparsed.rows.first, ['Bob', '2026-01-02', 'first row']);
      },
    );
  });
}
