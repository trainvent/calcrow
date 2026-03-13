import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'sheet_file_models.dart';

Map<String, Object?> parseOdsSheetDataTransfer(Map<String, Object?> message) {
  final bytes = message['bytes'];
  final fileName = message['fileName'];
  final path = message['path'];
  final nowMilliseconds = message['nowMillisecondsSinceEpoch'];
  if (bytes is! Uint8List || fileName is! String) {
    throw ArgumentError('Invalid ODS parse request.');
  }

  final parsed = OdsSheetLogic.parse(
    bytes: bytes,
    fileName: fileName,
    path: path as String?,
    now: nowMilliseconds is int
        ? DateTime.fromMillisecondsSinceEpoch(nowMilliseconds)
        : null,
  );
  return simpleSheetDataToTransfer(parsed);
}

Map<String, Object?> simpleSheetDataToTransfer(SimpleSheetData data) {
  return <String, Object?>{
    'fileName': data.fileName,
    'path': data.path,
    'format': data.format.name,
    'headers': data.headers,
    'valueTypes': data.valueTypes,
    'readOnlyColumns': data.readOnlyColumns,
    'rows': data.rows,
    'pendingTypeSelectionColumns': data.pendingTypeSelectionColumns,
    'csvDelimiter': data.csvDelimiter,
    'hasTypeRow': data.hasTypeRow,
    'sheetName': data.xlsxSheetName,
    'sourceBytes': data.sourceBytes,
  };
}

SimpleSheetData simpleSheetDataFromTransfer(Map<String, Object?> message) {
  final formatName =
      (message['format'] as String?) ?? SimpleFileFormat.csv.name;
  final format = SimpleFileFormat.values.firstWhere(
    (candidate) => candidate.name == formatName,
    orElse: () => SimpleFileFormat.csv,
  );
  return SimpleSheetData(
    fileName: (message['fileName'] as String?) ?? 'calcrow_simple',
    path: message['path'] as String?,
    format: format,
    headers: ((message['headers'] as List?) ?? const <Object?>[])
        .map((value) => value?.toString() ?? '')
        .toList(),
    valueTypes: ((message['valueTypes'] as List?) ?? const <Object?>[])
        .map((value) => value?.toString() ?? '')
        .toList(),
    readOnlyColumns:
        ((message['readOnlyColumns'] as List?) ?? const <Object?>[])
            .map((value) => value == true)
            .toList(),
    rows: ((message['rows'] as List?) ?? const <Object?>[])
        .map(
          (row) => ((row as List?) ?? const <Object?>[])
              .map((value) => value?.toString() ?? '')
              .toList(),
        )
        .toList(),
    pendingTypeSelectionColumns:
        ((message['pendingTypeSelectionColumns'] as List?) ?? const <Object?>[])
            .map((value) => value is int ? value : int.parse('$value'))
            .toList(),
    csvDelimiter: (message['csvDelimiter'] as String?) ?? ',',
    hasTypeRow: message['hasTypeRow'] == true,
    xlsxSheetName: message['sheetName'] as String?,
    sourceBytes: message['sourceBytes'] as Uint8List?,
  );
}

class OdsSheetLogic {
  const OdsSheetLogic._();

  static const String _nsOffice =
      'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const String _nsTable =
      'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  static const String _nsText =
      'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const String _nsCalcExt =
      'urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0';

  static SimpleSheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      throw const FormatException('The selected ODS has no content.xml.');
    }

    final contentXml = utf8.decode(contentFile.content as List<int>);
    final document = XmlDocument.parse(contentXml);
    final spreadsheet = _spreadsheetElement(document);
    if (spreadsheet == null) {
      throw const FormatException('The selected ODS has no spreadsheet body.');
    }

    final tables = _childElements(
      spreadsheet,
      localName: 'table',
      namespace: _nsTable,
    ).toList();
    if (tables.isEmpty) {
      throw const FormatException('The selected ODS has no sheets.');
    }

    final sheetName = _selectBestSheetName(tables, now ?? DateTime.now());
    final table = tables.firstWhere(
      (candidate) =>
          _attribute(candidate, 'name', namespace: _nsTable) == sheetName,
    );

    final parsedRows = _parseTableRows(table);
    final rawRows = parsedRows
        .map((row) => row.values.map((cell) => cell.value).toList())
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList();
    if (rawRows.isEmpty) {
      throw const FormatException('The selected ODS sheet is empty.');
    }

    final rawReadOnlyRows = parsedRows
        .map((row) => row.values.map((cell) => cell.isFormula).toList())
        .take(rawRows.length)
        .toList();
    final width = rawRows.fold<int>(
      0,
      (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth,
    );
    final normalizedRows = rawRows
        .map((row) => _normalizeRowToWidth(row, width))
        .toList();
    final normalizedReadOnly = rawReadOnlyRows
        .map((row) => _normalizeReadOnlyRow(row, width))
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
    final bodyRows = normalizedRows
        .skip(1)
        .map((row) => row.take(headerCount).toList())
        .toList();
    final trimmedRowCount = _trimTrailingFooterRows(
      headers: headers,
      rows: bodyRows,
    );
    final rows = bodyRows.take(trimmedRowCount).toList();
    final readOnlyColumns = List<bool>.generate(headerCount, (index) {
      for (final row in normalizedReadOnly.skip(1).take(trimmedRowCount)) {
        if (index < row.length && row[index]) {
          return true;
        }
      }
      return false;
    });
    final valueTypes = _inferSimpleTypes(
      headerCount,
      rows.take(20).toList(),
      headers: headers,
    );
    final pendingTypeSelectionColumns = List<int>.generate(
      headerCount,
      (index) => index,
    ).where((index) => !readOnlyColumns[index]).toList();

    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: SimpleFileFormat.ods,
      headers: headers,
      valueTypes: valueTypes,
      readOnlyColumns: readOnlyColumns,
      rows: rows,
      pendingTypeSelectionColumns: pendingTypeSelectionColumns,
      xlsxSheetName: sheetName,
      sourceBytes: bytes,
    );
  }

  static Uint8List buildBytes(SimpleSheetData data) {
    final sourceBytes = data.sourceBytes;
    if (sourceBytes == null || sourceBytes.isEmpty) {
      throw StateError('No ODS source document is loaded.');
    }

    final archive = ZipDecoder().decodeBytes(sourceBytes, verify: true);
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      throw StateError('The ODS document has no content.xml.');
    }

    final document = XmlDocument.parse(
      utf8.decode(contentFile.content as List<int>),
    );
    final spreadsheet = _spreadsheetElement(document);
    if (spreadsheet == null) {
      throw StateError('The ODS document has no spreadsheet body.');
    }

    final preferredSheetName = data.xlsxSheetName?.trim();
    if (preferredSheetName == null || preferredSheetName.isEmpty) {
      throw StateError('No ODS sheet is selected.');
    }

    final table =
        _childElements(
          spreadsheet,
          localName: 'table',
          namespace: _nsTable,
        ).firstWhere(
          (candidate) =>
              _attribute(candidate, 'name', namespace: _nsTable) ==
              preferredSheetName,
          orElse: () => throw StateError(
            'Could not find the imported sheet "$preferredSheetName" in the ODS document.',
          ),
        );

    for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
      final row = data.rows[rowIndex];
      final targetRow = _ensureEditableRow(table, rowIndex + 1);
      for (var col = 0; col < data.headers.length; col++) {
        if (data.readOnlyColumns[col]) continue;
        final value = col < row.length ? row[col].trim() : '';
        final targetCell = _ensureEditableCell(targetRow, col);
        _writeCellValue(targetCell, type: data.valueTypes[col], raw: value);
      }
    }

    final encodedXml = utf8.encode(document.toXmlString(pretty: false));
    final updatedContentFile =
        ArchiveFile(
            contentFile.name,
            encodedXml.length,
            Uint8List.fromList(encodedXml),
          )
          ..compress = contentFile.compress
          ..comment = contentFile.comment
          ..crc32 = null
          ..isFile = contentFile.isFile
          ..mode = contentFile.mode
          ..lastModTime = contentFile.lastModTime;
    archive.addFile(updatedContentFile);
    final encodedArchive = ZipEncoder().encode(archive);
    if (encodedArchive == null || encodedArchive.isEmpty) {
      throw StateError('Could not encode ODS document.');
    }
    return Uint8List.fromList(encodedArchive);
  }

  static XmlElement? _spreadsheetElement(XmlDocument document) {
    final body = document.rootElement
        .findElements('body', namespace: _nsOffice)
        .firstOrNull;
    return body?.findElements('spreadsheet', namespace: _nsOffice).firstOrNull;
  }

  static List<_OdsParsedRow> _parseTableRows(XmlElement table) {
    final rows = <_OdsParsedRow>[];
    for (final rowElement in _childElements(
      table,
      localName: 'table-row',
      namespace: _nsTable,
    )) {
      final repeatCount = _repetition(
        rowElement,
        'number-rows-repeated',
        namespace: _nsTable,
      );
      final parsedCells = _parseRowCells(rowElement);
      for (var i = 0; i < repeatCount; i++) {
        rows.add(_OdsParsedRow(values: parsedCells));
      }
    }
    return rows;
  }

  static List<_OdsParsedCell> _parseRowCells(XmlElement rowElement) {
    final cells = <_OdsParsedCell>[];
    for (final cellElement in rowElement.childElements) {
      final local = cellElement.name.local;
      final namespace = cellElement.name.namespaceUri;
      if (namespace != _nsTable) continue;
      if (local != 'table-cell' && local != 'covered-table-cell') {
        continue;
      }
      final repeatCount = _repetition(
        cellElement,
        'number-columns-repeated',
        namespace: _nsTable,
      );
      final value = local == 'covered-table-cell'
          ? ''
          : _cellDisplayValue(cellElement);
      final isFormula =
          _attribute(cellElement, 'formula', namespace: _nsTable) != null;
      for (var i = 0; i < repeatCount; i++) {
        cells.add(_OdsParsedCell(value: value, isFormula: isFormula));
      }
    }
    return cells;
  }

  static String _cellDisplayValue(XmlElement cell) {
    final textNodes = cell.descendants
        .whereType<XmlElement>()
        .where(
          (element) =>
              element.name.local == 'p' && element.name.namespaceUri == _nsText,
        )
        .map((element) => element.innerText.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (textNodes.isNotEmpty) {
      return textNodes.join('\n');
    }

    final timeValue = _attribute(cell, 'time-value', namespace: _nsOffice);
    if (timeValue != null && timeValue.isNotEmpty) {
      final formatted = _formatOdsTimeValue(timeValue);
      if (formatted != null) return formatted;
    }

    return _attribute(cell, 'value', namespace: _nsOffice) ??
        _attribute(cell, 'date-value', namespace: _nsOffice) ??
        '';
  }

  static XmlElement _ensureEditableRow(XmlElement table, int logicalRowIndex) {
    final handles = _buildRowHandles(table);
    if (logicalRowIndex < handles.length) {
      return _dedicateRepeatedRow(table, handles[logicalRowIndex]);
    }

    final newRow = XmlElement(XmlName('table-row', 'table'));
    table.children.add(newRow);
    return newRow;
  }

  static List<_OdsRowHandle> _buildRowHandles(XmlElement table) {
    final handles = <_OdsRowHandle>[];
    for (final row in _childElements(
      table,
      localName: 'table-row',
      namespace: _nsTable,
    )) {
      final repeatCount = _repetition(
        row,
        'number-rows-repeated',
        namespace: _nsTable,
      );
      for (var i = 0; i < repeatCount; i++) {
        handles.add(
          _OdsRowHandle(
            element: row,
            repeatedIndex: i,
            repeatedCount: repeatCount,
          ),
        );
      }
    }
    return handles;
  }

  static XmlElement _dedicateRepeatedRow(
    XmlElement table,
    _OdsRowHandle handle,
  ) {
    if (handle.repeatedCount <= 1) {
      return handle.element;
    }

    final parentChildren = table.children;
    final originalIndex = parentChildren.indexOf(handle.element);
    final before = handle.repeatedIndex;
    final after = handle.repeatedCount - before - 1;
    final replacements = <XmlNode>[
      if (before > 0) _cloneWithRepeat(handle.element, before, isRow: true),
      _cloneWithRepeat(handle.element, 1, isRow: true),
      if (after > 0) _cloneWithRepeat(handle.element, after, isRow: true),
    ];
    parentChildren.removeAt(originalIndex);
    parentChildren.insertAll(originalIndex, replacements);
    return replacements[before > 0 ? 1 : 0] as XmlElement;
  }

  static XmlElement _ensureEditableCell(
    XmlElement row,
    int logicalColumnIndex,
  ) {
    while (true) {
      final handles = _buildCellHandles(row);
      if (logicalColumnIndex < handles.length) {
        return _dedicateRepeatedCell(row, handles[logicalColumnIndex]);
      }
      row.children.add(XmlElement(XmlName('table-cell', 'table')));
    }
  }

  static List<_OdsCellHandle> _buildCellHandles(XmlElement row) {
    final handles = <_OdsCellHandle>[];
    for (final cell in row.childElements) {
      final local = cell.name.local;
      final namespace = cell.name.namespaceUri;
      if (namespace != _nsTable) continue;
      if (local != 'table-cell' && local != 'covered-table-cell') {
        continue;
      }
      final repeatCount = _repetition(
        cell,
        'number-columns-repeated',
        namespace: _nsTable,
      );
      for (var i = 0; i < repeatCount; i++) {
        handles.add(
          _OdsCellHandle(
            element: cell,
            repeatedIndex: i,
            repeatedCount: repeatCount,
          ),
        );
      }
    }
    return handles;
  }

  static XmlElement _dedicateRepeatedCell(
    XmlElement row,
    _OdsCellHandle handle,
  ) {
    if (handle.repeatedCount <= 1 &&
        handle.element.name.local == 'table-cell') {
      return handle.element;
    }

    final parentChildren = row.children;
    final originalIndex = parentChildren.indexOf(handle.element);
    final before = handle.repeatedIndex;
    final after = handle.repeatedCount - before - 1;
    final template = handle.element.name.local == 'covered-table-cell'
        ? XmlElement(XmlName('table-cell', 'table'))
        : handle.element;
    final replacements = <XmlNode>[
      if (before > 0) _cloneWithRepeat(template, before, isRow: false),
      _cloneWithRepeat(template, 1, isRow: false),
      if (after > 0) _cloneWithRepeat(template, after, isRow: false),
    ];
    parentChildren.removeAt(originalIndex);
    parentChildren.insertAll(originalIndex, replacements);
    return replacements[before > 0 ? 1 : 0] as XmlElement;
  }

  static XmlElement _cloneWithRepeat(
    XmlElement source,
    int repeatCount, {
    required bool isRow,
  }) {
    final clone = source.copy();
    _setAttribute(
      clone,
      isRow ? 'number-rows-repeated' : 'number-columns-repeated',
      repeatCount > 1 ? '$repeatCount' : null,
      namespace: _nsTable,
      prefix: 'table',
    );
    return clone;
  }

  static void _writeCellValue(
    XmlElement cell, {
    required String type,
    required String raw,
  }) {
    _setAttribute(
      cell,
      'number-columns-repeated',
      null,
      namespace: _nsTable,
      prefix: 'table',
    );
    _setAttribute(cell, 'formula', null, namespace: _nsTable, prefix: 'table');
    _setAttribute(
      cell,
      'value-type',
      null,
      namespace: _nsOffice,
      prefix: 'office',
    );
    _setAttribute(
      cell,
      'value-type',
      null,
      namespace: _nsCalcExt,
      prefix: 'calcext',
    );
    _setAttribute(cell, 'value', null, namespace: _nsOffice, prefix: 'office');
    _setAttribute(
      cell,
      'time-value',
      null,
      namespace: _nsOffice,
      prefix: 'office',
    );
    _setAttribute(
      cell,
      'date-value',
      null,
      namespace: _nsOffice,
      prefix: 'office',
    );
    cell.children.clear();

    final value = raw.trim();
    if (value.isEmpty) {
      return;
    }

    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.contains('time') ||
        normalizedType.contains('duration')) {
      final parsed = _parseTimeParts(value);
      if (parsed != null) {
        _setAttribute(
          cell,
          'value-type',
          'time',
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setAttribute(
          cell,
          'value-type',
          'time',
          namespace: _nsCalcExt,
          prefix: 'calcext',
        );
        _setAttribute(
          cell,
          'time-value',
          _odsDurationLiteral(
            hours: parsed.hours,
            minutes: parsed.minutes,
            seconds: parsed.seconds,
          ),
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setTextValue(cell, _formatTimeParts(parsed));
        return;
      }
    }

    if (normalizedType.contains('int') ||
        normalizedType.contains('double') ||
        normalizedType.contains('decimal') ||
        normalizedType.contains('number') ||
        normalizedType.contains('num')) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) {
        _setAttribute(
          cell,
          'value-type',
          'float',
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setAttribute(
          cell,
          'value-type',
          'float',
          namespace: _nsCalcExt,
          prefix: 'calcext',
        );
        _setAttribute(
          cell,
          'value',
          parsed.toString(),
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setTextValue(cell, value);
        return;
      }
    }

    _setAttribute(
      cell,
      'value-type',
      'string',
      namespace: _nsOffice,
      prefix: 'office',
    );
    _setAttribute(
      cell,
      'value-type',
      'string',
      namespace: _nsCalcExt,
      prefix: 'calcext',
    );
    _setTextValue(cell, value);
  }

  static void _setTextValue(XmlElement cell, String value) {
    cell.children.add(
      XmlElement(XmlName('p', 'text'), const <XmlAttribute>[], <XmlNode>[
        XmlText(value),
      ]),
    );
  }

  static void _setAttribute(
    XmlElement element,
    String localName,
    String? value, {
    required String namespace,
    required String prefix,
  }) {
    element.attributes.removeWhere(
      (attribute) =>
          attribute.name.local == localName &&
          (attribute.name.namespaceUri == namespace ||
              attribute.name.prefix == prefix),
    );
    if (value == null) return;
    element.attributes.add(XmlAttribute(XmlName(localName, prefix), value));
  }

  static String? _attribute(
    XmlElement element,
    String localName, {
    required String namespace,
  }) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName &&
          attribute.name.namespaceUri == namespace) {
        return attribute.value;
      }
    }
    return null;
  }

  static Iterable<XmlElement> _childElements(
    XmlElement parent, {
    required String localName,
    required String namespace,
  }) {
    return parent.childElements.where(
      (element) =>
          element.name.local == localName &&
          element.name.namespaceUri == namespace,
    );
  }

  static int _repetition(
    XmlElement element,
    String localName, {
    required String namespace,
  }) {
    final raw = _attribute(element, localName, namespace: namespace);
    final parsed = int.tryParse(raw ?? '');
    return parsed == null || parsed < 1 ? 1 : parsed;
  }

  static List<String> _normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
  }

  static List<bool> _normalizeReadOnlyRow(List<bool> row, int width) {
    return List<bool>.generate(
      width,
      (index) => index < row.length ? row[index] : false,
    );
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

  static bool _isDateHeaderName(String header) {
    final value = header.trim().toLowerCase();
    return value == 'date' ||
        value == 'datum' ||
        value == 'tag' ||
        value == 'data' ||
        value == 'fecha';
  }

  static String _selectBestSheetName(List<XmlElement> tables, DateTime now) {
    final candidates = <String>{
      ..._monthTokens(now.month),
      '${now.month}',
      now.month.toString().padLeft(2, '0'),
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
      '${now.month.toString().padLeft(2, '0')}-${now.year}',
    }.map((value) => value.toLowerCase()).toList();

    for (final table in tables) {
      final name = _attribute(table, 'name', namespace: _nsTable)?.trim() ?? '';
      final lowered = name.toLowerCase();
      if (candidates.contains(lowered)) {
        return name;
      }
    }
    for (final table in tables) {
      final name = _attribute(table, 'name', namespace: _nsTable)?.trim() ?? '';
      final lowered = name.toLowerCase();
      if (candidates.any(lowered.contains)) {
        return name;
      }
    }
    final fallback = _attribute(tables.first, 'name', namespace: _nsTable);
    if (fallback == null || fallback.trim().isEmpty) {
      throw const FormatException('The selected ODS has no named sheets.');
    }
    return fallback;
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

  static _OdsTimeParts? _parseTimeParts(String value) {
    final trimmed = value.trim().toLowerCase();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    var hours = int.tryParse(match.group(1) ?? '');
    final minutes = int.tryParse(match.group(2) ?? '');
    final seconds = int.tryParse(match.group(3) ?? '0');
    final meridiem = match.group(4);
    if (hours == null || minutes == null || seconds == null) return null;
    if (minutes < 0 || minutes > 59 || seconds < 0 || seconds > 59) {
      return null;
    }
    if (meridiem != null) {
      if (hours < 1 || hours > 12) return null;
      if (hours == 12) {
        hours = meridiem == 'am' ? 0 : 12;
      } else if (meridiem == 'pm') {
        hours += 12;
      }
    }
    return _OdsTimeParts(hours: hours, minutes: minutes, seconds: seconds);
  }

  static String _odsDurationLiteral({
    required int hours,
    required int minutes,
    required int seconds,
  }) {
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return 'PT${hh}H${mm}M${ss}S';
  }

  static String _formatTimeParts(_OdsTimeParts value) {
    final hh = value.hours.toString().padLeft(2, '0');
    final mm = value.minutes.toString().padLeft(2, '0');
    final ss = value.seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  static String? _formatOdsTimeValue(String raw) {
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return _formatTimeParts(
      _OdsTimeParts(hours: hours, minutes: minutes, seconds: seconds),
    );
  }
}

class _OdsParsedRow {
  const _OdsParsedRow({required this.values});

  final List<_OdsParsedCell> values;
}

class _OdsParsedCell {
  const _OdsParsedCell({required this.value, required this.isFormula});

  final String value;
  final bool isFormula;
}

class _OdsRowHandle {
  const _OdsRowHandle({
    required this.element,
    required this.repeatedIndex,
    required this.repeatedCount,
  });

  final XmlElement element;
  final int repeatedIndex;
  final int repeatedCount;
}

class _OdsCellHandle {
  const _OdsCellHandle({
    required this.element,
    required this.repeatedIndex,
    required this.repeatedCount,
  });

  final XmlElement element;
  final int repeatedIndex;
  final int repeatedCount;
}

class _OdsTimeParts {
  const _OdsTimeParts({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int hours;
  final int minutes;
  final int seconds;
}
