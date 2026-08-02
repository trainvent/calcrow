import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calcrow/core/sheet_type_logic/csv_codec.dart';
import 'package:calcrow/core/sheet_type_logic/ods_codec.dart';
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
      expect(FieldTypeGuesser.normalizeTypeLabel('money:EUR'), 'money');
      expect(FieldTypeGuesser.displayTypeLabel('money:EUR'), 'money:EUR');
      expect(FieldTypeGuesser.currencyCodeFromType('money:eur'), 'EUR');
    });

    test('header guesses use field-aware tokens', () {
      expect(FieldTypeGuesser.typeFromHeader('Date'), 'date');
      expect(FieldTypeGuesser.typeFromHeader('Entry Date'), 'date');
      expect(FieldTypeGuesser.typeFromHeader('Endurance'), isNull);
      expect(FieldTypeGuesser.typeFromHeader('Hours'), 'float');
      expect(FieldTypeGuesser.typeFromHeader('Sets'), 'int');
      expect(FieldTypeGuesser.typeFromHeader('RSVP'), 'boolean');
      expect(FieldTypeGuesser.typeFromHeader('Amount'), 'money');
      expect(FieldTypeGuesser.typeFromHeader('Expenses'), 'money');
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

    test('CSV money fields preserve selected currency', () async {
      final parsed = await parseCsv(
        'Date;Amount;Notes\n'
        'date;money:EUR;text\n'
        '2026-05-11;42,50;paid\n',
      );

      expect(parsed.valueTypes, ['date', 'money:EUR', 'text']);

      final reparsed = await parseCsvBytes(CsvSheetCodec.buildBytes(parsed));
      expect(reparsed.valueTypes, ['date', 'money:EUR', 'text']);
      expect(reparsed.rows, [
        ['2026-05-11', '42,50', 'paid'],
      ]);
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

    test(
      'XLSX inspection finds a compatible third sheet with row 8 headers',
      () {
        final bytes = buildNamedWorkbookBytes({
          'Overview': [
            ['Workbook overview'],
          ],
          'People': [
            ['Name', 'Notes'],
            ['Alice', 'Example'],
          ],
          'Archive 2025': [
            ['Archived time records'],
            <String>[],
            ['Generated by another system'],
            <String>[],
            <String>[],
            <String>[],
            <String>[],
            ['Date', 'Start', 'End', 'Notes'],
            ['2025-12-30', '09:00:00', '17:00:00', 'first'],
            ['2025-12-31', '09:00:00', '15:00:00', 'second'],
          ],
        });

        final inspection = XlsxSheetCodec.inspectSheets(
          bytes: bytes,
          fileName: 'archive.xlsx',
          path: '/tmp/archive.xlsx',
        );
        final compatible = inspection.sheets
            .where((sheet) => sheet.hasDateColumn)
            .toList();

        expect(inspection.sheetCount, 3);
        expect(compatible, hasLength(1));
        expect(compatible.single.name, 'Archive 2025');
        expect(compatible.single.headerRowIndex, 7);
        expect(compatible.single.entryCount, 2);

        final parsed = parseXlsx(bytes, sheetName: 'Archive 2025');
        expect(parsed.xlsxSheetName, 'Archive 2025');
        expect(parsed.headerRowIndex, 7);
        expect(parsed.headers, ['Date', 'Start', 'End', 'Notes']);
        expect(parsed.rows, [
          ['2025-12-30', '09:00:00', '17:00:00', 'first'],
          ['2025-12-31', '09:00:00', '15:00:00', 'second'],
        ]);
      },
    );

    test('XLSX detects row 5 headers with only one entry', () {
      final parsed = parseXlsx(
        buildWorkbookBytes([
          ['Time report'],
          <String>[],
          ['Prepared externally'],
          <String>[],
          ['Date', 'Hours', 'Notes'],
          ['2025-12-31', '8', 'last entry'],
        ]),
      );

      expect(parsed.headerRowIndex, 4);
      expect(parsed.headers, ['Date', 'Hours', 'Notes']);
      expect(parsed.rows, [
        ['2025-12-31', '8', 'last entry'],
      ]);
    });

    test('XLSX detects recognizable row 8 headers without entries', () {
      final parsed = parseXlsx(
        buildWorkbookBytes([
          ['Time report'],
          <String>[],
          ['Prepared externally'],
          <String>[],
          <String>[],
          <String>[],
          <String>[],
          ['Date', 'Start', 'End', 'Notes'],
        ]),
      );

      expect(parsed.headerRowIndex, 7);
      expect(parsed.headers, ['Date', 'Start', 'End', 'Notes']);
      expect(parsed.rows, isEmpty);
    });

    test('XLSX suggests and creates a current month sheet on request', () {
      final bytes = buildNamedWorkbookBytes({
        'March': [
          ['Date', 'Start', 'End', 'Pause', 'Notes'],
          ['2026-03-28', '09:00:00', '17:00:00', '00:30:00', 'older month'],
        ],
        'April': [
          ['Date', 'Start', 'End', 'Pause', 'Notes'],
          ['2026-04-28', '09:00:00', '17:00:00', '00:30:00', 'old month'],
        ],
      });
      final suggestion = XlsxSheetCodec.suggestCurrentMonthSheet(
        bytes: bytes,
        fileName: 'calcrow_sheet_2026.xlsx',
        now: DateTime(2026, 7, 11),
      );

      expect(suggestion?.sourceSheetName, 'March');
      expect(suggestion?.targetSheetName, 'July');

      final parsed = XlsxSheetCodec.createCurrentMonthSheet(
        bytes: bytes,
        fileName: 'calcrow_sheet_2026.xlsx',
        path: '/tmp/calcrow_sheet_2026.xlsx',
        now: DateTime(2026, 7, 11),
      );

      expect(parsed.xlsxSheetName, 'July');
      expect(parsed.headers, ['Date', 'Start', 'End', 'Pause', 'Notes']);
      expect(parsed.valueTypes, ['date', 'time', 'time', 'duration', 'text']);
      expect(parsed.rows, [
        ['2026-07-28', '', '', '', ''],
      ]);
      expect(parsed.workbook?.tables.containsKey('July'), isTrue);

      final reparsed = parseXlsx(
        XlsxSheetCodec.buildBytes(
          copySheetData(
            parsed,
            rows: const <List<String>>[
              <String>[
                '2026-07-28',
                '09:00:00',
                '17:00:00',
                '00:30:00',
                'new month',
              ],
            ],
          ),
        ),
        fileName: 'calcrow_sheet_2026.xlsx',
        now: DateTime(2026, 7, 11),
      );

      expect(reparsed.xlsxSheetName, 'July');
      expect(reparsed.rows, [
        ['2026-07-28', '09:00:00', '17:00:00', '00:30:00', 'new month'],
      ]);
    });

    test('XLSX monthly clone preserves styles and retargets formulas', () {
      final workbook = excel_pkg.Excel.createExcel();
      final defaultSheet = workbook.getDefaultSheet()!;
      workbook.rename(defaultSheet, 'März');
      final sheet = workbook['März'];
      sheet.cell(excel_pkg.CellIndex.indexByString('A1'))
        ..value = excel_pkg.TextCellValue('Datum')
        ..cellStyle = excel_pkg.CellStyle(bold: true);
      sheet.cell(excel_pkg.CellIndex.indexByString('B1')).value =
          excel_pkg.TextCellValue('Betrag');
      sheet.cell(excel_pkg.CellIndex.indexByString('C1')).value =
          excel_pkg.TextCellValue('Berechnet');
      sheet.cell(excel_pkg.CellIndex.indexByString('A2')).value =
          excel_pkg.TextCellValue('2026-03-30');
      sheet.cell(excel_pkg.CellIndex.indexByString('B2')).value =
          excel_pkg.IntCellValue(12);
      sheet.cell(excel_pkg.CellIndex.indexByString('C2')).value =
          excel_pkg.FormulaCellValue("'März'!B2*2");
      final encoded = Uint8List.fromList(workbook.encode()!);

      final suggestion = XlsxSheetCodec.suggestCurrentMonthSheet(
        bytes: encoded,
        fileName: 'tagebuch_2026.xlsx',
        now: DateTime(2026, 7, 1),
        preferredLanguageCode: 'de',
      );
      final created = XlsxSheetCodec.createCurrentMonthSheet(
        bytes: encoded,
        fileName: 'tagebuch_2026.xlsx',
        path: null,
        now: DateTime(2026, 7, 1),
        preferredLanguageCode: 'de',
      );
      final target = created.workbook!.tables['Juli']!;

      expect(suggestion?.targetSheetName, 'Juli');
      expect(
        target.cell(excel_pkg.CellIndex.indexByString('A1')).cellStyle?.isBold,
        isTrue,
      );
      expect(
        target.cell(excel_pkg.CellIndex.indexByString('A2')).value.toString(),
        contains('2026-07-30'),
      );
      expect(
        target.cell(excel_pkg.CellIndex.indexByString('B2')).value,
        isNull,
      );
      expect(
        target.cell(excel_pkg.CellIndex.indexByString('C2')).value,
        isA<excel_pkg.FormulaCellValue>().having(
          (value) => value.formula,
          'formula',
          "'Juli'!B2*2",
        ),
      );
    });

    test('XLSX monthly logbook opens an existing current month sheet', () {
      final parsed = parseXlsx(
        buildNamedWorkbookBytes({
          'June': [
            ['Date', 'Start', 'End', 'Pause', 'Notes'],
            ['2026-06-28', '09:00:00', '17:00:00', '00:30:00', 'old month'],
          ],
          'July': [
            ['Date', 'Start', 'End', 'Pause', 'Notes'],
            ['2026-07-11', '09:00:00', '17:00:00', '00:30:00', 'current'],
          ],
        }),
        fileName: 'calcrow_sheet_2026.xlsx',
        now: DateTime(2026, 7, 11),
      );

      expect(parsed.xlsxSheetName, 'July');
      expect(parsed.rows, [
        ['2026-07-11', '09:00:00', '17:00:00', '00:30:00', 'current'],
      ]);
    });

    test('XLSX monthly logbook refuses a different year suffix', () {
      expect(
        () => parseXlsx(
          buildWorkbookBytes([
            ['Date', 'Notes'],
          ]),
          fileName: 'calcrow_sheet_2026.xlsx',
          now: DateTime(2027, 1, 1),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Create or open a 2027 logbook'),
          ),
        ),
      );
    });

    test('XLSX yearly logbook creates a current year sheet on open', () {
      final parsed = parseXlsx(
        buildNamedWorkbookBytes({
          '2026': [
            ['Date', 'Start', 'End', 'Pause', 'Notes'],
            ['2026-12-28', '09:00:00', '17:00:00', '00:30:00', 'old year'],
          ],
        }),
        fileName: 'calcrow_sheet.xlsx',
        now: DateTime(2027, 1, 3),
      );

      expect(parsed.xlsxSheetName, '2027');
      expect(parsed.headers, ['Date', 'Start', 'End', 'Pause', 'Notes']);
      expect(parsed.valueTypes, ['date', 'time', 'time', 'duration', 'text']);
      expect(parsed.rows, isEmpty);
      expect(parsed.workbook?.tables.containsKey('2027'), isTrue);
      expect(parsed.workbook?.tables['2027']?.rows.length, 1);

      final reparsed = parseXlsx(
        XlsxSheetCodec.buildBytes(
          copySheetData(
            parsed,
            rows: const <List<String>>[
              <String>[
                '2027-01-03',
                '09:00:00',
                '17:00:00',
                '00:30:00',
                'new year',
              ],
            ],
          ),
        ),
        fileName: 'calcrow_sheet.xlsx',
        now: DateTime(2027, 1, 3),
      );

      expect(reparsed.xlsxSheetName, '2027');
      expect(reparsed.rows, [
        ['2027-01-03', '09:00:00', '17:00:00', '00:30:00', 'new year'],
      ]);
    });

    test('XLSX yearly logbook opens the current year sheet when present', () {
      final parsed = parseXlsx(
        buildNamedWorkbookBytes({
          '2026': [
            ['Date', 'Notes'],
            ['2026-12-28', 'old year'],
          ],
          '2027': [
            ['Date', 'Notes'],
            ['2027-01-03', 'current year'],
          ],
        }),
        fileName: 'calcrow_sheet.xlsx',
        now: DateTime(2027, 1, 3),
      );

      expect(parsed.xlsxSheetName, '2027');
      expect(parsed.rows, [
        ['2027-01-03', 'current year'],
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

    test('XLSX isolates only saves that introduce a new cell style', () {
      final workbook = excel_pkg.Excel.createExcel();
      final emptyDraft = SheetData(
        fileName: 'fresh.xlsx',
        path: null,
        format: SheetFileFormat.xlsx,
        headers: const <String>['Date', 'Distance', 'Cost'],
        valueTypes: const <String>['date', 'float', 'money:EUR'],
        readOnlyColumns: const <bool>[false, false, false],
        rows: const <List<String>>[],
        workbook: workbook,
      );

      XlsxSheetCodec.buildBytes(emptyDraft);
      final firstRowBytes = XlsxSheetCodec.buildBytes(
        copySheetData(
          emptyDraft,
          rows: const <List<String>>[
            <String>['2026-08-01', '0,5', ''],
          ],
        ),
      );

      final reusedStyleBytes = XlsxSheetCodec.buildBytes(
        copySheetData(
          emptyDraft,
          rows: const <List<String>>[
            <String>['2026-08-01', '0,5', ''],
            <String>['2026-08-02', '1,5', ''],
          ],
        ),
      );
      final newMoneyStyleBytes = XlsxSheetCodec.buildBytes(
        copySheetData(
          emptyDraft,
          rows: const <List<String>>[
            <String>['2026-08-01', '0,5', ''],
            <String>['2026-08-02', '1,5', '12,30'],
          ],
        ),
      );

      final firstRowWorkbook = excel_pkg.Excel.decodeBytes(firstRowBytes);
      final firstRowSheet =
          firstRowWorkbook.tables[firstRowWorkbook.getDefaultSheet()]!;
      final dateCell = firstRowSheet.cell(
        excel_pkg.CellIndex.indexByString('A2'),
      );
      final distanceCell = firstRowSheet.cell(
        excel_pkg.CellIndex.indexByString('B2'),
      );
      final reusedWorkbook = excel_pkg.Excel.decodeBytes(reusedStyleBytes);
      final reusedSheet =
          reusedWorkbook.tables[reusedWorkbook.getDefaultSheet()]!;
      final savedWorkbook = excel_pkg.Excel.decodeBytes(newMoneyStyleBytes);
      final savedSheet = savedWorkbook.tables[savedWorkbook.getDefaultSheet()]!;
      final moneyCell = savedSheet.cell(
        excel_pkg.CellIndex.indexByString('C3'),
      );

      expect(dateCell.value, isA<excel_pkg.DateCellValue>());
      expect(dateCell.cellStyle?.numberFormat.formatCode, contains('yy'));
      expect(distanceCell.value, const excel_pkg.DoubleCellValue(0.5));
      expect(
        distanceCell.cellStyle?.numberFormat.formatCode,
        isNot(contains('yy')),
      );
      expect(
        reusedSheet.cell(excel_pkg.CellIndex.indexByString('B3')).value,
        const excel_pkg.DoubleCellValue(1.5),
      );
      expect(moneyCell.value, const excel_pkg.DoubleCellValue(12.3));
      expect(moneyCell.cellStyle?.numberFormat.formatCode, contains('EUR'));
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

    test('XLSX money fields are written as formatted numeric cells', () {
      final draft = SheetData(
        fileName: 'invoices.xlsx',
        path: null,
        format: SheetFileFormat.xlsx,
        headers: const <String>['Date', 'Amount', 'Notes'],
        valueTypes: const <String>['date', 'money:EUR', 'text'],
        readOnlyColumns: List<bool>.filled(3, false),
        rows: const <List<String>>[
          <String>['2026-05-11', '42.50', 'paid'],
        ],
        workbook: excel_pkg.Excel.createExcel(),
      );

      final bytes = XlsxSheetCodec.buildBytes(draft);
      final workbook = excel_pkg.Excel.decodeBytes(bytes);
      final sheet = workbook.tables[workbook.getDefaultSheet()]!;
      final amountCell = sheet.rows[1][1]!;

      expect(amountCell.value, const excel_pkg.DoubleCellValue(42.5));
      expect(amountCell.cellStyle?.numberFormat.formatCode, contains('EUR'));

      final reparsed = parseXlsx(bytes);
      expect(reparsed.valueTypes, ['date', 'money:USD', 'text']);
      expect(reparsed.rows, [
        ['2026-05-11', '42,5', 'paid'],
      ]);
    });
  });

  group('ODS codec', () {
    test('ODS can be built from a fresh sheet draft', () {
      final draft = SheetData(
        fileName: 'fresh.ods',
        path: null,
        format: SheetFileFormat.ods,
        headers: const <String>['Date', 'Start', 'End', 'Notes'],
        valueTypes: const <String>['date', 'time', 'time', 'text'],
        readOnlyColumns: List<bool>.filled(4, false),
        rows: const <List<String>>[],
        xlsxSheetName: 'July',
      );

      final parsed = parseOds(OdsSheetCodec.buildBytes(draft));

      expect(parsed.headers, ['Date', 'Start', 'End', 'Notes']);
      expect(parsed.rows, isEmpty);
      expect(parsed.xlsxSheetName, 'July');
      expect(parsed.sourceBytes, isNotNull);
    });

    test('fresh ODS roundtrips the first saved row', () {
      final draft = SheetData(
        fileName: 'fresh.ods',
        path: null,
        format: SheetFileFormat.ods,
        headers: const <String>['Date', 'Start', 'End', 'Notes'],
        valueTypes: const <String>['date', 'time', 'time', 'text'],
        readOnlyColumns: List<bool>.filled(4, false),
        rows: const <List<String>>[],
        xlsxSheetName: 'July',
      );
      final parsed = parseOds(OdsSheetCodec.buildBytes(draft));
      final updated = copySheetData(
        parsed,
        rows: const <List<String>>[
          <String>['2026-07-11', '09:00:00', '17:00:00', 'first row'],
        ],
      );

      final reparsed = parseOds(OdsSheetCodec.buildBytes(updated));

      expect(reparsed.headers, ['Date', 'Start', 'End', 'Notes']);
      expect(reparsed.rows, [
        ['2026-07-11', '09:00:00', '17:00:00', 'first row'],
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
  return buildNamedWorkbookBytes({'Sheet1': rows});
}

Uint8List buildNamedWorkbookBytes(Map<String, List<List<String>>> sheets) {
  final workbook = excel_pkg.Excel.createExcel();
  final defaultSheetName = workbook.getDefaultSheet();
  var firstSheet = true;
  for (final entry in sheets.entries) {
    final sheetName = entry.key;
    if (firstSheet &&
        defaultSheetName != null &&
        defaultSheetName != sheetName) {
      workbook.rename(defaultSheetName, sheetName);
    }
    firstSheet = false;
    final sheet = workbook[sheetName];
    for (var rowIndex = 0; rowIndex < entry.value.length; rowIndex++) {
      final row = entry.value[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        sheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: columnIndex,
                rowIndex: rowIndex,
              ),
            )
            .value = excel_pkg.TextCellValue(
          row[columnIndex],
        );
      }
    }
  }

  final encoded = workbook.encode();
  expect(encoded, isNotNull);
  return Uint8List.fromList(encoded!);
}

SheetData parseXlsx(
  Uint8List bytes, {
  String fileName = 'sample.xlsx',
  DateTime? now,
  String? sheetName,
}) {
  return XlsxSheetCodec.parse(
    bytes: bytes,
    fileName: fileName,
    path: '/tmp/sample.xlsx',
    now: now,
    sheetName: sheetName,
  );
}

SheetData parseOds(Uint8List bytes) {
  return OdsSheetCodec.parse(
    bytes: bytes,
    fileName: 'sample.ods',
    path: '/tmp/sample.ods',
  );
}
