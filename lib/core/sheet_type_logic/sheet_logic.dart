import 'package:calcrow/core/guessers/field_type_guesser.dart';

class SheetLogic {
  const SheetLogic._();

  static SheetTableBounds detectTableBounds(
    List<List<String>> rows, {
    required String emptyHeaderError,
  }) {
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        if (!looksLikeDateValue(row[columnIndex])) continue;
        var dateMatches = 0;
        for (var probeRow = rowIndex; probeRow < rows.length; probeRow++) {
          final value = rows[probeRow][columnIndex].trim();
          if (value.isEmpty) continue;
          if (looksLikeDateValue(value)) {
            dateMatches++;
          }
          if (dateMatches >= 2) break;
        }
        if (dateMatches < 2) continue;

        var candidateHeaderRowIndex = rowIndex - 1;
        var hasTypeRow = false;
        if (candidateHeaderRowIndex > 0 &&
            looksLikeTypeRow(rows[candidateHeaderRowIndex])) {
          candidateHeaderRowIndex--;
          hasTypeRow = true;
        }
        final headerRow = rows[candidateHeaderRowIndex];
        if (candidateHeaderRowIndex > 0 &&
            FieldTypeGuesser.looksLikeDataRow(headerRow)) {
          continue;
        }
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
        return SheetTableBounds(
          headerRowIndex: candidateHeaderRowIndex,
          startColumnIndex: startColumnIndex,
          columnCount: columnCount,
          hasTypeRow: hasTypeRow,
        );
      }
    }

    final headerRow = rows.first;
    final firstEmptyHeaderIndex = headerRow.indexWhere(
      (value) => value.trim().isEmpty,
    );
    final headerCount = firstEmptyHeaderIndex >= 0
        ? firstEmptyHeaderIndex
        : headerRow.length;
    if (headerCount == 0) {
      throw FormatException(emptyHeaderError);
    }
    return SheetTableBounds(
      headerRowIndex: 0,
      startColumnIndex: 0,
      columnCount: headerCount,
      hasTypeRow: rows.length > 1 && looksLikeTypeRow(rows[1]),
    );
  }

  static bool looksLikeTypeRow(List<String> values) {
    if (values.isEmpty) return false;
    var matches = 0;
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (FieldTypeGuesser.isKnownTypeToken(normalized)) {
        matches++;
      }
    }
    return matches >= (values.length / 2).ceil();
  }

  static List<FieldTypeInference> inferTypeDetails({
    required List<String> headers,
    required List<List<String>> rows,
    required List<bool> readOnlyColumns,
  }) => FieldTypeGuesser.inferTypeDetails(
    headers: headers,
    rows: rows,
    readOnlyColumns: readOnlyColumns,
  );

  static List<String> inferTypes(
    int width,
    List<List<String>> sampleRows, {
    List<String>? headers,
  }) => FieldTypeGuesser.inferTypes(width, sampleRows, headers: headers);

  static int trimTrailingFooterRows({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    if (rows.isEmpty) return 0;
    final dateColumnIndex = FieldTypeGuesser.findDateColumnIndex(
      headers: headers,
      rows: rows,
    );
    if (dateColumnIndex == null) {
      return rows.length;
    }

    var lastDateRowIndex = -1;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final value = dateColumnIndex < row.length ? row[dateColumnIndex] : '';
      if (looksLikeDateValue(value)) {
        lastDateRowIndex = rowIndex;
      }
    }
    if (lastDateRowIndex < 0) {
      return rows.length;
    }
    return lastDateRowIndex + 1;
  }

  static List<String> normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
  }

  static String normalizeTypeLabel(String raw) =>
      FieldTypeGuesser.normalizeTypeLabel(raw);

  static bool isIntegerType(String rawType) =>
      FieldTypeGuesser.isIntegerType(rawType);

  static bool isDecimalType(String rawType) =>
      FieldTypeGuesser.isDecimalType(rawType);

  static bool isBooleanType(String rawType) =>
      FieldTypeGuesser.isBooleanType(rawType);

  static String displayTypeLabel(String rawType) =>
      FieldTypeGuesser.displayTypeLabel(rawType);

  static bool looksLikeDateValue(String value) =>
      FieldTypeGuesser.looksLikeDateValue(value);

  static bool looksLikeTimeValue(String value) =>
      FieldTypeGuesser.looksLikeTimeValue(value);

  static bool looksLikeBooleanValue(String value) =>
      FieldTypeGuesser.looksLikeBooleanValue(value);

  static bool looksLikeIntegerValue(String value) =>
      FieldTypeGuesser.looksLikeIntegerValue(value);

  static bool looksLikeDecimalValue(String value) =>
      FieldTypeGuesser.looksLikeDecimalValue(value);

  static bool looksLikeFormulaExpression(String value) =>
      FieldTypeGuesser.looksLikeFormulaExpression(value);

  static String? typeFromHeader(String header) =>
      FieldTypeGuesser.typeFromHeader(header);

  static String selectBestSheetName(
    Iterable<String> names,
    DateTime now, {
    String? fallback,
  }) {
    final candidates = <String>{
      ..._monthTokens(now.month),
      '${now.month}',
      now.month.toString().padLeft(2, '0'),
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
      '${now.month.toString().padLeft(2, '0')}-${now.year}',
    }.map((value) => value.toLowerCase()).toList();
    for (final name in names) {
      final lowered = name.trim().toLowerCase();
      if (candidates.contains(lowered)) {
        return name;
      }
    }
    for (final name in names) {
      final lowered = name.trim().toLowerCase();
      if (candidates.any(lowered.contains)) {
        return name;
      }
    }
    final fallbackName = fallback ?? names.first;
    if (fallbackName.trim().isEmpty) {
      throw const FormatException('The selected document has no named sheets.');
    }
    return fallbackName;
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
}

class SheetTableBounds {
  const SheetTableBounds({
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
