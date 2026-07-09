class FieldTypeGuesser {
  const FieldTypeGuesser._();

  static const String defaultCurrencyCode = 'USD';
  static const List<String> currencyCodes = <String>[
    'USD',
    'EUR',
    'GBP',
    'CHF',
    'JPY',
    'CAD',
    'AUD',
  ];

  static List<FieldTypeInference> inferTypeDetails({
    required List<String> headers,
    required List<List<String>> rows,
    required List<bool> readOnlyColumns,
  }) {
    final width = headers.length;
    return List<FieldTypeInference>.generate(width, (index) {
      final headerGuess = typeFromHeader(headers[index]);
      if (_isStrongHeaderGuess(headerGuess)) {
        return FieldTypeInference(type: headerGuess!, confirmedFromData: true);
      }
      if (readOnlyColumns[index]) {
        return FieldTypeInference(
          type: headerGuess ?? 'float',
          confirmedFromData: true,
        );
      }
      for (final row in rows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        if (looksLikeFormulaExpression(value)) continue;
        final valueType = typeFromValue(value);
        if (headerGuess == 'money' &&
            (valueType == 'int' || valueType == 'float')) {
          return FieldTypeInference(
            type: moneyType(defaultCurrencyCode),
            confirmedFromData: false,
          );
        }
        return FieldTypeInference(type: valueType, confirmedFromData: true);
      }
      return FieldTypeInference(
        type: headerGuess == 'money'
            ? moneyType(defaultCurrencyCode)
            : headerGuess ?? 'text',
        confirmedFromData: false,
      );
    });
  }

  static List<String> inferTypes(
    int width,
    List<List<String>> sampleRows, {
    List<String>? headers,
  }) {
    return List<String>.generate(width, (index) {
      final headerGuess = headers != null && index < headers.length
          ? typeFromHeader(headers[index])
          : null;
      if (_isStrongHeaderGuess(headerGuess)) {
        return headerGuess!;
      }
      for (final row in sampleRows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        final valueType = typeFromValue(value);
        if (headerGuess == 'money' &&
            (valueType == 'int' || valueType == 'float')) {
          return moneyType(defaultCurrencyCode);
        }
        return valueType;
      }
      return headerGuess == 'money'
          ? moneyType(defaultCurrencyCode)
          : headerGuess ?? 'text';
    });
  }

  static String typeFromValue(String value) {
    if (looksLikeMoneyValue(value)) return moneyType(defaultCurrencyCode);
    if (looksLikeDateValue(value)) return 'date';
    if (looksLikeTimeValue(value)) return 'time';
    if (looksLikeBooleanValue(value)) return 'boolean';
    if (looksLikeDecimalValue(value)) return 'float';
    if (looksLikeIntegerValue(value)) return 'int';
    return 'text';
  }

  static String? typeFromHeader(String header) {
    final value = header.trim().toLowerCase();
    final tokens = _tokens(value);
    if (value.isEmpty) return null;
    if (isDateHeaderName(header)) return 'date';
    if (_hasAnyToken(tokens, const <String>[
      'start',
      'beginn',
      'begin',
      'end',
      'ende',
      'time',
      'uhr',
    ])) {
      return 'time';
    }
    if (_hasAnyToken(tokens, const <String>[
      'pause',
      'break',
      'minutes',
      'minuten',
      'minute',
      'min',
    ])) {
      return 'duration';
    }
    if (_hasAnyToken(tokens, const <String>[
      'bool',
      'rsvp',
      'paid',
      'done',
      'active',
    ])) {
      return 'boolean';
    }
    if (_hasAnyToken(tokens, const <String>[
      'reps',
      'rep',
      'sets',
      'set',
      'count',
      'quantity',
      'qty',
    ])) {
      return 'int';
    }
    if (_hasAnyToken(tokens, const <String>[
          'amount',
          'price',
          'cost',
          'costs',
          'expense',
          'expenses',
          'money',
          'currency',
          'total',
          'subtotal',
          'fee',
          'fees',
          'budget',
          'revenue',
          'income',
          'payment',
          'payments',
          'salary',
          'wage',
          'lohn',
          'verdienst',
        ]) ||
        _containsAny(value, const <String>[
          r'$',
          '€',
          '£',
          '¥',
          ' usd',
          ' eur',
          ' gbp',
          ' chf',
        ])) {
      return 'money';
    }
    if (_containsAny(value, const <String>[
      'hour',
      'stunden',
      'decimal',
      'float',
      'distance',
    ])) {
      return 'float';
    }
    if (_hasAnyToken(tokens, const <String>['km', 'kg', 'mi'])) return 'float';
    if (value.contains('mail')) return 'email';
    if (value.contains('phone') || value.contains('telefon')) return 'phone';
    return null;
  }

  static String normalizeTypeLabel(String raw) {
    final type = raw.trim().toLowerCase();
    if (isMoneyType(type)) return 'money';
    if (type.contains('date')) return 'date';
    if (type.contains('duration') || type.contains('timespan')) {
      return 'duration';
    }
    if (type.contains('time')) return 'time';
    if (isBooleanType(type)) return 'boolean';
    if (isIntegerType(type)) return 'int';
    if (type.contains('double') ||
        type.contains('decimal') ||
        type.contains('float') ||
        type.contains('num')) {
      return 'float';
    }
    if (type.contains('email')) return 'email';
    if (type.contains('phone')) return 'phone';
    return 'text';
  }

  static String displayTypeLabel(String rawType) {
    final normalizedType = normalizeTypeLabel(rawType);
    if (normalizedType == 'int') return 'integer';
    if (normalizedType == 'float') return 'float';
    if (normalizedType == 'money') {
      return moneyType(currencyCodeFromType(rawType));
    }
    return normalizedType;
  }

  static bool isMoneyType(String rawType) {
    final type = rawType.trim().toLowerCase();
    if (type == 'money' || type == 'currency') return true;
    if (type.startsWith('money:') || type.startsWith('currency:')) return true;
    return type.contains('money') || type.contains('currency');
  }

  static String moneyType(String currencyCode) {
    return 'money:${normalizeCurrencyCode(currencyCode)}';
  }

  static String normalizeCurrencyCode(String rawCurrencyCode) {
    final normalized = rawCurrencyCode.trim().toUpperCase();
    if (currencyCodes.contains(normalized)) return normalized;
    return defaultCurrencyCode;
  }

  static String currencyCodeFromType(String rawType) {
    final type = rawType.trim();
    final separated = RegExp(
      r'^(?:money|currency)\s*[:/ -]\s*([a-zA-Z]{3})$',
      caseSensitive: false,
    ).firstMatch(type);
    if (separated != null) {
      return normalizeCurrencyCode(separated.group(1)!);
    }
    final upper = type.toUpperCase();
    for (final currencyCode in currencyCodes) {
      if (RegExp(
        r'(^|[^A-Z])' + currencyCode + r'([^A-Z]|$)',
      ).hasMatch(upper)) {
        return currencyCode;
      }
    }
    return defaultCurrencyCode;
  }

  static bool isIntegerType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'number' ||
        type == 'integer' ||
        type == 'int' ||
        type.contains('integer');
  }

  static bool isDecimalType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type.contains('double') ||
        type.contains('decimal') ||
        type.contains('float') ||
        (type.contains('num') && !isIntegerType(type));
  }

  static bool isBooleanType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type == 'boolean' || type == 'bool';
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

  static bool looksLikeBooleanValue(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized == 'TRUE' || normalized == 'FALSE';
  }

  static bool looksLikeIntegerValue(String value) {
    return RegExp(r'^[+-]?\d+$').hasMatch(value.trim());
  }

  static bool looksLikeDecimalValue(String value) {
    return RegExp(r'^[+-]?\d+[.,]\d+$').hasMatch(value.trim());
  }

  static bool looksLikeMoneyValue(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    return RegExp(
          r'^(?:[$€£¥]\s*)?[+-]?\d+(?:[.,]\d{1,2})?\s*(?:[$€£¥]|USD|EUR|GBP|CHF|JPY|CAD|AUD)?$',
          caseSensitive: false,
        ).hasMatch(compact) &&
        RegExp(
          r'[$€£¥]|USD|EUR|GBP|CHF|JPY|CAD|AUD',
          caseSensitive: false,
        ).hasMatch(compact);
  }

  static bool looksLikeFormulaExpression(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    if (compact.startsWith('=')) return true;
    return RegExp(r'^[A-Z]{1,3}\d+\s*=').hasMatch(compact);
  }

  static bool looksLikeDataRow(List<String> row) {
    var nonEmptyCount = 0;
    var dataLikeCount = 0;
    for (final rawValue in row) {
      final value = rawValue.trim();
      if (value.isEmpty) continue;
      nonEmptyCount++;
      if (looksLikeDateValue(value) ||
          looksLikeTimeValue(value) ||
          looksLikeMoneyValue(value) ||
          looksLikeBooleanValue(value) ||
          looksLikeDecimalValue(value) ||
          looksLikeIntegerValue(value)) {
        dataLikeCount++;
      }
    }
    if (nonEmptyCount == 0) return false;
    return dataLikeCount >= (nonEmptyCount / 2).ceil();
  }

  static int? findDateColumnIndex({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final headerIndex = headers.indexWhere(isDateHeaderName);
    if (headerIndex >= 0) return headerIndex;

    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      var matches = 0;
      var checked = 0;
      for (final row in rows) {
        if (columnIndex >= row.length) continue;
        final value = row[columnIndex].trim();
        if (value.isEmpty) continue;
        checked++;
        if (looksLikeDateValue(value)) matches++;
        if (checked >= 12) break;
      }
      if (matches >= 3) return columnIndex;
    }
    return null;
  }

  static bool isDateHeaderName(String header) {
    final tokens = _tokens(header);
    return _hasAnyToken(tokens, const <String>[
      'date',
      'datum',
      'tag',
      'data',
      'fecha',
    ]);
  }

  static bool isKnownTypeToken(String type) {
    if (type.contains('date')) return true;
    if (type.contains('time')) return true;
    if (type.contains('duration')) return true;
    if (type.contains('timespan')) return true;
    if (type.contains('bool')) return true;
    if (type.contains('int')) return true;
    if (type.contains('double')) return true;
    if (type.contains('decimal')) return true;
    if (type.contains('float')) return true;
    if (type.contains('number')) return true;
    if (type.contains('num')) return true;
    if (type.contains('currency')) return true;
    if (type.contains('money')) return true;
    if (type.contains('text')) return true;
    if (type.contains('string')) return true;
    if (type.contains('email')) return true;
    if (type.contains('phone')) return true;
    return false;
  }

  static bool _isStrongHeaderGuess(String? type) {
    return type == 'date' ||
        type == 'time' ||
        type == 'duration' ||
        type == 'boolean';
  }

  static bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  static List<String> _tokens(String value) {
    return value
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static bool _hasAnyToken(List<String> valueTokens, List<String> candidates) {
    return candidates.any(valueTokens.contains);
  }
}

class FieldTypeInference {
  const FieldTypeInference({
    required this.type,
    required this.confirmedFromData,
  });

  final String type;
  final bool confirmedFromData;
}
