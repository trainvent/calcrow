import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:xml/xml.dart';

import 'sheet_file_models.dart';
import 'sheet_logic.dart';

class OdsWorkbookInspection {
  const OdsWorkbookInspection({
    required this.sheetCount,
    required this.sheetNames,
    required this.sheets,
  });

  final int sheetCount;
  final List<String> sheetNames;
  final List<OdsSheetInfo> sheets;
}

class OdsSheetInfo {
  const OdsSheetInfo({
    required this.name,
    required this.headerRowIndex,
    required this.entryCount,
    required this.hasDateColumn,
    required this.hasEditableTextColumn,
  });

  final String name;
  final int headerRowIndex;
  final int entryCount;
  final bool hasDateColumn;
  final bool hasEditableTextColumn;
}

class OdsMonthlySheetSuggestion {
  const OdsMonthlySheetSuggestion({
    required this.sourceSheetName,
    required this.targetSheetName,
    required this.year,
  });

  final String sourceSheetName;
  final String targetSheetName;
  final int year;
}

Map<String, Object?> parseOdsSheetDataTransfer(Map<String, Object?> message) {
  final bytes = message['bytes'];
  final fileName = message['fileName'];
  final path = message['path'];
  final nowMilliseconds = message['nowMillisecondsSinceEpoch'];
  final sheetName = message['sheetName'];
  if (bytes is! Uint8List || fileName is! String) {
    throw ArgumentError('Invalid ODS parse request.');
  }

  final parsed = OdsSheetCodec.parse(
    bytes: bytes,
    fileName: fileName,
    path: path as String?,
    now: nowMilliseconds is int
        ? DateTime.fromMillisecondsSinceEpoch(nowMilliseconds)
        : null,
    sheetName: sheetName as String?,
  );
  return sheetDataToTransfer(parsed);
}

Map<String, Object?> sheetDataToTransfer(SheetData data) {
  return <String, Object?>{
    'fileName': data.fileName,
    'path': data.path,
    'format': data.format.name,
    'headers': data.headers,
    'valueTypes': data.valueTypes,
    'readOnlyColumns': data.readOnlyColumns,
    'rows': data.rows,
    'pendingTypeSelectionColumns': data.pendingTypeSelectionColumns,
    'hasCachedValueTypes': data.hasCachedValueTypes,
    'csvDelimiter': data.csvDelimiter,
    'hasTypeRow': data.hasTypeRow,
    'sheetName': data.xlsxSheetName,
    'sourceBytes': data.sourceBytes,
  };
}

SheetData sheetDataFromTransfer(Map<String, Object?> message) {
  final formatName = (message['format'] as String?) ?? SheetFileFormat.csv.name;
  final format = SheetFileFormat.values.firstWhere(
    (candidate) => candidate.name == formatName,
    orElse: () => SheetFileFormat.csv,
  );
  return SheetData(
    fileName: (message['fileName'] as String?) ?? 'calcrow_sheet',
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
    hasCachedValueTypes: message['hasCachedValueTypes'] == true,
    csvDelimiter: (message['csvDelimiter'] as String?) ?? ',',
    hasTypeRow: message['hasTypeRow'] == true,
    xlsxSheetName: message['sheetName'] as String?,
    sourceBytes: message['sourceBytes'] as Uint8List?,
  );
}

class OdsSheetCodec {
  const OdsSheetCodec._();

  static const String _nsOffice =
      'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const String _nsTable =
      'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  static const String _nsText =
      'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const String _nsCalcExt =
      'urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0';

  static SheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
    String? sheetName,
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

    final selectedSheetName = sheetName?.trim().isNotEmpty == true
        ? sheetName!.trim()
        : _selectBestSheetName(tables, now ?? DateTime.now());
    final table = tables.firstWhere(
      (candidate) =>
          _attribute(candidate, 'name', namespace: _nsTable) ==
          selectedSheetName,
      orElse: () => throw FormatException(
        'Could not find the selected ODS worksheet “$selectedSheetName”.',
      ),
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
        .map((row) => SheetLogic.normalizeRowToWidth(row, width))
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
    final trimmedRowCount = SheetLogic.trimTrailingFooterRows(
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
    final valueTypes = FieldTypeGuesser.inferTypes(
      headerCount,
      rows.take(20).toList(),
      headers: headers,
    );
    final pendingTypeSelectionColumns = List<int>.generate(
      headerCount,
      (index) => index,
    ).where((index) => !readOnlyColumns[index]).toList();

    return SheetData(
      fileName: fileName,
      path: path,
      format: SheetFileFormat.ods,
      headers: headers,
      valueTypes: valueTypes,
      readOnlyColumns: readOnlyColumns,
      rows: rows,
      pendingTypeSelectionColumns: pendingTypeSelectionColumns,
      xlsxSheetName: selectedSheetName,
      sourceBytes: bytes,
    );
  }

  static OdsWorkbookInspection inspectSheets({
    required Uint8List bytes,
    required String fileName,
    required String? path,
  }) {
    final names = _sheetNames(bytes);
    final sheets = <OdsSheetInfo>[];
    for (final name in names) {
      try {
        final parsed = parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
          sheetName: name,
        );
        var hasEditableTextColumn = false;
        for (var index = 0; index < parsed.headers.length; index++) {
          if (parsed.readOnlyColumns[index]) continue;
          if (parsed.valueTypes[index].trim().toLowerCase() == 'text') {
            hasEditableTextColumn = true;
            break;
          }
        }
        sheets.add(
          OdsSheetInfo(
            name: name,
            headerRowIndex: 0,
            entryCount: parsed.rows.length,
            hasDateColumn:
                FieldTypeGuesser.findDateColumnIndex(
                  headers: parsed.headers,
                  rows: parsed.rows,
                ) !=
                null,
            hasEditableTextColumn: hasEditableTextColumn,
          ),
        );
      } on FormatException {
        // Empty and non-tabular worksheets are not selectable editor pages.
      }
    }
    return OdsWorkbookInspection(
      sheetCount: names.length,
      sheetNames: names,
      sheets: sheets,
    );
  }

  static OdsMonthlySheetSuggestion? suggestCurrentMonthSheet({
    required Uint8List bytes,
    required String fileName,
    DateTime? now,
    String preferredLanguageCode = 'en',
  }) {
    final effectiveNow = now ?? DateTime.now();
    final year = _monthlyLogbookYear(fileName);
    if (year == null || year != effectiveNow.year) return null;
    final names = _sheetNames(bytes);
    if (_findMonthSheetName(names, effectiveNow.month) != null) return null;

    final candidates = <({String name, int month, bool sameLength})>[];
    final targetDays = _daysInMonth(2000, effectiveNow.month);
    for (final name in names) {
      final month = _monthNumberForSheetName(name);
      if (month == null) continue;
      try {
        parse(bytes: bytes, fileName: fileName, path: null, sheetName: name);
      } on FormatException {
        continue;
      }
      candidates.add((
        name: name,
        month: month,
        sameLength: _daysInMonth(2000, month) == targetDays,
      ));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      if (a.sameLength != b.sameLength) return a.sameLength ? -1 : 1;
      final aDistance = (effectiveNow.month - a.month + 12) % 12;
      final bDistance = (effectiveNow.month - b.month + 12) % 12;
      return aDistance.compareTo(bDistance);
    });
    final languageCode = _monthLanguageCode(
      names,
      fallback: preferredLanguageCode,
    );
    return OdsMonthlySheetSuggestion(
      sourceSheetName: candidates.first.name,
      targetSheetName: _monthName(
        effectiveNow.month,
        languageCode: languageCode,
      ),
      year: year,
    );
  }

  static SheetData createCurrentMonthSheet({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
    String preferredLanguageCode = 'en',
    String? sourceSheetName,
    String? targetSheetName,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final suggestion = suggestCurrentMonthSheet(
      bytes: bytes,
      fileName: fileName,
      now: effectiveNow,
      preferredLanguageCode: preferredLanguageCode,
    );
    if (suggestion == null) {
      throw const FormatException(
        'A current-month worksheet cannot be safely suggested.',
      );
    }
    final effectiveSource = sourceSheetName?.trim().isNotEmpty == true
        ? sourceSheetName!.trim()
        : suggestion.sourceSheetName;
    final effectiveTarget = targetSheetName?.trim().isNotEmpty == true
        ? targetSheetName!.trim()
        : suggestion.targetSheetName;
    final names = _sheetNames(bytes);
    _validateNewSheetName(effectiveTarget, existingNames: names);

    final sourceData = parse(
      bytes: bytes,
      fileName: fileName,
      path: path,
      sheetName: effectiveSource,
    );
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      throw const FormatException('The selected ODS has no content.xml.');
    }
    final document = XmlDocument.parse(
      utf8.decode(contentFile.content as List<int>),
    );
    final spreadsheet = _spreadsheetElement(document);
    if (spreadsheet == null) {
      throw const FormatException('The selected ODS has no spreadsheet body.');
    }
    final sourceTable =
        _childElements(
          spreadsheet,
          localName: 'table',
          namespace: _nsTable,
        ).firstWhere(
          (table) =>
              _attribute(table, 'name', namespace: _nsTable) == effectiveSource,
          orElse: () => throw FormatException(
            'The blueprint worksheet “$effectiveSource” does not exist.',
          ),
        );
    final targetTable = sourceTable.copy();
    _setAttribute(
      targetTable,
      'name',
      effectiveTarget,
      namespace: _nsTable,
      prefix: 'table',
    );
    final sourceIndex = spreadsheet.children.indexOf(sourceTable);
    spreadsheet.children.insert(sourceIndex + 1, targetTable);
    final targetRow = _ensureEditableRow(targetTable, 1);
    final dateColumn = FieldTypeGuesser.findDateColumnIndex(
      headers: sourceData.headers,
      rows: sourceData.rows,
    );
    for (var column = 0; column < sourceData.headers.length; column++) {
      final cell = _ensureEditableCell(targetRow, column);
      final formula = _attribute(cell, 'formula', namespace: _nsTable);
      if (formula != null && formula.isNotEmpty) {
        _setAttribute(
          cell,
          'formula',
          formula.replaceAll(effectiveSource, effectiveTarget),
          namespace: _nsTable,
          prefix: 'table',
        );
        continue;
      }
      _writeCellValue(
        cell,
        type: sourceData.valueTypes[column],
        raw: column == dateColumn ? _formatDate(effectiveNow) : '',
      );
    }
    final tableRows = _childElements(
      targetTable,
      localName: 'table-row',
      namespace: _nsTable,
    ).toList();
    for (final extraRow in tableRows.skip(2).toList()) {
      targetTable.children.remove(extraRow);
    }
    final createdBytes = _replaceContentXml(
      archive: archive,
      contentFile: contentFile,
      document: document,
    );
    return parse(
      bytes: createdBytes,
      fileName: fileName,
      path: path,
      now: effectiveNow,
      sheetName: effectiveTarget,
    );
  }

  static Uint8List buildBytes(SheetData data) {
    final sourceBytes = data.sourceBytes == null || data.sourceBytes!.isEmpty
        ? _buildFreshSourceBytes(data)
        : data.sourceBytes!;

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

  static Uint8List _buildFreshSourceBytes(SheetData data) {
    final sheetName = _freshSheetName(data);
    final contentXml = _freshContentXml(sheetName: sheetName, data: data);
    final manifestXml = _freshManifestXml();
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'mimetype',
          'application/vnd.oasis.opendocument.spreadsheet'.length,
          utf8.encode('application/vnd.oasis.opendocument.spreadsheet'),
        )..compress = false,
      )
      ..addFile(
        ArchiveFile(
          'content.xml',
          utf8.encode(contentXml).length,
          utf8.encode(contentXml),
        ),
      )
      ..addFile(
        ArchiveFile(
          'META-INF/manifest.xml',
          utf8.encode(manifestXml).length,
          utf8.encode(manifestXml),
        ),
      );
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Could not create ODS document.');
    }
    return Uint8List.fromList(encoded);
  }

  static String _freshSheetName(SheetData data) {
    final preferred = data.xlsxSheetName?.trim();
    return preferred == null || preferred.isEmpty ? 'Sheet1' : preferred;
  }

  static String _freshContentXml({
    required String sheetName,
    required SheetData data,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'office:document-content',
      attributes: {
        'xmlns:office': _nsOffice,
        'xmlns:table': _nsTable,
        'xmlns:text': _nsText,
        'xmlns:calcext': _nsCalcExt,
        'office:version': '1.3',
      },
      nest: () {
        builder.element(
          'office:body',
          nest: () {
            builder.element(
              'office:spreadsheet',
              nest: () {
                builder.element(
                  'table:table',
                  attributes: {'table:name': sheetName},
                  nest: () {
                    _buildFreshRow(
                      builder,
                      data.headers.map((header) => header.trim()).toList(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
  }

  static void _buildFreshRow(XmlBuilder builder, List<String> values) {
    builder.element(
      'table:table-row',
      nest: () {
        for (final value in values) {
          builder.element(
            'table:table-cell',
            attributes: {
              'office:value-type': 'string',
              'calcext:value-type': 'string',
            },
            nest: () {
              builder.element('text:p', nest: value);
            },
          );
        }
      },
    );
  }

  static String _freshManifestXml() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'manifest:manifest',
      attributes: {
        'xmlns:manifest': 'urn:oasis:names:tc:opendocument:xmlns:manifest:1.0',
        'manifest:version': '1.3',
      },
      nest: () {
        builder.element(
          'manifest:file-entry',
          attributes: {
            'manifest:full-path': '/',
            'manifest:media-type':
                'application/vnd.oasis.opendocument.spreadsheet',
          },
        );
        builder.element(
          'manifest:file-entry',
          attributes: {
            'manifest:full-path': 'content.xml',
            'manifest:media-type': 'text/xml',
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
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

    final booleanValue = _attribute(
      cell,
      'boolean-value',
      namespace: _nsOffice,
    );
    if (booleanValue != null && booleanValue.isNotEmpty) {
      return booleanValue.trim().toLowerCase() == 'true' ? 'TRUE' : 'FALSE';
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
      'currency',
      null,
      namespace: _nsOffice,
      prefix: 'office',
    );
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

    if (FieldTypeGuesser.isIntegerType(normalizedType) ||
        FieldTypeGuesser.isDecimalType(normalizedType)) {
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

    if (FieldTypeGuesser.isMoneyType(normalizedType)) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) {
        final currencyCode = FieldTypeGuesser.currencyCodeFromType(type);
        _setAttribute(
          cell,
          'value-type',
          'currency',
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setAttribute(
          cell,
          'value-type',
          'currency',
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
        _setAttribute(
          cell,
          'currency',
          currencyCode,
          namespace: _nsOffice,
          prefix: 'office',
        );
        _setTextValue(cell, value);
        return;
      }
    }

    if (FieldTypeGuesser.isBooleanType(normalizedType) &&
        FieldTypeGuesser.looksLikeBooleanValue(value)) {
      final boolValue = value.trim().toUpperCase() == 'TRUE';
      _setAttribute(
        cell,
        'value-type',
        'boolean',
        namespace: _nsOffice,
        prefix: 'office',
      );
      _setAttribute(
        cell,
        'value-type',
        'boolean',
        namespace: _nsCalcExt,
        prefix: 'calcext',
      );
      _setAttribute(
        cell,
        'boolean-value',
        boolValue ? 'true' : 'false',
        namespace: _nsOffice,
        prefix: 'office',
      );
      _setTextValue(cell, boolValue ? 'TRUE' : 'FALSE');
      return;
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

  static List<bool> _normalizeReadOnlyRow(List<bool> row, int width) {
    return List<bool>.generate(
      width,
      (index) => index < row.length ? row[index] : false,
    );
  }

  static List<String> _sheetNames(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final contentFile = archive.findFile('content.xml');
    if (contentFile == null) {
      throw const FormatException('The selected ODS has no content.xml.');
    }
    final document = XmlDocument.parse(
      utf8.decode(contentFile.content as List<int>),
    );
    final spreadsheet = _spreadsheetElement(document);
    if (spreadsheet == null) {
      throw const FormatException('The selected ODS has no spreadsheet body.');
    }
    return _childElements(spreadsheet, localName: 'table', namespace: _nsTable)
        .map((table) => _attribute(table, 'name', namespace: _nsTable) ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Uint8List _replaceContentXml({
    required Archive archive,
    required ArchiveFile contentFile,
    required XmlDocument document,
  }) {
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

  static int? _monthlyLogbookYear(String fileName) {
    final match = RegExp(
      r'_(\d{4})(?:\.[^.]+)?$',
      caseSensitive: false,
    ).firstMatch(fileName.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String? _findMonthSheetName(Iterable<String> names, int month) {
    for (final name in names) {
      if (_monthNumberForSheetName(name) == month) return name;
    }
    return null;
  }

  static int? _monthNumberForSheetName(String name) {
    final normalized = _normalizeMonthName(name);
    for (var month = 1; month <= 12; month++) {
      if (_monthNamesForDetection(month).contains(normalized)) return month;
    }
    return null;
  }

  static Set<String> _monthNamesForDetection(int month) => <String>{
    _normalizeMonthName(_monthName(month)),
    _normalizeMonthName(_monthName(month, languageCode: 'de')),
    ..._monthTokens(month).map(_normalizeMonthName),
  };

  static String _normalizeMonthName(String value) =>
      value.trim().toLowerCase().replaceAll('ä', 'ae');

  static Iterable<String> _monthTokens(int month) {
    const names = <int, List<String>>{
      1: ['jan', 'januar'],
      2: ['feb', 'februar'],
      3: ['mar', 'maerz', 'marz'],
      4: ['apr'],
      5: ['may', 'mai'],
      6: ['jun', 'juni'],
      7: ['jul', 'juli'],
      8: ['aug'],
      9: ['sep'],
      10: ['oct', 'oktober', 'okt'],
      11: ['nov'],
      12: ['dec', 'dezember', 'dez'],
    };
    return names[month] ?? const <String>[];
  }

  static String _monthName(int month, {String languageCode = 'en'}) {
    final names = languageCode.toLowerCase().startsWith('de')
        ? const [
            'Januar',
            'Februar',
            'März',
            'April',
            'Mai',
            'Juni',
            'Juli',
            'August',
            'September',
            'Oktober',
            'November',
            'Dezember',
          ]
        : const [
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
          ];
    return names[month - 1];
  }

  static String _monthLanguageCode(
    Iterable<String> names, {
    required String fallback,
  }) {
    const germanOnly = {
      'januar',
      'februar',
      'maerz',
      'mai',
      'juni',
      'juli',
      'oktober',
      'dezember',
    };
    const englishOnly = {
      'january',
      'february',
      'march',
      'may',
      'june',
      'july',
      'october',
      'december',
    };
    for (final name in names.map(_normalizeMonthName)) {
      if (germanOnly.contains(name)) return 'de';
      if (englishOnly.contains(name)) return 'en';
    }
    return fallback.toLowerCase().startsWith('de') ? 'de' : 'en';
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static void _validateNewSheetName(
    String name, {
    required Iterable<String> existingNames,
  }) {
    if (name.isEmpty) {
      throw const FormatException('The new worksheet name cannot be empty.');
    }
    if (name.length > 31 ||
        RegExp(r"[\\/*?:\[\]]").hasMatch(name) ||
        name.startsWith("'") ||
        name.endsWith("'")) {
      throw const FormatException('The new worksheet name is not valid.');
    }
    final normalized = name.toLowerCase();
    if (existingNames.any((existing) => existing.toLowerCase() == normalized)) {
      throw FormatException('A worksheet named “$name” already exists.');
    }
  }

  static String _selectBestSheetName(List<XmlElement> tables, DateTime now) {
    final names = tables
        .map((table) => _attribute(table, 'name', namespace: _nsTable) ?? '')
        .toList(growable: false);
    final fallback = _attribute(tables.first, 'name', namespace: _nsTable);
    return SheetLogic.selectBestSheetName(names, now, fallback: fallback);
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
