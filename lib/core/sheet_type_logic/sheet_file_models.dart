import 'package:excel/excel.dart' as excel_pkg;

enum SimpleFileFormat { csv, xlsx }

class SimpleSheetData {
  const SimpleSheetData({
    required this.fileName,
    required this.path,
    required this.format,
    required this.headers,
    required this.valueTypes,
    required this.readOnlyColumns,
    required this.rows,
    this.csvDelimiter = ',',
    this.hasTypeRow = false,
    this.xlsxSheetName,
    this.workbook,
  });

  final String fileName;
  final String? path;
  final SimpleFileFormat format;
  final List<String> headers;
  final List<String> valueTypes;
  final List<bool> readOnlyColumns;
  final List<List<String>> rows;
  final String csvDelimiter;
  final bool hasTypeRow;
  final String? xlsxSheetName;
  final excel_pkg.Excel? workbook;
}
