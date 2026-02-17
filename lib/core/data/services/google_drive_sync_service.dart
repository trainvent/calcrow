import 'dart:convert';
import 'dart:typed_data';

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
  static const String _filesApiBase = 'https://www.googleapis.com/drive/v3/files';
  static const String _uploadApiBase =
      'https://www.googleapis.com/upload/drive/v3/files';

  Future<GoogleDriveFileMetadata> createSyncFile({
    required String accessToken,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final boundary = 'calcrow_boundary_${DateTime.now().microsecondsSinceEpoch}';
    final metadataJson = jsonEncode(<String, Object>{
      'name': fileName,
    });

    final body = _buildMultipartBody(
      boundary: boundary,
      metadataJson: metadataJson,
      bytes: bytes,
      mimeType: mimeType,
    );

    final uri = Uri.parse(
      '$_uploadApiBase?uploadType=multipart&fields=id,name,mimeType,modifiedTime',
    );
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveSyncException(
        'Could not create Drive sync file (${response.statusCode}).',
      );
    }

    return _parseMetadata(response.body);
  }

  Future<GoogleDriveFileMetadata> getFileMetadata({
    required String accessToken,
    required String fileId,
  }) async {
    final uri = Uri.parse(
      '$_filesApiBase/$fileId?fields=id,name,mimeType,modifiedTime',
    );
    final response = await http.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveSyncException(
        'Could not read Drive file metadata (${response.statusCode}).',
      );
    }
    return _parseMetadata(response.body);
  }

  Future<GoogleDriveFileMetadata> updateFileBytes({
    required String accessToken,
    required String fileId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse(
      '$_uploadApiBase/$fileId?uploadType=media&fields=id,name,mimeType,modifiedTime',
    );
    final response = await http.patch(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': mimeType,
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveSyncException(
        'Could not update Drive sync file (${response.statusCode}).',
      );
    }
    return _parseMetadata(response.body);
  }

  GoogleDriveFileMetadata _parseMetadata(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const GoogleDriveSyncException('Invalid Drive metadata response.');
    }

    final id = (decoded['id'] as String?)?.trim();
    final name = (decoded['name'] as String?)?.trim();
    final mimeType = (decoded['mimeType'] as String?)?.trim();
    final modifiedTimeRaw = (decoded['modifiedTime'] as String?)?.trim();

    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const GoogleDriveSyncException('Drive metadata is incomplete.');
    }

    DateTime? modifiedTime;
    if (modifiedTimeRaw != null && modifiedTimeRaw.isNotEmpty) {
      modifiedTime = DateTime.tryParse(modifiedTimeRaw)?.toUtc();
    }

    return GoogleDriveFileMetadata(
      id: id,
      name: name,
      mimeType: (mimeType == null || mimeType.isEmpty)
          ? 'application/octet-stream'
          : mimeType,
      modifiedTime: modifiedTime,
    );
  }

  Uint8List _buildMultipartBody({
    required String boundary,
    required String metadataJson,
    required Uint8List bytes,
    required String mimeType,
  }) {
    final buffer = StringBuffer();
    buffer.write('--$boundary\r\n');
    buffer.write('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    buffer.write(metadataJson);
    buffer.write('\r\n');
    buffer.write('--$boundary\r\n');
    buffer.write('Content-Type: $mimeType\r\n\r\n');

    final prefix = utf8.encode(buffer.toString());
    final suffix = utf8.encode('\r\n--$boundary--');

    return Uint8List.fromList(<int>[
      ...prefix,
      ...bytes,
      ...suffix,
    ]);
  }
}
