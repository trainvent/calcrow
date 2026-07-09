import 'dart:typed_data';

import 'sheet_file_models.dart';
import 'xlsx_codec.dart';

class GSheetCodec {
  const GSheetCodec._();

  static const String googleSheetsMimeType =
      'application/vnd.google-apps.spreadsheet';

  static SheetData parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    DateTime? now,
  }) {
    final parsed = XlsxSheetCodec.parse(
      bytes: bytes,
      fileName: fileName,
      path: path,
      now: now,
    );
    return SheetData(
      fileName: parsed.fileName,
      path: parsed.path,
      format: SheetFileFormat.gsheet,
      headers: parsed.headers,
      valueTypes: parsed.valueTypes,
      readOnlyColumns: parsed.readOnlyColumns,
      rows: parsed.rows,
      pendingTypeSelectionColumns: parsed.pendingTypeSelectionColumns,
      hasCachedValueTypes: parsed.hasCachedValueTypes,
      csvDelimiter: parsed.csvDelimiter,
      hasTypeRow: parsed.hasTypeRow,
      headerRowIndex: parsed.headerRowIndex,
      startColumnIndex: parsed.startColumnIndex,
      xlsxSheetName: parsed.xlsxSheetName,
      workbook: parsed.workbook,
      sourceBytes: bytes,
    );
  }

  static Uint8List buildBytes(SheetData data) {
    return XlsxSheetCodec.buildBytes(
      SheetData(
        fileName: data.fileName,
        path: data.path,
        format: SheetFileFormat.xlsx,
        headers: data.headers,
        valueTypes: data.valueTypes,
        readOnlyColumns: data.readOnlyColumns,
        rows: data.rows,
        pendingTypeSelectionColumns: data.pendingTypeSelectionColumns,
        hasCachedValueTypes: data.hasCachedValueTypes,
        csvDelimiter: data.csvDelimiter,
        hasTypeRow: data.hasTypeRow,
        headerRowIndex: data.headerRowIndex,
        startColumnIndex: data.startColumnIndex,
        xlsxSheetName: data.xlsxSheetName,
        workbook: data.workbook,
        sourceBytes: data.sourceBytes,
      ),
    );
  }
}
