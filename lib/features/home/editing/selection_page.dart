import 'dart:async';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saf_util/saf_util.dart';

import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/simple_cloud_document_service.dart';
import 'package:calcrow/core/data/services/simple_local_document_service.dart';
import 'package:calcrow/core/data/services/simple_sheet_persistence_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/simple_type_hint_cache.dart';

import 'simple/create_doc_page.dart';
import 'simple/editing_page.dart';

enum _SimpleSetupAction { open, create }

enum _SimpleCreateDestination { local, cloud }

enum _SimpleLocalCreateTarget { currentSafFolder, pickSafFolder }

enum _SimpleDocumentSource { local, cloud }

class SelectionPage extends StatefulWidget {
  const SelectionPage({super.key});

  @override
  State<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends State<SelectionPage> {
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

  static final SafUtil _safUtil = SafUtil();

  final SimpleSheetPersistenceService _sheetPersistenceService =
      SimpleSheetPersistenceService();

  EditorOpenMode _simpleOpenMode = EditorOpenMode.dateBasedOpenEnd;
  _SimpleSetupAction _simpleSetupAction = _SimpleSetupAction.open;
  _SimpleDocumentSource _simpleDocumentSource = _SimpleDocumentSource.local;
  LocalSimpleDocumentSelection? _selectedLocalDocument;
  String? _simpleImportedFileName;
  String? _simpleImportedPath;
  Uint8List? _simpleImportedSourceBytes;
  bool _rememberLocalDocumentForReopen = false;
  bool _isOpeningDocument = false;
  bool _isChoosingLocalDocument = false;
  bool _isChoosingCloudFile = false;
  Widget? _activeEditor;

  bool get _supportsLocalFileEditing =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  _SimpleDocumentSource get _effectiveSimpleDocumentSource {
    if (!_supportsLocalFileEditing &&
        _simpleDocumentSource == _SimpleDocumentSource.local) {
      return _SimpleDocumentSource.cloud;
    }
    return _simpleDocumentSource;
  }

  bool get _hasRememberedLocalDocument =>
      _rememberLocalDocumentForReopen &&
      (_simpleImportedPath?.trim().isNotEmpty == true ||
          (_simpleImportedSourceBytes?.isNotEmpty ?? false)) &&
      (_simpleImportedFileName?.trim().isNotEmpty == true);

  Future<void> _runWithDocumentOpeningIndicator(
    Future<void> Function() action,
  ) async {
    if (_isOpeningDocument) return;
    setState(() => _isOpeningDocument = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isOpeningDocument = false);
    }
  }

  Future<SimpleSheetData> _parseSimpleSheetData({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    String? mimeType,
  }) async {
    return SimpleSheetFileService.parse(
      bytes: bytes,
      fileName: fileName,
      path: path,
      mimeType: mimeType,
    );
  }

  Future<void> _pushEditor({
    required SimpleSheetData sheetData,
    required EditorDocumentTarget target,
    String? successMessage,
  }) async {
    if (!mounted) return;
    setState(() {
      _activeEditor = EditingPage(
        initialSheetData: sheetData,
        initialDocumentTarget: target,
        initialOpenMode: _simpleOpenMode,
        initialSuccessMessage: successMessage,
        showBackToSelection: true,
        onBackToSelection: _returnToSelection,
      );
    });
  }

  void _returnToSelection() {
    if (!mounted) return;
    setState(() => _activeEditor = null);
  }

  Future<void> _chooseLocalDocumentForSimple() async {
    if (!_supportsLocalFileEditing) return;
    if (_isChoosingLocalDocument || _isOpeningDocument) return;
    setState(() {
      _simpleSetupAction = _SimpleSetupAction.open;
      _simpleDocumentSource = _SimpleDocumentSource.local;
      _isChoosingLocalDocument = true;
    });
    try {
      final selection = await ServiceLocator.simpleLocalDocumentService
          .pickDocumentForSimpleEditor(
            acceptedTypeGroups: _localDocumentTypeGroups,
            readXFilePath: _readXFilePath,
          );
      if (!mounted || selection == null) return;
      setState(() => _cacheSelectedLocalDocument(selection));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected local document ${selection.fileName}.'),
        ),
      );
    } on LocalSimpleDocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on UnsupportedError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '$error')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select document: $error')),
      );
    } finally {
      if (mounted) setState(() => _isChoosingLocalDocument = false);
    }
  }

  void _cacheSelectedLocalDocument(LocalSimpleDocumentSelection selection) {
    _selectedLocalDocument = selection;
    _simpleImportedFileName = selection.fileName;
    _simpleImportedPath = selection.existingPath;
    _simpleImportedSourceBytes = selection.bytes;
    _rememberLocalDocumentForReopen = true;
  }

  Future<void> _openOrChooseLocalDocumentForSimple() async {
    if (!_supportsLocalFileEditing) return;
    if (!_hasRememberedLocalDocument) {
      await _importLocalDocumentForSimple();
      return;
    }

    await _runWithDocumentOpeningIndicator(() async {
      try {
        final result = await ServiceLocator.simpleLocalDocumentService
            .reopenDocumentForSimpleEditor(
              fileName: _simpleImportedFileName!,
              existingPath: _simpleImportedPath,
              cachedBytes: _simpleImportedSourceBytes,
              parseSheetData: _parseSimpleSheetData,
            );
        if (!mounted) return;
        await _pushEditor(
          sheetData: result.sheetData,
          target: LocalEditorDocumentTarget(existingPath: result.existingPath),
          successMessage: 'Opened local document ${result.sheetData.fileName}.',
        );
      } on LocalSimpleDocumentException {
        if (!mounted) return;
        setState(() => _rememberLocalDocumentForReopen = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not reopen the remembered local file. Choose it again.',
            ),
          ),
        );
        await _importLocalDocumentForSimple();
      } catch (_) {
        if (!mounted) return;
        setState(() => _rememberLocalDocumentForReopen = false);
        await _importLocalDocumentForSimple();
      }
    });
  }

  Future<void> _importLocalDocumentForSimple() async {
    await _runWithDocumentOpeningIndicator(() async {
      try {
        var selection = _selectedLocalDocument;
        if (selection == null) {
          selection = await ServiceLocator.simpleLocalDocumentService
              .pickDocumentForSimpleEditor(
                acceptedTypeGroups: _localDocumentTypeGroups,
                readXFilePath: _readXFilePath,
              );
          if (!mounted || selection == null) return;
          _cacheSelectedLocalDocument(selection);
        }
        final result = await ServiceLocator.simpleLocalDocumentService
            .openSelectedDocumentForSimpleEditor(
              selection: selection,
              parseSheetData: _parseSimpleSheetData,
            );
        if (!mounted) return;

        final sheetData = result.sheetData;
        final sourceLabel = switch (sheetData.format) {
          SimpleFileFormat.csv =>
            'Loaded ${sheetData.fileName} (${sheetData.rows.length} entries).',
          SimpleFileFormat.xlsx =>
            'Loaded ${sheetData.fileName} (${sheetData.rows.length} entries) from tab ${sheetData.xlsxSheetName ?? 'default'}.${result.hasSafTarget ? ' SAF target ready.' : ' SAF target not detected.'}',
          SimpleFileFormat.ods =>
            'Loaded ${sheetData.fileName} (${sheetData.rows.length} entries) from sheet ${sheetData.xlsxSheetName ?? 'default'}.${result.hasSafTarget ? ' SAF target ready.' : ' SAF target not detected.'}',
          SimpleFileFormat.gsheet =>
            'Loaded Google Sheet ${sheetData.fileName} (${sheetData.rows.length} entries) from tab ${sheetData.xlsxSheetName ?? 'default'}.',
        };
        await _pushEditor(
          sheetData: sheetData,
          target: LocalEditorDocumentTarget(existingPath: result.existingPath),
          successMessage: sourceLabel,
        );
      } on LocalSimpleDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
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

  Future<bool> _openCloudDocument({required CloudFileMetadata file}) async {
    var opened = false;
    await _runWithDocumentOpeningIndicator(() async {
      try {
        final result = await ServiceLocator.simpleCloudDocumentService
            .openDocument(file: file, parseSheetData: _parseSimpleSheetData);
        if (!mounted) return;
        opened = true;
        await _pushEditor(
          sheetData: result.sheetData,
          target: CloudEditorDocumentTarget(
            provider: result.file.provider,
            fileId: result.file.id,
            fileName: result.file.name,
            mimeType: result.file.mimeType,
          ),
          successMessage:
              'Opened ${ServiceLocator.simpleCloudDocumentService.providerLabel(result.file.provider)} document ${result.file.name}.',
        );
      } on CloudSimpleDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } on UnsupportedError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message ?? '$error')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open cloud document: $error')),
        );
      }
    });
    return opened;
  }

  Future<void> _openOrChooseCloudSyncFile() async {
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      await _chooseCloudSyncFile();
      return;
    }

    try {
      final settings = await ServiceLocator.userRepository.getUserSettings(
        session.uid,
      );
      final selectedFile = ServiceLocator.simpleCloudDocumentService
          .selectedSyncFileFromSettings(settings);
      if (selectedFile == null) {
        await _chooseCloudSyncFile();
        return;
      }

      final opened = await _openCloudDocument(file: selectedFile);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open saved sync file. Choose another one.',
            ),
          ),
        );
        await _chooseCloudSyncFile();
      }
    } catch (_) {
      await _chooseCloudSyncFile();
    }
  }

  Future<void> _chooseCloudSyncFile() async {
    if (_isChoosingCloudFile) return;

    final messenger = ScaffoldMessenger.of(context);
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Connect a cloud provider in Settings first.'),
        ),
      );
      return;
    }

    setState(() {
      _simpleSetupAction = _SimpleSetupAction.open;
      _isChoosingCloudFile = true;
    });
    try {
      final settings = await ServiceLocator.userRepository.getUserSettings(
        session.uid,
      );
      final provider = ServiceLocator.simpleCloudDocumentService
          .activeProviderFromSettings(settings);
      if (provider == null) {
        throw const CloudSimpleDocumentException(
          'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.',
        );
      }

      if (!mounted) return;
      final selection = await showDialog<_CloudFileSelection>(
        context: context,
        builder: (context) => _CloudFilePickerDialog(
          provider: provider,
          selectedFileId: ServiceLocator.simpleCloudDocumentService
              .selectedSyncFileFromSettings(settings)
              ?.id,
        ),
      );
      if (selection == null) return;

      if (selection.createNew) {
        final createdFile = await ServiceLocator.simpleCloudDocumentService
            .createSyncFile(parentFolderId: selection.folderId);
        await ServiceLocator.simpleCloudDocumentService.setSelectedSyncFile(
          file: createdFile,
        );
        await _openCloudDocument(file: createdFile);
        return;
      }

      final selectedFile = selection.file;
      if (selectedFile == null) {
        await ServiceLocator.simpleCloudDocumentService.clearSelectedSyncFile();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${ServiceLocator.simpleCloudDocumentService.providerLabel(provider)} sync file cleared.',
            ),
          ),
        );
        return;
      }

      await ServiceLocator.simpleCloudDocumentService.setSelectedSyncFile(
        file: selectedFile,
      );
      await _openCloudDocument(file: selectedFile);
    } on CloudSimpleDocumentException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isChoosingCloudFile = false);
    }
  }

  Future<String> _cloudDocumentSubtitle() async {
    return ServiceLocator.simpleCloudDocumentService.buildSubtitle();
  }

  Future<_SimpleDocumentPromptData> _simpleDocumentPromptData() async {
    if (!ServiceLocator.isSetup) {
      return _SimpleDocumentPromptData(
        localSubtitle: _defaultLocalDocumentSubtitle(),
        cloudSubtitle: 'Connect a cloud provider in Settings first.',
        hasSelectedCloudFile: false,
        hasRememberedLocalFile: _hasRememberedLocalDocument,
      );
    }
    final session = ServiceLocator.authService.currentSession;
    UserSettingsData? settings;
    if (session != null) {
      settings = await ServiceLocator.userRepository.getUserSettings(
        session.uid,
      );
    }
    final selectedCloudFile = settings == null
        ? null
        : ServiceLocator.simpleCloudDocumentService
              .selectedSyncFileFromSettings(settings);
    final cloudSubtitle = settings == null
        ? 'Connect a cloud provider in Settings first.'
        : await _cloudDocumentSubtitle();
    return _SimpleDocumentPromptData(
      localSubtitle: _hasRememberedLocalDocument
          ? 'Selected local file: $_simpleImportedFileName'
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'Open a CSV, XLSX, or ODS document'
          : 'Open CSV, XLSX, or ODS. Calcrow detects the file type automatically.',
      cloudSubtitle: cloudSubtitle,
      hasSelectedCloudFile: selectedCloudFile != null,
      hasRememberedLocalFile: _hasRememberedLocalDocument,
    );
  }

  String _defaultLocalDocumentSubtitle() {
    if (_hasRememberedLocalDocument) {
      return 'Selected local file: $_simpleImportedFileName';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'Open a CSV, XLSX, or ODS document';
    }
    return 'Open CSV, XLSX, or ODS. Calcrow detects the file type automatically.';
  }

  Future<void> _openSelectedSimpleDocument() async {
    setState(() {
      _simpleOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _simpleSetupAction = _SimpleSetupAction.open;
    });
    switch (_effectiveSimpleDocumentSource) {
      case _SimpleDocumentSource.local:
        await _openOrChooseLocalDocumentForSimple();
      case _SimpleDocumentSource.cloud:
        await _openOrChooseCloudSyncFile();
    }
  }

  Future<void> _createSimpleDocument() async {
    setState(() {
      _simpleOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _simpleSetupAction = _SimpleSetupAction.create;
    });
    final draft = await Navigator.of(context).push<SimpleDocumentDraft>(
      MaterialPageRoute(builder: (context) => const CreateDocPage()),
    );
    if (!mounted) return;
    if (draft == null) {
      setState(() => _simpleSetupAction = _SimpleSetupAction.open);
      return;
    }
    await _createSimpleDocumentFromDraft(draft);
  }

  Future<void> _createSimpleDocumentFromDraft(SimpleDocumentDraft draft) async {
    setState(() {
      _simpleOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _simpleSetupAction = _SimpleSetupAction.create;
    });
    final sheetData = SimpleSheetData(
      fileName: draft.fileName,
      path: null,
      format: draft.format,
      headers: draft.headers,
      valueTypes: draft.valueTypes,
      readOnlyColumns: List<bool>.filled(draft.headers.length, false),
      rows: const <List<String>>[],
      csvDelimiter: ',',
      hasTypeRow: false,
      headerRowIndex: 0,
      startColumnIndex: 0,
      xlsxSheetName: null,
      workbook: draft.format == SimpleFileFormat.xlsx
          ? excel_pkg.Excel.createExcel()
          : null,
    );
    final destination = await showDialog<_SimpleCreateDestination>(
      context: context,
      builder: (context) =>
          _CreateDestinationDialog(showLocal: _supportsLocalFileEditing),
    );
    if (!mounted) return;
    if (destination == null) {
      setState(() => _simpleSetupAction = _SimpleSetupAction.open);
      return;
    }
    switch (destination) {
      case _SimpleCreateDestination.local:
        await _createLocalSimpleDocument(sheetData);
      case _SimpleCreateDestination.cloud:
        await _createCloudSimpleDocument(sheetData);
    }
  }

  Future<void> _createLocalSimpleDocument(SimpleSheetData sheetData) async {
    try {
      final bytes = SimpleSheetFileService.buildBytes(sheetData);
      final preferredSafTreeUri = await _safTreeUriForNewLocalDocument();
      if (!mounted) return;
      final result = await _sheetPersistenceService.persistBytes(
        SimplePersistRequest(
          bytes: bytes,
          fileName: sheetData.fileName,
          typeGroup: _typeGroupForFormat(sheetData.format),
          mimeType: _mimeTypeForFormat(sheetData.format),
          confirmButtonText: _createConfirmButtonTextForFormat(
            sheetData.format,
          ),
          preferredSafTreeUri: preferredSafTreeUri,
          mode: preferredSafTreeUri == null
              ? SimplePersistMode.asIs
              : SimplePersistMode.safPreferred,
        ),
      );
      if (!mounted) return;

      await SimpleTypeHintCache.rememberCsvTypes(
        fileName: result.resolvedFileName,
        path: result.savedPath,
        valueTypes: sheetData.valueTypes,
      );

      await _pushEditor(
        sheetData: _copySimpleSheetData(
          sheetData,
          fileName: result.resolvedFileName,
          path: result.savedPath,
          sourceBytes: bytes,
        ),
        target: LocalEditorDocumentTarget(existingPath: result.savedPath),
        successMessage: 'Created ${result.resolvedFileName}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _simpleSetupAction = _SimpleSetupAction.open);
      if (error is StateError && error.message == 'Save canceled.') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create document canceled.')),
        );
        return;
      }
      if (error is StateError &&
          error.message == 'Could not acquire a writable SAF folder URI.') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not acquire a writable SAF folder URI.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create local document: $error')),
      );
    }
  }

  Future<void> _createCloudSimpleDocument(SimpleSheetData sheetData) async {
    final folder = await _pickCloudCreateFolder();
    if (!mounted || folder == null) return;

    await _runWithDocumentOpeningIndicator(() async {
      try {
        final bytes = SimpleSheetFileService.buildBytes(sheetData);
        final metadata = await ServiceLocator.simpleCloudDocumentService
            .createDocument(
              fileName: sheetData.fileName,
              bytes: bytes,
              mimeType: _mimeTypeForFormat(sheetData.format),
              parentFolderId: folder.id,
            );
        await ServiceLocator.simpleCloudDocumentService.setSelectedSyncFile(
          file: metadata,
        );
        if (!mounted) return;

        await SimpleTypeHintCache.rememberCsvTypes(
          fileName: metadata.name,
          path: metadata.id,
          valueTypes: sheetData.valueTypes,
        );

        await _pushEditor(
          sheetData: _copySimpleSheetData(
            sheetData,
            fileName: metadata.name,
            path: null,
            sourceBytes: bytes,
          ),
          target: CloudEditorDocumentTarget(
            provider: metadata.provider,
            fileId: metadata.id,
            fileName: metadata.name,
            mimeType: metadata.mimeType,
          ),
          successMessage: 'Created ${metadata.name} in ${folder.name}.',
        );
      } on CloudSimpleDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create cloud document: $error')),
        );
      }
    });
  }

  Future<_CloudFolderPickResult?> _pickCloudCreateFolder() async {
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect a cloud provider in Settings first.'),
        ),
      );
      return null;
    }

    try {
      final settings = await ServiceLocator.userRepository.getUserSettings(
        session.uid,
      );
      if (!mounted) return null;
      final provider = ServiceLocator.simpleCloudDocumentService
          .activeProviderFromSettings(settings);
      if (provider == null) {
        throw const CloudSimpleDocumentException(
          'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.',
        );
      }
      return showDialog<_CloudFolderPickResult>(
        context: context,
        builder: (context) => _CloudFolderPickerDialog(provider: provider),
      );
    } on CloudSimpleDocumentException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }

  Future<void> _setRecentSimpleOpeningConfiguration() async {
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to use recent opening configurations.'),
        ),
      );
      return;
    }

    final settings = await ServiceLocator.userRepository.getUserSettings(
      session.uid,
    );
    if (!mounted) return;
    final configs = settings.simpleRecentOpenConfigs;
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recent opening configurations saved yet.'),
        ),
      );
      return;
    }

    final selected = await showDialog<SimpleRecentOpenConfig>(
      context: context,
      builder: (dialogContext) => _SimpleRecentConfigDialog(configs: configs),
    );
    if (!mounted || selected == null) return;
    await _applySimpleRecentOpenConfig(selected);
  }

  Future<void> _applySimpleRecentOpenConfig(
    SimpleRecentOpenConfig config,
  ) async {
    final openMode = _simpleOpenModeFromName(config.openMode);
    final source = _simpleDocumentSourceFromRecent(config.source);
    setState(() {
      _simpleOpenMode = openMode;
      _simpleDocumentSource = source;
      if (source == _SimpleDocumentSource.local) {
        _simpleImportedFileName = config.fileName;
        _simpleImportedPath = config.path;
        _simpleImportedSourceBytes = null;
        _selectedLocalDocument = null;
        _rememberLocalDocumentForReopen = config.path?.isNotEmpty == true;
      } else {
        _rememberLocalDocumentForReopen = false;
        _simpleImportedPath = null;
        _simpleImportedSourceBytes = null;
        _selectedLocalDocument = null;
      }
    });

    if (source == _SimpleDocumentSource.cloud && config.fileId != null) {
      final session = ServiceLocator.authService.currentSession;
      final provider = config.source == SimpleRecentDocumentSource.googleDrive
          ? CloudSyncProvider.googleDrive
          : CloudSyncProvider.webDav;
      if (session != null) {
        await ServiceLocator.userRepository.setCloudSyncProvider(
          uid: session.uid,
          provider: provider,
        );
      }
      await ServiceLocator.simpleCloudDocumentService.setSelectedSyncFile(
        file: CloudFileMetadata(
          provider: provider,
          id: config.fileId!,
          name: config.fileName,
          mimeType: config.mimeType ?? 'text/csv',
        ),
      );
    }
  }

  EditorOpenMode _simpleOpenModeFromName(String name) {
    return EditorOpenMode.values.firstWhere(
      (candidate) => candidate.name == name,
      orElse: () => EditorOpenMode.dateBased,
    );
  }

  _SimpleDocumentSource _simpleDocumentSourceFromRecent(
    SimpleRecentDocumentSource source,
  ) {
    return switch (source) {
      SimpleRecentDocumentSource.local => _SimpleDocumentSource.local,
      SimpleRecentDocumentSource.googleDrive ||
      SimpleRecentDocumentSource.webDav => _SimpleDocumentSource.cloud,
    };
  }

  String _simpleOpenModeLabel(EditorOpenMode mode) {
    return switch (mode) {
      EditorOpenMode.dateBased => 'Diary',
      EditorOpenMode.dateBasedOpenEnd => 'Logbook',
      EditorOpenMode.textBased => 'Namelist',
    };
  }

  String _simpleOpenModeDescription(EditorOpenMode mode) {
    return switch (mode) {
      EditorOpenMode.dateBased =>
        'Open the existing row for today and keep one entry per day.',
      EditorOpenMode.dateBasedOpenEnd =>
        'Open today if it exists, otherwise start a new row for today.',
      EditorOpenMode.textBased =>
        'Choose an existing named entry from a text column and edit that row.',
    };
  }

  String _simpleOpenModeTableHint(EditorOpenMode mode) {
    return switch (mode) {
      EditorOpenMode.dateBased =>
        'Your table needs a date column with one prepared row per day.',
      EditorOpenMode.dateBasedOpenEnd =>
        'Your table needs a date column; Calcrow can add today as a new row.',
      EditorOpenMode.textBased =>
        'Your table needs an editable text column with the entry names.',
    };
  }

  void _showSimpleOpenModeInfo(EditorOpenMode selectedMode) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);
        final modes = EditorOpenMode.values;

        return AlertDialog(
          title: const Text('Opening modes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final mode in modes) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _simpleOpenModeLabel(mode),
                          style: dialogTheme.textTheme.titleSmall,
                        ),
                      ),
                      if (mode == selectedMode)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: dialogTheme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_simpleOpenModeDescription(mode)),
                  const SizedBox(height: 4),
                  Text(
                    _simpleOpenModeTableHint(mode),
                    style: dialogTheme.textTheme.bodySmall?.copyWith(
                      color: dialogTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (mode != modes.last) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _forgetRememberedLocalDocument() {
    setState(() {
      _rememberLocalDocumentForReopen = false;
      _simpleImportedPath = null;
      _simpleImportedSourceBytes = null;
      _selectedLocalDocument = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Remembered local file cleared. Pick a file again anytime.',
        ),
      ),
    );
  }

  Future<void> _clearSelectedCloudSyncFile() async {
    try {
      await ServiceLocator.simpleCloudDocumentService.clearSelectedSyncFile();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remembered cloud sync file cleared.')),
      );
    } on CloudSimpleDocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<String?> _safTreeUriForNewLocalDocument() async {
    final preferredSafTreeUri = await _preferredSafTreeUri();
    if (!mounted) return preferredSafTreeUri;
    if (!_isAndroidPlatform ||
        preferredSafTreeUri == null ||
        preferredSafTreeUri.isEmpty) {
      return preferredSafTreeUri;
    }
    final target = await showDialog<_SimpleLocalCreateTarget>(
      context: context,
      builder: (context) => const _LocalCreateTargetDialog(),
    );
    if (!mounted) return null;
    switch (target) {
      case null:
        throw StateError('Save canceled.');
      case _SimpleLocalCreateTarget.currentSafFolder:
        return preferredSafTreeUri;
      case _SimpleLocalCreateTarget.pickSafFolder:
        return _pickSafTreeUriForNewDocument();
    }
  }

  Future<String?> _pickSafTreeUriForNewDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_isAndroidPlatform) {
      messenger.showSnackBar(
        const SnackBar(content: Text('SAF folder setup is Android-only.')),
      );
      return null;
    }
    final pickedDirectory = await _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    final treeUri = pickedDirectory?.uri.trim();
    if (treeUri == null || treeUri.isEmpty) {
      throw StateError('Save canceled.');
    }
    final normalizedTreeUri = treeUri.trim();
    if (!_sheetPersistenceService.canUseSafTreeUri(normalizedTreeUri)) {
      throw StateError('Could not acquire a writable SAF folder URI.');
    }
    return normalizedTreeUri;
  }

  Future<String?> _preferredSafTreeUri() async {
    if (!ServiceLocator.isSetup) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    final session = ServiceLocator.authService.currentSession;
    if (session == null) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    final settings = await (() async {
      try {
        return await ServiceLocator.userRepository.getUserSettings(session.uid);
      } catch (_) {
        return null;
      }
    })();
    if (settings == null) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    final uri = settings.safTreeUri;
    if (uri == null || uri.isEmpty) {
      return SimpleSheetPersistenceService.runtimeSafTreeUri;
    }
    return uri;
  }

  SimpleSheetData _copySimpleSheetData(
    SimpleSheetData data, {
    required String fileName,
    required String? path,
    required Uint8List? sourceBytes,
  }) {
    return SimpleSheetData(
      fileName: fileName,
      path: path,
      format: data.format,
      headers: data.headers,
      valueTypes: data.valueTypes,
      readOnlyColumns: data.readOnlyColumns,
      rows: data.rows,
      pendingTypeSelectionColumns: data.pendingTypeSelectionColumns,
      csvDelimiter: data.csvDelimiter,
      hasTypeRow: data.hasTypeRow,
      headerRowIndex: data.headerRowIndex,
      startColumnIndex: data.startColumnIndex,
      xlsxSheetName: data.xlsxSheetName,
      workbook: data.workbook,
      sourceBytes: sourceBytes,
    );
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

  String _mimeTypeForFormat(SimpleFileFormat format) {
    return SimpleSheetFileService.mimeTypeForFormat(format);
  }

  XTypeGroup _typeGroupForFormat(SimpleFileFormat format) {
    switch (format) {
      case SimpleFileFormat.csv:
        return _csvTypeGroup;
      case SimpleFileFormat.xlsx:
      case SimpleFileFormat.gsheet:
        return _xlsxTypeGroup;
      case SimpleFileFormat.ods:
        return _odsTypeGroup;
    }
  }

  String _createConfirmButtonTextForFormat(SimpleFileFormat format) {
    switch (format) {
      case SimpleFileFormat.csv:
        return 'Create CSV';
      case SimpleFileFormat.xlsx:
      case SimpleFileFormat.gsheet:
        return 'Create XLSX';
      case SimpleFileFormat.ods:
        return 'Create ODS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEditor = _activeEditor;
    if (activeEditor != null) {
      return activeEditor;
    }

    final theme = Theme.of(context);
    final isCreateMode = _simpleSetupAction == _SimpleSetupAction.create;
    final setupOpenMode = isCreateMode
        ? EditorOpenMode.dateBasedOpenEnd
        : _simpleOpenMode;
    final openModeItems = isCreateMode
        ? <DropdownMenuItem<EditorOpenMode>>[
            DropdownMenuItem(
              value: EditorOpenMode.dateBasedOpenEnd,
              child: Text(
                _simpleOpenModeLabel(EditorOpenMode.dateBasedOpenEnd),
              ),
            ),
          ]
        : EditorOpenMode.values
              .map(
                (mode) => DropdownMenuItem<EditorOpenMode>(
                  value: mode,
                  child: Text(_simpleOpenModeLabel(mode)),
                ),
              )
              .toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Get Started',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person_outline_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Opening Mode',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Explain opening modes',
                          onPressed: () =>
                              _showSimpleOpenModeInfo(setupOpenMode),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EditorOpenMode>(
                      initialValue: setupOpenMode,
                      decoration: const InputDecoration(
                        labelText: 'How to open the sheet',
                      ),
                      items: openModeItems,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _simpleOpenMode = isCreateMode
                              ? EditorOpenMode.dateBasedOpenEnd
                              : value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<_SimpleDocumentPromptData>(
              future: _simpleDocumentPromptData(),
              builder: (context, snapshot) {
                final data =
                    snapshot.data ??
                    const _SimpleDocumentPromptData(
                      localSubtitle: 'Open CSV, XLSX, or ODS.',
                      cloudSubtitle:
                          'Choose or create the active cloud sync file.',
                      hasSelectedCloudFile: false,
                      hasRememberedLocalFile: false,
                    );
                return Column(
                  children: [
                    _ChooseDocumentCard(
                      selected: _simpleSetupAction == _SimpleSetupAction.open,
                      selectedSource: _effectiveSimpleDocumentSource,
                      localSubtitle: data.localSubtitle,
                      cloudSubtitle: data.cloudSubtitle,
                      isChoosingLocalDocument: _isChoosingLocalDocument,
                      isChoosingCloudFile: _isChoosingCloudFile,
                      hasRememberedLocalFile: data.hasRememberedLocalFile,
                      hasSelectedCloudFile: data.hasSelectedCloudFile,
                      showLocalDocument: _supportsLocalFileEditing,
                      onSelected: () => setState(
                        () => _simpleSetupAction = _SimpleSetupAction.open,
                      ),
                      onSourceChanged: (source) {
                        setState(() {
                          _simpleSetupAction = _SimpleSetupAction.open;
                          _simpleDocumentSource = source;
                        });
                      },
                      onChooseLocal: data.hasRememberedLocalFile
                          ? () => setState(() {
                              _simpleSetupAction = _SimpleSetupAction.open;
                              _simpleDocumentSource =
                                  _SimpleDocumentSource.local;
                            })
                          : _chooseLocalDocumentForSimple,
                      onClearLocal: _forgetRememberedLocalDocument,
                      onClearCloud: _clearSelectedCloudSyncFile,
                    ),
                    const SizedBox(height: 14),
                    _CreateDocumentCard(
                      selected: _simpleSetupAction == _SimpleSetupAction.create,
                      onSelected: () => setState(() {
                        _simpleSetupAction = _SimpleSetupAction.create;
                        _simpleOpenMode = EditorOpenMode.dateBasedOpenEnd;
                      }),
                      onCreate: _createSimpleDocument,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _setRecentSimpleOpeningConfiguration,
                        child: const Text('Set Recent'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _isOpeningDocument ||
                                _isChoosingCloudFile ||
                                (_simpleSetupAction ==
                                        _SimpleSetupAction.open &&
                                    _effectiveSimpleDocumentSource ==
                                        _SimpleDocumentSource.local &&
                                    !_hasRememberedLocalDocument)
                            ? null
                            : _simpleSetupAction == _SimpleSetupAction.open
                            ? _openSelectedSimpleDocument
                            : _createSimpleDocument,
                        child: Text(
                          _simpleSetupAction == _SimpleSetupAction.open
                              ? 'Open'
                              : 'Create',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_isOpeningDocument)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.82),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _SimpleDocumentPromptData {
  const _SimpleDocumentPromptData({
    required this.localSubtitle,
    required this.cloudSubtitle,
    required this.hasSelectedCloudFile,
    required this.hasRememberedLocalFile,
  });

  final String localSubtitle;
  final String cloudSubtitle;
  final bool hasSelectedCloudFile;
  final bool hasRememberedLocalFile;
}

class _SimpleRecentConfigDialog extends StatelessWidget {
  const _SimpleRecentConfigDialog({required this.configs});

  final List<SimpleRecentOpenConfig> configs;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set recent'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: configs
              .map(
                (config) => ListTile(
                  leading: Icon(_iconForSource(config.source)),
                  title: Text(config.fileName),
                  subtitle: Text(
                    '${_sourceLabel(config.source)} - ${_openModeLabel(config.openMode)}',
                  ),
                  onTap: () => Navigator.of(context).pop(config),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static IconData _iconForSource(SimpleRecentDocumentSource source) {
    return switch (source) {
      SimpleRecentDocumentSource.local => Icons.folder_open_rounded,
      SimpleRecentDocumentSource.googleDrive ||
      SimpleRecentDocumentSource.webDav => Icons.cloud_outlined,
    };
  }

  static String _sourceLabel(SimpleRecentDocumentSource source) {
    return switch (source) {
      SimpleRecentDocumentSource.local => 'Local',
      SimpleRecentDocumentSource.googleDrive => 'Google Drive',
      SimpleRecentDocumentSource.webDav => 'WebDAV',
    };
  }

  static String _openModeLabel(String openMode) {
    return switch (openMode) {
      'dateBased' => 'Diary',
      'dateBasedOpenEnd' => 'Logbook',
      'textBased' => 'Namelist',
      _ => 'Opening mode',
    };
  }
}

class _ChooseDocumentCard extends StatelessWidget {
  const _ChooseDocumentCard({
    required this.selected,
    required this.selectedSource,
    required this.localSubtitle,
    required this.cloudSubtitle,
    required this.isChoosingLocalDocument,
    required this.isChoosingCloudFile,
    required this.hasRememberedLocalFile,
    required this.hasSelectedCloudFile,
    required this.showLocalDocument,
    required this.onSelected,
    required this.onSourceChanged,
    required this.onChooseLocal,
    required this.onClearLocal,
    required this.onClearCloud,
  });

  final bool selected;
  final _SimpleDocumentSource selectedSource;
  final String localSubtitle;
  final String cloudSubtitle;
  final bool isChoosingLocalDocument;
  final bool isChoosingCloudFile;
  final bool hasRememberedLocalFile;
  final bool hasSelectedCloudFile;
  final bool showLocalDocument;
  final VoidCallback onSelected;
  final ValueChanged<_SimpleDocumentSource> onSourceChanged;
  final VoidCallback onChooseLocal;
  final VoidCallback onClearLocal;
  final VoidCallback onClearCloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text('Choose Document', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (showLocalDocument)
                _DocumentSourceTile(
                  selected: selectedSource == _SimpleDocumentSource.local,
                  title: 'Local document',
                  subtitle: localSubtitle,
                  icon: Icons.folder_open_rounded,
                  trailing: isChoosingLocalDocument
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: onChooseLocal,
                  clearAction: hasRememberedLocalFile
                      ? _InlineSetupAction(
                          icon: Icons.clear,
                          tooltip: 'Clear remembered local file',
                          onTap: onClearLocal,
                        )
                      : null,
                ),
              _DocumentSourceTile(
                selected: selectedSource == _SimpleDocumentSource.cloud,
                title: 'Cloud document',
                subtitle: cloudSubtitle,
                icon: Icons.cloud_outlined,
                trailing: isChoosingCloudFile
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () => onSourceChanged(_SimpleDocumentSource.cloud),
                clearAction: hasSelectedCloudFile
                    ? _InlineSetupAction(
                        icon: Icons.clear,
                        tooltip: 'Clear remembered cloud file',
                        onTap: onClearCloud,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateDocumentCard extends StatelessWidget {
  const _CreateDocumentCard({
    required this.selected,
    required this.onSelected,
    required this.onCreate,
  });

  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 8),
                  Text('Create Document', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              _DocumentSourceTile(
                selected: selected,
                title: 'Create New',
                subtitle: 'Define columns and field types for a fresh sheet.',
                icon: Icons.add_circle_outline_rounded,
                onTap: onCreate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentSourceTile extends StatelessWidget {
  const _DocumentSourceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.clearAction,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? clearAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.check_circle_rounded : icon),
      title: Text(title),
      subtitle: Row(
        children: [
          if (clearAction != null) ...[clearAction!, const SizedBox(width: 8)],
          Expanded(child: Text(subtitle)),
        ],
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: selected ? theme.colorScheme.primary : null,
          ),
      onTap: onTap,
    );
  }
}

class _CreateDestinationDialog extends StatelessWidget {
  const _CreateDestinationDialog({required this.showLocal});

  final bool showLocal;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save New Document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLocal)
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Local'),
              subtitle: const Text('Choose a save location on this device.'),
              onTap: () =>
                  Navigator.of(context).pop(_SimpleCreateDestination.local),
            ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Cloud'),
            subtitle: const Text('Choose a Google Drive or WebDAV folder.'),
            onTap: () =>
                Navigator.of(context).pop(_SimpleCreateDestination.cloud),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _LocalCreateTargetDialog extends StatelessWidget {
  const _LocalCreateTargetDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose SAF Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Use current SAF folder'),
            subtitle: const Text(
              'Save into the folder configured in Settings.',
            ),
            onTap: () => Navigator.of(
              context,
            ).pop(_SimpleLocalCreateTarget.currentSafFolder),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Pick SAF folder'),
            subtitle: const Text('Choose a writable Android folder.'),
            onTap: () => Navigator.of(
              context,
            ).pop(_SimpleLocalCreateTarget.pickSafFolder),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CloudFileSelection {
  const _CloudFileSelection._({
    this.file,
    this.createNew = false,
    this.folderId,
  });

  const _CloudFileSelection.pick(CloudFileMetadata file) : this._(file: file);

  const _CloudFileSelection.clear() : this._();

  const _CloudFileSelection.createNew({String? folderId})
    : this._(createNew: true, folderId: folderId);

  final CloudFileMetadata? file;
  final bool createNew;
  final String? folderId;
}

class _CloudFolderNode {
  const _CloudFolderNode({required this.id, required this.name});

  final String? id;
  final String name;
}

class _CloudFolderPickResult {
  const _CloudFolderPickResult({required this.id, required this.name});

  final String? id;
  final String name;
}

class _CloudFolderPickerDialog extends StatefulWidget {
  const _CloudFolderPickerDialog({required this.provider});

  final CloudSyncProvider provider;

  @override
  State<_CloudFolderPickerDialog> createState() =>
      _CloudFolderPickerDialogState();
}

class _CloudFolderPickerDialogState extends State<_CloudFolderPickerDialog> {
  List<CloudBrowserEntry> _entries = const <CloudBrowserEntry>[];
  late List<_CloudFolderNode> _folderStack = <_CloudFolderNode>[
    _CloudFolderNode(
      id: null,
      name: widget.provider == CloudSyncProvider.googleDrive
          ? 'My Drive'
          : 'WebDAV root',
    ),
  ];
  bool _isLoading = true;
  String? _errorText;

  String? get _currentFolderId => _folderStack.last.id;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final entries = await ServiceLocator.simpleCloudDocumentService
          .listFolderEntries(folderId: _currentFolderId);
      if (!mounted) return;
      setState(() {
        _entries = entries.where((entry) => entry.isFolder).toList();
      });
    } on CloudSimpleDocumentException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFolder(CloudBrowserEntry entry) {
    setState(() {
      _folderStack = <_CloudFolderNode>[
        ..._folderStack,
        _CloudFolderNode(id: entry.id, name: entry.name),
      ];
    });
    unawaited(_loadFolder());
  }

  void _goUp() {
    if (_folderStack.length <= 1) return;
    setState(() {
      _folderStack = _folderStack.sublist(0, _folderStack.length - 1);
    });
    unawaited(_loadFolder());
  }

  void _useCurrentFolder() {
    Navigator.of(context).pop(
      _CloudFolderPickResult(
        id: _currentFolderId,
        name: _folderStack.last.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderLabel = _folderStack.map((node) => node.name).join(' / ');
    return AlertDialog(
      title: const Text('Choose Folder'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _folderStack.length > 1 ? _goUp : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Up one folder',
                ),
                Expanded(
                  child: Text(
                    folderLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              )
            else if (_errorText != null)
              SelectableText(_errorText!)
            else if (_entries.isEmpty)
              const Text('This folder has no subfolders.'),
            if (!_isLoading && _errorText == null && _entries.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _entries
                      .map(
                        (entry) => ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(entry.name),
                          subtitle: const Text('Folder'),
                          onTap: () => _openFolder(entry),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading || _errorText != null
              ? null
              : _useCurrentFolder,
          child: const Text('Use This Folder'),
        ),
      ],
    );
  }
}

class _CloudFilePickerDialog extends StatefulWidget {
  const _CloudFilePickerDialog({
    required this.provider,
    required this.selectedFileId,
  });

  final CloudSyncProvider provider;
  final String? selectedFileId;

  @override
  State<_CloudFilePickerDialog> createState() => _CloudFilePickerDialogState();
}

class _CloudFilePickerDialogState extends State<_CloudFilePickerDialog> {
  List<CloudBrowserEntry> _entries = const <CloudBrowserEntry>[];
  late List<_CloudFolderNode> _folderStack = <_CloudFolderNode>[
    _CloudFolderNode(
      id: null,
      name: widget.provider == CloudSyncProvider.googleDrive
          ? 'My Drive'
          : 'WebDAV root',
    ),
  ];
  bool _isLoading = true;
  String? _errorText;

  String? get _currentFolderId => _folderStack.last.id;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final entries = await ServiceLocator.simpleCloudDocumentService
          .listFolderEntries(folderId: _currentFolderId);
      if (!mounted) return;
      setState(() => _entries = entries);
    } on CloudSimpleDocumentException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFolder(CloudBrowserEntry entry) {
    setState(() {
      _folderStack = <_CloudFolderNode>[
        ..._folderStack,
        _CloudFolderNode(id: entry.id, name: entry.name),
      ];
    });
    unawaited(_loadFolder());
  }

  void _goUp() {
    if (_folderStack.length <= 1) return;
    setState(() {
      _folderStack = _folderStack.sublist(0, _folderStack.length - 1);
    });
    unawaited(_loadFolder());
  }

  @override
  Widget build(BuildContext context) {
    final folderLabel = _folderStack.map((node) => node.name).join(' / ');
    return AlertDialog(
      title: const Text('Choose sync file'),
      content: SelectionArea(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _folderStack.length > 1 ? _goUp : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: 'Up one folder',
                  ),
                  Expanded(
                    child: Text(
                      folderLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else if (_errorText != null)
                SelectableText(_errorText!)
              else if (_entries.isEmpty)
                const Text(
                  'This folder has no supported CSV, XLSX, or ODS files yet. Open another folder or create a new sync file here.',
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _entries
                        .map(
                          (entry) => ListTile(
                            leading: Icon(
                              entry.isFolder
                                  ? Icons.folder_outlined
                                  : entry.id == widget.selectedFileId
                                  ? Icons.check_circle_rounded
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(entry.name),
                            subtitle: Text(
                              entry.isFolder
                                  ? 'Folder'
                                  : _mimeLabel(entry.mimeType),
                            ),
                            onTap: () {
                              if (entry.isFolder) {
                                _openFolder(entry);
                                return;
                              }
                              Navigator.of(context).pop(
                                _CloudFileSelection.pick(
                                  entry.asFileMetadata(),
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _CloudFileSelection.clear()),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_CloudFileSelection.createNew(folderId: _currentFolderId)),
          child: const Text('Create new'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static String _mimeLabel(String mimeType) {
    switch (mimeType) {
      case 'text/csv':
        return 'CSV';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'XLSX';
      case 'application/vnd.oasis.opendocument.spreadsheet':
        return 'ODS';
      case GoogleDriveSyncService.googleSheetsMimeType:
        return 'Google Sheets';
      default:
        return mimeType;
    }
  }
}

class _InlineSetupAction extends StatelessWidget {
  const _InlineSetupAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
