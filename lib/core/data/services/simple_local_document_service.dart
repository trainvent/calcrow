import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../../sheet_type_logic/sheet_file_models.dart';
import 'simple_sheet_persistence_service.dart';

typedef ParseSimpleSheetData =
    Future<SimpleSheetData> Function({
      required Uint8List bytes,
      required String fileName,
      required String? path,
    });

class LocalSimpleDocumentOpenResult {
  const LocalSimpleDocumentOpenResult({
    required this.sheetData,
    required this.existingPath,
    required this.hasSafTarget,
  });

  final SimpleSheetData sheetData;
  final String? existingPath;
  final bool hasSafTarget;
}

class SimpleLocalDocumentService {
  SimpleLocalDocumentService({
    SafStream? safStream,
    SafUtil? safUtil,
    SimpleSheetPersistenceService? persistenceService,
  }) : _safStream = safStream ?? SafStream(),
       _safUtil = safUtil ?? SafUtil(),
       _persistenceService =
           persistenceService ?? SimpleSheetPersistenceService();

  final SafStream _safStream;
  final SafUtil _safUtil;
  final SimpleSheetPersistenceService _persistenceService;

  Future<LocalSimpleDocumentOpenResult?> openDocumentForSimpleEditor({
    required List<XTypeGroup> acceptedTypeGroups,
    required ParseSimpleSheetData parseSheetData,
    required String? Function(XFile file) readXFilePath,
  }) async {
    Uint8List bytes = Uint8List(0);
    String fileName = 'imported_document';
    String? sourcePath;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final pickedFile = await _safUtil.pickFile(
        mimeTypes: const <String>[
          'text/csv',
          'text/comma-separated-values',
          'application/csv',
          'text/*',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.ms-excel',
          'application/vnd.oasis.opendocument.spreadsheet',
          'application/octet-stream',
        ],
      );
      if (pickedFile == null) return null;
      fileName = pickedFile.name.trim().isEmpty ? fileName : pickedFile.name;
      sourcePath = pickedFile.uri.trim().isEmpty ? null : pickedFile.uri.trim();
      if (sourcePath != null) {
        bytes = await _safStream.readFileBytes(sourcePath);
      }
    } else {
      final file = await openFile(
        acceptedTypeGroups: acceptedTypeGroups,
        confirmButtonText: 'Open document',
      );
      if (file == null) return null;
      fileName = file.name;
      bytes = await file.readAsBytes();
      sourcePath = readXFilePath(file);
    }

    if (bytes.isEmpty) {
      throw const LocalSimpleDocumentException(
        'Could not read document content.',
      );
    }

    final sheetData = await parseSheetData(
      bytes: bytes,
      fileName: fileName,
      path: sourcePath,
    );
    final hasSafTarget =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        sourcePath != null &&
        _persistenceService.canUseDirectSafUri(sourcePath);
    return LocalSimpleDocumentOpenResult(
      sheetData: sheetData,
      existingPath: sourcePath,
      hasSafTarget: hasSafTarget,
    );
  }
}

class LocalSimpleDocumentException implements Exception {
  const LocalSimpleDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}
