import 'dart:convert';
import 'dart:typed_data';

import 'sheet_file_models.dart';
import 'simple_sheet_logic.dart';

class CsvSheetCodec {
  const CsvSheetCodec._();

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
    final tableBounds = SimpleSheetLogic.detectTableBounds(
      parsedRows,
      emptyHeaderError: 'CSV header row is empty.',
    );
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
        : SimpleSheetLogic.normalizeRowToWidth(
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
          (row) => SimpleSheetLogic.normalizeRowToWidth(
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
        : List<int>.generate(
            tableBounds.columnCount,
            (index) => index,
          ).where((index) {
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
      final normalized = SimpleSheetLogic.normalizeRowToWidth(
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

  static List<SimpleSheetTypeInference> _buildTypeInferenceFromTypeRow({
    required int headerCount,
    required List<String> secondLineValues,
  }) {
    return List<SimpleSheetTypeInference>.generate(
      headerCount,
      (index) => SimpleSheetTypeInference(
        type: index < secondLineValues.length
            ? SimpleSheetLogic.normalizeTypeLabel(secondLineValues[index])
            : 'text',
        confirmedFromData: true,
      ),
    );
  }

  static List<SimpleSheetTypeInference> _inferSimpleTypes({
    required List<String> headers,
    required List<List<String>> rows,
    required List<bool> readOnlyColumns,
  }) {
    return SimpleSheetLogic.inferSimpleTypeDetails(
      headers: headers,
      rows: rows,
      readOnlyColumns: readOnlyColumns,
    );
  }

  static List<bool> _detectReadOnlyColumns(int width, List<List<String>> rows) {
    final readOnly = List<bool>.filled(width, false);
    for (final row in rows) {
      for (var index = 0; index < width && index < row.length; index++) {
        if (SimpleSheetLogic.looksLikeFormulaExpression(row[index])) {
          readOnly[index] = true;
        }
      }
    }
    return readOnly;
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
