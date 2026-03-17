import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;

import 'sheet_file_models.dart';

class XlsxSheetLogic {
  const XlsxSheetLogic._();

  static SimpleSheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
  }) {
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('The selected XLSX has no sheets.');
    }

    final sheetName = _selectBestSheetName(excel, now ?? DateTime.now());
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
        .map((row) => _normalizeRowToWidth(row, width))
        .toList();
    final tableBounds = _detectTableBounds(normalizedRows);
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
          (row) => row
              .skip(tableBounds.startColumnIndex)
              .take(headerCount)
              .toList(),
        )
        .toList();
    final trimmedRowCount = _trimTrailingFooterRows(
      headers: headers,
      rows: bodyRows,
    );
    final rows = bodyRows.take(trimmedRowCount).toList();
    final valueTypes = _inferSimpleTypes(
      headerCount,
      rows.take(20).toList(),
      headers: headers,
    );
    final readOnlyColumns = List<bool>.filled(headerCount, false);
    for (var rowIndex = dataStartRowIndex; rowIndex < sheet.rows.length; rowIndex++) {
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
        if (_looksLikeFormulaExpression(value?.toString() ?? '')) {
          readOnlyColumns[col] = true;
        }
      }
    }
    final pendingTypeSelectionColumns = List<int>.generate(
      headerCount,
      (index) => index,
    ).where((index) => !readOnlyColumns[index]).toList();

    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: SimpleFileFormat.xlsx,
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

  static Uint8List buildBytes(SimpleSheetData data) {
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
        cell.value = _xlsxCellValueFromSimple(
          type: data.valueTypes[col],
          raw: value,
        );
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
    required SimpleSheetData data,
  }) {
    for (var col = 0; col < data.headers.length; col++) {
      if (!data.readOnlyColumns[col]) continue;

      String? templateFormula;
      int? templateRowNumber;
      for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
        final rowNumber = data.headerRowIndex + (data.hasTypeRow ? 2 : 1) + rowIndex;
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
        final rowNumber = data.headerRowIndex + (data.hasTypeRow ? 2 : 1) + rowIndex;
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

  static _XlsxTableBounds _detectTableBounds(List<List<String>> rows) {
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        if (!_looksLikeDateValue(row[columnIndex])) continue;
        var dateMatches = 0;
        for (var probeRow = rowIndex; probeRow < rows.length; probeRow++) {
          final value = rows[probeRow][columnIndex].trim();
          if (value.isEmpty) continue;
          if (_looksLikeDateValue(value)) {
            dateMatches++;
          }
          if (dateMatches >= 2) break;
        }
        if (dateMatches < 2) continue;

        var candidateHeaderRowIndex = rowIndex - 1;
        var hasTypeRow = false;
        if (candidateHeaderRowIndex > 0 &&
            _looksLikeTypeRow(rows[candidateHeaderRowIndex])) {
          candidateHeaderRowIndex--;
          hasTypeRow = true;
        }
        final headerRow = rows[candidateHeaderRowIndex];
        var startColumnIndex = columnIndex;
        while (startColumnIndex > 0 &&
            headerRow[startColumnIndex - 1].trim().isNotEmpty) {
          startColumnIndex--;
        }
        var endColumnIndex = columnIndex;
        while (endColumnIndex < headerRow.length &&
            headerRow[endColumnIndex].trim().isNotEmpty) {
          endColumnIndex++;
        }
        final columnCount = endColumnIndex - startColumnIndex;
        if (columnCount <= 0) continue;
        if (headerRow
            .skip(startColumnIndex)
            .take(columnCount)
            .every((value) => value.trim().isEmpty)) {
          continue;
        }
        return _XlsxTableBounds(
          headerRowIndex: candidateHeaderRowIndex,
          startColumnIndex: startColumnIndex,
          columnCount: columnCount,
          hasTypeRow: hasTypeRow,
        );
      }
    }

    final rawHeaders = rows.first;
    final firstEmptyHeaderIndex = rawHeaders.indexWhere(
      (value) => value.trim().isEmpty,
    );
    final headerCount = firstEmptyHeaderIndex >= 0
        ? firstEmptyHeaderIndex
        : rawHeaders.length;
    if (headerCount == 0) {
      throw const FormatException('First row has no header titles.');
    }
    return _XlsxTableBounds(
      headerRowIndex: 0,
      startColumnIndex: 0,
      columnCount: headerCount,
      hasTypeRow: rows.length > 1 && _looksLikeTypeRow(rows[1]),
    );
  }

  static bool _looksLikeTypeRow(List<String> values) {
    if (values.isEmpty) return false;
    var matches = 0;
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (_isKnownTypeToken(normalized)) {
        matches++;
      }
    }
    return matches >= (values.length / 2).ceil();
  }

  static bool _isKnownTypeToken(String type) {
    if (type.contains('date')) return true;
    if (type.contains('time')) return true;
    if (type.contains('duration')) return true;
    if (type.contains('timespan')) return true;
    if (type.contains('int')) return true;
    if (type.contains('double')) return true;
    if (type.contains('decimal')) return true;
    if (type.contains('number')) return true;
    if (type.contains('num')) return true;
    if (type.contains('bool')) return true;
    if (type.contains('text')) return true;
    if (type.contains('string')) return true;
    if (type.contains('currency')) return true;
    if (type.contains('money')) return true;
    if (type.contains('email')) return true;
    if (type.contains('phone')) return true;
    return false;
  }

  static String _selectBestSheetName(excel_pkg.Excel excel, DateTime now) {
    final candidates = <String>{
      ..._monthTokens(now.month),
      '${now.month}',
      now.month.toString().padLeft(2, '0'),
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
      '${now.month.toString().padLeft(2, '0')}-${now.year}',
    }.map((value) => value.toLowerCase()).toList();
    for (final name in excel.tables.keys) {
      final lowered = name.trim().toLowerCase();
      if (candidates.contains(lowered)) {
        return name;
      }
    }
    for (final name in excel.tables.keys) {
      final lowered = name.trim().toLowerCase();
      if (candidates.any(lowered.contains)) {
        return name;
      }
    }
    return excel.getDefaultSheet() ?? excel.tables.keys.first;
  }

  static Iterable<String> _monthTokens(int month) {
    const names = <int, List<String>>{
      1: <String>['january', 'jan', 'januar'],
      2: <String>['february', 'feb', 'februar'],
      3: <String>['march', 'mar', 'maerz', 'marz'],
      4: <String>['april', 'apr'],
      5: <String>['may', 'mai'],
      6: <String>['june', 'jun', 'juni'],
      7: <String>['july', 'jul', 'juli'],
      8: <String>['august', 'aug'],
      9: <String>['september', 'sep'],
      10: <String>['october', 'oct', 'oktober', 'okt'],
      11: <String>['november', 'nov'],
      12: <String>['december', 'dec', 'dezember', 'dez'],
    };
    return names[month] ?? const <String>[];
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
    if (value is num) {
      return value.toString().replaceAll('.', ',');
    }
    return value.toString().trim();
  }

  static excel_pkg.CellValue? _xlsxCellValueFromSimple({
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
    if (normalizedType.contains('int')) {
      final parsed = int.tryParse(value);
      if (parsed != null) return excel_pkg.IntCellValue(parsed);
    }
    if (normalizedType.contains('double') ||
        normalizedType.contains('decimal') ||
        normalizedType.contains('number') ||
        normalizedType.contains('num')) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return excel_pkg.DoubleCellValue(parsed);
    }
    return excel_pkg.TextCellValue(value);
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

  static List<String> _normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
  }

  static List<String> _inferSimpleTypes(
    int width,
    List<List<String>> sampleRows, {
    List<String>? headers,
  }) {
    return List<String>.generate(width, (index) {
      final headerGuess = headers != null && index < headers.length
          ? _typeFromHeader(headers[index])
          : null;
      if (headerGuess == 'date' ||
          headerGuess == 'time' ||
          headerGuess == 'duration') {
        return headerGuess!;
      }
      for (final row in sampleRows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        if (_looksLikeDateValue(value)) return 'date';
        if (_looksLikeTimeValue(value)) return 'time';
        if (_looksLikeDecimalValue(value)) return 'decimal';
        if (_looksLikeIntegerValue(value)) return 'int';
        return 'text';
      }
      return headerGuess ?? 'text';
    });
  }

  static int _trimTrailingFooterRows({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) return 0;
    final dateColumnIndex = _findDateColumnIndex(headers: headers, rows: rows);
    if (dateColumnIndex == null) {
      return rows.length;
    }

    var lastDateRowIndex = -1;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final value = dateColumnIndex < row.length ? row[dateColumnIndex] : '';
      if (_looksLikeDateValue(value)) {
        lastDateRowIndex = rowIndex;
      }
    }
    if (lastDateRowIndex < 0) {
      return rows.length;
    }
    return lastDateRowIndex + 1;
  }

  static int? _findDateColumnIndex({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final headerIndex = headers.indexWhere(_isDateHeaderName);
    if (headerIndex >= 0) return headerIndex;

    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      var matches = 0;
      var checked = 0;
      for (final row in rows) {
        if (columnIndex >= row.length) continue;
        final value = row[columnIndex].trim();
        if (value.isEmpty) continue;
        checked++;
        if (_looksLikeDateValue(value)) {
          matches++;
        }
        if (checked >= 12) break;
      }
      if (matches >= 3) {
        return columnIndex;
      }
    }
    return null;
  }

  static bool _looksLikeDateValue(String value) {
    final compact = value.trim();
    return RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2,4}$').hasMatch(compact) ||
        RegExp(r'^\d{4}[./-]\d{1,2}[./-]\d{1,2}$').hasMatch(compact);
  }

  static bool _looksLikeTimeValue(String value) {
    final compact = value.trim().toLowerCase();
    return RegExp(r'^\d{1,2}:\d{2}(:\d{2})?(\s?(am|pm))?$').hasMatch(compact);
  }

  static bool _looksLikeIntegerValue(String value) {
    return RegExp(r'^[+-]?\d+$').hasMatch(value.trim());
  }

  static bool _looksLikeDecimalValue(String value) {
    final compact = value.trim();
    return RegExp(r'^[+-]?\d+[.,]\d+$').hasMatch(compact);
  }

  static bool _isDateHeaderName(String header) {
    final value = header.trim().toLowerCase();
    return value == 'date' ||
        value == 'datum' ||
        value == 'tag' ||
        value == 'data' ||
        value == 'fecha';
  }

  static String? _typeFromHeader(String header) {
    final value = header.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (_isDateHeaderName(header)) {
      return 'date';
    }
    if (value.contains('pause') ||
        value.contains('break') ||
        value.contains('minutes') ||
        value.contains('minuten')) {
      return 'duration';
    }
    if (value.contains('start') ||
        value.contains('beginn') ||
        value.contains('begin') ||
        value.contains('end') ||
        value.contains('ende') ||
        value.contains('time') ||
        value.contains('uhr')) {
      return 'time';
    }
    return null;
  }

  static bool _looksLikeFormulaExpression(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    if (compact.startsWith('=')) return true;
    return RegExp(r'^[A-Z]{1,3}\d+\s*=').hasMatch(compact);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _XlsxTableBounds {
  const _XlsxTableBounds({
    required this.headerRowIndex,
    required this.startColumnIndex,
    required this.columnCount,
    required this.hasTypeRow,
  });

  final int headerRowIndex;
  final int startColumnIndex;
  final int columnCount;
  final bool hasTypeRow;
}
