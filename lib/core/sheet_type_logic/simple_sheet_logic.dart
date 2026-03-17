class SimpleSheetLogic {
  const SimpleSheetLogic._();

  static SimpleSheetTableBounds detectTableBounds(
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
        return SimpleSheetTableBounds(
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
    return SimpleSheetTableBounds(
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
      if (_isKnownTypeToken(normalized)) {
        matches++;
      }
    }
    return matches >= (values.length / 2).ceil();
  }

  static List<SimpleSheetTypeInference> inferSimpleTypeDetails({
    required List<String> headers,
    required List<List<String>> rows,
    required List<bool> readOnlyColumns,
  }) {
    final width = headers.length;
    return List<SimpleSheetTypeInference>.generate(width, (index) {
      final headerGuess = typeFromHeader(headers[index]);
      if (headerGuess == 'date' ||
          headerGuess == 'time' ||
          headerGuess == 'duration') {
        return SimpleSheetTypeInference(
          type: headerGuess!,
          confirmedFromData: true,
        );
      }
      if (readOnlyColumns[index]) {
        return SimpleSheetTypeInference(
          type: headerGuess ?? 'decimal',
          confirmedFromData: true,
        );
      }
      for (final row in rows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        if (looksLikeFormulaExpression(value)) continue;
        if (looksLikeDateValue(value)) {
          return const SimpleSheetTypeInference(
            type: 'date',
            confirmedFromData: true,
          );
        }
        if (looksLikeTimeValue(value)) {
          return const SimpleSheetTypeInference(
            type: 'time',
            confirmedFromData: true,
          );
        }
        if (looksLikeDecimalValue(value)) {
          return const SimpleSheetTypeInference(
            type: 'decimal',
            confirmedFromData: true,
          );
        }
        if (looksLikeIntegerValue(value)) {
          return const SimpleSheetTypeInference(
            type: 'int',
            confirmedFromData: true,
          );
        }
        return const SimpleSheetTypeInference(
          type: 'text',
          confirmedFromData: true,
        );
      }
      return SimpleSheetTypeInference(
        type: headerGuess ?? 'text',
        confirmedFromData: false,
      );
    });
  }

  static List<String> inferSimpleTypes(
    int width,
    List<List<String>> sampleRows, {
    List<String>? headers,
  }) {
    return List<String>.generate(width, (index) {
      final headerGuess = headers != null && index < headers.length
          ? typeFromHeader(headers[index])
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
        if (looksLikeDateValue(value)) return 'date';
        if (looksLikeTimeValue(value)) return 'time';
        if (looksLikeDecimalValue(value)) return 'decimal';
        if (looksLikeIntegerValue(value)) return 'int';
        return 'text';
      }
      return headerGuess ?? 'text';
    });
  }

  static int trimTrailingFooterRows({
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

  static String normalizeTypeLabel(String raw) {
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

  static bool looksLikeDateValue(String value) {
    final compact = value.trim();
    return RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2,4}$').hasMatch(compact) ||
        RegExp(r'^\d{4}[./-]\d{1,2}[./-]\d{1,2}$').hasMatch(compact);
  }

  static bool looksLikeTimeValue(String value) {
    final compact = value.trim().toLowerCase();
    return RegExp(r'^\d{1,2}:\d{2}(:\d{2})?(\s?(am|pm))?$').hasMatch(compact);
  }

  static bool looksLikeIntegerValue(String value) {
    return RegExp(r'^[+-]?\d+$').hasMatch(value.trim());
  }

  static bool looksLikeDecimalValue(String value) {
    return RegExp(r'^[+-]?\d+[.,]\d+$').hasMatch(value.trim());
  }

  static bool looksLikeFormulaExpression(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    if (compact.startsWith('=')) return true;
    return RegExp(r'^[A-Z]{1,3}\d+\s*=').hasMatch(compact);
  }

  static String? typeFromHeader(String header) {
    final value = header.trim().toLowerCase();
    if (value.isEmpty) return null;
    if (_isDateHeaderName(header)) {
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
        if (looksLikeDateValue(value)) {
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

  static bool _isDateHeaderName(String header) {
    final value = header.trim().toLowerCase();
    return value == 'date' ||
        value == 'datum' ||
        value == 'tag' ||
        value == 'data' ||
        value.contains('fecha');
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

class SimpleSheetTableBounds {
  const SimpleSheetTableBounds({
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

class SimpleSheetTypeInference {
  const SimpleSheetTypeInference({
    required this.type,
    required this.confirmedFromData,
  });

  final String type;
  final bool confirmedFromData;
}
