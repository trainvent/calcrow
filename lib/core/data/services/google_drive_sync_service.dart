import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class GoogleDriveSyncException implements Exception {
  const GoogleDriveSyncException(this.message);

  final String message;

  @override
  String toString() => message;
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

class GoogleDriveBrowserEntry {
  const GoogleDriveBrowserEntry({
    required this.id,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final String mimeType;
  final DateTime? modifiedTime;

  bool get isFolder => mimeType == GoogleDriveSyncService.folderMimeType;

  GoogleDriveFileMetadata asFileMetadata() {
    return GoogleDriveFileMetadata(
      id: id,
      name: name,
      mimeType: mimeType,
      modifiedTime: modifiedTime,
    );
  }
}

class GoogleDriveSyncService {
  static const String folderMimeType = 'application/vnd.google-apps.folder';
  static const List<String> supportedMimeTypes = <String>[
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.spreadsheet',
  ];

  Future<GoogleDriveFileMetadata> createSyncFile({
    required http.Client authenticatedClient,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? parentFolderId,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    final fileToUpload = drive.File()..name = fileName;
    final normalizedParentFolderId = parentFolderId?.trim();
    if (normalizedParentFolderId != null && normalizedParentFolderId.isNotEmpty) {
      fileToUpload.parents = <String>[normalizedParentFolderId];
    }
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

  Future<Uint8List> downloadFileBytes({
    required http.Client authenticatedClient,
    required String fileId,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    try {
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw const GoogleDriveSyncException(
          'Drive file download did not return media bytes.',
        );
      }
      final chunks = await response.stream.toList();
      return Uint8List.fromList(
        chunks.expand((chunk) => chunk).toList(growable: false),
      );
    } catch (e) {
      if (e is GoogleDriveSyncException) rethrow;
      throw GoogleDriveSyncException('Could not download Drive file: $e');
    }
  }

  Future<List<GoogleDriveFileMetadata>> listSyncFiles({
    required http.Client authenticatedClient,
  }) async {
    final entries = await listFolderEntries(
      authenticatedClient: authenticatedClient,
    );
    return entries
        .where((entry) => !entry.isFolder)
        .map((entry) => entry.asFileMetadata())
        .toList();
  }

  Future<List<GoogleDriveBrowserEntry>> listFolderEntries({
    required http.Client authenticatedClient,
    String? folderId,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    final mimeQuery = supportedMimeTypes
        .map((mimeType) => "mimeType='${mimeType.replaceAll("'", r"\'")}'")
        .join(' or ');
    final normalizedFolderId = folderId?.trim();
    final parentId = normalizedFolderId == null || normalizedFolderId.isEmpty
        ? 'root'
        : normalizedFolderId;
    try {
      final response = await driveApi.files.list(
        q:
            "trashed = false and '$parentId' in parents and (mimeType='$folderMimeType' or ($mimeQuery))",
        orderBy: 'folder,name_natural',
        pageSize: 50,
        $fields: 'files(id,name,mimeType,modifiedTime)',
      );
      final files = response.files;
      if (files == null || files.isEmpty) {
        return const <GoogleDriveBrowserEntry>[];
      }
      return files.map(_convertBrowserEntry).toList();
    } catch (e) {
      throw GoogleDriveSyncException('Could not list Drive sync files: $e');
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

  GoogleDriveBrowserEntry _convertBrowserEntry(drive.File file) {
    final id = file.id;
    final name = file.name;
    if (id == null || name == null) {
      throw const GoogleDriveSyncException('Drive metadata is incomplete.');
    }
    return GoogleDriveBrowserEntry(
      id: id,
      name: name,
      mimeType: file.mimeType ?? 'application/octet-stream',
      modifiedTime: file.modifiedTime,
    );
  }
}
