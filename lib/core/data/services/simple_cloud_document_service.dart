import 'dart:convert';
import 'dart:typed_data';

import '../../sheet_type_logic/sheet_file_models.dart';
import 'auth_service.dart';
import 'db_service.dart';
import 'google_drive_auth_service.dart';
import 'google_drive_sync_service.dart';
import 'simple_local_document_service.dart';

class CloudSimpleDocumentOpenResult {
  const CloudSimpleDocumentOpenResult({
    required this.sheetData,
    required this.file,
  });

  final SimpleSheetData sheetData;
  final GoogleDriveFileMetadata file;
}

class SimpleCloudDocumentService {
  SimpleCloudDocumentService({
    required AuthService authService,
    required DbService dbService,
    required GoogleDriveAuthService googleDriveAuthService,
    required GoogleDriveSyncService googleDriveSyncService,
  }) : _authService = authService,
       _dbService = dbService,
       _googleDriveAuthService = googleDriveAuthService,
       _googleDriveSyncService = googleDriveSyncService;

  final AuthService _authService;
  final DbService _dbService;
  final GoogleDriveAuthService _googleDriveAuthService;
  final GoogleDriveSyncService _googleDriveSyncService;

  Future<String> buildSubtitle() async {
    final session = _authService.currentSession;
    if (session == null) {
      return 'Connect your Google account in Settings first.';
    }
    final settings = await _dbService.getUserSettings(session.uid);
    final linked = settings?['googleDriveLinked'];
    if (linked is! bool || !linked) {
      return 'Connect your Google account in Settings first.';
    }
    final fileName = (settings?['googleDriveSyncFileName'] as String?)?.trim();
    if (fileName != null && fileName.isNotEmpty) {
      return 'Manage Google Drive sync file: $fileName';
    }
    return 'Choose or create the Google Drive file used for sync.';
  }

  Future<void> setSelectedSyncFile({
    required GoogleDriveFileMetadata file,
  }) async {
    final session = _requireSession();
    await _dbService.setGoogleDriveSyncFile(
      uid: session.uid,
      fileId: file.id,
      fileName: file.name,
      mimeType: file.mimeType,
    );
  }

  Future<void> clearSelectedSyncFile() async {
    final session = _requireSession();
    await _dbService.clearGoogleDriveSyncFile(uid: session.uid);
  }

  Future<GoogleDriveFileMetadata> createSyncFile({
    String? parentFolderId,
  }) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    try {
      return await _googleDriveSyncService.createSyncFile(
        authenticatedClient: client,
        fileName: 'calcrow_sync.csv',
        bytes: Uint8List.fromList(
          utf8.encode('Date,Start,End,Break (min),Notes\n'),
        ),
        mimeType: 'text/csv',
        parentFolderId: parentFolderId,
      );
    } finally {
      client.close();
    }
  }

  Future<CloudSimpleDocumentOpenResult> openDocument({
    required GoogleDriveFileMetadata file,
    required ParseSimpleSheetData parseSheetData,
  }) async {
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    late final Uint8List bytes;
    try {
      bytes = await _googleDriveSyncService.downloadFileBytes(
        authenticatedClient: client,
        fileId: file.id,
      );
    } finally {
      client.close();
    }
    if (bytes.isEmpty) {
      throw const GoogleDriveSyncException('Could not read Drive file content.');
    }
    final sheetData = await parseSheetData(
      bytes: bytes,
      fileName: file.name,
      path: null,
    );
    return CloudSimpleDocumentOpenResult(sheetData: sheetData, file: file);
  }

  Future<GoogleDriveFileMetadata> persistDocument({
    required String fileId,
    required String existingMimeType,
    required String fileName,
    required Uint8List bytes,
    required String outputMimeType,
  }) async {
    final session = _requireSession();
    final client = await _googleDriveAuthService.getAuthenticatedClient();
    late final GoogleDriveFileMetadata metadata;
    try {
      if (existingMimeType != outputMimeType) {
        metadata = await _googleDriveSyncService.createSyncFile(
          authenticatedClient: client,
          fileName: fileName,
          bytes: bytes,
          mimeType: outputMimeType,
        );
      } else {
        metadata = await _googleDriveSyncService.updateFileBytes(
          authenticatedClient: client,
          fileId: fileId,
          bytes: bytes,
          mimeType: outputMimeType,
        );
      }
    } finally {
      client.close();
    }
    await _dbService.setGoogleDriveSyncFile(
      uid: session.uid,
      fileId: metadata.id,
      fileName: metadata.name,
      mimeType: metadata.mimeType,
    );
    return metadata;
  }

  AuthSession _requireSession() {
    final session = _authService.currentSession;
    if (session == null) {
      throw const GoogleDriveAuthException(
        'Google account is not linked. Connect it in Settings first.',
      );
    }
    return session;
  }
}
