import 'dart:convert';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:calcrow/app/widgets/triangle_loading_indicator.dart';
import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/features/home/presentation/tabs/advanced/widgets/notes_widget.dart';
import 'package:calcrow/features/home/presentation/tabs/advanced/widgets/row_definement_widget.dart';
import 'package:calcrow/features/home/presentation/tabs/advanced/widgets/smart_data_widget.dart';
import 'package:calcrow/features/home/presentation/tabs/advanced/widgets/wellbeing_widget.dart';
import 'package:calcrow/features/home/presentation/tabs/advanced/widgets/workhours_widget.dart';
import 'package:calcrow/core/data/services/google_drive_auth_service.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/simple_sheet_persistence_service.dart';
import 'package:calcrow/core/sheet_type_logic/csv_logic.dart';
import 'package:calcrow/core/sheet_type_logic/ods_logic.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_logic.dart';
import 'package:calcrow/features/home/presentation/tabs/simple/widgets/select_time_widget.dart';
import 'package:calcrow/features/home/presentation/tabs/simple/widgets/timespan_widget.dart';

import '../../sheet_preview_store.dart';

enum _WidgetBlock { rowDefinement, workhours, smartData, wellbeing, notes }

class TodayTabSimple extends StatefulWidget {
  const TodayTabSimple({super.key});

  @override
  State<TodayTabSimple> createState() => _TodayTabSimpleState();
}

class _TodayTabSimpleState extends State<TodayTabSimple> {
  static const String _internalSafTestCsvAsset =
      'test_objects/raw/Arbeitszeiten_2026.csv';
  static const String _internalSafTestXlsxAsset =
      'test_objects/raw/Arbeitszeiten_2026.xlsx';
  static const String _internalSafTestOdsAsset =
      'test_objects/raw/Arbeitszeiten_2026_Randnotiz.ods';
  static const List<String> _simpleTypeOptions = <String>[
    'text',
    'date',
    'time',
    'duration',
    'int',
    'decimal',
    'email',
    'phone',
  ];
  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv'],
  );
  static const XTypeGroup _xlsxTypeGroup = XTypeGroup(
    label: 'XLSX',
    extensions: <String>['xlsx'],
  );
  static const XTypeGroup _odsTypeGroup = XTypeGroup(
    label: 'ODS',
    extensions: <String>['ods'],
  );
  static const List<XTypeGroup> _localDocumentTypeGroups = <XTypeGroup>[
    _csvTypeGroup,
    _xlsxTypeGroup,
    _odsTypeGroup,
  ];
  static const List<_WidgetBlock> _widgetBlocks = <_WidgetBlock>[
    _WidgetBlock.rowDefinement,
    _WidgetBlock.workhours,
    _WidgetBlock.smartData,
    _WidgetBlock.wellbeing,
    _WidgetBlock.notes,
  ];
  static const String _defaultStartTime = '09:00';
  static const String _defaultEndTime = '17:30';
  static const String _defaultBreakMinutes = '30';
  static const double _defaultMoodLevel = 0.45;
  static const double _defaultEnergyLevel = 0.62;
  static const int _previewRowLimit = 100;
  static final SafStream _safStreamReader = SafStream();
  static final SafUtil _safUtil = SafUtil();
  final SimpleSheetPersistenceService _sheetPersistenceService =
      SimpleSheetPersistenceService();

  final TextEditingController _dateController = TextEditingController(
    text: _formatDate(DateTime.now()),
  );
  final TextEditingController _startController = TextEditingController(
    text: _defaultStartTime,
  );
  final TextEditingController _endController = TextEditingController(
    text: _defaultEndTime,
  );
  final TextEditingController _breakController = TextEditingController(
    text: _defaultBreakMinutes,
  );
  final TextEditingController _notesController = TextEditingController();

  bool _setupDone = false;
  late bool _isAdvancedMode;
  String? _simpleImportedFileName;
  String? _simpleImportedPath;
  String? _simpleImportedSheetName;
  SimpleFileFormat? _simpleImportedFormat;
  String _simpleCsvDelimiter = ',';
  bool _simpleHasTypeRow = false;
  List<String> _simpleHeaders = const <String>[];
  List<String> _simpleValueTypes = const <String>[];
  List<bool> _simpleReadOnlyColumns = const <bool>[];
  List<int> _simplePendingTypeSelectionColumns = const <int>[];
  List<List<String>> _simpleRows = const <List<String>>[];
  List<TextEditingController> _simpleControllers =
      const <TextEditingController>[];
  excel_pkg.Excel? _simpleImportedWorkbook;
  Uint8List? _simpleImportedSourceBytes;
  int _simpleEditingRowIndex = 0;
  String? _importedFileName;
  String? _simpleXlsxLink;
  List<List<String>> _allRows = const <List<String>>[];
  int? _selectedExistingRowIndex;
  double _moodLevel = 0.45;
  double _energyLevel = 0.62;
  bool _showRowDefinement = true;
  bool _showWorkhours = true;
  bool _showSmartData = true;
  bool _showWellbeing = true;
  bool _showNotes = true;
  bool _isOpeningDocument = false;

  @override
  void initState() {
    super.initState();
    _isAdvancedMode = false;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startController.dispose();
    _endController.dispose();
    _breakController.dispose();
    _notesController.dispose();
    for (final controller in _simpleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasSimpleSchema =>
      _simpleHeaders.isNotEmpty &&
      _simpleValueTypes.length == _simpleHeaders.length &&
      _simpleReadOnlyColumns.length == _simpleHeaders.length;

  bool get _hasSimpleControllersReady =>
      _simpleControllers.length == _simpleHeaders.length &&
      _simpleReadOnlyColumns.length == _simpleHeaders.length;

  Future<void> _runWithDocumentOpeningIndicator(
    Future<void> Function() action,
  ) async {
    if (_isOpeningDocument) return;
    setState(() {
      _isOpeningDocument = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningDocument = false;
        });
      }
    }
  }

  Future<void> _importLocalDocumentForSimple() async {
    await _runWithDocumentOpeningIndicator(() async {
      try {
        final messenger = ScaffoldMessenger.of(context);
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
          if (!mounted || pickedFile == null) return;
          fileName = pickedFile.name.trim().isEmpty ? fileName : pickedFile.name;
          sourcePath = pickedFile.uri.trim().isEmpty ? null : pickedFile.uri.trim();
          if (sourcePath != null) {
            bytes = await _safStreamReader.readFileBytes(sourcePath);
          }
        } else {
          final file = await openFile(
            acceptedTypeGroups: _localDocumentTypeGroups,
            confirmButtonText: 'Open document',
          );
          if (!mounted || file == null) return;
          fileName = file.name;
          bytes = await file.readAsBytes();
          sourcePath = _readXFilePath(file);
        }

        if (!mounted) return;
        if (bytes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not read document content.')),
          );
          return;
        }

        final format = _detectSimpleFileFormat(
          fileName: fileName,
          path: sourcePath,
          bytes: bytes,
        );
        late final SimpleSheetData sheetData;
        switch (format) {
          case SimpleFileFormat.csv:
            sheetData = CsvSheetLogic.parse(
              bytes: bytes,
              fileName: fileName,
              path: sourcePath,
            );
          case SimpleFileFormat.xlsx:
            sheetData = XlsxSheetLogic.parse(
              bytes: bytes,
              fileName: fileName,
              path: sourcePath,
            );
          case SimpleFileFormat.ods:
            sheetData = await _parseOdsSheetData(
              bytes: bytes,
              fileName: fileName,
              path: sourcePath,
            );
        }
        if (!mounted) return;

        final hasSafTarget =
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            sourcePath != null &&
            _sheetPersistenceService.canUseDirectSafUri(sourcePath);
        _loadSimpleProfileData(sheetData);

        final sourceLabel = switch (sheetData.format) {
          SimpleFileFormat.csv => 'Loaded $fileName (${sheetData.rows.length} entries).',
          SimpleFileFormat.xlsx =>
            'Loaded $fileName (${sheetData.rows.length} entries) from tab ${sheetData.xlsxSheetName ?? 'default'}.${hasSafTarget ? ' SAF target ready.' : ' SAF target not detected.'}',
          SimpleFileFormat.ods =>
            'Loaded $fileName (${sheetData.rows.length} entries) from sheet ${sheetData.xlsxSheetName ?? 'default'}.${hasSafTarget ? ' SAF target ready.' : ' SAF target not detected.'}',
        };
        messenger.showSnackBar(SnackBar(content: Text(sourceLabel)));
      } on UnsupportedError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message ?? '$error')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    });
  }

  Future<SimpleSheetData> _parseOdsSheetData({
    required Uint8List bytes,
    required String fileName,
    required String? path,
  }) async {
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

  Future<void> _openXlsxViaLink() async {
    final controller = TextEditingController(text: _simpleXlsxLink ?? '');
    try {
      final submitted = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Open with link'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'XLSX link',
              hintText: 'https://...xlsx or Google Sheets URL',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Open link'),
            ),
          ],
        ),
      );
      if (!mounted || submitted == null) return;
      if (submitted.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No link entered.')));
        return;
      }
      if (!_looksLikeXlsxDocLink(submitted)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'MVP accepts only XLSX document links (.xlsx or Google Sheets URL).',
            ),
          ),
        );
        return;
      }
      setState(() {
        _simpleXlsxLink = submitted;
      });
      await _importXlsxFromLink(submitted);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importXlsxFromLink(String sourceLink) async {
    await _runWithDocumentOpeningIndicator(() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final downloadUrl = _xlsxDownloadUrlFromShareLink(sourceLink);
        final uri = Uri.tryParse(downloadUrl);
        if (uri == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('The link is not a valid URL.')),
          );
          return;
        }
        final response = await http.get(uri);
        if (!mounted) return;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Could not open link (HTTP ${response.statusCode}).',
              ),
            ),
          );
          return;
        }
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('The link returned an empty file.')),
          );
          return;
        }

        final fileName = _fileNameFromUrl(uri) ?? 'linked_file.xlsx';
        final sheetData = XlsxSheetLogic.parse(
          bytes: bytes,
          fileName: fileName,
          path: null,
        );
        _loadSimpleProfileData(sheetData);

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Loaded $fileName (${sheetData.rows.length} entries) from link.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Open via link failed: $error')));
      }
    });
  }

  bool _looksLikeXlsxDocLink(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (!(uri.scheme == 'https' || uri.scheme == 'http')) return false;
    final lowered = value.trim().toLowerCase();
    return lowered.endsWith('.xlsx') ||
        lowered.contains('.xlsx?') ||
        lowered.contains('docs.google.com/spreadsheets/');
  }

  String _xlsxDownloadUrlFromShareLink(String source) {
    final trimmed = source.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;
    if (host.contains('docs.google.com') &&
        segments.length >= 3 &&
        segments.first == 'spreadsheets' &&
        segments[1] == 'd') {
      final fileId = segments[2];
      return 'https://docs.google.com/spreadsheets/d/$fileId/export?format=xlsx';
    }

    if (host.contains('drive.google.com')) {
      if (segments.length >= 3 &&
          segments.first == 'file' &&
          segments[1] == 'd') {
        final fileId = segments[2];
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
      final fileId = uri.queryParameters['id'];
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?export=download&id=$fileId';
      }
    }

    return trimmed;
  }

  String? _fileNameFromUrl(Uri uri) {
    final xlsxSegment = uri.pathSegments.lastWhere(
      (segment) => segment.toLowerCase().endsWith('.xlsx'),
      orElse: () => '',
    );
    if (xlsxSegment.isNotEmpty) return xlsxSegment;
    final maybeName =
        uri.queryParameters['filename'] ?? uri.queryParameters['name'];
    if (maybeName != null && maybeName.trim().isNotEmpty) {
      return maybeName.trim();
    }
    return null;
  }

  SimpleFileFormat _detectSimpleFileFormat({
    required String fileName,
    required String? path,
    required Uint8List bytes,
  }) {
    final normalizedName = fileName.trim().toLowerCase();
    final normalizedPath = path?.trim().toLowerCase();
    final extensionSource =
        normalizedName.isNotEmpty ? normalizedName : (normalizedPath ?? '');
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
            : utf8.decode(mimetypeFile.content as List<int>, allowMalformed: true)
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

  bool _looksLikeZipArchive(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
  }

  void _loadSimpleProfileData(SimpleSheetData sheetData) {
    setState(() {
      _simpleImportedFileName = sheetData.fileName;
      _simpleImportedPath = sheetData.path;
      _simpleImportedFormat = sheetData.format;
      _simpleCsvDelimiter = sheetData.csvDelimiter;
      _simpleHasTypeRow = sheetData.hasTypeRow;
      _simpleImportedSheetName = sheetData.xlsxSheetName;
      _simpleHeaders = sheetData.headers;
      _simpleValueTypes = sheetData.valueTypes;
      _simpleReadOnlyColumns = sheetData.readOnlyColumns;
      _simplePendingTypeSelectionColumns =
          sheetData.pendingTypeSelectionColumns;
      _simpleRows = sheetData.rows;
      _simpleImportedWorkbook = sheetData.workbook;
      _simpleImportedSourceBytes = sheetData.sourceBytes;
    });

    _selectSimpleEditorTargetRow();
    _publishSimpleRowsToPreview();
  }

  Future<void> _openInternalSafTestCsv() async {
    await _runWithDocumentOpeningIndicator(() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final asset = await rootBundle.load(_internalSafTestCsvAsset);
        if (!mounted) return;
        final bytes = asset.buffer.asUint8List();
        if (bytes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('The bundled SAF test CSV is empty.')),
          );
          return;
        }

        var fileName = _internalSafTestCsvAsset.split('/').last;
        String? path;
        var createdSafCopy = false;

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final saveResult = await _createInternalSafTestCopy(
            bytes: bytes,
            fileName: fileName,
            typeGroup: _csvTypeGroup,
            mimeType: 'text/csv',
            confirmButtonText: 'Create Test CSV',
          );
          if (!mounted) return;
          fileName = saveResult.resolvedFileName;
          path = saveResult.savedPath;
          createdSafCopy = true;
        }

        final sheetData = CsvSheetLogic.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
        );
        _loadSimpleProfileData(sheetData);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              createdSafCopy
                  ? 'Loaded SAF test copy $fileName. Confirm field formats, then save rows back to the same SAF file.'
                  : 'Loaded bundled test CSV $fileName.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        if (error is StateError && error.message == 'Save canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF test copy canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'SAF folder selection canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF folder selection canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'Could not acquire a writable SAF folder URI.') {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not acquire a writable SAF folder URI.'),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open SAF test CSV: $error')),
        );
      }
    });
  }

  Future<void> _openInternalSafTestXlsx() async {
    await _runWithDocumentOpeningIndicator(() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final asset = await rootBundle.load(_internalSafTestXlsxAsset);
        if (!mounted) return;
        final bytes = asset.buffer.asUint8List();
        if (bytes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('The bundled SAF test XLSX is empty.'),
            ),
          );
          return;
        }

        var fileName = _internalSafTestXlsxAsset.split('/').last;
        String? path;
        var createdSafCopy = false;

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final saveResult = await _createInternalSafTestCopy(
            bytes: bytes,
            fileName: fileName,
            typeGroup: _xlsxTypeGroup,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            confirmButtonText: 'Create Test XLSX',
          );
          if (!mounted) return;
          fileName = saveResult.resolvedFileName;
          path = saveResult.savedPath;
          createdSafCopy = true;
        }

        final sheetData = XlsxSheetLogic.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
        );
        _loadSimpleProfileData(sheetData);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              createdSafCopy
                  ? 'Loaded SAF test copy $fileName. Save rows back to the same SAF Excel file.'
                  : 'Loaded bundled test XLSX $fileName.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        if (error is StateError && error.message == 'Save canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF test copy canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'SAF folder selection canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF folder selection canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'Could not acquire a writable SAF folder URI.') {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not acquire a writable SAF folder URI.'),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open SAF test XLSX: $error')),
        );
      }
    });
  }

  Future<void> _openInternalSafTestOds() async {
    await _runWithDocumentOpeningIndicator(() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final asset = await rootBundle.load(_internalSafTestOdsAsset);
        if (!mounted) return;
        final bytes = asset.buffer.asUint8List();
        if (bytes.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('The bundled SAF test ODS is empty.')),
          );
          return;
        }

        var fileName = _internalSafTestOdsAsset.split('/').last;
        String? path;
        var createdSafCopy = false;

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final saveResult = await _createInternalSafTestCopy(
            bytes: bytes,
            fileName: fileName,
            typeGroup: _odsTypeGroup,
            mimeType: 'application/vnd.oasis.opendocument.spreadsheet',
            confirmButtonText: 'Create Test ODS',
          );
          if (!mounted) return;
          fileName = saveResult.resolvedFileName;
          path = saveResult.savedPath;
          createdSafCopy = true;
        }

        final sheetData = await _parseOdsSheetData(
          bytes: bytes,
          fileName: fileName,
          path: path,
        );
        if (!mounted) return;
        _loadSimpleProfileData(sheetData);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              createdSafCopy
                  ? 'Loaded SAF test copy $fileName. Save rows back to the same SAF ODS file.'
                  : 'Loaded bundled test ODS $fileName.',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        if (error is StateError && error.message == 'Save canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF test copy canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'SAF folder selection canceled.') {
          messenger.showSnackBar(
            const SnackBar(content: Text('SAF folder selection canceled.')),
          );
          return;
        }
        if (error is StateError &&
            error.message == 'Could not acquire a writable SAF folder URI.') {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not acquire a writable SAF folder URI.'),
            ),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open SAF test ODS: $error')),
        );
      }
    });
  }

  Future<SimplePersistResult> _createInternalSafTestCopy({
    required Uint8List bytes,
    required String fileName,
    required XTypeGroup typeGroup,
    required String mimeType,
    required String confirmButtonText,
  }) async {
    final preferredTreeUri = await _preferredSafTreeUri();
    if (preferredTreeUri != null &&
        preferredTreeUri.isNotEmpty &&
        _sheetPersistenceService.canUseSafTreeUri(preferredTreeUri)) {
      try {
        return await _sheetPersistenceService.persistBytes(
          SimplePersistRequest(
            bytes: bytes,
            fileName: fileName,
            typeGroup: typeGroup,
            mimeType: mimeType,
            confirmButtonText: confirmButtonText,
            preferredSafTreeUri: preferredTreeUri,
            mode: SimplePersistMode.safPreferred,
          ),
        );
      } on StateError catch (error) {
        if (!_shouldRetryInternalSafPicker(error)) rethrow;
      }
    }

    final pickedTreeUri = await _pickWritableSafTreeUri();
    if (pickedTreeUri == null) {
      throw StateError('SAF folder selection canceled.');
    }

    return _sheetPersistenceService.persistBytes(
      SimplePersistRequest(
        bytes: bytes,
        fileName: fileName,
        typeGroup: typeGroup,
        mimeType: mimeType,
        confirmButtonText: confirmButtonText,
        preferredSafTreeUri: pickedTreeUri,
        mode: SimplePersistMode.safPreferred,
      ),
    );
  }

  bool _shouldRetryInternalSafPicker(StateError error) {
    return error.message ==
            'No SAF target selected. Open a SAF-backed file first or configure SAF folder in Settings.' ||
        error.message == 'SAF stream write failed.';
  }

  Future<String?> _pickWritableSafTreeUri() async {
    final pickedDirectory = await _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    if (!mounted) return null;
    final pickedTreeUri = pickedDirectory?.uri.trim();
    if (pickedTreeUri == null || pickedTreeUri.isEmpty) {
      return null;
    }
    if (!_sheetPersistenceService.canUseSafTreeUri(pickedTreeUri)) {
      throw StateError('Could not acquire a writable SAF folder URI.');
    }
    SimpleSheetPersistenceService.setRuntimeSafTreeUri(pickedTreeUri);
    return pickedTreeUri;
  }

  String? _readXFilePath(XFile file) {
    try {
      final path = file.path.trim();
      if (path.isEmpty) return null;
      if (SimpleSheetPersistenceService.isTemporaryPath(path)) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  List<String> _normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
  }

  int? _simpleDateColumnIndex() {
    if (_simpleHeaders.isEmpty) return null;
    final typeIndex = _simpleValueTypes.indexWhere(
      (type) => type.trim().toLowerCase() == 'date',
    );
    if (typeIndex >= 0) return typeIndex;
    final headerIndex = _simpleHeaders.indexWhere(
      (header) => _isDateHeaderName(header),
    );
    if (headerIndex >= 0) return headerIndex;
    return null;
  }

  void _selectSimpleEditorTargetRow() {
    if (!_hasSimpleSchema) return;

    final dateColumn = _simpleDateColumnIndex();
    final today = DateTime.now();
    int targetRowIndex = _simpleRows.length;

    if (dateColumn != null) {
      int? fallbackMatchIndex;
      for (var i = _simpleRows.length - 1; i >= 0; i--) {
        final row = _simpleRows[i];
        if (dateColumn >= row.length) {
          continue;
        }
        final rowDate = _parseDateFromCellValue(row[dateColumn]);
        if (rowDate == null || !_isSameCalendarDate(rowDate, today)) {
          continue;
        }
        fallbackMatchIndex ??= i;
        if (_rowHasEditableEmptyCell(row, dateColumn: dateColumn)) {
          targetRowIndex = i;
          break;
        }
      }
      targetRowIndex = targetRowIndex == _simpleRows.length
          ? (fallbackMatchIndex ?? targetRowIndex)
          : targetRowIndex;
    }

    final draft = targetRowIndex < _simpleRows.length
        ? _simpleRows[targetRowIndex]
        : List<String>.filled(_simpleHeaders.length, '');
    if (dateColumn != null && (draft[dateColumn].trim().isEmpty)) {
      draft[dateColumn] = _formatDate(today);
    }

    _replaceSimpleControllers(draft);
    setState(() {
      _simpleEditingRowIndex = targetRowIndex;
    });
  }

  bool _rowHasEditableEmptyCell(List<String> row, {required int dateColumn}) {
    for (var i = 0; i < _simpleHeaders.length; i++) {
      if (i == dateColumn || _simpleReadOnlyColumns[i]) continue;
      final value = i < row.length ? row[i].trim() : '';
      if (value.isEmpty) return true;
    }
    return false;
  }

  void _replaceSimpleControllers(List<String> values) {
    final oldControllers = _simpleControllers;
    final nextControllers = List<TextEditingController>.generate(
      _simpleHeaders.length,
      (index) => TextEditingController(
        text: index < values.length ? values[index] : '',
      ),
    );

    setState(() {
      _simpleControllers = nextControllers;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _saveSimpleRow() =>
      _saveSimpleRowInternal(mode: SimplePersistMode.safPreferred);

  Future<void> _saveSimpleRowAsIs() =>
      _saveSimpleRowInternal(mode: SimplePersistMode.asIs);

  Future<void> _saveSimpleRowInternal({required SimplePersistMode mode}) async {
    if (!_hasSimpleSchema ||
        _simpleControllers.length != _simpleHeaders.length) {
      return;
    }

    final updatedRow = _simpleControllers
        .map((controller) => controller.text.trim())
        .toList();
    final nextRows = List<List<String>>.from(_simpleRows);
    final forcedTargetIndex = _findBestExistingRowForSave(updatedRow);
    final effectiveTargetIndex = forcedTargetIndex ?? _simpleEditingRowIndex;

    if (effectiveTargetIndex < nextRows.length) {
      final normalizedUpdated = _normalizeRowToWidth(
        updatedRow,
        _simpleHeaders.length,
      );
      if (forcedTargetIndex != null &&
          forcedTargetIndex != _simpleEditingRowIndex) {
        nextRows[effectiveTargetIndex] = _mergeRowForAutoFill(
          existing: nextRows[effectiveTargetIndex],
          incoming: normalizedUpdated,
        );
      } else {
        nextRows[effectiveTargetIndex] = normalizedUpdated;
      }
    } else {
      nextRows.add(_normalizeRowToWidth(updatedRow, _simpleHeaders.length));
    }

    setState(() {
      _simpleRows = nextRows;
      _simpleEditingRowIndex = effectiveTargetIndex;
      if (_simpleEditingRowIndex >= _simpleRows.length) {
        _simpleEditingRowIndex = _simpleRows.length - 1;
      }
    });
    _publishSimpleRowsToPreview();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saveResult = await _persistSimpleSheet(mode: mode);
      if (!mounted) return;
      try {
        final syncFileName = await _syncSimpleSheetToGoogleDrive();
        if (!mounted) return;
        if (syncFileName != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Row saved to ${saveResult.locationLabel} and synced to Google Drive ($syncFileName).',
              ),
            ),
          );
          return;
        }
      } on GoogleDriveAuthException catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Row saved to ${saveResult.locationLabel}, but cloud sync failed: ${error.message}',
            ),
          ),
        );
        return;
      } on GoogleDriveSyncException catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Row saved to ${saveResult.locationLabel}, but cloud sync failed: ${error.message}',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(_saveMessage(saveResult))));
    } catch (error) {
      if (!mounted) return;
      if (error is StateError && error.message == 'Save canceled.') {
        messenger.showSnackBar(
          const SnackBar(content: Text('Row updated. File save canceled.')),
        );
        return;
      }
      if (error is StateError && error.message == 'SAF save canceled.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('SAF save canceled. Use "Save as is" in Preview.'),
          ),
        );
        return;
      }
      if (error is StateError &&
          error.message == 'SAF save is not supported on this platform.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'SAF save is not available here. Use "Save as is" in Preview.',
            ),
          ),
        );
        return;
      }
      if (error is StateError &&
          error.message ==
              'No SAF target selected. Open a SAF-backed file first or configure SAF folder in Settings.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No SAF target selected. Open a SAF-backed file or configure SAF folder in Settings, or use "Save as is" in Preview.',
            ),
          ),
        );
        return;
      }
      if (error is StateError &&
          error.message ==
              'Current file is not SAF-backed. Use "Save as is" or reopen with SAF.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Current file is not SAF-backed. Use "Save as is" in Preview, or reopen via SAF.',
            ),
          ),
        );
        return;
      }
      if (error is StateError && error.message == 'SAF stream write failed.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'SAF stream write failed. Use "Save as is" in Preview.',
            ),
          ),
        );
        return;
      }
      if (error is StateError &&
          error.message ==
              'SAF target is incompatible for direct overwrite. Reopen from a writable folder via SAF.') {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This SAF source cannot be overwritten directly. Reopen from a writable folder via SAF, or use "Save as is".',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Row saved in app, but file write failed: $error'),
        ),
      );
    }
  }

  String _saveMessage(SimplePersistResult saveResult) {
    if (kIsWeb) {
      return 'Row updated. Downloaded updated file as ${saveResult.locationLabel}.';
    }
    if (saveResult.usedAppDocumentsFallback) {
      return 'Row saved to app storage at ${saveResult.locationLabel}.';
    }
    if (saveResult.overwroteExistingFile) {
      return 'Row saved to ${saveResult.locationLabel}.';
    }
    return 'Row saved to ${saveResult.locationLabel}. Future saves will overwrite this file.';
  }

  int? _findBestExistingRowForSave(List<String> updatedRow) {
    final dateColumn = _simpleDateColumnIndex();
    if (dateColumn == null || dateColumn >= updatedRow.length) {
      return null;
    }
    final targetDate = _parseDateFromCellValue(updatedRow[dateColumn]);
    if (targetDate == null) {
      return null;
    }

    int? fallbackMatchIndex;
    for (var i = _simpleRows.length - 1; i >= 0; i--) {
      final row = _simpleRows[i];
      if (dateColumn >= row.length) continue;
      final rowDate = _parseDateFromCellValue(row[dateColumn]);
      if (rowDate == null || !_isSameCalendarDate(rowDate, targetDate)) {
        continue;
      }
      fallbackMatchIndex ??= i;
      if (_rowHasEditableEmptyCell(row, dateColumn: dateColumn)) {
        return i;
      }
    }
    return fallbackMatchIndex;
  }

  List<String> _mergeRowForAutoFill({
    required List<String> existing,
    required List<String> incoming,
  }) {
    final normalizedExisting = _normalizeRowToWidth(
      existing,
      _simpleHeaders.length,
    );
    return List<String>.generate(_simpleHeaders.length, (index) {
      final next = index < incoming.length ? incoming[index].trim() : '';
      if (next.isNotEmpty) return next;
      return normalizedExisting[index];
    });
  }

  void _clearSimpleEditableFields() {
    final dateColumn = _simpleDateColumnIndex();
    for (var i = 0; i < _simpleControllers.length; i++) {
      if (i == dateColumn || _simpleReadOnlyColumns[i]) continue;
      _simpleControllers[i].clear();
    }
    setState(() {});
  }

  void _updatePendingSimpleType(int columnIndex, String nextType) {
    final nextTypes = List<String>.from(_simpleValueTypes);
    if (columnIndex < 0 || columnIndex >= nextTypes.length) return;
    nextTypes[columnIndex] = nextType;
    setState(() {
      _simpleValueTypes = nextTypes;
    });
  }

  void _confirmPendingSimpleTypes() {
    if (_simplePendingTypeSelectionColumns.isEmpty) return;
    setState(() {
      _simplePendingTypeSelectionColumns = const <int>[];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Field formats confirmed.')));
  }

  void _publishSimpleRowsToPreview() {
    SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
        .copyWith(
          headers: _simpleHeaders,
          rows: _simpleRows.take(_previewRowLimit).toList(),
          fileName: _simpleImportedFileName,
          rowCount: _simpleRows.length,
          onSaveAsIs: _saveSimpleRowAsIs,
        );
  }

  Future<SimplePersistResult> _persistSimpleSheet({
    required SimplePersistMode mode,
  }) async {
    final format = _simpleImportedFormat;
    if (format == SimpleFileFormat.xlsx) {
      return _persistSimpleXlsx(mode: mode);
    }
    if (format == SimpleFileFormat.ods) {
      return _persistSimpleOds(mode: mode);
    }
    return _persistSimpleCsv(mode: mode);
  }

  Future<String?> _syncSimpleSheetToGoogleDrive() async {
    if (!ServiceLocator.isSetup) return null;

    final session = ServiceLocator.authService.currentSession;
    if (session == null) return null;

    final settings = await ServiceLocator.dbService.getUserSettings(
      session.uid,
    );
    final linked = settings?['googleDriveLinked'];
    if (linked is! bool || !linked) return null;

    final authenticatedClient = await ServiceLocator.googleDriveAuthService
        .getAuthenticatedClient();

    final format = _simpleImportedFormat;
    final simpleData = _buildSimpleSheetDataForPersist();
    final bytes = format == SimpleFileFormat.xlsx
        ? XlsxSheetLogic.buildBytes(simpleData)
        : format == SimpleFileFormat.ods
        ? OdsSheetLogic.buildBytes(simpleData)
        : CsvSheetLogic.buildBytes(simpleData);
    final mimeType = format == SimpleFileFormat.xlsx
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : format == SimpleFileFormat.ods
        ? 'application/vnd.oasis.opendocument.spreadsheet'
        : 'text/csv';
    final fileName = _simpleSuggestedFileName(
      defaultExtension: format == SimpleFileFormat.xlsx
          ? 'xlsx'
          : format == SimpleFileFormat.ods
          ? 'ods'
          : 'csv',
    );

    final existingFileId = (settings?['googleDriveSyncFileId'] as String?)
        ?.trim();
    final existingMimeType = (settings?['googleDriveSyncMimeType'] as String?)
        ?.trim();

    final GoogleDriveFileMetadata metadata;
    try {
      if (existingFileId == null ||
          existingFileId.isEmpty ||
          existingMimeType == null ||
          existingMimeType.isEmpty ||
          existingMimeType != mimeType) {
        metadata = await ServiceLocator.googleDriveSyncService.createSyncFile(
          authenticatedClient: authenticatedClient,
          fileName: fileName,
          bytes: bytes,
          mimeType: mimeType,
        );
      } else {
        metadata = await ServiceLocator.googleDriveSyncService.updateFileBytes(
          authenticatedClient: authenticatedClient,
          fileId: existingFileId,
          bytes: bytes,
          mimeType: mimeType,
        );
      }
    } finally {
      authenticatedClient.close();
    }
    await ServiceLocator.dbService.setGoogleDriveSyncFile(
      uid: session.uid,
      fileId: metadata.id,
      fileName: metadata.name,
      mimeType: metadata.mimeType,
    );
    return metadata.name;
  }

  Future<SimplePersistResult> _persistSimpleCsv({
    required SimplePersistMode mode,
  }) async {
    final bytes = CsvSheetLogic.buildBytes(_buildSimpleSheetDataForPersist());
    final fileName = _simpleSuggestedFileName();
    return _persistSimpleBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _csvTypeGroup,
      mimeType: 'text/csv',
      confirmButtonText: 'Save CSV',
      mode: mode,
    );
  }

  Future<SimplePersistResult> _persistSimpleXlsx({
    required SimplePersistMode mode,
  }) async {
    final bytes = XlsxSheetLogic.buildBytes(_buildSimpleSheetDataForPersist());

    final fileName = _simpleSuggestedFileName(defaultExtension: 'xlsx');
    return _persistSimpleBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _xlsxTypeGroup,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      confirmButtonText: 'Save XLSX',
      mode: mode,
    );
  }

  Future<SimplePersistResult> _persistSimpleOds({
    required SimplePersistMode mode,
  }) async {
    final bytes = OdsSheetLogic.buildBytes(_buildSimpleSheetDataForPersist());

    final fileName = _simpleSuggestedFileName(defaultExtension: 'ods');
    return _persistSimpleBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _odsTypeGroup,
      mimeType: 'application/vnd.oasis.opendocument.spreadsheet',
      confirmButtonText: 'Save ODS',
      mode: mode,
    );
  }

  SimpleSheetData _buildSimpleSheetDataForPersist() {
    return SimpleSheetData(
      fileName: _simpleImportedFileName ?? 'calcrow_simple',
      path: _simpleImportedPath,
      format: _simpleImportedFormat ?? SimpleFileFormat.csv,
      headers: _simpleHeaders,
      valueTypes: _simpleValueTypes,
      readOnlyColumns: _simpleReadOnlyColumns,
      rows: _simpleRows,
      csvDelimiter: _simpleCsvDelimiter,
      hasTypeRow: _simpleHasTypeRow,
      xlsxSheetName: _simpleImportedSheetName,
      workbook: _simpleImportedWorkbook,
      sourceBytes: _simpleImportedSourceBytes,
    );
  }

  Future<SimplePersistResult> _persistSimpleBytes({
    required Uint8List bytes,
    required String fileName,
    required XTypeGroup typeGroup,
    required String mimeType,
    required String confirmButtonText,
    required SimplePersistMode mode,
  }) async {
    final preferredSafTreeUri = await _preferredSafTreeUri();
    final result = await _sheetPersistenceService.persistBytes(
      SimplePersistRequest(
        bytes: bytes,
        fileName: fileName,
        typeGroup: typeGroup,
        mimeType: mimeType,
        confirmButtonText: confirmButtonText,
        existingPath: _simpleImportedPath,
        preferredSafTreeUri: preferredSafTreeUri,
        mode: mode,
      ),
    );
    _simpleImportedPath = result.savedPath;
    _simpleImportedFileName = result.resolvedFileName;
    return result;
  }

  Future<String?> _preferredSafTreeUri() async {
    if (!ServiceLocator.isSetup) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    final settings = await ServiceLocator.dbService.getUserSettings(
      session.uid,
    );
    final uri = (settings?['safTreeUri'] as String?)?.trim();
    if (uri == null || uri.isEmpty) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    return uri;
  }

  String _simpleSuggestedFileName({String? defaultExtension}) {
    final current = _simpleImportedFileName?.trim();
    final extension =
        defaultExtension ??
        (_simpleImportedFormat == SimpleFileFormat.xlsx
            ? 'xlsx'
            : _simpleImportedFormat == SimpleFileFormat.ods
            ? 'ods'
            : 'csv');
    if (current == null || current.isEmpty) {
      return 'calcrow_simple.$extension';
    }
    if (current.toLowerCase().endsWith('.$extension')) {
      return current;
    }
    return '$current.$extension';
  }

  Future<void> _importCsv() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[_csvTypeGroup],
        confirmButtonText: 'Import CSV',
      );

      if (!mounted || file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not read CSV file content.')),
        );
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The selected CSV is empty.')),
        );
        return;
      }

      final delimiter = _detectDelimiter(lines.first);
      final parsedHeader = _splitCsvLine(lines.first, delimiter: delimiter);
      final parsedRows = lines
          .skip(1)
          .map((line) => _splitCsvLine(line, delimiter: delimiter))
          .toList();

      setState(() {
        _setupDone = true;
        _importedFileName = file.name;
        _allRows = parsedRows.reversed.toList();
        _selectedExistingRowIndex = null;
        _showRowDefinement = true;
        _showWorkhours = true;
        _showSmartData = true;
        _showWellbeing = true;
        _showNotes = true;
      });
      final currentHeaders = SheetPreviewStore.notifier.value.headers;
      SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
          .copyWith(
            headers: parsedHeader.isNotEmpty ? parsedHeader : currentHeaders,
            rows: _allRows.take(_previewRowLimit).toList(),
            fileName: file.name,
            rowCount: _allRows.length,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Imported ${file.name} (${_allRows.length} rows).'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  void _createNewCsv() {
    final now = DateTime.now();
    setState(() {
      _setupDone = true;
      _importedFileName = _buildMonthlyFileName(now);
      _allRows = <List<String>>[];
      _selectedExistingRowIndex = null;
      _showRowDefinement = true;
      _showWorkhours = true;
      _showSmartData = false;
      _showWellbeing = false;
      _showNotes = false;
    });
    final headers = _headersForVisibleWidgets();
    SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
        .copyWith(
          headers: headers,
          rows: const <List<String>>[],
          fileName: _importedFileName,
          rowCount: 0,
        );
  }

  void _saveRow() {
    final messenger = ScaffoldMessenger.of(context);
    final headers = _allRows.isNotEmpty
        ? SheetPreviewStore.notifier.value.headers
        : _headersForVisibleWidgets();
    final valuesByHeader = <String, String>{
      'Date': _dateController.text.trim(),
      'Start': _startController.text.trim(),
      'End': _endController.text.trim(),
      'Pause': '${_breakMinutes}m',
      'Mood': '${(_moodLevel * 100).round()}%',
      'Energy': '${(_energyLevel * 100).round()}%',
      'Health': '${(_energyLevel * 100).round()}%',
      'Steps': '7500',
      'Notes': _notesController.text.trim(),
    };
    final row = headers.map((header) => valuesByHeader[header] ?? '').toList();

    setState(() {
      _setupDone = true;
      _selectedExistingRowIndex = null;
      _allRows = <List<String>>[row, ..._allRows];
    });
    SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
        .copyWith(
          headers: headers,
          rows: _allRows.take(_previewRowLimit).toList(),
          rowCount: _allRows.length,
        );

    messenger.showSnackBar(const SnackBar(content: Text('New row submitted.')));
  }

  void _clearEditorWindow() {
    setState(() {
      _selectedExistingRowIndex = null;
      _dateController.text = _formatDate(DateTime.now());
      _startController.text = _defaultStartTime;
      _endController.text = _defaultEndTime;
      _breakController.text = _defaultBreakMinutes;
      _notesController.clear();
      _moodLevel = _defaultMoodLevel;
      _energyLevel = _defaultEnergyLevel;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Editor cleared.')));
  }

  List<String> _splitCsvLine(String line, {required String delimiter}) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }

      if (!inQuotes && char == delimiter) {
        cells.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    cells.add(buffer.toString().trim());
    return cells;
  }

  String _detectDelimiter(String line) {
    const candidates = <String>[',', ';', '\t'];
    String best = ',';
    var bestCount = -1;

    for (final candidate in candidates) {
      final count = _countDelimiterOutsideQuotes(line, candidate);
      if (count > bestCount) {
        best = candidate;
        bestCount = count;
      }
    }
    return best;
  }

  int _countDelimiterOutsideQuotes(String line, String delimiter) {
    var inQuotes = false;
    var count = 0;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && char == delimiter) {
        count++;
      }
    }

    return count;
  }

  bool _isDateHeaderName(String header) {
    final value = header.trim().toLowerCase();
    return value == 'date' ||
        value == 'datum' ||
        value == 'tag' ||
        value == 'data' ||
        value == 'fecha';
  }

  DateTime? _parseDateFromCellValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    DateTime? tryBuild(int year, int month, int day) {
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      return DateTime(year, month, day);
    }

    final iso = RegExp(
      r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$',
    ).firstMatch(value);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      return tryBuild(year, month, day);
    }

    final dmy = RegExp(
      r'^(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?$',
    ).firstMatch(value);
    if (dmy != null) {
      final day = int.parse(dmy.group(1)!);
      final month = int.parse(dmy.group(2)!);
      final yearGroup = dmy.group(3);
      int year;
      if (yearGroup == null || yearGroup.isEmpty) {
        year = DateTime.now().year;
      } else if (yearGroup.length == 2) {
        final yy = int.parse(yearGroup);
        year = yy >= 70 ? 1900 + yy : 2000 + yy;
      } else {
        year = int.parse(yearGroup);
      }
      return tryBuild(year, month, day);
    }

    return null;
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _buildMonthlyFileName(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'month_${year}_$month.csv';
  }

  int get _breakMinutes => int.tryParse(_breakController.text.trim()) ?? 0;

  String get _totalHours {
    final start = _parseTime(_startController.text.trim());
    final end = _parseTime(_endController.text.trim());
    if (start == null || end == null) return '--:--';

    final rawMinutes = end.inMinutes - start.inMinutes - _breakMinutes;
    if (rawMinutes < 0) return '--:--';
    final hours = rawMinutes ~/ 60;
    final minutes = rawMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Duration? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return Duration(hours: hour, minutes: minute);
  }

  Set<_WidgetBlock> get _visibleWidgets {
    final items = <_WidgetBlock>{};
    if (_showRowDefinement) items.add(_WidgetBlock.rowDefinement);
    if (_showWorkhours) items.add(_WidgetBlock.workhours);
    if (_showSmartData) items.add(_WidgetBlock.smartData);
    if (_showWellbeing) items.add(_WidgetBlock.wellbeing);
    if (_showNotes) items.add(_WidgetBlock.notes);
    return items;
  }

  void _toggleWidget(_WidgetBlock block) {
    if (_allRows.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Widget layout is locked because this CSV already has entries.',
          ),
        ),
      );
      return;
    }

    setState(() {
      switch (block) {
        case _WidgetBlock.rowDefinement:
          _showRowDefinement = !_showRowDefinement;
          break;
        case _WidgetBlock.workhours:
          _showWorkhours = !_showWorkhours;
          break;
        case _WidgetBlock.smartData:
          _showSmartData = !_showSmartData;
          break;
        case _WidgetBlock.wellbeing:
          _showWellbeing = !_showWellbeing;
          break;
        case _WidgetBlock.notes:
          _showNotes = !_showNotes;
          break;
      }
    });
    if (_setupDone && _allRows.isEmpty) {
      final headers = _headersForVisibleWidgets();
      SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
          .copyWith(headers: headers);
    }
  }

  List<String> _headersForVisibleWidgets() {
    final headers = <String>[];
    if (_showRowDefinement) {
      headers.add('Date');
    }
    if (_showWorkhours) {
      headers.addAll(const <String>['Start', 'End', 'Pause']);
    }
    if (_showWellbeing) {
      headers.addAll(const <String>['Mood', 'Energy']);
    }
    if (_showSmartData) {
      headers.addAll(const <String>['Health', 'Steps']);
    }
    if (_showNotes) {
      headers.add('Notes');
    }
    return headers;
  }

  int? _headerIndex(List<String> headers, String name) {
    final index = headers.indexOf(name);
    if (index < 0) return null;
    return index;
  }

  List<int> _sameDateRowIndices() {
    final headers = SheetPreviewStore.notifier.value.headers;
    final dateIndex = _headerIndex(headers, 'Date');
    final dateValue = _dateController.text.trim();
    if (dateIndex == null || dateValue.isEmpty) {
      return const <int>[];
    }

    final matches = <int>[];
    for (var i = 0; i < _allRows.length; i++) {
      final row = _allRows[i];
      if (dateIndex < row.length && row[dateIndex].trim() == dateValue) {
        matches.add(i);
      }
    }
    return matches;
  }

  void _loadPreviousSameDateEntry() {
    final matches = _sameDateRowIndices();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entry found for this date.')),
      );
      return;
    }

    int nextIndex = 0;
    if (_selectedExistingRowIndex != null) {
      final currentPos = matches.indexOf(_selectedExistingRowIndex!);
      if (currentPos >= 0) {
        nextIndex = (currentPos + 1) % matches.length;
      }
    }

    final targetRowIndex = matches[nextIndex];
    final targetRow = _allRows[targetRowIndex];
    final headers = SheetPreviewStore.notifier.value.headers;

    setState(() {
      _selectedExistingRowIndex = targetRowIndex;
      _dateController.text = _cellValue(targetRow, headers, 'Date');
      _startController.text = _cellValue(
        targetRow,
        headers,
        'Start',
        fallback: _defaultStartTime,
      );
      _endController.text = _cellValue(
        targetRow,
        headers,
        'End',
        fallback: _defaultEndTime,
      );
      _breakController.text = _readBreakMinutes(
        _cellValue(targetRow, headers, 'Pause'),
      );
      _notesController.text = _cellValue(targetRow, headers, 'Notes');
      _moodLevel = _readPercentValue(
        _cellValue(targetRow, headers, 'Mood'),
        fallback: _defaultMoodLevel,
      );
      final energyRaw = _cellValue(
        targetRow,
        headers,
        'Energy',
        fallback: _cellValue(targetRow, headers, 'Health'),
      );
      _energyLevel = _readPercentValue(
        energyRaw,
        fallback: _defaultEnergyLevel,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded same-date entry ${nextIndex + 1}/${matches.length}. Edit and submit a new row if needed.',
        ),
      ),
    );
  }

  void _loadNextSameDateEntry() {
    final matches = _sameDateRowIndices();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entry found for this date.')),
      );
      return;
    }

    int nextIndex = 0;
    if (_selectedExistingRowIndex != null) {
      final currentPos = matches.indexOf(_selectedExistingRowIndex!);
      if (currentPos >= 0) {
        if (currentPos == 0) {
          _switchToCreateNewForCurrentDate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create new entry mode.')),
          );
          return;
        }
        nextIndex = currentPos - 1;
      }
    }

    final targetRowIndex = matches[nextIndex];
    final targetRow = _allRows[targetRowIndex];
    final headers = SheetPreviewStore.notifier.value.headers;

    setState(() {
      _selectedExistingRowIndex = targetRowIndex;
      _dateController.text = _cellValue(targetRow, headers, 'Date');
      _startController.text = _cellValue(
        targetRow,
        headers,
        'Start',
        fallback: _defaultStartTime,
      );
      _endController.text = _cellValue(
        targetRow,
        headers,
        'End',
        fallback: _defaultEndTime,
      );
      _breakController.text = _readBreakMinutes(
        _cellValue(targetRow, headers, 'Pause'),
      );
      _notesController.text = _cellValue(targetRow, headers, 'Notes');
      _moodLevel = _readPercentValue(
        _cellValue(targetRow, headers, 'Mood'),
        fallback: _defaultMoodLevel,
      );
      final energyRaw = _cellValue(
        targetRow,
        headers,
        'Energy',
        fallback: _cellValue(targetRow, headers, 'Health'),
      );
      _energyLevel = _readPercentValue(
        energyRaw,
        fallback: _defaultEnergyLevel,
      );
    });
  }

  void _switchToCreateNewForCurrentDate() {
    final currentDate = _dateController.text.trim();
    setState(() {
      _selectedExistingRowIndex = null;
      _dateController.text = currentDate.isEmpty
          ? _formatDate(DateTime.now())
          : currentDate;
      _startController.text = _defaultStartTime;
      _endController.text = _defaultEndTime;
      _breakController.text = _defaultBreakMinutes;
      _notesController.clear();
      _moodLevel = _defaultMoodLevel;
      _energyLevel = _defaultEnergyLevel;
    });
  }

  String _cellValue(
    List<String> row,
    List<String> headers,
    String name, {
    String fallback = '',
  }) {
    final index = _headerIndex(headers, name);
    if (index == null || index >= row.length) return fallback;
    final value = row[index].trim();
    if (value.isEmpty) return fallback;
    return value;
  }

  static String _readBreakMinutes(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return _defaultBreakMinutes;
    return digits;
  }

  static double _readPercentValue(String value, {required double fallback}) {
    final normalized = value.replaceAll('%', '').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null) return fallback;
    final value01 = (parsed / 100).clamp(0.0, 1.0);
    return value01.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            _TopHeader(
              isAdvancedMode: _isAdvancedMode,
              showModeSwitch: false,
              headerTitle: _headerTitle,
              setupDone: _setupDone,
              widgetOptions: _widgetBlocks,
              visibleWidgets: _visibleWidgets,
              onBack: _handleBack,
              onToggleMode: _toggleMode,
              onToggleWidget: _setupDone ? _toggleWidget : null,
            ),
            const SizedBox(height: 14),
            if (!_isAdvancedMode) ...[
              _buildSimpleView(theme),
            ] else if (!_setupDone) ...[
              _buildSetupView(theme),
            ] else ...[
              _buildEditorView(theme),
            ],
          ],
        ),
        if (_isOpeningDocument)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.82),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TriangleLoadingIndicator(
                          size: 72,
                          baseColor: theme.colorScheme.primary,
                          strokeColor: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Opening document...',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSimpleView(ThemeData theme) {
    if (!_hasSimpleSchema) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TabBar(
                tabs: [
                  Tab(text: 'Edit Local Document'),
                  Tab(text: 'Test SAF Internal'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _SetupCard(
                        title: 'Edit Local Document',
                        subtitle:
                            !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.android
                            ? 'Open a CSV, XLSX, or ODS document via Android SAF for direct save-back when available'
                            : 'Open CSV, XLSX, or ODS. Calcrow detects the file type automatically.',
                        icon: Icons.folder_open_rounded,
                        onTap: _importLocalDocumentForSimple,
                      ),
                      const SizedBox(height: 10),
                      _SetupCard(
                        title: 'Open with link',
                        subtitle:
                            _simpleXlsxLink ?? 'MVP: only XLSX document links',
                        icon: Icons.link_rounded,
                        onTap: _openXlsxViaLink,
                      ),
                    ],
                  ),
                  ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _SetupCard(
                        title: 'Open Arbeitszeiten_2026.csv',
                        subtitle:
                            !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.android
                            ? 'Creates a SAF-backed copy first, then opens it in Simple mode'
                            : 'Loads the bundled raw test sheet into Simple mode',
                        icon: Icons.science_rounded,
                        onTap: _openInternalSafTestCsv,
                      ),
                      const SizedBox(height: 10),
                      _SetupCard(
                        title: 'Open Arbeitszeiten_2026.xlsx',
                        subtitle:
                            !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.android
                            ? 'Creates a SAF-backed Excel copy first, then opens it in Simple mode'
                            : 'Loads the bundled raw Excel test sheet into Simple mode',
                        icon: Icons.table_view_rounded,
                        onTap: _openInternalSafTestXlsx,
                      ),
                      const SizedBox(height: 10),
                      _SetupCard(
                        title: 'Open Arbeitszeiten_2026_Randnotiz.ods',
                        subtitle:
                            !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.android
                            ? 'Creates a SAF-backed ODS copy first, then opens it in Simple mode'
                            : 'Loads the bundled raw ODS test sheet into Simple mode',
                        icon: Icons.table_chart_rounded,
                        onTap: _openInternalSafTestOds,
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'These test sheets have headers, empty input cells, and calculated columns. CSV asks for missing editable formats once. XLSX and ODS keep formula columns read-only and save back to the same workbook.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              'Simple mode will auto-jump to today\'s row if a date column exists, otherwise it opens a new row at the bottom.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (!_hasSimpleControllersReady) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(child: Text('Preparing editor fields...')),
            ],
          ),
        ),
      );
    }

    final dateColumn = _simpleDateColumnIndex();
    final isEditingExisting = _simpleEditingRowIndex < _simpleRows.length;
    final hasPendingTypeSelection =
        _simplePendingTypeSelectionColumns.isNotEmpty;
    final targetLabel = isEditingExisting
        ? 'Editing row ${_simpleEditingRowIndex + 1} of ${_simpleRows.length}'
        : 'Editing new row at bottom';
    final isSheetDocumentSource =
        _simpleImportedFormat == SimpleFileFormat.xlsx ||
        _simpleImportedFormat == SimpleFileFormat.ods;
    final sheetName = _simpleImportedSheetName?.trim();
    final activeSheetLabel = isSheetDocumentSource
        ? ((sheetName == null || sheetName.isEmpty) ? 'default' : sheetName)
        : null;
    final pendingTypeSelectionMessage = isSheetDocumentSource
        ? 'Set Datatypes and bear in mind that calculated fields are read-only.'
        : 'This file has no usable type row yet. Pick the editable field formats once before saving.';

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current File', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        _simpleImportedFileName == null
                            ? targetLabel
                            : '${_simpleImportedFileName!} - $targetLabel',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (activeSheetLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Active sheet: $activeSheetLabel',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _importLocalDocumentForSimple,
                  child: const Text('Open Document'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (hasPendingTypeSelection) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm field formats',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pendingTypeSelectionMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._simplePendingTypeSelectionColumns.map((index) {
                    final header = _simpleHeaders[index];
                    final currentType = _simpleValueTypes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue: _simpleTypeOptions.contains(currentType)
                            ? currentType
                            : 'text',
                        decoration: InputDecoration(labelText: header),
                        items: _simpleTypeOptions
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          _updatePendingSimpleType(index, value);
                        },
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _confirmPendingSimpleTypes,
                      child: const Text('Use these formats'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List<Widget>.generate(_simpleHeaders.length, (index) {
                final header = _simpleHeaders[index];
                final type = _simpleValueTypes[index];
                final isDateField = index == dateColumn;
                final isFormulaField = _simpleReadOnlyColumns[index];
                if (isFormulaField) {
                  return const SizedBox.shrink();
                }
                final isReadOnly = isDateField;
                final isDurationField =
                    _isSimpleDurationType(type) ||
                    _isSimpleTimespanField(header);
                final keyboardType = _keyboardForSimpleType(type);
                final helperText =
                    'Type: $type${isDateField ? ' (fixed)' : ''}';
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _simpleHeaders.length - 1 ? 0 : 10,
                  ),
                  child: !isReadOnly && isDurationField
                      ? TimespanWidget(
                          controller: _simpleControllers[index],
                          labelText: header,
                          hintText: 'Minutes (e.g. 30)',
                          helperText: '$helperText (enter minutes)',
                        )
                      : !isReadOnly && _isSimpleTimeType(type)
                      ? SelectTimeWidget(
                          controller: _simpleControllers[index],
                          labelText: header,
                          hintText: _hintForSimpleType(
                            type,
                            isDateField: isDateField,
                          ),
                          helperText: helperText,
                        )
                      : TextField(
                          controller: _simpleControllers[index],
                          readOnly: isReadOnly,
                          keyboardType: keyboardType,
                          decoration: InputDecoration(
                            labelText: header,
                            hintText: _hintForSimpleType(
                              type,
                              isDateField: isDateField,
                            ),
                            helperText: helperText,
                          ),
                          minLines: header.toLowerCase().contains('note')
                              ? 2
                              : 1,
                          maxLines: header.toLowerCase().contains('note')
                              ? 4
                              : 1,
                        ),
                );
              }).where((widget) => widget is! SizedBox).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: hasPendingTypeSelection ? null : _saveSimpleRow,
                    child: const Text('Save Row'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectSimpleEditorTargetRow,
                    child: const Text('Jump Today'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearSimpleEditableFields,
                  tooltip: 'Clear editable fields',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TextInputType _keyboardForSimpleType(String rawType) {
    final type = rawType.trim().toLowerCase();
    if (type.contains('int') ||
        type.contains('double') ||
        type.contains('num') ||
        type.contains('decimal')) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    if (type.contains('mail')) {
      return TextInputType.emailAddress;
    }
    if (type.contains('phone')) {
      return TextInputType.phone;
    }
    if (type.contains('duration')) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    if (type.contains('date') || type.contains('time')) {
      return TextInputType.datetime;
    }
    return TextInputType.text;
  }

  bool _isSimpleTimeType(String rawType) {
    return rawType.trim().toLowerCase().contains('time');
  }

  bool _isSimpleDurationType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type.contains('duration') || type.contains('timespan');
  }

  bool _isSimpleTimespanField(String header) {
    final value = header.trim().toLowerCase();
    return value.contains('pause') || value.contains('break');
  }

  String? _hintForSimpleType(String rawType, {required bool isDateField}) {
    if (isDateField) {
      return 'YYYY-MM-DD';
    }

    final type = rawType.trim().toLowerCase();
    if (type.contains('duration')) {
      return 'Minutes or HH:MM:SS';
    }
    if (type.contains('time')) {
      return 'HH:MM:SS';
    }
    if (type.contains('date')) {
      return 'YYYY-MM-DD';
    }
    if (type.contains('int')) {
      return '123';
    }
    if (type.contains('double') ||
        type.contains('num') ||
        type.contains('decimal') ||
        type.contains('number')) {
      return '123.45 or 123,45';
    }
    if (type.contains('email')) {
      return 'name@example.com';
    }
    if (type.contains('phone')) {
      return '+49 123 456789';
    }
    return null;
  }

  Widget _buildSetupView(ThemeData theme) {
    return Column(
      children: [
        _SetupCard(
          title: 'Create New CSV',
          subtitle: 'Start from a fresh monthly sheet',
          icon: Icons.arrow_forward_ios_rounded,
          onTap: _createNewCsv,
        ),
        const SizedBox(height: 10),
        _SetupCard(
          title: 'Select Local File',
          subtitle:
              _importedFileName ?? 'Open an existing CSV from this device',
          icon: Icons.folder_open_rounded,
          onTap: _importCsv,
        ),
        const SizedBox(height: 10),
        _SetupCard(
          title: 'Open with link',
          subtitle: _simpleXlsxLink ?? 'MVP: only XLSX document links',
          icon: Icons.link_rounded,
          onTap: _openXlsxViaLink,
        ),
        const SizedBox(height: 14),
        Text(
          'Tip: this follows your sketch flow. Pick a file first, then edit daily rows.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildEditorView(ThemeData theme) {
    return Column(
      children: [
        if (_showRowDefinement)
          RowDefinementWidget(dateController: _dateController),
        if (_showWorkhours) ...[
          if (_showRowDefinement) const SizedBox(height: 10),
          WorkhoursWidget(
            startController: _startController,
            endController: _endController,
            breakController: _breakController,
            totalHours: _totalHours,
            onChanged: () => setState(() {}),
          ),
        ],
        if (_showSmartData) ...[
          if (_showRowDefinement || _showWorkhours) const SizedBox(height: 10),
          SmartDataWidget(energyLevel: _energyLevel),
        ],
        if (_showWellbeing) ...[
          const SizedBox(height: 10),
          WellbeingWidget(
            moodLevel: _moodLevel,
            energyLevel: _energyLevel,
            onMoodChanged: (value) => setState(() => _moodLevel = value),
            onEnergyChanged: (value) => setState(() => _energyLevel = value),
          ),
        ],
        if (_showNotes) ...[
          const SizedBox(height: 10),
          NotesWidget(
            notesController: _notesController,
            onClearNote: () {
              _notesController.clear();
              setState(() {});
            },
          ),
        ],
        const SizedBox(height: 10),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildBottomActions() {
    final sameDateMatches = _sameDateRowIndices();
    final hasSameDateEntries = sameDateMatches.isNotEmpty;
    final isBrowsingExisting =
        hasSameDateEntries && _selectedExistingRowIndex != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasSameDateEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${sameDateMatches.length} entr${sameDateMatches.length == 1 ? 'y' : 'ies'} for this date found.',
                ),
              ),
            Row(
              children: [
                if (hasSameDateEntries) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadPreviousSameDateEntry,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: isBrowsingExisting
                        ? _loadNextSameDateEntry
                        : _saveRow,
                    child: Text(isBrowsingExisting ? 'Next Row' : 'Submit New'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearEditorWindow,
                  tooltip: 'Clear editor',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _headerTitle {
    if (!_isAdvancedMode) {
      if (_hasSimpleSchema) {
        return 'Editor';
      }
      return 'Get Started';
    }
    return _setupDone ? 'Calcrow Daily Editor' : 'Get Started';
  }

  void _handleBack() {
    if (!_isAdvancedMode) {
      if (_hasSimpleSchema) {
        _exitSimpleEditor();
      }
      return;
    }
    if (_setupDone) {
      setState(() {
        _setupDone = false;
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toggleMode() {
    setState(() {
      _isAdvancedMode = !_isAdvancedMode;
      if (_isAdvancedMode) {
        _setupDone = false;
      }
    });
  }

  void _exitSimpleEditor() {
    final oldControllers = _simpleControllers;
    setState(() {
      _simpleImportedFileName = null;
      _simpleImportedPath = null;
      _simpleImportedSheetName = null;
      _simpleImportedFormat = null;
      _simpleCsvDelimiter = ',';
      _simpleHasTypeRow = false;
      _simpleHeaders = const <String>[];
      _simpleValueTypes = const <String>[];
      _simpleReadOnlyColumns = const <bool>[];
      _simpleRows = const <List<String>>[];
      _simpleControllers = const <TextEditingController>[];
      _simpleEditingRowIndex = 0;
      _simpleImportedWorkbook = null;
      _simpleImportedSourceBytes = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
    SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
        .copyWith(clearOnSaveAsIs: true);
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.isAdvancedMode,
    required this.showModeSwitch,
    required this.headerTitle,
    required this.setupDone,
    required this.widgetOptions,
    required this.visibleWidgets,
    required this.onBack,
    required this.onToggleMode,
    required this.onToggleWidget,
  });

  final bool isAdvancedMode;
  final bool showModeSwitch;
  final String headerTitle;
  final bool setupDone;
  final List<_WidgetBlock> widgetOptions;
  final Set<_WidgetBlock> visibleWidgets;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;
  final ValueChanged<_WidgetBlock>? onToggleWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(headerTitle, style: theme.textTheme.titleMedium),
            ),
            if (isAdvancedMode && setupDone)
              PopupMenuButton<_WidgetBlock>(
                tooltip: 'Manage widgets',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: onToggleWidget,
                itemBuilder: (context) => widgetOptions.map((block) {
                  return CheckedPopupMenuItem<_WidgetBlock>(
                    value: block,
                    checked: visibleWidgets.contains(block),
                    child: Text(_labelForWidget(block)),
                  );
                }).toList(),
              ),
            if (isAdvancedMode && setupDone) const SizedBox(width: 6),
            if (showModeSwitch)
              TextButton(
                onPressed: onToggleMode,
                child: Text(isAdvancedMode ? 'Advanced' : 'Simple'),
              ),
            if (showModeSwitch) const SizedBox(width: 6),
            const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person_outline_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  static String _labelForWidget(_WidgetBlock block) {
    switch (block) {
      case _WidgetBlock.rowDefinement:
        return 'Row-Definement';
      case _WidgetBlock.workhours:
        return 'Workhours';
      case _WidgetBlock.smartData:
        return 'Smart Data';
      case _WidgetBlock.wellbeing:
        return 'Wellbeing';
      case _WidgetBlock.notes:
        return 'Notes';
    }
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon),
            ],
          ),
        ),
      ),
    );
  }
}
