import 'dart:convert';
import 'dart:typed_data';

import 'sheet_file_models.dart';

class CsvSheetLogic {
  const CsvSheetLogic._();

  static SimpleSheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
  }) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final rawLines = content.split(RegExp(r'\r?\n'));
    if (rawLines.isNotEmpty && rawLines.last.trim().isEmpty) {
      rawLines.removeLast();
    }
    final nonEmptyLines = rawLines.where((line) => line.trim().isNotEmpty).toList();
    if (nonEmptyLines.length < 2) {
      throw const FormatException(
        'Simple mode expects line 1 headers and line 2 value types.',
      );
    }

    final delimiter = _detectDelimiter(
      nonEmptyLines.take(12).toList(growable: false),
    );
    final parsedRows = rawLines
        .map((line) => _splitCsvLine(line, delimiter: delimiter))
        .toList();
    final tableBounds = _detectTableBounds(parsedRows);
    final headerRow = parsedRows[tableBounds.headerRowIndex];
    final headers = headerRow
        .skip(tableBounds.startColumnIndex)
        .take(tableBounds.columnCount)
        .map((value) => value.trim())
        .toList();
    final typeRowIndex = tableBounds.hasTypeRow
        ? tableBounds.headerRowIndex + 1
        : null;
    final secondLineValues = typeRowIndex == null
        ? const <String>[]
        : _normalizeRowToWidth(
            parsedRows[typeRowIndex]
                .skip(tableBounds.startColumnIndex)
                .take(tableBounds.columnCount)
                .toList(),
            tableBounds.columnCount,
          );
    final dataStartRowIndex =
        tableBounds.headerRowIndex + (tableBounds.hasTypeRow ? 2 : 1);
    final rows = parsedRows
        .skip(dataStartRowIndex)
        .map(
          (row) => _normalizeRowToWidth(
            row
                .skip(tableBounds.startColumnIndex)
                .take(tableBounds.columnCount)
                .toList(),
            tableBounds.columnCount,
          ),
        )
        .toList();
    final readOnlyColumns = _detectReadOnlyColumns(tableBounds.columnCount, rows);
    final typeInference = tableBounds.hasTypeRow
        ? _buildTypeInferenceFromTypeRow(
            headerCount: tableBounds.columnCount,
            secondLineValues: secondLineValues,
          )
        : _inferSimpleTypes(
            headers: headers,
            rows: rows.take(20).toList(),
            readOnlyColumns: readOnlyColumns,
          );
    final pendingTypeSelectionColumns = tableBounds.hasTypeRow
        ? const <int>[]
        : List<int>.generate(tableBounds.columnCount, (index) => index).where((index) {
            if (readOnlyColumns[index]) return false;
            return !typeInference[index].confirmedFromData;
          }).toList();

    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: SimpleFileFormat.csv,
      headers: headers,
      valueTypes: typeInference.map((item) => item.type).toList(),
      readOnlyColumns: readOnlyColumns,
      rows: rows,
      pendingTypeSelectionColumns: pendingTypeSelectionColumns,
      csvDelimiter: delimiter,
      hasTypeRow: tableBounds.hasTypeRow,
      headerRowIndex: tableBounds.headerRowIndex,
      startColumnIndex: tableBounds.startColumnIndex,
      sourceBytes: bytes,
    );
  }

  static Uint8List buildBytes(SimpleSheetData sheetData) {
    final delimiter = sheetData.csvDelimiter;
    final originalContent = sheetData.sourceBytes == null
        ? null
        : utf8.decode(sheetData.sourceBytes!, allowMalformed: true);
    final originalLines = originalContent == null
        ? <String>[]
        : originalContent.split(RegExp(r'\r?\n'));
    if (originalLines.isNotEmpty && originalLines.last.trim().isEmpty) {
      originalLines.removeLast();
    }
    final originalRows = originalLines
        .map((line) => _splitCsvLine(line, delimiter: delimiter))
        .toList();
    final minRowCount =
        sheetData.headerRowIndex + (sheetData.hasTypeRow ? 2 : 1) + sheetData.rows.length;
    while (originalRows.length < minRowCount) {
      originalRows.add(<String>[]);
    }

    _writeRowSegment(
      rows: originalRows,
      rowIndex: sheetData.headerRowIndex,
      startColumnIndex: sheetData.startColumnIndex,
      values: sheetData.headers,
    );
    if (sheetData.hasTypeRow) {
      _writeRowSegment(
        rows: originalRows,
        rowIndex: sheetData.headerRowIndex + 1,
        startColumnIndex: sheetData.startColumnIndex,
        values: sheetData.valueTypes,
      );
    }

    final dataStartRowIndex =
        sheetData.headerRowIndex + (sheetData.hasTypeRow ? 2 : 1);
    for (var rowIndex = 0; rowIndex < sheetData.rows.length; rowIndex++) {
      final normalized = _normalizeRowToWidth(
        sheetData.rows[rowIndex],
        sheetData.headers.length,
      );
      _writeRowSegment(
        rows: originalRows,
        rowIndex: dataStartRowIndex + rowIndex,
        startColumnIndex: sheetData.startColumnIndex,
        values: normalized,
      );
    }

    final encodedLines = originalRows
        .map(
          (row) => row.map((cell) => _escapeCsvCell(cell, delimiter)).join(delimiter),
        )
        .toList();
    return Uint8List.fromList(utf8.encode('${encodedLines.join('\n')}\n'));
  }

  static List<String> _splitCsvLine(String line, {required String delimiter}) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && char == delimiter) {
        cells.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  static String _detectDelimiter(List<String> lines) {
    const candidates = <String>[',', ';', '\t'];
    String best = ',';
    var bestCount = -1;
    for (final candidate in candidates) {
      final count = lines.fold<int>(
        0,
        (sum, line) => sum + _countDelimiterOutsideQuotes(line, candidate),
      );
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  static _CsvTableBounds _detectTableBounds(List<List<String>> rows) {
    final width = rows.fold<int>(
      0,
      (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth,
    );
    final normalizedRows = rows.map((row) => _normalizeRowToWidth(row, width)).toList();

    for (var rowIndex = 1; rowIndex < normalizedRows.length; rowIndex++) {
      final row = normalizedRows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        if (!_looksLikeDateValue(row[columnIndex])) continue;
        var dateMatches = 0;
        for (var probeRow = rowIndex; probeRow < normalizedRows.length; probeRow++) {
          final value = normalizedRows[probeRow][columnIndex].trim();
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
            _looksLikeTypeRow(normalizedRows[candidateHeaderRowIndex])) {
          candidateHeaderRowIndex--;
          hasTypeRow = true;
        }
        final headerRow = normalizedRows[candidateHeaderRowIndex];
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
        return _CsvTableBounds(
          headerRowIndex: candidateHeaderRowIndex,
          startColumnIndex: startColumnIndex,
          columnCount: columnCount,
          hasTypeRow: hasTypeRow,
        );
      }
    }

    final headerRow = normalizedRows.first;
    final firstEmptyHeaderIndex = headerRow.indexWhere((value) => value.trim().isEmpty);
    final headerCount = firstEmptyHeaderIndex >= 0
        ? firstEmptyHeaderIndex
        : headerRow.length;
    if (headerCount == 0) {
      throw const FormatException('CSV header row is empty.');
    }
    final hasTypeRow =
        normalizedRows.length > 1 && _looksLikeTypeRow(normalizedRows[1]);
    return _CsvTableBounds(
      headerRowIndex: 0,
      startColumnIndex: 0,
      columnCount: headerCount,
      hasTypeRow: hasTypeRow,
    );
  }

  static void _writeRowSegment({
    required List<List<String>> rows,
    required int rowIndex,
    required int startColumnIndex,
    required List<String> values,
  }) {
    while (rows[rowIndex].length < startColumnIndex + values.length) {
      rows[rowIndex].add('');
    }
    for (var columnOffset = 0; columnOffset < values.length; columnOffset++) {
      rows[rowIndex][startColumnIndex + columnOffset] = values[columnOffset];
    }
  }

  static int _countDelimiterOutsideQuotes(String line, String delimiter) {
    var inQuotes = false;
    var count = 0;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && char == delimiter) {
        count++;
      }
    }
    return count;
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

  static List<_CsvTypeInference> _buildTypeInferenceFromTypeRow({
    required int headerCount,
    required List<String> secondLineValues,
  }) {
    return List<_CsvTypeInference>.generate(
      headerCount,
      (index) => _CsvTypeInference(
        type: index < secondLineValues.length
            ? _normalizeTypeLabel(secondLineValues[index])
            : 'text',
        confirmedFromData: true,
      ),
    );
  }

  static List<_CsvTypeInference> _inferSimpleTypes({
    required List<String> headers,
    required List<List<String>> rows,
    required List<bool> readOnlyColumns,
  }) {
    final width = headers.length;
    final sampleRows = rows;
    return List<_CsvTypeInference>.generate(width, (index) {
      final headerGuess = _typeFromHeader(headers[index]);
      if (headerGuess == 'date' ||
          headerGuess == 'time' ||
          headerGuess == 'duration') {
        return _CsvTypeInference(type: headerGuess!, confirmedFromData: true);
      }
      if (readOnlyColumns[index]) {
        return _CsvTypeInference(
          type: headerGuess ?? 'decimal',
          confirmedFromData: true,
        );
      }
      for (final row in sampleRows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        if (_looksLikeFormulaExpression(value)) continue;
        if (_looksLikeDateValue(value)) {
          return const _CsvTypeInference(type: 'date', confirmedFromData: true);
        }
        if (_looksLikeTimeValue(value)) {
          return const _CsvTypeInference(type: 'time', confirmedFromData: true);
        }
        if (_looksLikeDecimalValue(value)) {
          return const _CsvTypeInference(
            type: 'decimal',
            confirmedFromData: true,
          );
        }
        if (_looksLikeIntegerValue(value)) {
          return const _CsvTypeInference(type: 'int', confirmedFromData: true);
        }
        return const _CsvTypeInference(type: 'text', confirmedFromData: true);
      }
      return _CsvTypeInference(
        type: headerGuess ?? 'text',
        confirmedFromData: false,
      );
    });
  }

  static String _normalizeTypeLabel(String raw) {
    final type = raw.trim().toLowerCase();
    if (type.contains('date')) return 'date';
    if (type.contains('duration') || type.contains('timespan')) {
      return 'duration';
    }
    if (type.contains('time')) return 'time';
    if (type.contains('int')) return 'int';
    if (type.contains('double') ||
        type.contains('decimal') ||
        type.contains('number')) {
      return 'decimal';
    }
    if (type.contains('email')) return 'email';
    if (type.contains('phone')) return 'phone';
    return 'text';
  }

  static List<String> _normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
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
    return RegExp(r'^[+-]?\d+[.,]\d+$').hasMatch(value.trim());
  }

  static List<bool> _detectReadOnlyColumns(int width, List<List<String>> rows) {
    final readOnly = List<bool>.filled(width, false);
    for (final row in rows) {
      for (var index = 0; index < width && index < row.length; index++) {
        if (_looksLikeFormulaExpression(row[index])) {
          readOnly[index] = true;
        }
      }
    }
    return readOnly;
  }

  static bool _looksLikeFormulaExpression(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('=') && trimmed.length > 1;
  }

  static String? _typeFromHeader(String header) {
    final value = header.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'date' || value == 'datum' || value.contains('fecha')) {
      return 'date';
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
    if (value.contains('pause') ||
        value.contains('break') ||
        value.contains('minutes') ||
        value.contains('minuten')) {
      return 'duration';
    }
    if (value.contains('hour') ||
        value.contains('stunden') ||
        value.contains('decimal') ||
        value.contains('wage') ||
        value.contains('lohn') ||
        value.contains('verdienst') ||
        value.contains('amount') ||
        value.contains('price')) {
      return 'decimal';
    }
    if (value.contains('mail')) return 'email';
    if (value.contains('phone') || value.contains('telefon')) return 'phone';
    return null;
  }

  static String _escapeCsvCell(String value, String delimiter) {
    final escaped = value.replaceAll('"', '""');
    final mustQuote =
        escaped.contains(delimiter) ||
        escaped.contains('"') ||
        escaped.contains('\n');
    return mustQuote ? '"$escaped"' : escaped;
  }
}

class _CsvTableBounds {
  const _CsvTableBounds({
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

class _CsvTypeInference {
  const _CsvTypeInference({
    required this.type,
    required this.confirmedFromData,
  });

  final String type;
  final bool confirmedFromData;
}
