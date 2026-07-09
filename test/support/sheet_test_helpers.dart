import 'dart:convert';
import 'dart:typed_data';

import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

SheetData copySheetData(
  SheetData source, {
  List<String>? headers,
  List<String>? valueTypes,
  List<bool>? readOnlyColumns,
  List<List<String>>? rows,
}) {
  return SheetData(
    fileName: source.fileName,
    path: source.path,
    format: source.format,
    headers: headers ?? source.headers,
    valueTypes: valueTypes ?? source.valueTypes,
    readOnlyColumns: readOnlyColumns ?? source.readOnlyColumns,
    rows: rows ?? source.rows,
    pendingTypeSelectionColumns: source.pendingTypeSelectionColumns,
    hasCachedValueTypes: source.hasCachedValueTypes,
    csvDelimiter: source.csvDelimiter,
    hasTypeRow: source.hasTypeRow,
    headerRowIndex: source.headerRowIndex,
    startColumnIndex: source.startColumnIndex,
    xlsxSheetName: source.xlsxSheetName,
    workbook: source.workbook,
    sourceBytes: source.sourceBytes,
  );
}
