import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:calcrow/core/guessers/field_type_guesser.dart';

import 'sheet_file_models.dart';
import 'sheet_logic.dart';

class XlsxSheetCodec {
  const XlsxSheetCodec._();

  static SheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    _checkMonthlyLogbookYear(fileName: fileName, now: effectiveNow);
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('The selected XLSX has no sheets.');
    }

    final currentMonthSheetName = _currentMonthSheetNameForMonthlyLogbook(
      excel,
      fileName: fileName,
      now: effectiveNow,
    );
    if (currentMonthSheetName != null) {
      return _parseSheet(
        excel: excel,
        fileName: fileName,
        path: path,
        sheetName: currentMonthSheetName,
      );
    }

    final sheetName = _selectBestSheetName(excel, effectiveNow);
    return _parseSheet(
      excel: excel,
      fileName: fileName,
      path: path,
      sheetName: sheetName,
    );
  }

  static SheetData _parseSheet({
    required excel_pkg.Excel excel,
    required String fileName,
    required String? path,
    required String sheetName,
  }) {
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) {
      throw const FormatException('The selected XLSX sheet is empty.');
    }

    final rawRows = sheet.rows
        .map((row) => row.map((cell) => _xlsxCellToString(cell)).toList())
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList();
    if (rawRows.isEmpty) {
      throw const FormatException('The selected XLSX sheet is empty.');
    }

    final width = rawRows.fold<int>(
      0,
      (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth,
    );
    final normalizedRows = rawRows
        .map((row) => SheetLogic.normalizeRowToWidth(row, width))
        .toList();
    final tableBounds = SheetLogic.detectTableBounds(
      normalizedRows,
      emptyHeaderError: 'First row has no header titles.',
    );
    final headerCount = tableBounds.columnCount;
    final headers = normalizedRows[tableBounds.headerRowIndex]
        .skip(tableBounds.startColumnIndex)
        .take(headerCount)
        .map((value) => value.trim())
        .toList();
    final dataStartRowIndex =
        tableBounds.headerRowIndex + (tableBounds.hasTypeRow ? 2 : 1);
    final bodyRows = normalizedRows
        .skip(dataStartRowIndex)
        .map(
          (row) =>
              row.skip(tableBounds.startColumnIndex).take(headerCount).toList(),
        )
        .toList();
    final trimmedRowCount = SheetLogic.trimTrailingFooterRows(
      headers: headers,
      rows: bodyRows,
    );
    final rows = bodyRows.take(trimmedRowCount).toList();
    final valueTypes = FieldTypeGuesser.inferTypes(
      headerCount,
      rows.take(20).toList(),
      headers: headers,
    );
    final readOnlyColumns = List<bool>.filled(headerCount, false);
    for (
      var rowIndex = dataStartRowIndex;
      rowIndex < sheet.rows.length;
      rowIndex++
    ) {
      final row = sheet.rows[rowIndex];
      for (
        var col = 0;
        col < headerCount && tableBounds.startColumnIndex + col < row.length;
        col++
      ) {
        final cell = row[tableBounds.startColumnIndex + col];
        final value = cell?.value;
        if (value is excel_pkg.FormulaCellValue) {
          readOnlyColumns[col] = true;
          continue;
        }
        if (FieldTypeGuesser.looksLikeFormulaExpression(
          value?.toString() ?? '',
        )) {
          readOnlyColumns[col] = true;
        }
      }
    }
    final pendingTypeSelectionColumns = List<int>.generate(
      headerCount,
      (index) => index,
    ).where((index) => !readOnlyColumns[index]).toList();

    return SheetData(
      fileName: fileName,
      path: path,
      format: SheetFileFormat.xlsx,
      headers: headers,
      valueTypes: valueTypes,
      readOnlyColumns: readOnlyColumns,
      rows: rows,
      pendingTypeSelectionColumns: pendingTypeSelectionColumns,
      hasTypeRow: tableBounds.hasTypeRow,
      headerRowIndex: tableBounds.headerRowIndex,
      startColumnIndex: tableBounds.startColumnIndex,
      xlsxSheetName: sheetName,
      workbook: excel,
    );
  }

  static void _checkMonthlyLogbookYear({
    required String fileName,
    required DateTime now,
  }) {
    final year = _monthlyLogbookYear(fileName);
    if (year == null || year == now.year) return;
    throw FormatException(
      'This logbook is for $year. Create or open a ${now.year} logbook instead.',
    );
  }

  static String? _currentMonthSheetNameForMonthlyLogbook(
    excel_pkg.Excel excel, {
    required String fileName,
    required DateTime now,
  }) {
    if (_monthlyLogbookYear(fileName) == null) return null;

    final existing = _findMonthSheetName(excel.tables.keys, now.month);
    if (existing != null) return existing;

    final sourceSheetName = _selectBestSheetName(excel, now);
    final source = _parseSheet(
      excel: excel,
      fileName: fileName,
      path: null,
      sheetName: sourceSheetName,
    );
    final monthSheetName = _monthName(now.month);
    final monthSheet = excel[monthSheetName];
    for (var col = 0; col < source.headers.length; col++) {
      monthSheet
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: source.startColumnIndex + col,
              rowIndex: source.headerRowIndex,
            ),
          )
          .value = excel_pkg.TextCellValue(
        source.headers[col],
      );
    }
    if (source.hasTypeRow) {
      for (var col = 0; col < source.valueTypes.length; col++) {
        monthSheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: source.startColumnIndex + col,
                rowIndex: source.headerRowIndex + 1,
              ),
            )
            .value = excel_pkg.TextCellValue(
          source.valueTypes[col],
        );
      }
    }
    excel.setDefaultSheet(monthSheetName);
    return monthSheetName;
  }

  static int? _monthlyLogbookYear(String fileName) {
    final match = RegExp(
      r'_(\d{4})(?:\.[^.]+)?$',
      caseSensitive: false,
    ).firstMatch(fileName.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String? _findMonthSheetName(Iterable<String> names, int month) {
    final candidates = <String>{
      _monthName(month),
      ..._monthTokens(month),
    }.map((value) => value.toLowerCase()).toSet();
    for (final name in names) {
      if (candidates.contains(name.trim().toLowerCase())) {
        return name;
      }
    }
    for (final name in names) {
      final lowered = name.trim().toLowerCase();
      if (candidates.any(lowered.contains)) {
        return name;
      }
    }
    return null;
  }

  static String _monthName(int month) {
    return const <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
  }

  static Iterable<String> _monthTokens(int month) {
    const names = <int, List<String>>{
      1: <String>['jan', 'januar'],
      2: <String>['feb', 'februar'],
      3: <String>['mar', 'maerz', 'marz'],
      4: <String>['apr'],
      5: <String>['may', 'mai'],
      6: <String>['jun', 'juni'],
      7: <String>['jul', 'juli'],
      8: <String>['aug'],
      9: <String>['sep'],
      10: <String>['oct', 'oktober', 'okt'],
      11: <String>['nov'],
      12: <String>['dec', 'dezember', 'dez'],
    };
    return names[month] ?? const <String>[];
  }

  static Uint8List buildBytes(SheetData data) {
    final workbook = data.workbook;
    if (workbook == null) {
      throw StateError('No XLSX workbook is loaded.');
    }
    final sheetName = _resolveSheetNameForPersist(workbook, data.xlsxSheetName);
    final sheet = workbook.tables[sheetName];
    if (sheet == null) {
      throw StateError('Could not find sheet "$sheetName" in XLSX workbook.');
    }

    for (var col = 0; col < data.headers.length; col++) {
      sheet
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: data.startColumnIndex + col,
              rowIndex: data.headerRowIndex,
            ),
          )
          .value = excel_pkg.TextCellValue(
        data.headers[col],
      );
    }

    if (data.hasTypeRow) {
      for (var col = 0; col < data.valueTypes.length; col++) {
        sheet
            .cell(
              excel_pkg.CellIndex.indexByColumnRow(
                columnIndex: data.startColumnIndex + col,
                rowIndex: data.headerRowIndex + 1,
              ),
            )
            .value = excel_pkg.TextCellValue(
          data.valueTypes[col],
        );
      }
    }

    final dataStartRowIndex = data.headerRowIndex + (data.hasTypeRow ? 2 : 1);
    for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
      final row = data.rows[rowIndex];
      for (var col = 0; col < data.headers.length; col++) {
        if (data.readOnlyColumns[col]) continue;
        final value = col < row.length ? row[col].trim() : '';
        final cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: data.startColumnIndex + col,
            rowIndex: dataStartRowIndex + rowIndex,
          ),
        );
        cell.value = _xlsxCellValueFromSheet(
          type: data.valueTypes[col],
          raw: value,
        );
        _applyMoneyStyle(cell: cell, type: data.valueTypes[col], raw: value);
      }
    }

    _restoreReadOnlyFormulas(sheet: sheet, data: data);

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not encode XLSX workbook.');
    }
    return Uint8List.fromList(bytes);
  }

  static void _restoreReadOnlyFormulas({
    required excel_pkg.Sheet sheet,
    required SheetData data,
  }) {
    for (var col = 0; col < data.headers.length; col++) {
      if (!data.readOnlyColumns[col]) continue;

      String? templateFormula;
      int? templateRowNumber;
      for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
        final rowNumber =
            data.headerRowIndex + (data.hasTypeRow ? 2 : 1) + rowIndex;
        final cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: data.startColumnIndex + col,
            rowIndex: rowNumber,
          ),
        );
        final value = cell.value;
        if (value is! excel_pkg.FormulaCellValue) continue;
        final formula = value.formula.trim();
        if (formula.isEmpty) continue;
        templateFormula = formula;
        templateRowNumber = rowNumber + 1;
        break;
      }

      if (templateFormula == null || templateRowNumber == null) {
        continue;
      }

      for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
        final rowNumber =
            data.headerRowIndex + (data.hasTypeRow ? 2 : 1) + rowIndex;
        final sheetRowNumber = rowNumber + 1;
        if (!_rowHasAnyEditableValue(
          row: data.rows[rowIndex],
          readOnlyColumns: data.readOnlyColumns,
        )) {
          continue;
        }
        final cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: data.startColumnIndex + col,
            rowIndex: rowNumber,
          ),
        );
        final existing = cell.value;
        if (existing is excel_pkg.FormulaCellValue &&
            existing.formula.trim().isNotEmpty) {
          continue;
        }
        final shifted = _shiftFormulaRows(
          formula: templateFormula,
          fromRowNumber: templateRowNumber,
          toRowNumber: sheetRowNumber,
        );
        cell.value = excel_pkg.FormulaCellValue(shifted);
      }
    }
  }

  static bool _rowHasAnyEditableValue({
    required List<String> row,
    required List<bool> readOnlyColumns,
  }) {
    for (var i = 0; i < readOnlyColumns.length; i++) {
      if (readOnlyColumns[i]) continue;
      final value = i < row.length ? row[i].trim() : '';
      if (value.isNotEmpty) return true;
    }
    return false;
  }

  static String _shiftFormulaRows({
    required String formula,
    required int fromRowNumber,
    required int toRowNumber,
  }) {
    final delta = toRowNumber - fromRowNumber;
    if (delta == 0) return formula;

    final referenceRegex = RegExp(r'(\$?[A-Z]{1,3})(\$?)(\d+)');
    return formula.replaceAllMapped(referenceRegex, (match) {
      final column = match.group(1)!;
      final rowPrefix = match.group(2)!;
      final rawRow = match.group(3)!;
      if (rowPrefix == r'$') {
        return '$column$rowPrefix$rawRow';
      }
      final baseRow = int.parse(rawRow);
      final shiftedRow = baseRow + delta;
      final safeRow = shiftedRow < 1 ? 1 : shiftedRow;
      return '$column$safeRow';
    });
  }

  static String _resolveSheetNameForPersist(
    excel_pkg.Excel workbook,
    String? preferredSheetName,
  ) {
    final available = workbook.tables.keys.toList(growable: false);
    if (available.isEmpty) {
      throw StateError('The XLSX workbook has no sheets.');
    }
    final preferred = preferredSheetName?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      if (workbook.tables.containsKey(preferred)) {
        return preferred;
      }
      for (final candidate in available) {
        if (candidate.trim() == preferred) {
          return candidate;
        }
      }
      final loweredPreferred = preferred.toLowerCase();
      for (final candidate in available) {
        if (candidate.trim().toLowerCase() == loweredPreferred) {
          return candidate;
        }
      }
      throw StateError(
        'Could not find the imported sheet "$preferred" in the workbook.',
      );
    }

    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && workbook.tables.containsKey(defaultSheet)) {
      return defaultSheet;
    }
    return available.first;
  }

  static String _selectBestSheetName(excel_pkg.Excel excel, DateTime now) {
    return SheetLogic.selectBestSheetName(
      excel.tables.keys,
      now,
      fallback: excel.getDefaultSheet() ?? excel.tables.keys.first,
    );
  }

  static String _xlsxCellToString(excel_pkg.Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    if (value is excel_pkg.DateCellValue) {
      return _formatDate(value.asDateTimeLocal());
    }
    if (value is excel_pkg.DateTimeCellValue) {
      return _formatDate(value.asDateTimeLocal());
    }
    if (value is excel_pkg.TimeCellValue) {
      return value.toString();
    }
    if (value is excel_pkg.IntCellValue) {
      return value.value.toString();
    }
    if (value is excel_pkg.DoubleCellValue) {
      return value.value.toString().replaceAll('.', ',');
    }
    if (value is excel_pkg.BoolCellValue) {
      return value.value ? 'TRUE' : 'FALSE';
    }
    if (value is num) {
      return value.toString().replaceAll('.', ',');
    }
    return value.toString().trim();
  }

  static excel_pkg.CellValue? _xlsxCellValueFromSheet({
    required String type,
    required String raw,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.contains('date')) {
      final parsedDate = _parseDate(value);
      if (parsedDate != null) {
        return excel_pkg.DateCellValue.fromDateTime(parsedDate);
      }
    }
    if (normalizedType.contains('duration')) {
      return excel_pkg.TextCellValue(value);
    }
    if (normalizedType.contains('time')) {
      final parsedTime = _parseTime(value);
      if (parsedTime != null) {
        return parsedTime;
      }
    }
    if (FieldTypeGuesser.isBooleanType(normalizedType) &&
        FieldTypeGuesser.looksLikeBooleanValue(value)) {
      return excel_pkg.BoolCellValue(value.toUpperCase() == 'TRUE');
    }
    if (FieldTypeGuesser.isIntegerType(normalizedType)) {
      final parsed = int.tryParse(value);
      if (parsed != null) return excel_pkg.IntCellValue(parsed);
    }
    if (FieldTypeGuesser.isMoneyType(normalizedType)) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return excel_pkg.DoubleCellValue(parsed);
    }
    if (FieldTypeGuesser.isDecimalType(normalizedType)) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return excel_pkg.DoubleCellValue(parsed);
    }
    return excel_pkg.TextCellValue(value);
  }

  static void _applyMoneyStyle({
    required excel_pkg.Data cell,
    required String type,
    required String raw,
  }) {
    if (!FieldTypeGuesser.isMoneyType(type)) return;
    if (raw.trim().isEmpty) return;
    final currencyCode = FieldTypeGuesser.currencyCodeFromType(type);
    cell.cellStyle = (cell.cellStyle ?? excel_pkg.CellStyle()).copyWith(
      numberFormat: excel_pkg.CustomNumericNumFormat(
        formatCode: '"$currencyCode" #,##0.00;[Red]-"$currencyCode" #,##0.00',
      ),
    );
  }

  static DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    final ymd = RegExp(
      r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$',
    ).firstMatch(trimmed);
    if (ymd != null) {
      final year = int.parse(ymd.group(1)!);
      final month = int.parse(ymd.group(2)!);
      final day = int.parse(ymd.group(3)!);
      return _safeDate(year: year, month: month, day: day);
    }

    final dmy = RegExp(
      r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$',
    ).firstMatch(trimmed);
    if (dmy != null) {
      final day = int.parse(dmy.group(1)!);
      final month = int.parse(dmy.group(2)!);
      var year = int.parse(dmy.group(3)!);
      if (year < 100) {
        year += year >= 70 ? 1900 : 2000;
      }
      return _safeDate(year: year, month: month, day: day);
    }
    return null;
  }

  static DateTime? _safeDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      final parsed = DateTime(year, month, day);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static excel_pkg.TimeCellValue? _parseTime(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '') ?? 0;
    final meridiem = match.group(4);

    if (minute > 59 || second > 59) return null;
    if (meridiem != null) {
      if (hour < 1 || hour > 12) return null;
      if (hour == 12) {
        hour = meridiem == 'am' ? 0 : 12;
      } else if (meridiem == 'pm') {
        hour += 12;
      }
    } else if (hour > 23) {
      return null;
    }

    return excel_pkg.TimeCellValue(hour: hour, minute: minute, second: second);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
