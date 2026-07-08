import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'csv_codec.dart';
import 'gsheet_codec.dart';
import 'ods_codec.dart';
import 'sheet_file_models.dart';
import 'simple_type_hint_cache.dart';
import 'xlsx_codec.dart';

class SimpleSheetFileService {
  const SimpleSheetFileService._();

  static Future<SimpleSheetData> parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    String? mimeType,
  }) async {
    final format = detectFormat(
      fileName: fileName,
      path: path,
      bytes: bytes,
      mimeType: mimeType,
    );
    switch (format) {
      case SimpleFileFormat.csv:
        return await CsvSheetCodec.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
        );
      case SimpleFileFormat.xlsx:
        return await _applyCachedTypeHints(
          XlsxSheetCodec.parse(bytes: bytes, fileName: fileName, path: path),
        );
      case SimpleFileFormat.ods:
        final transfer = await Isolate.run<Map<String, Object?>>(
          () => parseOdsSheetDataTransfer(<String, Object?>{
            'bytes': bytes,
            'fileName': fileName,
            'path': path,
            'nowMillisecondsSinceEpoch': DateTime.now().millisecondsSinceEpoch,
          }),
        );
        return await _applyCachedTypeHints(
          simpleSheetDataFromTransfer(transfer),
        );
      case SimpleFileFormat.gsheet:
        return await _applyCachedTypeHints(
          GSheetCodec.parse(
            bytes: bytes,
            fileName: fileName,
            path: path,
            now: DateTime.now(),
          ),
        );
    }
  }

  static Future<SimpleSheetData> _applyCachedTypeHints(
    SimpleSheetData data,
  ) async {
    if (data.pendingTypeSelectionColumns.isEmpty) return data;
    final cachedTypes = await SimpleTypeHintCache.readCsvTypes(
      fileName: data.fileName,
      path: data.path,
    );
    if (cachedTypes == null || cachedTypes.length != data.headers.length) {
      return data;
    }
    return SimpleSheetData(
      fileName: data.fileName,
      path: data.path,
      format: data.format,
      headers: data.headers,
      valueTypes: cachedTypes,
      readOnlyColumns: data.readOnlyColumns,
      rows: data.rows,
      pendingTypeSelectionColumns: const <int>[],
      hasCachedValueTypes: true,
      csvDelimiter: data.csvDelimiter,
      hasTypeRow: data.hasTypeRow,
      headerRowIndex: data.headerRowIndex,
      startColumnIndex: data.startColumnIndex,
      xlsxSheetName: data.xlsxSheetName,
      workbook: data.workbook,
      sourceBytes: data.sourceBytes,
    );
  }

  static SimpleFileFormat detectFormat({
    required String fileName,
    required String? path,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final normalizedMimeType = mimeType?.trim().toLowerCase();
    if (normalizedMimeType == GSheetCodec.googleSheetsMimeType) {
      return SimpleFileFormat.gsheet;
    }
    final normalizedName = fileName.trim().toLowerCase();
    final normalizedPath = path?.trim().toLowerCase();
    final extensionSource = normalizedName.isNotEmpty
        ? normalizedName
        : (normalizedPath ?? '');
    if (extensionSource.endsWith('.csv')) return SimpleFileFormat.csv;
    if (extensionSource.endsWith('.xlsx')) return SimpleFileFormat.xlsx;
    if (extensionSource.endsWith('.ods')) return SimpleFileFormat.ods;
    if (extensionSource.endsWith('.xls')) {
      throw UnsupportedError(
        'Legacy .xls files are not supported yet. Use .xlsx, .ods, or .csv.',
      );
    }

    if (_looksLikeZipArchive(bytes)) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        if (archive.findFile('xl/workbook.xml') != null ||
            archive.files.any((file) => file.name.startsWith('xl/'))) {
          return SimpleFileFormat.xlsx;
        }
        final mimetypeFile = archive.findFile('mimetype');
        final mimetype = mimetypeFile == null
            ? null
            : utf8
                  .decode(
                    mimetypeFile.content as List<int>,
                    allowMalformed: true,
                  )
                  .trim()
                  .toLowerCase();
        if (mimetype == 'application/vnd.oasis.opendocument.spreadsheet' ||
            archive.findFile('content.xml') != null) {
          return SimpleFileFormat.ods;
        }
      } catch (_) {
        throw UnsupportedError(
          'Could not detect this document type. Use .xlsx, .ods, or .csv.',
        );
      }
      throw UnsupportedError(
        'This archive format is not supported. Use .xlsx, .ods, or .csv.',
      );
    }

    return SimpleFileFormat.csv;
  }

  static Uint8List buildBytes(SimpleSheetData data) {
    switch (data.format) {
      case SimpleFileFormat.csv:
        return CsvSheetCodec.buildBytes(data);
      case SimpleFileFormat.xlsx:
        return XlsxSheetCodec.buildBytes(data);
      case SimpleFileFormat.ods:
        return OdsSheetCodec.buildBytes(data);
      case SimpleFileFormat.gsheet:
        return GSheetCodec.buildBytes(data);
    }
  }

  static String mimeTypeForFormat(SimpleFileFormat format) {
    switch (format) {
      case SimpleFileFormat.csv:
        return 'text/csv';
      case SimpleFileFormat.xlsx:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case SimpleFileFormat.ods:
        return 'application/vnd.oasis.opendocument.spreadsheet';
      case SimpleFileFormat.gsheet:
        return GSheetCodec.googleSheetsMimeType;
    }
  }

  static String defaultExtensionForFormat(SimpleFileFormat format) {
    switch (format) {
      case SimpleFileFormat.csv:
        return 'csv';
      case SimpleFileFormat.xlsx:
        return 'xlsx';
      case SimpleFileFormat.ods:
        return 'ods';
      case SimpleFileFormat.gsheet:
        return 'xlsx';
    }
  }

  static bool _looksLikeZipArchive(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
  }
}
