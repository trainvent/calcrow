import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveSyncException implements Exception {
  const GoogleDriveSyncException(this.message);

  final String message;
}

class GoogleDriveFileMetadata {
  const GoogleDriveFileMetadata({
    required this.id,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final String mimeType;
  final DateTime? modifiedTime;
}

class GoogleDriveSyncService {
  Future<GoogleDriveFileMetadata> createSyncFile({
    required http.Client authenticatedClient,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    final fileToUpload = drive.File()..name = fileName;
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    try {
      final file = await driveApi.files.create(
        fileToUpload,
        uploadMedia: media,
        $fields: 'id,name,mimeType,modifiedTime',
      );
      return _convertFile(file);
    } catch (e) {
      throw GoogleDriveSyncException('Could not create Drive sync file: $e');
    }
  }

  Future<GoogleDriveFileMetadata> getFileMetadata({
    required http.Client authenticatedClient,
    required String fileId,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    try {
      final file = await driveApi.files.get(
        fileId,
        $fields: 'id,name,mimeType,modifiedTime',
      ) as drive.File;
      return _convertFile(file);
    } catch (e) {
      throw GoogleDriveSyncException('Could not read Drive file metadata: $e');
    }
  }

  Future<GoogleDriveFileMetadata> updateFileBytes({
    required http.Client authenticatedClient,
    required String fileId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    try {
      final file = await driveApi.files.update(
        drive.File(),
        fileId,
        uploadMedia: media,
        $fields: 'id,name,mimeType,modifiedTime',
      );
      return _convertFile(file);
    } catch (e) {
      throw GoogleDriveSyncException('Could not update Drive sync file: $e');
    }
  }

  GoogleDriveFileMetadata _convertFile(drive.File file) {
    final id = file.id;
    final name = file.name;
    if (id == null || name == null) {
      throw const GoogleDriveSyncException('Drive metadata is incomplete.');
    }
    return GoogleDriveFileMetadata(
      id: id,
      name: name,
      mimeType: file.mimeType ?? 'application/octet-stream',
      modifiedTime: file.modifiedTime,
    );
  }
}
