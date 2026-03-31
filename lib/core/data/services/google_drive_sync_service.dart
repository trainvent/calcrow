import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import '../../sheet_type_logic/sheet_file_models.dart';

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
  static const String googleSheetsMimeType =
      'application/vnd.google-apps.spreadsheet';
  static const List<String> supportedMimeTypes = <String>[
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.spreadsheet',
    googleSheetsMimeType,
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
    if (normalizedParentFolderId != null &&
        normalizedParentFolderId.isNotEmpty) {
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
      final file =
          await driveApi.files.get(
                fileId,
                $fields: 'id,name,mimeType,modifiedTime',
                supportsAllDrives: true,
              )
              as drive.File;
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
        supportsAllDrives: true,
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
        supportsAllDrives: true,
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

  Future<Uint8List> exportGoogleSheetAsXlsx({
    required http.Client authenticatedClient,
    required String fileId,
  }) async {
    final driveApi = drive.DriveApi(authenticatedClient);
    try {
      final response = await driveApi.files.export(
        fileId,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw const GoogleDriveSyncException(
          'Google Sheet export did not return media bytes.',
        );
      }
      final chunks = await response.stream.toList();
      return Uint8List.fromList(
        chunks.expand((chunk) => chunk).toList(growable: false),
      );
    } catch (e) {
      if (e is GoogleDriveSyncException) rethrow;
      throw GoogleDriveSyncException(
        _friendlyGoogleSheetsError(action: 'export Google Sheet', error: e),
      );
    }
  }

  Future<GoogleDriveFileMetadata> updateGoogleSheet({
    required http.Client authenticatedClient,
    required String fileId,
    required SimpleSheetData data,
  }) async {
    final sheetsApi = sheets.SheetsApi(authenticatedClient);
    final sheetName = data.xlsxSheetName?.trim();
    if (sheetName == null || sheetName.isEmpty) {
      throw const GoogleDriveSyncException(
        'No Google Sheets tab is selected for save-back.',
      );
    }

    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(
        fileId,
        includeGridData: false,
      );
      final availableSheets = spreadsheet.sheets ?? const <sheets.Sheet>[];
      final targetSheet = availableSheets.cast<sheets.Sheet?>().firstWhere(
        (candidate) => candidate?.properties?.title?.trim() == sheetName,
        orElse: () => null,
      );
      if (targetSheet?.properties?.title == null) {
        throw GoogleDriveSyncException(
          'Could not find the Google Sheets tab "$sheetName".',
        );
      }

      final requests = <sheets.ValueRange>[
        _headerValueRange(data),
        if (data.hasTypeRow) _typeRowValueRange(data),
        ..._dataValueRanges(data),
      ];
      if (requests.isEmpty) {
        throw const GoogleDriveSyncException(
          'There is no editable Google Sheets content to save.',
        );
      }

      await sheetsApi.spreadsheets.values.batchUpdate(
        sheets.BatchUpdateValuesRequest(
          data: requests,
          valueInputOption: 'USER_ENTERED',
        ),
        fileId,
      );
      return getFileMetadata(
        authenticatedClient: authenticatedClient,
        fileId: fileId,
      );
    } catch (e) {
      if (e is GoogleDriveSyncException) rethrow;
      throw GoogleDriveSyncException(
        _friendlyGoogleSheetsError(action: 'update Google Sheet', error: e),
      );
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
        q: "trashed = false and '$parentId' in parents and (mimeType='$folderMimeType' or ($mimeQuery))",
        orderBy: 'folder,name_natural',
        pageSize: 50,
        $fields: 'files(id,name,mimeType,modifiedTime)',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
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

  sheets.ValueRange _headerValueRange(SimpleSheetData data) {
    return sheets.ValueRange(
      range: _rowRangeA1(
        sheetName: data.xlsxSheetName!,
        rowNumber: data.headerRowIndex + 1,
        startColumnIndex: data.startColumnIndex,
        endColumnIndexExclusive: data.startColumnIndex + data.headers.length,
      ),
      majorDimension: 'ROWS',
      values: <List<Object?>>[data.headers.cast<Object?>()],
    );
  }

  sheets.ValueRange _typeRowValueRange(SimpleSheetData data) {
    return sheets.ValueRange(
      range: _rowRangeA1(
        sheetName: data.xlsxSheetName!,
        rowNumber: data.headerRowIndex + 2,
        startColumnIndex: data.startColumnIndex,
        endColumnIndexExclusive: data.startColumnIndex + data.valueTypes.length,
      ),
      majorDimension: 'ROWS',
      values: <List<Object?>>[data.valueTypes.cast<Object?>()],
    );
  }

  List<sheets.ValueRange> _dataValueRanges(SimpleSheetData data) {
    final requests = <sheets.ValueRange>[];
    final segmentRanges = _editableColumnSegments(data.readOnlyColumns);
    final dataStartRowIndex = data.headerRowIndex + (data.hasTypeRow ? 2 : 1);
    for (var rowIndex = 0; rowIndex < data.rows.length; rowIndex++) {
      final normalizedRow = List<String>.generate(
        data.headers.length,
        (index) => index < data.rows[rowIndex].length
            ? data.rows[rowIndex][index]
            : '',
      );
      for (final segment in segmentRanges) {
        requests.add(
          sheets.ValueRange(
            range: _rowRangeA1(
              sheetName: data.xlsxSheetName!,
              rowNumber: dataStartRowIndex + rowIndex + 1,
              startColumnIndex: data.startColumnIndex + segment.$1,
              endColumnIndexExclusive: data.startColumnIndex + segment.$2,
            ),
            majorDimension: 'ROWS',
            values: <List<Object?>>[
              normalizedRow
                  .sublist(segment.$1, segment.$2)
                  .map<Object?>((value) => value)
                  .toList(growable: false),
            ],
          ),
        );
      }
    }
    return requests;
  }

  List<(int, int)> _editableColumnSegments(List<bool> readOnlyColumns) {
    final segments = <(int, int)>[];
    int? start;
    for (var index = 0; index < readOnlyColumns.length; index++) {
      final isEditable = !readOnlyColumns[index];
      if (isEditable && start == null) {
        start = index;
      }
      if (!isEditable && start != null) {
        segments.add((start, index));
        start = null;
      }
    }
    if (start != null) {
      segments.add((start, readOnlyColumns.length));
    }
    return segments;
  }

  String _rowRangeA1({
    required String sheetName,
    required int rowNumber,
    required int startColumnIndex,
    required int endColumnIndexExclusive,
  }) {
    final escapedSheetName = sheetName.replaceAll("'", "''");
    return "'$escapedSheetName'!"
        '${_columnLabel(startColumnIndex)}$rowNumber:'
        '${_columnLabel(endColumnIndexExclusive - 1)}$rowNumber';
  }

  String _columnLabel(int columnIndex) {
    var index = columnIndex;
    final buffer = StringBuffer();
    do {
      final remainder = index % 26;
      buffer.writeCharCode(65 + remainder);
      index = (index ~/ 26) - 1;
    } while (index >= 0);
    return buffer.toString().split('').reversed.join();
  }

  String _friendlyGoogleSheetsError({
    required String action,
    required Object error,
  }) {
    final message = '$error';
    if (message.contains('status: 403')) {
      return 'Google rejected the request while trying to $action (403). '
          'Please relink Google Drive, confirm this account can access the sheet, '
          'and make sure Google Sheets access is enabled for the app.';
    }
    return 'Could not $action: $error';
  }
}
