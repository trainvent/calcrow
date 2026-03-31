import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_pkg;

enum SimpleFileFormat { csv, xlsx, ods, gsheet }

class SimpleSheetData {
  const SimpleSheetData({
    required this.fileName,
    required this.path,
    required this.format,
    required this.headers,
    required this.valueTypes,
    required this.readOnlyColumns,
    required this.rows,
    this.pendingTypeSelectionColumns = const <int>[],
    this.csvDelimiter = ',',
    this.hasTypeRow = false,
    this.headerRowIndex = 0,
    this.startColumnIndex = 0,
    this.xlsxSheetName,
    this.workbook,
    this.sourceBytes,
  });

  final String fileName;
  final String? path;
  final SimpleFileFormat format;
  final List<String> headers;
  final List<String> valueTypes;
  final List<bool> readOnlyColumns;
  final List<List<String>> rows;
  final List<int> pendingTypeSelectionColumns;
  final String csvDelimiter;
  final bool hasTypeRow;
  final int headerRowIndex;
  final int startColumnIndex;
  final String? xlsxSheetName;
  final excel_pkg.Excel? workbook;
  final Uint8List? sourceBytes;
}
