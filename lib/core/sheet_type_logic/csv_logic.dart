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
    final lines = content
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) {
      throw const FormatException(
        'Simple mode expects line 1 headers and line 2 value types.',
      );
    }

    final delimiter = _detectDelimiter(lines[0]);
    final headers = _splitCsvLine(lines[0], delimiter: delimiter);
    if (headers.isEmpty) {
      throw const FormatException('CSV header row is empty.');
    }

    final secondLineValues = _splitCsvLine(lines[1], delimiter: delimiter);
    final hasTypeRow = _looksLikeTypeRow(secondLineValues);
    final valueTypes = hasTypeRow
        ? List<String>.generate(
            headers.length,
            (index) => index < secondLineValues.length
                ? _normalizeTypeLabel(secondLineValues[index])
                : 'text',
          )
        : _inferSimpleTypes(
            headers.length,
            lines
                .skip(1)
                .map((line) => _splitCsvLine(line, delimiter: delimiter))
                .take(20)
                .toList(),
          );

    final rows = lines
        .skip(hasTypeRow ? 2 : 1)
        .map(
          (line) => _normalizeRowToWidth(
            _splitCsvLine(line, delimiter: delimiter),
            headers.length,
          ),
        )
        .toList();

    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: SimpleFileFormat.csv,
      headers: headers,
      valueTypes: valueTypes,
      readOnlyColumns: List<bool>.filled(headers.length, false),
      rows: rows,
      csvDelimiter: delimiter,
      hasTypeRow: hasTypeRow,
    );
  }

  static Uint8List buildBytes(SimpleSheetData sheetData) {
    final delimiter = sheetData.csvDelimiter;
    final lines = <String>[];
    lines.add(
      sheetData.headers
          .map((cell) => _escapeCsvCell(cell, delimiter))
          .join(delimiter),
    );
    if (sheetData.hasTypeRow) {
      lines.add(
        sheetData.valueTypes
            .map((cell) => _escapeCsvCell(cell, delimiter))
            .join(delimiter),
      );
    }
    for (final row in sheetData.rows) {
      final normalized = _normalizeRowToWidth(row, sheetData.headers.length);
      lines.add(
        normalized
            .map((cell) => _escapeCsvCell(cell, delimiter))
            .join(delimiter),
      );
    }
    return Uint8List.fromList(utf8.encode('${lines.join('\n')}\n'));
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

  static String _detectDelimiter(String line) {
    const candidates = <String>[',', ';', '\t'];
    String best = ',';
    var bestCount = -1;
    for (final candidate in candidates) {
      final count = _countDelimiterOutsideQuotes(line, candidate);
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
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

  static List<String> _inferSimpleTypes(int width, List<List<String>> sampleRows) {
    return List<String>.generate(width, (index) {
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

  static String _normalizeTypeLabel(String raw) {
    final type = raw.trim().toLowerCase();
    if (type.contains('date')) return 'date';
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

  static String _escapeCsvCell(String value, String delimiter) {
    final escaped = value.replaceAll('"', '""');
    final mustQuote =
        escaped.contains(delimiter) ||
        escaped.contains('"') ||
        escaped.contains('\n');
    return mustQuote ? '"$escaped"' : escaped;
  }
}
