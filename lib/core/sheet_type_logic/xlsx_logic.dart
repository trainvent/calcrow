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

    final rawHeaders = normalizedRows.first;
    final firstEmptyHeaderIndex = rawHeaders.indexWhere(
      (value) => value.trim().isEmpty,
    );
    final headerCount = firstEmptyHeaderIndex >= 0
        ? firstEmptyHeaderIndex
        : rawHeaders.length;
    if (headerCount == 0) {
      throw const FormatException('First row has no header titles.');
    }

    final headers = rawHeaders
        .take(headerCount)
        .map((value) => value.trim())
        .toList();
    final rows = normalizedRows
        .skip(1)
        .map((row) => row.take(headerCount).toList())
        .toList();
    final valueTypes = _inferSimpleTypes(
      headerCount,
      rows.take(20).toList(),
      headers: headers,
    );
    final readOnlyColumns = List<bool>.filled(headerCount, false);
    for (final row in sheet.rows.skip(1)) {
      for (var col = 0; col < headerCount && col < row.length; col++) {
        final cell = row[col];
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

    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: SimpleFileFormat.xlsx,
      headers: headers,
      valueTypes: valueTypes,
      readOnlyColumns: readOnlyColumns,
      rows: rows,
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
            excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
          )
          .value = excel_pkg.TextCellValue(data.headers[col]);
    }

    for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
      final row = data.rows[rowIndex];
      for (var col = 0; col < data.headers.length; col++) {
        if (data.readOnlyColumns[col]) continue;
        final value = col < row.length ? row[col].trim() : '';
        final cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: rowIndex + 1,
          ),
        );
        cell.value = _xlsxCellValueFromSimple(type: data.valueTypes[col], raw: value);
      }
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not encode XLSX workbook.');
    }
    return Uint8List.fromList(bytes);
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
      if (headers != null &&
          index < headers.length &&
          _isDateHeaderName(headers[index])) {
        return 'date';
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
      return 'text';
    });
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
