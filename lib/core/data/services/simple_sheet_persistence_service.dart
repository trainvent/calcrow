import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';

enum SimplePersistMode { safPreferred, asIs }

class SimplePersistRequest {
  const SimplePersistRequest({
    required this.bytes,
    required this.fileName,
    required this.typeGroup,
    required this.mimeType,
    required this.confirmButtonText,
    this.existingPath,
    this.preferredSafTreeUri,
    this.mode = SimplePersistMode.safPreferred,
  });

  final Uint8List bytes;
  final String fileName;
  final XTypeGroup typeGroup;
  final String mimeType;
  final String confirmButtonText;
  final String? existingPath;
  final String? preferredSafTreeUri;
  final SimplePersistMode mode;
}

class SimplePersistResult {
  const SimplePersistResult({
    required this.locationLabel,
    required this.overwroteExistingFile,
    required this.usedAppDocumentsFallback,
    required this.savedPath,
    required this.resolvedFileName,
  });

  final String locationLabel;
  final bool overwroteExistingFile;
  final bool usedAppDocumentsFallback;
  final String savedPath;
  final String resolvedFileName;
}

class SimpleSheetPersistenceService {
  SimpleSheetPersistenceService({SafStream? safStream})
    : _safStream = safStream ?? SafStream();

  final SafStream _safStream;
  static String? _runtimeSafTreeUri;

  static String? get runtimeSafTreeUri => _runtimeSafTreeUri;

  static void setRuntimeSafTreeUri(String? treeUri) {
    final trimmed = treeUri?.trim();
    _runtimeSafTreeUri =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static bool isTemporaryPath(String path) {
    final normalized = path.toLowerCase();
    if (normalized.isEmpty) return true;
    if (kIsWeb) return true;
    return normalized.contains('/cache/') ||
        normalized.contains('/tmp/') ||
        normalized.contains('/file_picker/') ||
        normalized.contains('/file_selector/');
  }

  bool canUseDirectSafUri(String path) {
    if (!_isAndroidPlatform) return false;
    return _isAndroidSafDocumentUri(path) &&
        parentTreeUriFromDocumentUri(path) != null;
  }

  bool canUseSafTreeUri(String treeUri) {
    if (!_isAndroidPlatform) return false;
    final uri = Uri.tryParse(treeUri);
    if (uri == null || uri.scheme != 'content') return false;
    return uri.pathSegments.contains('tree');
  }

  static String? parentTreeUriFromDocumentUri(String documentUri) {
    final uri = Uri.tryParse(documentUri);
    if (uri == null || uri.scheme != 'content') {
      return null;
    }
    final encodedSegments = uri.pathSegments;
    final treeIndex = encodedSegments.indexOf('tree');
    if (treeIndex >= 0 && treeIndex + 1 < encodedSegments.length) {
      return uri.replace(
        pathSegments: <String>[
          'tree',
          Uri.decodeComponent(encodedSegments[treeIndex + 1]),
        ],
      ).toString();
    }
    final documentIndex = encodedSegments.indexOf('document');
    if (documentIndex < 0 || documentIndex + 1 >= encodedSegments.length) {
      return null;
    }
    final docId = Uri.decodeComponent(encodedSegments[documentIndex + 1]);
    final slashIndex = docId.lastIndexOf('/');
    if (slashIndex > 0) {
      final parentDocId = docId.substring(0, slashIndex).trim();
      if (parentDocId.isEmpty) {
        return null;
      }
      return uri.replace(
        pathSegments: <String>['tree', parentDocId],
      ).toString();
    }

    // Some providers return root-level document IDs without '/'.
    // Example: "primary:myfile.xlsx" -> parent should be "primary:".
    final colonIndex = docId.indexOf(':');
    if (colonIndex > 0) {
      final volume = docId.substring(0, colonIndex).trim();
      final tail = docId.substring(colonIndex + 1).trim();
      if (volume.isNotEmpty) {
        final inferredParent = tail.contains('.') ? '$volume:' : docId;
        return uri.replace(
          pathSegments: <String>['tree', inferredParent],
        ).toString();
      }
    }
    return null;
  }

  Future<SimplePersistResult> persistBytes(SimplePersistRequest request) async {
    final output = XFile.fromData(
      request.bytes,
      name: request.fileName,
      mimeType: request.mimeType,
    );
    final existingPath = request.existingPath?.trim();
    final canOverwriteExisting =
        existingPath != null &&
        existingPath.isNotEmpty &&
        !isTemporaryPath(existingPath);
    if (canOverwriteExisting &&
        request.mode == SimplePersistMode.safPreferred &&
        _isAndroidSafDocumentUri(existingPath)) {
      final safSaved = await _tryOverwriteWithSaf(
        existingPath: existingPath,
        bytes: request.bytes,
        fileName: request.fileName,
        mimeType: request.mimeType,
      );
      if (safSaved != null) {
        return SimplePersistResult(
          locationLabel: _displayLocationLabel(
            path: safSaved.path,
            fallbackName: request.fileName,
          ),
          overwroteExistingFile: true,
          usedAppDocumentsFallback: false,
          savedPath: safSaved.path,
          resolvedFileName: safSaved.fileName,
        );
      }
    }

    if (request.mode == SimplePersistMode.safPreferred) {
      if (!_isAndroidPlatform) {
        throw StateError('SAF save is not supported on this platform.');
      }
      final preferredTreeUri = request.preferredSafTreeUri?.trim();
      if (preferredTreeUri != null &&
          preferredTreeUri.isNotEmpty &&
          canUseSafTreeUri(preferredTreeUri)) {
        final savedToTree = await _writeViaSafTreeUri(
          treeUri: preferredTreeUri,
          bytes: request.bytes,
          fileName: request.fileName,
          mimeType: request.mimeType,
        );
        if (savedToTree != null) {
          return savedToTree;
        }
      }
      if (!canOverwriteExisting) {
        throw StateError(
          'No SAF target selected. Open a SAF-backed file first or configure SAF folder in Settings.',
        );
      }
      if (!_isAndroidSafDocumentUri(existingPath)) {
        throw StateError(
          'Current file is not SAF-backed. Use "Save as is" or reopen with SAF.',
        );
      }
      if (parentTreeUriFromDocumentUri(existingPath) == null) {
        throw StateError(
          'SAF target is incompatible for direct overwrite. Reopen from a writable folder via SAF.',
        );
      }
      throw StateError('SAF stream write failed.');
    }

    if (canOverwriteExisting) {
      try {
        await output.saveTo(existingPath);
        return SimplePersistResult(
          locationLabel: existingPath,
          overwroteExistingFile: true,
          usedAppDocumentsFallback: false,
          savedPath: existingPath,
          resolvedFileName: request.fileName,
        );
      } catch (_) {
        // Fall through to save dialog.
      }
    }
    if (_isAndroidPlatform && request.mode == SimplePersistMode.asIs) {
      final savedPath = await _saveWithAndroidPicker(
        bytes: request.bytes,
        fileName: request.fileName,
        typeGroup: request.typeGroup,
      );
      if (savedPath != null && savedPath.isNotEmpty) {
        return SimplePersistResult(
          locationLabel: _displayLocationLabel(
            path: savedPath,
            fallbackName: request.fileName,
          ),
          overwroteExistingFile: false,
          usedAppDocumentsFallback: false,
          savedPath: savedPath,
          resolvedFileName:
              _fileNameFromDocumentUri(savedPath) ?? request.fileName,
        );
      }
    }

    FileSaveLocation? location;
    try {
      location = await getSaveLocation(
        acceptedTypeGroups: <XTypeGroup>[request.typeGroup],
        suggestedName: request.fileName,
        confirmButtonText: request.confirmButtonText,
      );
    } catch (error) {
      if (!_isSaveLocationUnimplementedError(error)) rethrow;
      final fallbackPath = await _androidAppDocumentsFallbackPath(
        request.fileName,
      );
      if (fallbackPath == null) {
        throw StateError('Save picker is unavailable on this platform.');
      }
      await output.saveTo(fallbackPath);
      return SimplePersistResult(
        locationLabel: fallbackPath,
        overwroteExistingFile: false,
        usedAppDocumentsFallback: true,
        savedPath: fallbackPath,
        resolvedFileName: request.fileName,
      );
    }
    if (location == null) {
      throw StateError('Save canceled.');
    }
    await output.saveTo(location.path);
    return SimplePersistResult(
      locationLabel: kIsWeb
          ? request.fileName
          : _displayLocationLabel(
              path: location.path,
              fallbackName: request.fileName,
            ),
      overwroteExistingFile: false,
      usedAppDocumentsFallback: false,
      savedPath: location.path,
      resolvedFileName: request.fileName,
    );
  }

  bool _isSaveLocationUnimplementedError(Object error) {
    if (error is UnimplementedError || error is MissingPluginException) {
      return true;
    }
    if (error is PlatformException) {
      final message = '${error.code} ${error.message ?? ''}'.toLowerCase();
      return message.contains('unimplemented') ||
          message.contains('not been implemented');
    }
    return false;
  }

  Future<String?> _androidAppDocumentsFallbackPath(String fileName) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    } catch (_) {
      return null;
    }
  }

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _isAndroidSafDocumentUri(String value) {
    return _isAndroidPlatform && value.toLowerCase().startsWith('content://');
  }

  String _displayLocationLabel({
    required String path,
    required String fallbackName,
  }) {
    if (!_isAndroidSafDocumentUri(path)) {
      return path;
    }
    final fileName = _fileNameFromDocumentUri(path);
    return fileName ?? fallbackName;
  }

  String? _fileNameFromDocumentUri(String uriValue) {
    final uri = Uri.tryParse(uriValue);
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }
    final encodedDocId = uri.pathSegments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => '',
    );
    if (encodedDocId.isEmpty) {
      return null;
    }
    final docId = Uri.decodeComponent(encodedDocId);
    if (docId.contains('/')) {
      final fileName = docId.split('/').last.trim();
      if (fileName.isNotEmpty) {
        return fileName;
      }
    }
    if (docId.contains(':')) {
      final tail = docId.split(':').last.trim();
      if (tail.isNotEmpty && tail.contains('.')) {
        return tail;
      }
    }
    return null;
  }

  Future<_SafOverwriteResult?> _tryOverwriteWithSaf({
    required String existingPath,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final treeUri = parentTreeUriFromDocumentUri(existingPath);
    if (treeUri == null) {
      return null;
    }
    final targetFileName = _fileNameFromDocumentUri(existingPath) ?? fileName;
    try {
      final newFile = await _safStream.writeFileBytes(
        treeUri,
        targetFileName,
        mimeType,
        bytes,
        overwrite: true,
      );
      final uriString = newFile.uri.toString();
      final resolvedFileName = (newFile.fileName ?? targetFileName).trim();
      return _SafOverwriteResult(
        path: uriString.isEmpty ? existingPath : uriString,
        fileName: resolvedFileName.isEmpty ? targetFileName : resolvedFileName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SimplePersistResult?> _writeViaSafTreeUri({
    required String treeUri,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final newFile = await _safStream.writeFileBytes(
        treeUri,
        fileName,
        mimeType,
        bytes,
        overwrite: true,
      );
      final uriString = newFile.uri.toString();
      final resolvedFileName = (newFile.fileName ?? fileName).trim();
      return SimplePersistResult(
        locationLabel: resolvedFileName.isEmpty ? fileName : resolvedFileName,
        overwroteExistingFile: true,
        usedAppDocumentsFallback: false,
        savedPath: uriString.isEmpty ? treeUri : uriString,
        resolvedFileName: resolvedFileName.isEmpty ? fileName : resolvedFileName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _saveWithAndroidPicker({
    required Uint8List bytes,
    required String fileName,
    required XTypeGroup typeGroup,
  }) async {
    try {
      return await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: typeGroup.extensions,
      );
    } on UnimplementedError {
      return null;
    } on UnsupportedError {
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class _SafOverwriteResult {
  const _SafOverwriteResult({required this.path, required this.fileName});

  final String path;
  final String fileName;
}
