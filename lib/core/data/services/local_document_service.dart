import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../../sheet_type_logic/sheet_file_models.dart';
import 'sheet_persistence_service.dart';

typedef ParseSheetData =
    Future<SheetData> Function({
      required Uint8List bytes,
      required String fileName,
      required String? path,
      String? mimeType,
    });

class LocalDocumentOpenResult {
  const LocalDocumentOpenResult({
    required this.sheetData,
    required this.existingPath,
    required this.hasSafTarget,
  });

  final SheetData sheetData;
  final String? existingPath;
  final bool hasSafTarget;
}

class LocalDocumentSelection {
  const LocalDocumentSelection({
    required this.fileName,
    required this.bytes,
    required this.existingPath,
    required this.hasSafTarget,
  });

  final String fileName;
  final Uint8List bytes;
  final String? existingPath;
  final bool hasSafTarget;
}

class LocalDocumentService {
  LocalDocumentService({
    SafStream? safStream,
    SafUtil? safUtil,
    SheetPersistenceService? persistenceService,
  }) : _safStream = safStream ?? SafStream(),
       _safUtil = safUtil ?? SafUtil(),
       _persistenceService = persistenceService ?? SheetPersistenceService();

  final SafStream _safStream;
  final SafUtil _safUtil;
  final SheetPersistenceService _persistenceService;

  Future<LocalDocumentSelection?> pickDocumentForEditor({
    required List<XTypeGroup> acceptedTypeGroups,
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
      throw const LocalDocumentException('Could not read document content.');
    }

    final hasSafTarget =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        sourcePath != null &&
        _persistenceService.canUseDirectSafUri(sourcePath);
    return LocalDocumentSelection(
      fileName: fileName,
      bytes: bytes,
      existingPath: sourcePath,
      hasSafTarget: hasSafTarget,
    );
  }

  Future<LocalDocumentOpenResult?> openDocumentForEditor({
    required List<XTypeGroup> acceptedTypeGroups,
    required ParseSheetData parseSheetData,
    required String? Function(XFile file) readXFilePath,
  }) async {
    final selection = await pickDocumentForEditor(
      acceptedTypeGroups: acceptedTypeGroups,
      readXFilePath: readXFilePath,
    );
    if (selection == null) return null;
    return openSelectedDocumentForEditor(
      selection: selection,
      parseSheetData: parseSheetData,
    );
  }

  Future<LocalDocumentOpenResult> openSelectedDocumentForEditor({
    required LocalDocumentSelection selection,
    required ParseSheetData parseSheetData,
  }) async {
    final sheetData = await parseSheetData(
      bytes: selection.bytes,
      fileName: selection.fileName,
      path: selection.existingPath,
      mimeType: null,
    );
    return LocalDocumentOpenResult(
      sheetData: sheetData,
      existingPath: selection.existingPath,
      hasSafTarget: selection.hasSafTarget,
    );
  }

  Future<LocalDocumentOpenResult> reopenDocumentForEditor({
    required String fileName,
    required String? existingPath,
    required Uint8List? cachedBytes,
    required ParseSheetData parseSheetData,
  }) async {
    final normalizedPath = existingPath?.trim();
    final normalizedName = fileName.trim().isEmpty
        ? 'imported_document'
        : fileName.trim();

    Uint8List bytes = Uint8List(0);
    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        bytes = await _safStream.readFileBytes(normalizedPath);
      } else {
        bytes = await XFile(normalizedPath).readAsBytes();
      }
    } else if (cachedBytes != null && cachedBytes.isNotEmpty) {
      bytes = cachedBytes;
    }

    if (bytes.isEmpty) {
      throw const LocalDocumentException(
        'Could not reopen the remembered local document.',
      );
    }

    final sheetData = await parseSheetData(
      bytes: bytes,
      fileName: normalizedName,
      path: normalizedPath,
      mimeType: null,
    );
    final hasSafTarget =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        normalizedPath != null &&
        _persistenceService.canUseDirectSafUri(normalizedPath);
    return LocalDocumentOpenResult(
      sheetData: sheetData,
      existingPath: normalizedPath,
      hasSafTarget: hasSafTarget,
    );
  }
}

class LocalDocumentException implements Exception {
  const LocalDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}
