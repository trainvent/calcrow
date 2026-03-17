import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'csv_codec.dart';
import 'ods_codec.dart';
import 'sheet_file_models.dart';
import 'xlsx_codec.dart';

class SimpleSheetFileService {
  const SimpleSheetFileService._();

  static Future<SimpleSheetData> parse({
    required Uint8List bytes,
    required String fileName,
    required String? path,
  }) async {
    final format = detectFormat(fileName: fileName, path: path, bytes: bytes);
    switch (format) {
      case SimpleFileFormat.csv:
        return CsvSheetCodec.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
        );
      case SimpleFileFormat.xlsx:
        return XlsxSheetCodec.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
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
        return simpleSheetDataFromTransfer(transfer);
    }
  }

  static SimpleFileFormat detectFormat({
    required String fileName,
    required String? path,
    required Uint8List bytes,
  }) {
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
