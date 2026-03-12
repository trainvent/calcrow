import 'dart:convert';
import 'dart:typed_data';

import '../../sheet_type_logic/sheet_file_models.dart';
import 'auth_service.dart';
import 'google_drive_auth_service.dart';
import 'google_drive_sync_service.dart';
import 'simple_local_document_service.dart';
import 'user_repository.dart';
import 'webdav_service.dart';

class CloudSimpleDocumentException implements Exception {
  const CloudSimpleDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudFileMetadata {
  const CloudFileMetadata({
    required this.provider,
    required this.id,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
  });

  final CloudSyncProvider provider;
  final String id;
  final String name;
  final String mimeType;
  final DateTime? modifiedTime;
}

class CloudBrowserEntry {
  const CloudBrowserEntry({
    required this.provider,
    required this.id,
    required this.name,
    required this.mimeType,
    required this.isFolder,
    this.modifiedTime,
  });

  final CloudSyncProvider provider;
  final String id;
  final String name;
  final String mimeType;
  final bool isFolder;
  final DateTime? modifiedTime;

  CloudFileMetadata asFileMetadata() {
    return CloudFileMetadata(
      provider: provider,
      id: id,
      name: name,
      mimeType: mimeType,
      modifiedTime: modifiedTime,
    );
  }
}

class CloudSimpleDocumentOpenResult {
  const CloudSimpleDocumentOpenResult({
    required this.sheetData,
    required this.file,
  });

  final SimpleSheetData sheetData;
  final CloudFileMetadata file;
}

class SimpleCloudDocumentService {
  SimpleCloudDocumentService({
    required AuthService authService,
    required UserRepository userRepository,
    required GoogleDriveAuthService googleDriveAuthService,
    required GoogleDriveSyncService googleDriveSyncService,
    required WebDavService webDavService,
  }) : _authService = authService,
       _userRepository = userRepository,
       _googleDriveAuthService = googleDriveAuthService,
       _googleDriveSyncService = googleDriveSyncService,
       _webDavService = webDavService;

  final AuthService _authService;
  final UserRepository _userRepository;
  final GoogleDriveAuthService _googleDriveAuthService;
  final GoogleDriveSyncService _googleDriveSyncService;
  final WebDavService _webDavService;

  Future<String> buildSubtitle() async {
    final session = _authService.currentSession;
    if (session == null) {
      return 'Connect a cloud provider in Settings first.';
    }
    final settings = await _userRepository.getUserSettings(session.uid);
    final provider = _activeProvider(settings);
    if (provider == null) {
      return 'Connect Google Drive or WebDAV in Settings first.';
    }
    return switch (provider) {
      CloudSyncProvider.googleDrive => _googleDriveSubtitle(settings),
      CloudSyncProvider.webDav => _webDavSubtitle(settings),
    };
  }

  Future<List<CloudBrowserEntry>> listFolderEntries({String? folderId}) async {
    final session = _requireSession();
    final settings = await _userRepository.getUserSettings(session.uid);
    final provider = _requireProvider(settings);
    return switch (provider) {
      CloudSyncProvider.googleDrive => _listGoogleDriveEntries(
        folderId: folderId,
      ),
      CloudSyncProvider.webDav => _listWebDavEntries(folderPath: folderId),
    };
  }

  Future<void> setSelectedSyncFile({required CloudFileMetadata file}) async {
    final session = _requireSession();
    switch (file.provider) {
      case CloudSyncProvider.googleDrive:
        return _userRepository.setGoogleDriveSyncFile(
          uid: session.uid,
          fileId: file.id,
          fileName: file.name,
          mimeType: file.mimeType,
        );
      case CloudSyncProvider.webDav:
        return _userRepository.setWebDavSyncFile(
          uid: session.uid,
          path: file.id,
          fileName: file.name,
          mimeType: file.mimeType,
        );
    }
  }

  Future<void> clearSelectedSyncFile() async {
    final session = _requireSession();
    final settings = await _userRepository.getUserSettings(session.uid);
    final provider = _requireProvider(settings);
    switch (provider) {
      case CloudSyncProvider.googleDrive:
        return _userRepository.clearGoogleDriveSyncFile(uid: session.uid);
      case CloudSyncProvider.webDav:
        return _userRepository.clearWebDavSyncFile(uid: session.uid);
    }
  }

  Future<CloudFileMetadata> createSyncFile({String? parentFolderId}) async {
    final session = _requireSession();
    final settings = await _userRepository.getUserSettings(session.uid);
    final provider = _requireProvider(settings);
    return switch (provider) {
      CloudSyncProvider.googleDrive => _createGoogleDriveSyncFile(
        parentFolderId: parentFolderId,
      ),
      CloudSyncProvider.webDav => _createWebDavSyncFile(
        sessionUid: session.uid,
        parentFolderPath: parentFolderId,
      ),
    };
  }

  Future<CloudSimpleDocumentOpenResult> openDocument({
    required CloudFileMetadata file,
    required ParseSimpleSheetData parseSheetData,
  }) async {
    final session = _requireSession();
    final bytes = switch (file.provider) {
      CloudSyncProvider.googleDrive => await _downloadGoogleDriveFile(
        fileId: file.id,
      ),
      CloudSyncProvider.webDav => await _downloadWebDavFile(
        sessionUid: session.uid,
        relativePath: file.id,
      ),
    };
    if (bytes.isEmpty) {
      throw const CloudSimpleDocumentException(
        'Could not read cloud document content.',
      );
    }
    final sheetData = await parseSheetData(
      bytes: bytes,
      fileName: file.name,
      path: null,
    );
    return CloudSimpleDocumentOpenResult(sheetData: sheetData, file: file);
  }

  Future<CloudFileMetadata> persistDocument({
    required CloudFileMetadata existingFile,
    required String fileName,
    required Uint8List bytes,
    required String outputMimeType,
  }) async {
    final session = _requireSession();
    final metadata = switch (existingFile.provider) {
      CloudSyncProvider.googleDrive => await _persistGoogleDriveDocument(
        existingFile: existingFile,
        fileName: fileName,
        bytes: bytes,
        outputMimeType: outputMimeType,
      ),
      CloudSyncProvider.webDav => await _persistWebDavDocument(
        sessionUid: session.uid,
        existingFile: existingFile,
        fileName: fileName,
        bytes: bytes,
        outputMimeType: outputMimeType,
      ),
    };
    await setSelectedSyncFile(file: metadata);
    return metadata;
  }

  CloudSyncProvider? activeProviderFromSettings(UserSettingsData settings) {
    return _activeProvider(settings);
  }

  CloudFileMetadata? selectedSyncFileFromSettings(UserSettingsData settings) {
    final provider = _activeProvider(settings);
    if (provider == null) return null;
    return switch (provider) {
      CloudSyncProvider.googleDrive => _selectedGoogleDriveFile(settings),
      CloudSyncProvider.webDav => _selectedWebDavFile(settings),
    };
  }

  String providerLabel(CloudSyncProvider provider) {
    return switch (provider) {
      CloudSyncProvider.googleDrive => 'Google Drive',
      CloudSyncProvider.webDav => 'WebDAV',
    };
  }

  AuthSession _requireSession() {
    final session = _authService.currentSession;
    if (session == null) {
      throw const CloudSimpleDocumentException(
        'Connect a cloud provider in Settings first.',
      );
    }
    return session;
  }

  CloudSyncProvider _requireProvider(UserSettingsData settings) {
    final provider = _activeProvider(settings);
    if (provider == null) {
      throw const CloudSimpleDocumentException(
        'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.',
      );
    }
    return provider;
  }

  CloudSyncProvider? _activeProvider(UserSettingsData settings) {
    final preferred = settings.cloudSyncProvider;
    if (preferred == CloudSyncProvider.googleDrive &&
        settings.googleDriveLinked) {
      return preferred;
    }
    if (preferred == CloudSyncProvider.webDav && settings.webDavLinked) {
      return preferred;
    }
    if (settings.googleDriveLinked) return CloudSyncProvider.googleDrive;
    if (settings.webDavLinked) return CloudSyncProvider.webDav;
    return null;
  }

  String _googleDriveSubtitle(UserSettingsData settings) {
    final fileName = settings.googleDriveSyncFileName;
    if (fileName != null && fileName.isNotEmpty) {
      return 'Manage Google Drive sync file: $fileName';
    }
    return 'Choose or create the Google Drive file used for sync.';
  }

  String _webDavSubtitle(UserSettingsData settings) {
    final fileName = settings.webDavSyncFileName;
    if (fileName != null && fileName.isNotEmpty) {
      return 'Manage WebDAV sync file: $fileName';
    }
    return 'Choose or create the WebDAV file used for sync.';
  }

  Future<List<CloudBrowserEntry>> _listGoogleDriveEntries({
    String? folderId,
  }) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    try {
      final entries = await _googleDriveSyncService.listFolderEntries(
        authenticatedClient: client,
        folderId: folderId,
      );
      return entries
          .map(
            (entry) => CloudBrowserEntry(
              provider: CloudSyncProvider.googleDrive,
              id: entry.id,
              name: entry.name,
              mimeType: entry.mimeType,
              isFolder: entry.isFolder,
              modifiedTime: entry.modifiedTime,
            ),
          )
          .toList();
    } on GoogleDriveAuthException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } on GoogleDriveSyncException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } finally {
      client.close();
    }
  }

  Future<List<CloudBrowserEntry>> _listWebDavEntries({
    String? folderPath,
  }) async {
    final session = _requireSession();
    try {
      final entries = await _webDavService.listFolderEntries(
        uid: session.uid,
        relativeFolderPath: folderPath,
      );
      return entries
          .map(
            (entry) => CloudBrowserEntry(
              provider: CloudSyncProvider.webDav,
              id: entry.path,
              name: entry.name,
              mimeType: entry.mimeType,
              isFolder: entry.isFolder,
              modifiedTime: entry.modifiedTime,
            ),
          )
          .toList();
    } on WebDavException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    }
  }

  Future<CloudFileMetadata> _createGoogleDriveSyncFile({
    String? parentFolderId,
  }) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    try {
      final file = await _googleDriveSyncService.createSyncFile(
        authenticatedClient: client,
        fileName: 'calcrow_sync.csv',
        bytes: Uint8List.fromList(
          utf8.encode('Date,Start,End,Break (min),Notes\n'),
        ),
        mimeType: 'text/csv',
        parentFolderId: parentFolderId,
      );
      return CloudFileMetadata(
        provider: CloudSyncProvider.googleDrive,
        id: file.id,
        name: file.name,
        mimeType: file.mimeType,
        modifiedTime: file.modifiedTime,
      );
    } on GoogleDriveAuthException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } on GoogleDriveSyncException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } finally {
      client.close();
    }
  }

  Future<CloudFileMetadata> _createWebDavSyncFile({
    required String sessionUid,
    String? parentFolderPath,
  }) async {
    final relativePath = [
      if (parentFolderPath != null && parentFolderPath.trim().isNotEmpty)
        parentFolderPath.trim().replaceAll(RegExp(r'/+$'), ''),
      'calcrow_sync.csv',
    ].join('/');
    late final WebDavFileMetadata file;
    try {
      file = await _webDavService.uploadFileBytes(
        uid: sessionUid,
        relativePath: relativePath,
        bytes: Uint8List.fromList(
          utf8.encode('Date,Start,End,Break (min),Notes\n'),
        ),
        mimeType: 'text/csv',
      );
    } on WebDavException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    }
    return CloudFileMetadata(
      provider: CloudSyncProvider.webDav,
      id: file.path,
      name: file.name,
      mimeType: file.mimeType,
      modifiedTime: file.modifiedTime,
    );
  }

  Future<Uint8List> _downloadGoogleDriveFile({required String fileId}) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    try {
      return await _googleDriveSyncService.downloadFileBytes(
        authenticatedClient: client,
        fileId: fileId,
      );
    } on GoogleDriveAuthException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } on GoogleDriveSyncException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } finally {
      client.close();
    }
  }

  Future<Uint8List> _downloadWebDavFile({
    required String sessionUid,
    required String relativePath,
  }) async {
    try {
      return await _webDavService.downloadFileBytes(
        uid: sessionUid,
        relativePath: relativePath,
      );
    } on WebDavException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    }
  }

  Future<CloudFileMetadata> _persistGoogleDriveDocument({
    required CloudFileMetadata existingFile,
    required String fileName,
    required Uint8List bytes,
    required String outputMimeType,
  }) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    try {
      final metadata = existingFile.mimeType != outputMimeType
          ? await _googleDriveSyncService.createSyncFile(
              authenticatedClient: client,
              fileName: fileName,
              bytes: bytes,
              mimeType: outputMimeType,
            )
          : await _googleDriveSyncService.updateFileBytes(
              authenticatedClient: client,
              fileId: existingFile.id,
              bytes: bytes,
              mimeType: outputMimeType,
            );
      return CloudFileMetadata(
        provider: CloudSyncProvider.googleDrive,
        id: metadata.id,
        name: metadata.name,
        mimeType: metadata.mimeType,
        modifiedTime: metadata.modifiedTime,
      );
    } on GoogleDriveAuthException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } on GoogleDriveSyncException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    } finally {
      client.close();
    }
  }

  Future<CloudFileMetadata> _persistWebDavDocument({
    required String sessionUid,
    required CloudFileMetadata existingFile,
    required String fileName,
    required Uint8List bytes,
    required String outputMimeType,
  }) async {
    final currentPath = existingFile.id;
    final nextPath = existingFile.mimeType == outputMimeType
        ? currentPath
        : _replaceFileName(currentPath, fileName);
    late final WebDavFileMetadata metadata;
    try {
      metadata = await _webDavService.uploadFileBytes(
        uid: sessionUid,
        relativePath: nextPath,
        bytes: bytes,
        mimeType: outputMimeType,
      );
    } on WebDavException catch (error) {
      throw CloudSimpleDocumentException(error.message);
    }
    return CloudFileMetadata(
      provider: CloudSyncProvider.webDav,
      id: metadata.path,
      name: metadata.name,
      mimeType: metadata.mimeType,
      modifiedTime: metadata.modifiedTime,
    );
  }

  CloudFileMetadata? _selectedGoogleDriveFile(UserSettingsData settings) {
    final fileId = settings.googleDriveSyncFileId;
    final fileName = settings.googleDriveSyncFileName;
    final mimeType = settings.googleDriveSyncMimeType;
    if (fileId == null || fileName == null || mimeType == null) return null;
    return CloudFileMetadata(
      provider: CloudSyncProvider.googleDrive,
      id: fileId,
      name: fileName,
      mimeType: mimeType,
    );
  }

  CloudFileMetadata? _selectedWebDavFile(UserSettingsData settings) {
    final path = settings.webDavSyncFilePath;
    final fileName = settings.webDavSyncFileName;
    final mimeType = settings.webDavSyncMimeType;
    if (path == null || fileName == null || mimeType == null) return null;
    return CloudFileMetadata(
      provider: CloudSyncProvider.webDav,
      id: path,
      name: fileName,
      mimeType: mimeType,
    );
  }

  String _replaceFileName(String path, String fileName) {
    final normalized = path.trim();
    final separator = normalized.lastIndexOf('/');
    if (separator == -1) return fileName;
    final directory = normalized.substring(0, separator + 1);
    return '$directory$fileName';
  }
}
