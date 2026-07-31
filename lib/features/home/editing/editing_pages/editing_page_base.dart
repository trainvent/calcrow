import 'dart:async';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/notes_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/row_definement_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/smart_data_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/wellbeing_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/workhours_widget.dart';
import 'package:calcrow/core/data/services/cloud_document_service.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/type_hint_cache.dart';
import 'package:calcrow/core/theme/app_text_styles.dart';
import 'package:calcrow/core/theme/app_layout_constants.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/core/prefills/document_prefill_cache.dart';
import 'package:calcrow/features/home/sheet/sheet_preview_store.dart';
import 'package:calcrow/features/home/editing/define_prefills_page.dart';
import 'package:calcrow/app/widgets/type_dropdown_list.dart';
import 'package:calcrow/app/widgets/document_prefill_selector.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/type_based_input_field.dart';
import 'package:open_filex/open_filex.dart';
import 'package:trainvent_general/trainvent_general.dart';

part 'diary_editing_page.dart';
part 'logbook_editing_page.dart';
part 'namelist_editing_page.dart';

enum _WidgetBlock { rowDefinement, workhours, smartData, wellbeing, notes }

enum EditorOpenMode { dateBased, dateBasedOpenEnd, textBased }

enum _UnsavedEditsChoice { save, discard, cancel }

enum _EditorAdjustAction { details, fieldFormats, prefills, verbose, open }

class EditingPageBase extends ConsumerStatefulWidget {
  const EditingPageBase({
    super.key,
    required this.initialSheetData,
    required this.initialDocumentTarget,
    required this.initialOpenMode,
    this.initialSuccessMessage,
    this.showBackToSelection = false,
    this.onBackToSelection,
    SheetPersistenceService? sheetPersistenceService,
  }) : _sheetPersistenceService = sheetPersistenceService;

  final SheetData initialSheetData;
  final EditorDocumentTarget initialDocumentTarget;
  final EditorOpenMode initialOpenMode;
  final String? initialSuccessMessage;
  final bool showBackToSelection;
  final VoidCallback? onBackToSelection;
  final SheetPersistenceService? _sheetPersistenceService;

  @override
  ConsumerState<EditingPageBase> createState() => _EditingPageBaseState();
}

class EditingPage extends EditingPageBase {
  const EditingPage({
    super.key,
    required super.initialSheetData,
    required super.initialDocumentTarget,
    required super.initialOpenMode,
    super.initialSuccessMessage,
    super.showBackToSelection = false,
    super.onBackToSelection,
    super.sheetPersistenceService,
  });
}

abstract class _EditingModeBehavior {
  const _EditingModeBehavior();

  EditorOpenMode get openMode;
  String pickButtonLabel(AppLocalizations localizations);
  bool get showsTextEntryActions => false;
  bool get showsDateOpenEndActions => false;
  String? get requiredFirstColumnType => null;

  Future<_OpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SheetData sheetData,
  );

  void afterLoaded(_EditingPageBaseState state) {}

  void handleSheetPreviewRowPick(_EditingPageBaseState state, int rowIndex) {}

  Future<void> handleSheetPreviewNewEntryPick(
    _EditingPageBaseState state,
  ) async {}

  Future<void> pickFromCurrentSheet(_EditingPageBaseState state);

  List<String> typeOptionsForColumn(
    _EditingPageBaseState state,
    int columnIndex,
  ) {
    if (columnIndex == 0 && requiredFirstColumnType != null) {
      return <String>[requiredFirstColumnType!];
    }
    return _EditingPageBaseState._documentTypeOptions;
  }

  String? validatePendingTypes(_EditingPageBaseState state) {
    final requiredType = requiredFirstColumnType;
    if (requiredType == null) return null;
    if (state._documentValueTypes.isEmpty) return null;
    final firstType = state._documentValueTypes.first.trim().toLowerCase();
    if (firstType == requiredType) return null;
    final localizations = state.context.l10n;
    return localizations.firstFieldMustStayForOpeningMode(
      requiredType == 'date' ? localizations.date : localizations.text,
    );
  }

  static _EditingModeBehavior forOpenMode(EditorOpenMode mode) {
    return switch (mode) {
      EditorOpenMode.dateBased => const _DiaryEditingModeBehavior(),
      EditorOpenMode.dateBasedOpenEnd => const _LogbookEditingModeBehavior(),
      EditorOpenMode.textBased => const _NamelistEditingModeBehavior(),
    };
  }
}

class _EditingPageBaseState extends ConsumerState<EditingPageBase>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _platformChannel = MethodChannel(
    'de.lemarq.calcrow/file_open',
  );

  static const List<String> _documentTypeOptions = <String>[
    'text',
    'date',
    'time',
    'duration',
    'integer',
    'float',
    'money',
    'boolean',
    'email',
    'phone',
  ];
  XTypeGroup get _csvTypeGroup =>
      XTypeGroup(label: context.l10n.csv, extensions: const <String>['csv']);
  XTypeGroup get _xlsxTypeGroup =>
      XTypeGroup(label: context.l10n.xlsx, extensions: const <String>['xlsx']);
  XTypeGroup get _odsTypeGroup =>
      XTypeGroup(label: context.l10n.ods, extensions: const <String>['ods']);
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
  late final SheetPersistenceService _sheetPersistenceService;
  late final ProviderSubscription<int?> _previewRowPickSubscription;

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
  late final AnimationController _typeTogglePulseController;
  late final Animation<double> _typeTogglePulse;

  bool _setupDone = false;
  late bool _isAdvancedMode;
  String? _documentImportedFileName;
  String? _documentImportedPath;
  String? _documentImportedSheetName;
  SheetFileFormat? _documentImportedFormat;
  String _documentCsvDelimiter = ',';
  bool _documentHasTypeRow = false;
  bool _documentHasCachedValueTypes = false;
  int _documentHeaderRowIndex = 0;
  int _documentStartColumnIndex = 0;
  List<String> _documentHeaders = const <String>[];
  List<String> _documentValueTypes = const <String>[];
  List<bool> _documentReadOnlyColumns = const <bool>[];
  List<int> _documentPendingTypeSelectionColumns = const <int>[];
  List<List<String>> _documentRows = const <List<String>>[];
  List<TextEditingController> _documentControllers =
      const <TextEditingController>[];
  List<String> _documentEditingBaseline = const <String>[];
  List<DocumentPrefill> _documentPrefills = const <DocumentPrefill>[];
  String? _documentPrefillKey;
  excel_pkg.Excel? _documentImportedWorkbook;
  Uint8List? _documentImportedSourceBytes;
  int _documentEditingRowIndex = 0;
  String? _importedFileName;
  List<List<String>> _allRows = const <List<String>>[];
  int? _selectedExistingRowIndex;
  double _moodLevel = 0.45;
  double _energyLevel = 0.62;
  bool _showRowDefinement = true;
  bool _showWorkhours = true;
  bool _showSmartData = true;
  bool _showWellbeing = true;
  bool _showNotes = true;
  bool _showFieldTypes = false;
  bool _isOpeningDocument = false;
  EditorDocumentTarget? _documentDocumentTarget;
  EditorOpenMode _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
  late final _EditingModeBehavior _modeBehavior;
  int? _documentTextSelectionColumnIndex;
  String? _documentTextSelectionValue;
  bool _isDocumentSaving = false;
  bool _documentSaveFailed = false;
  bool _saveDocumentAgain = false;
  bool _showQueuedSaveError = false;

  @override
  void initState() {
    super.initState();
    _isAdvancedMode = false;
    _documentOpenMode = widget.initialOpenMode;
    _modeBehavior = _EditingModeBehavior.forOpenMode(_documentOpenMode);
    _sheetPersistenceService =
        widget._sheetPersistenceService ?? SheetPersistenceService();
    _typeTogglePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _typeTogglePulse = CurvedAnimation(
      parent: _typeTogglePulseController,
      curve: Curves.easeInOut,
    );
    _previewRowPickSubscription = ref.listenManual<int?>(
      sheetPreviewPickedRowProvider,
      (previous, next) => _handleSheetPreviewRowPick(next),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialDocument());
    });
  }

  @override
  void dispose() {
    _previewRowPickSubscription.close();
    _dateController.dispose();
    _startController.dispose();
    _endController.dispose();
    _breakController.dispose();
    _notesController.dispose();
    for (final controller in _documentControllers) {
      controller.dispose();
    }
    _typeTogglePulseController.dispose();
    super.dispose();
  }

  bool get _hasDocumentSchema =>
      _documentHeaders.isNotEmpty &&
      _documentValueTypes.length == _documentHeaders.length &&
      _documentReadOnlyColumns.length == _documentHeaders.length;

  bool get _hasDocumentControllersReady =>
      _documentControllers.length == _documentHeaders.length &&
      _documentReadOnlyColumns.length == _documentHeaders.length;

  bool get _showsInlineSaveStatus {
    final dateColumn = _documentDateColumnIndex();
    if (dateColumn == null || !_isFixedDateField(dateColumn)) return false;
    return dateColumn >= _documentReadOnlyColumns.length ||
        !_documentReadOnlyColumns[dateColumn];
  }

  Future<void> _loadInitialDocument() async {
    final loaded = await _loadProfileData(
      widget.initialSheetData,
      target: widget.initialDocumentTarget,
    );
    if (!mounted) return;
    if (!loaded) {
      widget.onBackToSelection?.call();
      if (widget.onBackToSelection == null) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    final message = widget.initialSuccessMessage;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool get _supportsLocalFileEditing =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _openLocalDocumentFolderOrDocument() async {
    if (!_supportsLocalFileEditing) return;

    final path = _documentImportedPath?.trim();
    if (_documentDocumentTarget is LocalEditorDocumentTarget &&
        path != null &&
        path.isNotEmpty) {
      final opened = await _openLocalFileExternally(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        opened
            ? SnackBar(content: Text(context.l10n.openedDocumentInAnotherApp))
            : SnackBar(
                content: Text(context.l10n.couldNotOpenTheFileInAnotherApp),
              ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.chooseADocumentFromGetStarted)),
    );
  }

  Future<bool> _openLocalFileExternally(String path) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android &&
        path.toLowerCase().startsWith('content://')) {
      try {
        final result = await _platformChannel.invokeMethod<String>(
          'openSafDocument',
          <String, String>{
            'uri': path,
            'mimeType': _mimeTypeForLocalDocumentOpen(),
          },
        );
        return result == 'done';
      } catch (_) {
        return false;
      }
    }

    final result = await OpenFilex.open(
      path,
      type: _mimeTypeForLocalDocumentOpen(),
    );
    return result.type == ResultType.done;
  }

  String _mimeTypeForLocalDocumentOpen() {
    final format = _documentImportedFormat ?? SheetFileFormat.csv;
    return SheetFileService.mimeTypeForFormat(format);
  }

  Future<bool> _loadProfileData(
    SheetData sheetData, {
    EditorDocumentTarget? target,
  }) async {
    final selection = await _resolveOpeningSelection(sheetData);
    if (!mounted || selection == null) return false;

    setState(() {
      _documentImportedFileName = sheetData.fileName;
      _documentImportedPath = sheetData.path;
      _documentImportedFormat = sheetData.format;
      _documentCsvDelimiter = sheetData.csvDelimiter;
      _documentHasTypeRow = sheetData.hasTypeRow;
      _documentHasCachedValueTypes = sheetData.hasCachedValueTypes;
      _documentHeaderRowIndex = sheetData.headerRowIndex;
      _documentStartColumnIndex = sheetData.startColumnIndex;
      _documentImportedSheetName = sheetData.xlsxSheetName;
      _documentHeaders = sheetData.headers;
      _documentValueTypes = sheetData.valueTypes;
      _documentReadOnlyColumns = sheetData.readOnlyColumns;
      _documentPendingTypeSelectionColumns =
          sheetData.pendingTypeSelectionColumns;
      _documentRows = sheetData.rows;
      _documentImportedWorkbook = sheetData.workbook;
      _documentImportedSourceBytes = sheetData.sourceBytes;
      _documentDocumentTarget =
          target ?? LocalEditorDocumentTarget(existingPath: sheetData.path);
      _documentTextSelectionColumnIndex = selection.textColumnIndex;
      _documentTextSelectionValue = selection.textValue;
    });

    _selectEditorTargetRow(
      preferredRowIndex: selection.targetRowIndex,
      preserveSelectedTextTarget: true,
    );
    unawaited(_loadDocumentPrefills(sheetData, target: target));
    _publishRowsToPreview();
    _modeBehavior.afterLoaded(this);
    unawaited(_rememberOpenConfiguration(sheetData, target: target));
    return true;
  }

  Future<void> _loadDocumentPrefills(
    SheetData sheetData, {
    EditorDocumentTarget? target,
  }) async {
    final documentKey = _prefillKeyForDocument(sheetData, target: target);
    if (documentKey == null) return;
    _documentPrefillKey = documentKey;
    final legacyKeys = _legacyPrefillKeys(sheetData, target: target);

    try {
      final cached = await DocumentPrefillCache.readForFileName(
        sheetData.fileName,
        legacyDocumentKeys: legacyKeys,
      );
      if (mounted && _documentPrefillKey == documentKey) {
        setState(() => _documentPrefills = cached);
      }
    } catch (_) {
      // Remote storage may still provide the prefills.
    }

    if (!ServiceLocator.isSetup) return;
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;
    try {
      final remote = await ref
          .read(userRepositoryProvider)
          .readDocumentPrefills(
            uid: session.uid,
            documentKey: documentKey,
            fileName: sheetData.fileName,
          );
      if (remote == null) return;
      await DocumentPrefillCache.write(documentKey, remote);
      if (mounted && _documentPrefillKey == documentKey) {
        setState(() => _documentPrefills = remote);
      }
    } catch (_) {
      // Cached prefills remain usable while offline.
    }
  }

  String? _prefillKeyForDocument(
    SheetData sheetData, {
    EditorDocumentTarget? target,
  }) {
    final fileName = target is CloudEditorDocumentTarget
        ? target.fileName
        : sheetData.fileName;
    if (fileName.trim().isEmpty) return null;
    return documentPrefillKey(fileName);
  }

  List<String> _legacyPrefillKeys(
    SheetData sheetData, {
    EditorDocumentTarget? target,
  }) {
    if (target is CloudEditorDocumentTarget) {
      return <String>[
        cloudPrefillDocumentKey(target.provider.name, target.fileId),
      ];
    }
    final path = target is LocalEditorDocumentTarget
        ? target.existingPath
        : sheetData.path;
    if (path == null || path.trim().isEmpty) return const <String>[];
    return <String>[localPrefillDocumentKey(path)];
  }

  void _applyDocumentPrefill(DocumentPrefill prefill) {
    for (final entry in prefill.values.entries) {
      final index = _documentHeaders.indexOf(entry.key);
      if (index < 0 || index >= _documentControllers.length) continue;
      if (index < _documentReadOnlyColumns.length &&
          _documentReadOnlyColumns[index]) {
        continue;
      }
      if (_isFixedDateField(index)) continue;
      _documentControllers[index].text = entry.value;
    }
    setState(() {});
  }

  Future<void> _rememberOpenConfiguration(
    SheetData sheetData, {
    EditorDocumentTarget? target,
  }) async {
    if (!ServiceLocator.isSetup) return;
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;

    final openMode = _documentOpenMode.name;
    final fileName = sheetData.fileName.trim().isEmpty
        ? 'document'
        : sheetData.fileName.trim();
    RecentOpenConfig? config;
    if (target is CloudEditorDocumentTarget) {
      config = RecentOpenConfig(
        source: switch (target.provider) {
          CloudSyncProvider.googleDrive => RecentDocumentSource.googleDrive,
          CloudSyncProvider.webDav => RecentDocumentSource.webDav,
        },
        fileName: target.fileName,
        openMode: openMode,
        fileId: target.fileId,
        mimeType: target.mimeType,
      );
    } else {
      final path =
          (target is LocalEditorDocumentTarget
                  ? target.existingPath
                  : sheetData.path)
              ?.trim();
      if (path != null && path.isNotEmpty) {
        config = RecentOpenConfig(
          source: RecentDocumentSource.local,
          fileName: fileName,
          openMode: openMode,
          path: path,
        );
      }
    }

    if (config == null) return;
    try {
      await ref
          .read(userRepositoryProvider)
          .rememberOpenConfig(uid: session.uid, config: config);
    } catch (_) {
      // Recents should never block opening a document.
    }
  }

  List<String> _normalizeRowToWidth(List<String> row, int width) {
    return List<String>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    );
  }

  int? _documentDateColumnIndex() {
    if (_documentHeaders.isEmpty) return null;
    final typeIndex = _documentValueTypes.indexWhere(
      (type) => type.trim().toLowerCase() == 'date',
    );
    if (typeIndex >= 0) return typeIndex;
    final headerIndex = _documentHeaders.indexWhere(
      (header) => _isDateHeaderName(header),
    );
    if (headerIndex >= 0) return headerIndex;
    return null;
  }

  Future<_OpeningSelection?> _resolveOpeningSelection(
    SheetData sheetData,
  ) async {
    return _modeBehavior.resolveOpening(this, sheetData);
  }

  bool _cachedFirstColumnBlocksDateBasedOpening(SheetData sheetData) {
    if (!sheetData.hasCachedValueTypes || sheetData.valueTypes.isEmpty) {
      return false;
    }
    return sheetData.valueTypes.first.trim().toLowerCase() != 'date';
  }

  bool _cachedFirstColumnBlocksTextBasedOpening(SheetData sheetData) {
    if (!sheetData.hasCachedValueTypes || sheetData.valueTypes.isEmpty) {
      return false;
    }
    return sheetData.valueTypes.first.trim().toLowerCase() != 'text';
  }

  void _showCachedTypeMismatchSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Row(children: [Expanded(child: Text(message, maxLines: 2))]),
      ),
    );
  }

  _EditorTargetSelection _selectEditorTargetRow({
    int? preferredRowIndex,
    bool preserveSelectedTextTarget = false,
  }) {
    if (!_hasDocumentSchema) {
      return const _EditorTargetSelection(
        usedDateColumn: false,
        foundMatchingDateRow: false,
        targetRowIndex: 0,
      );
    }

    final dateColumn = _documentDateColumnIndex();
    final today = DateTime.now();
    int targetRowIndex = _documentRows.length;
    var foundMatchingDateRow = false;

    if (preferredRowIndex != null &&
        preferredRowIndex >= 0 &&
        preferredRowIndex <= _documentRows.length) {
      targetRowIndex = preferredRowIndex;
      if (preferredRowIndex < _documentRows.length) {
        foundMatchingDateRow =
            dateColumn != null &&
            dateColumn < _documentRows[preferredRowIndex].length &&
            (() {
              final rowDate = _parseDateFromCellValue(
                _documentRows[preferredRowIndex][dateColumn],
              );
              return rowDate != null && _isSameCalendarDate(rowDate, today);
            })();
      }
    } else if (dateColumn != null) {
      int? fallbackMatchIndex;
      for (var i = _documentRows.length - 1; i >= 0; i--) {
        final row = _documentRows[i];
        if (dateColumn >= row.length) {
          continue;
        }
        final rowDate = _parseDateFromCellValue(row[dateColumn]);
        if (rowDate == null || !_isSameCalendarDate(rowDate, today)) {
          continue;
        }
        foundMatchingDateRow = true;
        fallbackMatchIndex ??= i;
        if (_rowHasEditableEmptyCell(row, dateColumn: dateColumn)) {
          targetRowIndex = i;
          break;
        }
      }
      targetRowIndex = targetRowIndex == _documentRows.length
          ? (fallbackMatchIndex ?? targetRowIndex)
          : targetRowIndex;
    }

    final draft = targetRowIndex < _documentRows.length
        ? _documentRows[targetRowIndex]
        : List<String>.filled(_documentHeaders.length, '');
    if (preserveSelectedTextTarget &&
        _documentTextSelectionColumnIndex != null &&
        _documentTextSelectionValue != null) {
      final selectionColumn = _documentTextSelectionColumnIndex!;
      final selectionValue = _documentTextSelectionValue!.trim();
      if (selectionValue.isNotEmpty &&
          selectionColumn < draft.length &&
          draft[selectionColumn].trim().isEmpty) {
        draft[selectionColumn] = selectionValue;
      }
    }
    if (dateColumn != null && (draft[dateColumn].trim().isEmpty)) {
      draft[dateColumn] = _formatDate(today);
    }

    _replaceControllers(draft);
    setState(() {
      _documentEditingRowIndex = targetRowIndex;
      if (!preserveSelectedTextTarget) {
        _documentTextSelectionColumnIndex = null;
        _documentTextSelectionValue = null;
      }
    });
    return _EditorTargetSelection(
      usedDateColumn: dateColumn != null,
      foundMatchingDateRow: foundMatchingDateRow,
      targetRowIndex: targetRowIndex,
    );
  }

  _EditorTargetSelection _selectEditorTargetRowForSheetData(
    SheetData sheetData,
  ) {
    if (sheetData.headers.isEmpty) {
      return const _EditorTargetSelection(
        usedDateColumn: false,
        foundMatchingDateRow: false,
        targetRowIndex: 0,
      );
    }

    final typeIndex = sheetData.valueTypes.indexWhere(
      (type) => type.trim().toLowerCase() == 'date',
    );
    final dateColumn = typeIndex >= 0
        ? typeIndex
        : sheetData.headers.indexWhere((header) => _isDateHeaderName(header));
    if (dateColumn < 0) {
      return const _EditorTargetSelection(
        usedDateColumn: false,
        foundMatchingDateRow: false,
        targetRowIndex: 0,
      );
    }

    final today = DateTime.now();
    int? fallbackMatchIndex;
    for (var rowIndex = 0; rowIndex < sheetData.rows.length; rowIndex++) {
      final row = sheetData.rows[rowIndex];
      if (dateColumn >= row.length) continue;
      final rowDate = _parseDateFromCellValue(row[dateColumn]);
      if (rowDate != null && _isSameCalendarDate(rowDate, today)) {
        fallbackMatchIndex ??= rowIndex;
        if (_rowHasEditableEmptyCellForSheetData(
          row,
          dateColumn: dateColumn,
          readOnlyColumns: sheetData.readOnlyColumns,
          width: sheetData.headers.length,
        )) {
          return _EditorTargetSelection(
            usedDateColumn: true,
            foundMatchingDateRow: true,
            targetRowIndex: rowIndex,
          );
        }
      }
    }

    return _EditorTargetSelection(
      usedDateColumn: true,
      foundMatchingDateRow: fallbackMatchIndex != null,
      targetRowIndex: fallbackMatchIndex ?? sheetData.rows.length,
    );
  }

  List<int> _documentTextSelectableColumnsForSheetData(SheetData sheetData) {
    return _documentTextSelectableColumnsForSheetDataInternal(sheetData);
  }

  List<int> _documentTextSelectableColumnsForSheetDataInternal(
    SheetData sheetData, {
    int? excludedColumnIndex,
  }) {
    final indexes = <int>[];
    for (var index = 0; index < sheetData.headers.length; index++) {
      if (index == excludedColumnIndex) continue;
      if (index >= sheetData.readOnlyColumns.length ||
          sheetData.readOnlyColumns[index]) {
        continue;
      }
      final type = index < sheetData.valueTypes.length
          ? sheetData.valueTypes[index]
          : 'text';
      if (_supportsTextBasedOpening(type)) {
        indexes.add(index);
      }
    }
    return indexes;
  }

  bool _supportsTextBasedOpening(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type.isEmpty ||
        type.contains('text') ||
        type.contains('email') ||
        type.contains('phone');
  }

  DateTime _documentCurrentEditorDate(int dateColumn) {
    if (dateColumn >= 0 && dateColumn < _documentControllers.length) {
      final parsed = _parseDateFromCellValue(
        _documentControllers[dateColumn].text,
      );
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  bool _rowHasEditableEmptyCell(List<String> row, {required int dateColumn}) {
    for (var i = 0; i < _documentHeaders.length; i++) {
      final isReadOnly =
          i < _documentReadOnlyColumns.length && _documentReadOnlyColumns[i];
      if (i == dateColumn || isReadOnly) continue;
      final value = i < row.length ? row[i].trim() : '';
      if (value.isEmpty) return true;
    }
    return false;
  }

  bool _rowHasEditableEmptyCellForSheetData(
    List<String> row, {
    required int dateColumn,
    required List<bool> readOnlyColumns,
    required int width,
  }) {
    for (var i = 0; i < width; i++) {
      final isReadOnly = i < readOnlyColumns.length && readOnlyColumns[i];
      if (i == dateColumn || isReadOnly) continue;
      final value = i < row.length ? row[i].trim() : '';
      if (value.isEmpty) return true;
    }
    return false;
  }

  void _replaceControllers(List<String> values) {
    final oldControllers = _documentControllers;
    final nextControllers = List<TextEditingController>.generate(
      _documentHeaders.length,
      (index) => TextEditingController(
        text: _initialControllerValue(columnIndex: index, values: values),
      ),
    );

    setState(() {
      _documentControllers = nextControllers;
      _documentEditingBaseline = _normalizeRowToWidth(
        values,
        _documentHeaders.length,
      );
      _documentSaveFailed = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
  }

  Future<void> _requestDocumentSave({bool showError = false}) async {
    if (!_hasUnsavedRowEdits) return;
    if (_isDocumentSaving) {
      _saveDocumentAgain = true;
      _showQueuedSaveError = _showQueuedSaveError || showError;
      return;
    }

    var showCurrentError = showError;
    while (mounted && _hasUnsavedRowEdits) {
      setState(() {
        _isDocumentSaving = true;
        _documentSaveFailed = false;
      });
      final saved = await _saveDocumentRowInternal(
        mode: PersistMode.safPreferred,
        showSuccessMessage: false,
        showErrorMessage: showCurrentError,
      );
      if (!mounted) return;
      setState(() {
        _isDocumentSaving = false;
        _documentSaveFailed = !saved;
      });

      final saveAgain = _saveDocumentAgain;
      showCurrentError = _showQueuedSaveError;
      _saveDocumentAgain = false;
      _showQueuedSaveError = false;
      if (!saved || !saveAgain) break;
    }
  }

  void _handleDocumentFieldChanged() {
    if (!mounted) return;
    setState(() {
      _documentSaveFailed = false;
    });
  }

  void _handleDocumentFieldFocusChanged(bool hasFocus) {
    if (!hasFocus) {
      unawaited(_requestDocumentSave());
    }
  }

  void _handleSaveStatusPressed() {
    if (_isDocumentSaving || (!_hasUnsavedRowEdits && !_documentSaveFailed)) {
      return;
    }
    unawaited(_requestDocumentSave(showError: true));
  }

  Future<bool> _saveDocumentRowAsIs() =>
      _saveDocumentRowInternal(mode: PersistMode.asIs);

  String? _documentRowValidationError(List<String> row) {
    for (var index = 0; index < _documentHeaders.length; index++) {
      if (index >= row.length || index >= _documentValueTypes.length) continue;
      if (index < _documentReadOnlyColumns.length &&
          _documentReadOnlyColumns[index]) {
        continue;
      }
      if (_isFixedDateField(index)) continue;
      final value = row[index].trim();
      if (value.isEmpty) continue;
      final type = _documentValueTypes[index];
      final header = _documentHeaders[index];

      if (FieldTypeGuesser.isIntegerType(type) &&
          !FieldTypeGuesser.looksLikeIntegerValue(value)) {
        return '$header must be an integer.';
      }
      if (FieldTypeGuesser.isDecimalType(type) &&
          !FieldTypeGuesser.looksLikeIntegerValue(value) &&
          !FieldTypeGuesser.looksLikeDecimalValue(value)) {
        return '$header must be a float.';
      }
      if (FieldTypeGuesser.isMoneyType(type) &&
          !FieldTypeGuesser.looksLikeIntegerValue(value) &&
          !FieldTypeGuesser.looksLikeDecimalValue(value)) {
        return '$header must be a money amount.';
      }
      if (_isBooleanType(type) &&
          !FieldTypeGuesser.looksLikeBooleanValue(value)) {
        return '$header must be TRUE or FALSE.';
      }
      if (type.trim().toLowerCase() == 'date' &&
          !FieldTypeGuesser.looksLikeDateValue(value)) {
        return '$header must be a date.';
      }
      if (_isTimeType(type) && !FieldTypeGuesser.looksLikeTimeValue(value)) {
        return '$header must be a time.';
      }
      if (_isDurationType(type) && !_looksLikeDurationValue(value)) {
        return '$header must be a duration.';
      }
    }
    return null;
  }

  Future<bool> _saveDocumentRowInternal({
    required PersistMode mode,
    bool showSuccessMessage = true,
    bool showErrorMessage = true,
  }) async {
    if (!_hasDocumentSchema ||
        _documentControllers.length != _documentHeaders.length) {
      return false;
    }

    final updatedRow = _documentControllers
        .map((controller) => controller.text.trim())
        .toList();
    final validationError = _documentRowValidationError(updatedRow);
    if (validationError != null) {
      if (showErrorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
      }
      return false;
    }
    final nextRows = List<List<String>>.from(_documentRows);
    final forcedTargetIndex = _findBestExistingRowForSave(updatedRow);
    final effectiveTargetIndex = forcedTargetIndex ?? _documentEditingRowIndex;
    final normalizedUpdated = _normalizeRowToWidth(
      updatedRow,
      _documentHeaders.length,
    );

    if (effectiveTargetIndex < nextRows.length) {
      if (forcedTargetIndex != null &&
          forcedTargetIndex != _documentEditingRowIndex) {
        nextRows[effectiveTargetIndex] = _mergeRowForAutoFill(
          existing: nextRows[effectiveTargetIndex],
          incoming: normalizedUpdated,
        );
      } else {
        nextRows[effectiveTargetIndex] = normalizedUpdated;
      }
    } else {
      nextRows.add(normalizedUpdated);
    }

    setState(() {
      _documentRows = nextRows;
      _documentEditingRowIndex = effectiveTargetIndex;
      if (_documentEditingRowIndex >= _documentRows.length) {
        _documentEditingRowIndex = _documentRows.length - 1;
      }
      if (_documentTextSelectionColumnIndex != null &&
          _documentTextSelectionColumnIndex! < _documentHeaders.length &&
          _documentEditingRowIndex >= 0 &&
          _documentEditingRowIndex < _documentRows.length &&
          _documentTextSelectionColumnIndex! <
              _documentRows[_documentEditingRowIndex].length) {
        final nextValue =
            _documentRows[_documentEditingRowIndex][_documentTextSelectionColumnIndex!]
                .trim();
        _documentTextSelectionValue = nextValue.isEmpty ? null : nextValue;
      }
    });
    _publishRowsToPreview();
    final messenger = ScaffoldMessenger.of(context);
    void showSaveError(String message) {
      if (!showErrorMessage) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      final saveResult = await _persistSheet(mode: mode);
      if (!mounted) return false;
      if (showSuccessMessage) {
        messenger.showSnackBar(
          SnackBar(content: Text(_saveMessage(context.l10n, saveResult))),
        );
      }
      setState(() {
        _documentEditingBaseline = normalizedUpdated;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      if (error is StateError && error.message == 'Save canceled.') {
        showSaveError(context.l10n.rowUpdatedFileSaveCanceled);
        return false;
      }
      if (error is StateError && error.message == 'SAF save canceled.') {
        showSaveError(context.l10n.safSaveCanceledUseSaveAsIsInPreview);
        return false;
      }
      if (error is StateError &&
          error.message == 'SAF save is not supported on this platform.') {
        showSaveError(
          context.l10n.safSaveIsNotAvailableHereUseSaveAsIsInPreview,
        );
        return false;
      }
      if (error is StateError &&
          error.message ==
              'No SAF target selected. Open a SAF-backed file first or configure SAF folder in Settings.') {
        showSaveError(
          context
              .l10n
              .noSAFTargetSelectedOpenASAFBackedFileOrConfigureSAFFolderInSettingsOrUseSaveAsIsInPreview,
        );
        return false;
      }
      if (error is StateError &&
          error.message ==
              'Current file is not SAF-backed. Use "Save as is" or reopen with SAF.') {
        showSaveError(
          context
              .l10n
              .currentFileIsNotSAFBackedUseSaveAsIsInPreviewOrReopenViaSAF,
        );
        return false;
      }
      if (error is StateError && error.message == 'SAF stream write failed.') {
        showSaveError(context.l10n.safStreamWriteFailedUseSaveAsIsInPreview);
        return false;
      }
      if (error is StateError &&
          error.message ==
              'SAF target is incompatible for direct overwrite. Reopen from a writable folder via SAF.') {
        showSaveError(
          context
              .l10n
              .thisSAFSourceCannotBeOverwrittenDirectlyReopenFromAWritableFolderViaSAFOrUseSaveAsIs,
        );
        return false;
      }
      showSaveError(context.l10n.rowSavedButFileWriteFailed('$error'));
      return false;
    }
  }

  String _saveMessage(
    AppLocalizations localizations,
    PersistResult saveResult,
  ) {
    if (kIsWeb) {
      return localizations.rowUpdatedDownloadedFileAs(saveResult.locationLabel);
    }
    if (saveResult.usedAppDocumentsFallback) {
      return localizations.rowSavedToAppStorageAt(saveResult.locationLabel);
    }
    if (saveResult.overwroteExistingFile) {
      return localizations.rowSavedToLocation(saveResult.locationLabel);
    }
    return localizations.rowSavedFutureSavesOverwrite(saveResult.locationLabel);
  }

  int? _findBestExistingRowForSave(List<String> updatedRow) {
    if (_documentOpenMode != EditorOpenMode.dateBased) {
      return null;
    }
    final dateColumn = _documentDateColumnIndex();
    if (dateColumn == null || dateColumn >= updatedRow.length) {
      return null;
    }
    final targetDate = _parseDateFromCellValue(updatedRow[dateColumn]);
    if (targetDate == null) {
      return null;
    }

    int? fallbackMatchIndex;
    for (var i = _documentRows.length - 1; i >= 0; i--) {
      final row = _documentRows[i];
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
      _documentHeaders.length,
    );
    return List<String>.generate(_documentHeaders.length, (index) {
      final next = index < incoming.length ? incoming[index].trim() : '';
      if (next.isNotEmpty) return next;
      return normalizedExisting[index];
    });
  }

  void _clearEditableFields() {
    final dateColumn = _documentDateColumnIndex();
    for (var i = 0; i < _documentControllers.length; i++) {
      final isReadOnly =
          i < _documentReadOnlyColumns.length && _documentReadOnlyColumns[i];
      if (i == dateColumn || isReadOnly) continue;
      _documentControllers[i].clear();
    }
    setState(() {});
  }

  Future<String?> _pickCurrencyCode(String initialCurrencyCode) {
    final selectedCurrencyCode = FieldTypeGuesser.normalizeCurrencyCode(
      initialCurrencyCode,
    );
    return showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(context.l10n.selectCurrency),
          children: FieldTypeGuesser.currencyCodes
              .map(
                (currencyCode) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(currencyCode),
                  child: Row(
                    children: [
                      Expanded(child: Text(currencyCode)),
                      if (currencyCode == selectedCurrencyCode)
                        const Icon(Icons.check_rounded),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _handlePendingTypeChanged(
    int columnIndex,
    String nextType,
  ) async {
    if (columnIndex < 0 || columnIndex >= _documentValueTypes.length) return;
    if (nextType == 'money' &&
        !(columnIndex == 0 && _modeBehavior.requiredFirstColumnType != null)) {
      final selectedCurrencyCode = await _pickCurrencyCode(
        FieldTypeGuesser.currencyCodeFromType(_documentValueTypes[columnIndex]),
      );
      if (!mounted || selectedCurrencyCode == null) return;
      _updatePendingType(
        columnIndex,
        FieldTypeGuesser.moneyType(selectedCurrencyCode),
      );
      return;
    }
    _updatePendingType(columnIndex, nextType);
  }

  void _updatePendingType(int columnIndex, String nextType) {
    final nextTypes = List<String>.from(_documentValueTypes);
    if (columnIndex < 0 || columnIndex >= nextTypes.length) return;
    if (columnIndex == 0 && _modeBehavior.requiredFirstColumnType != null) {
      nextType = _modeBehavior.requiredFirstColumnType!;
    }
    if (nextType == 'money') {
      nextType = FieldTypeGuesser.moneyType(
        FieldTypeGuesser.currencyCodeFromType(nextTypes[columnIndex]),
      );
    }
    nextTypes[columnIndex] = nextType;
    setState(() {
      _documentValueTypes = nextTypes;
    });
  }

  void _toggleFieldTypes() {
    setState(() {
      _showFieldTypes = !_showFieldTypes;
    });
    if (_showFieldTypes) {
      _typeTogglePulseController.repeat(reverse: true);
    } else {
      _typeTogglePulseController.stop();
      _typeTogglePulseController.value = 0;
    }
  }

  void _handleEditorMenuAction(_EditorAdjustAction action) {
    switch (action) {
      case _EditorAdjustAction.details:
        unawaited(_showDocumentDetails());
      case _EditorAdjustAction.fieldFormats:
        _resetTypeSelection();
      case _EditorAdjustAction.prefills:
        unawaited(_editDocumentPrefills());
      case _EditorAdjustAction.verbose:
        _toggleFieldTypes();
      case _EditorAdjustAction.open:
        unawaited(_openLocalDocumentFolderOrDocument());
    }
  }

  List<PopupMenuEntry<_EditorAdjustAction>> _editorMenuItems(
    BuildContext context,
  ) {
    return <PopupMenuEntry<_EditorAdjustAction>>[
      PopupMenuItem<_EditorAdjustAction>(
        key: const ValueKey('editor-menu-details'),
        value: _EditorAdjustAction.details,
        child: Text(context.l10n.details),
      ),
      if (_canOpenLocalDocumentFromHeader)
        PopupMenuItem<_EditorAdjustAction>(
          key: const ValueKey('editor-menu-open'),
          value: _EditorAdjustAction.open,
          child: Text(context.l10n.openAction),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<_EditorAdjustAction>(
        key: const ValueKey('adjust-field-formats'),
        value: _EditorAdjustAction.fieldFormats,
        enabled: _documentPendingTypeSelectionColumns.isEmpty,
        child: Text(context.l10n.fieldFormats),
      ),
      PopupMenuItem<_EditorAdjustAction>(
        key: const ValueKey('adjust-prefills'),
        value: _EditorAdjustAction.prefills,
        enabled: _documentPendingTypeSelectionColumns.isEmpty,
        child: Text(context.l10n.definePrefills),
      ),
      PopupMenuItem<_EditorAdjustAction>(
        key: const ValueKey('editor-menu-verbose'),
        value: _EditorAdjustAction.verbose,
        child: Row(
          children: [
            Expanded(child: Text(context.l10n.verboseMode)),
            if (_showFieldTypes) ...[
              const SizedBox(width: 16),
              const Icon(Icons.check_rounded, size: 20),
            ],
          ],
        ),
      ),
    ];
  }

  Future<void> _showDocumentDetails() {
    final isEditingExisting = _documentEditingRowIndex < _documentRows.length;
    final targetLabel = isEditingExisting
        ? context.l10n.rowNumber(_documentEditingRowIndex + 1)
        : context.l10n.newRow;
    final isSheetDocumentSource =
        _documentImportedFormat == SheetFileFormat.xlsx ||
        _documentImportedFormat == SheetFileFormat.ods ||
        _documentImportedFormat == SheetFileFormat.gsheet;
    final sheetName = _documentImportedSheetName?.trim();
    final activeSheetLabel = isSheetDocumentSource
        ? ((sheetName == null || sheetName.isEmpty)
              ? context.l10n.defaultLabel
              : sheetName)
        : null;
    final fileName = _documentImportedFileName?.trim();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.currentFile),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName == null || fileName.isEmpty
                  ? targetLabel
                  : '$fileName - $targetLabel',
            ),
            if (activeSheetLabel != null) ...[
              const SizedBox(height: 8),
              Text(context.l10n.activeSheet(activeSheetLabel)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  bool get _canOpenLocalDocumentFromHeader =>
      _supportsLocalFileEditing &&
      (_documentDocumentTarget == null ||
          _documentDocumentTarget is LocalEditorDocumentTarget);

  String _editorTypeOptionFor(String type) {
    if (FieldTypeGuesser.isMoneyType(type)) return 'money';
    if (FieldTypeGuesser.isIntegerType(type)) return 'integer';
    if (FieldTypeGuesser.isDecimalType(type)) return 'float';
    return type;
  }

  String _localizedEditorTypeLabelFor(
    AppLocalizations localizations,
    String type,
  ) {
    if (FieldTypeGuesser.isMoneyType(type)) {
      final currencyCode = FieldTypeGuesser.currencyCodeFromType(type);
      return localizations.moneyWithCurrency(currencyCode);
    }
    return switch (_editorTypeOptionFor(type).trim().toLowerCase()) {
      'boolean' => localizations.boolean,
      'date' => localizations.date2,
      'duration' => localizations.duration,
      'email' => localizations.email2,
      'float' => localizations.float,
      'integer' || 'int' => localizations.integer,
      'money' => localizations.money,
      'phone' => localizations.phone,
      'text' => localizations.text2,
      'time' => localizations.time,
      _ => type,
    };
  }

  void _confirmPendingTypes() {
    if (_documentPendingTypeSelectionColumns.isEmpty) return;
    final validationMessage = _modeBehavior.validatePendingTypes(this);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    setState(() {
      _documentPendingTypeSelectionColumns = const <int>[];
    });
    unawaited(_rememberCurrentTypeHints());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.fieldFormatsConfirmed)));
  }

  void _resetTypeSelection() {
    final editableColumns =
        List<int>.generate(_documentHeaders.length, (index) => index).where((
          index,
        ) {
          if (index >= _documentValueTypes.length) return false;
          if (index == 0 && _modeBehavior.requiredFirstColumnType != null) {
            return true;
          }
          if (index < _documentReadOnlyColumns.length) {
            return !_documentReadOnlyColumns[index];
          }
          return true;
        }).toList();

    if (editableColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noEditableFieldTypesToReset)),
      );
      return;
    }

    setState(() {
      _documentPendingTypeSelectionColumns = editableColumns;
    });
  }

  Future<void> _editDocumentPrefills() async {
    final updatedPrefills = await Navigator.of(context)
        .push<List<DocumentPrefill>>(
          MaterialPageRoute(
            builder: (context) => DefinePrefillsPage(
              headers: _documentHeaders,
              valueTypes: _documentValueTypes,
              initialPrefills: _documentPrefills,
              submitLabel: context.l10n.save,
            ),
          ),
        );
    if (!mounted || updatedPrefills == null) return;

    setState(() => _documentPrefills = updatedPrefills);
    final fileName = _documentImportedFileName?.trim();
    if (fileName == null || fileName.isEmpty) return;
    final documentKey = documentPrefillKey(fileName);
    _documentPrefillKey = documentKey;
    try {
      await DocumentPrefillCache.write(documentKey, updatedPrefills);
    } catch (_) {
      // Remote storage may still preserve the changes.
    }

    if (!ServiceLocator.isSetup) return;
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;
    try {
      await ref
          .read(userRepositoryProvider)
          .rememberDocumentPrefills(
            uid: session.uid,
            documentKey: documentKey,
            fileName: fileName,
            prefills: updatedPrefills,
          );
    } catch (_) {
      // The local cache remains authoritative while remote storage is offline.
    }
  }

  Future<void> _rememberCurrentTypeHints() async {
    final target = _documentDocumentTarget;
    final fileName = _documentImportedFileName ?? 'calcrow_sheet';
    try {
      if (target is CloudEditorDocumentTarget) {
        await ref
            .read(cloudDocumentServiceProvider)
            .rememberTypeHints(
              file: CloudFileMetadata(
                provider: target.provider,
                id: target.fileId,
                name: target.fileName,
                mimeType: target.mimeType,
              ),
              valueTypes: _documentValueTypes,
            );
        return;
      }

      await TypeHintCache.rememberCsvTypes(
        fileName: fileName,
        path: _documentImportedPath,
        valueTypes: _documentValueTypes,
      );
    } catch (_) {
      // Type hints are convenience data; confirming formats should not fail.
    }
  }

  void _publishRowsToPreview() {
    ref
        .read(sheetPreviewProvider.notifier)
        .update(
          (preview) => preview.copyWith(
            headers: _documentHeaders,
            rows: _documentRows,
            fileName: _documentImportedFileName,
            rowCount: _documentRows.length,
            sheetName: _documentImportedSheetName,
            clearSheetName: _documentImportedSheetName?.trim().isEmpty != false,
            selectedRowIndex:
                _documentEditingRowIndex >= 0 &&
                    _documentEditingRowIndex < _documentRows.length
                ? _documentEditingRowIndex
                : null,
            clearSelectedRowIndex:
                _documentEditingRowIndex < 0 ||
                _documentEditingRowIndex >= _documentRows.length,
            onSaveAsIs: _saveDocumentRowAsIs,
          ),
        );
  }

  void _handleSheetPreviewRowPick(int? rowIndex) {
    if (rowIndex == null || !mounted) return;
    ref.read(sheetPreviewPickedRowProvider.notifier).emit(null);
    if (rowIndex == createNewEntryPickIndex) {
      unawaited(_modeBehavior.handleSheetPreviewNewEntryPick(this));
      return;
    }
    if (rowIndex < 0 || rowIndex >= _documentRows.length) {
      return;
    }
    _modeBehavior.handleSheetPreviewRowPick(this, rowIndex);
  }

  void _selectLogbookPreviewRow(int rowIndex) {
    setState(() {
      _documentTextSelectionColumnIndex = null;
      _documentTextSelectionValue = null;
    });
    _selectEditorTargetRow(preferredRowIndex: rowIndex);
    _publishRowsToPreview();
  }

  void _selectNamelistPreviewRow(int rowIndex) {
    final textTarget = _documentTextTargetForRowIndex(rowIndex);
    setState(() {
      _documentTextSelectionColumnIndex = textTarget?.columnIndex;
      _documentTextSelectionValue = textTarget?.value;
    });
    _selectEditorTargetRow(
      preferredRowIndex: rowIndex,
      preserveSelectedTextTarget: textTarget != null,
    );
    _publishRowsToPreview();
  }

  _TextTargetSelection? _documentTextTargetForRowIndex(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _documentRows.length) return null;
    final row = _documentRows[rowIndex];
    final candidateColumns = _documentTextSelectableColumnsForSheetData(
      _buildSheetDataForPersist(),
    );
    for (final columnIndex in candidateColumns) {
      final value = columnIndex < row.length ? row[columnIndex].trim() : '';
      if (value.isEmpty) continue;
      return _TextTargetSelection(
        columnIndex: columnIndex,
        rowIndex: rowIndex,
        value: value,
      );
    }
    return null;
  }

  void _beginTextEntryRowPick() {
    _publishRowsToPreview();
    ref
        .read(sheetPreviewActionsProvider.notifier)
        .beginRowPick(
          SheetPreviewRowPickRequest(
            selectableRowIndexes: <int>{
              for (
                var rowIndex = 0;
                rowIndex < _documentRows.length;
                rowIndex++
              )
                rowIndex,
            },
            title: context.l10n.pickEntry,
            subtitle: context.l10n.chooseAnyRowFromTheSheet,
            allowCreateNewEntry: true,
            createNewEntryLabel: context.l10n.createNewEntry,
          ),
        );
  }

  Future<void> _pickFromCurrentSheetForMode() async {
    await _modeBehavior.pickFromCurrentSheet(this);
  }

  Future<void> _pickTodayEntryFromCurrentSheet() async {
    final dateColumn = _documentDateColumnIndex();
    if (dateColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dateBasedOpenEndNeedsADetectedDateColumn),
        ),
      );
      return;
    }

    final targetDate = _documentCurrentEditorDate(dateColumn);
    final matchingRowIndexes = <int>{
      for (var rowIndex = 0; rowIndex < _documentRows.length; rowIndex++)
        if (dateColumn < _documentRows[rowIndex].length &&
            (() {
              final rowDate = _parseDateFromCellValue(
                _documentRows[rowIndex][dateColumn],
              );
              return rowDate != null &&
                  _isSameCalendarDate(rowDate, targetDate);
            })())
          rowIndex,
    };

    if (matchingRowIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.noRowsFoundFor(_formatDate(targetDate))),
        ),
      );
      return;
    }

    _publishRowsToPreview();
    ref
        .read(sheetPreviewActionsProvider.notifier)
        .beginRowPick(
          SheetPreviewRowPickRequest(
            selectableRowIndexes: matchingRowIndexes,
            title: context.l10n.pickRow,
            subtitle: context.l10n.chooseRowFor(_formatDate(targetDate)),
          ),
        );
  }

  bool get _hasUnsavedRowEdits {
    if (!_hasDocumentControllersReady) return false;
    final current = _documentControllers
        .map((controller) => controller.text.trim())
        .toList(growable: false);
    return !listEquals(
      _normalizeRowToWidth(current, _documentHeaders.length),
      _normalizeRowToWidth(_documentEditingBaseline, _documentHeaders.length),
    );
  }

  Future<bool> _confirmReplacingUnsavedEdits() async {
    if (!_hasUnsavedRowEdits) return true;

    final choice = await showDialog<_UnsavedEditsChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unsavedRowEdits),
        content: Text(context.l10n.saveTheCurrentRowBeforeStartingANewOne),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_UnsavedEditsChoice.cancel),
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(_UnsavedEditsChoice.discard),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(context.l10n.discard),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(_UnsavedEditsChoice.save),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(context.l10n.save),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    switch (choice) {
      case _UnsavedEditsChoice.save:
        return _saveDocumentRowInternal(mode: PersistMode.safPreferred);
      case _UnsavedEditsChoice.discard:
        return true;
      case _UnsavedEditsChoice.cancel:
      case null:
        return false;
    }
  }

  Future<void> _createNewTextEntry() async {
    if (!await _confirmReplacingUnsavedEdits()) return;
    if (!mounted) return;

    final candidateColumns = _documentTextSelectableColumnsForSheetData(
      _buildSheetDataForPersist(),
    );
    if (candidateColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .l10n
                .textBasedOpeningNeedsAtLeastOneEditableTextColumnForNewEntries,
          ),
        ),
      );
      return;
    }

    final textColumnIndex =
        (_documentTextSelectionColumnIndex != null &&
            candidateColumns.contains(_documentTextSelectionColumnIndex))
        ? _documentTextSelectionColumnIndex!
        : candidateColumns.first;
    final draft = List<String>.filled(_documentHeaders.length, '');
    _replaceControllers(draft);
    setState(() {
      _documentEditingRowIndex = _documentRows.length;
      _documentTextSelectionColumnIndex = textColumnIndex;
      _documentTextSelectionValue = null;
    });
    _publishRowsToPreview();
  }

  Future<void> _createNewDateOpenEndRow() async {
    if (!await _confirmReplacingUnsavedEdits()) return;
    if (!mounted) return;

    final dateColumn = _documentDateColumnIndex();
    if (dateColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dateBasedOpenEndNeedsADetectedDateColumn),
        ),
      );
      return;
    }

    final draft = List<String>.filled(_documentHeaders.length, '');
    draft[dateColumn] = _formatDate(DateTime.now());
    _replaceControllers(draft);
    setState(() {
      _documentEditingRowIndex = _documentRows.length;
      _documentTextSelectionColumnIndex = null;
      _documentTextSelectionValue = null;
    });
    _publishRowsToPreview();
  }

  Future<PersistResult> _persistSheet({required PersistMode mode}) async {
    final target = _documentDocumentTarget;
    if (target is CloudEditorDocumentTarget) {
      return _persistCloud(target: target);
    }
    final format = _documentImportedFormat;
    if (format == SheetFileFormat.xlsx) {
      return _persistXlsx(mode: mode);
    }
    if (format == SheetFileFormat.ods) {
      return _persistOds(mode: mode);
    }
    if (format == SheetFileFormat.gsheet) {
      return _persistCloud(
        target: _documentDocumentTarget as CloudEditorDocumentTarget,
      );
    }
    return _persistCsv(mode: mode);
  }

  Future<PersistResult> _persistCsv({required PersistMode mode}) async {
    final bytes = SheetFileService.buildBytes(_buildSheetDataForPersist());
    final fileName = _documentSuggestedFileName();
    return _persistBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _csvTypeGroup,
      mimeType: 'text/csv',
      confirmButtonText: context.l10n.saveCsv,
      mode: mode,
    );
  }

  Future<PersistResult> _persistXlsx({required PersistMode mode}) async {
    final bytes = SheetFileService.buildBytes(_buildSheetDataForPersist());

    final fileName = _documentSuggestedFileName(defaultExtension: 'xlsx');
    return _persistBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _xlsxTypeGroup,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      confirmButtonText: context.l10n.saveXlsx,
      mode: mode,
    );
  }

  Future<PersistResult> _persistOds({required PersistMode mode}) async {
    final bytes = SheetFileService.buildBytes(_buildSheetDataForPersist());

    final fileName = _documentSuggestedFileName(defaultExtension: 'ods');
    return _persistBytes(
      bytes: bytes,
      fileName: fileName,
      typeGroup: _odsTypeGroup,
      mimeType: 'application/vnd.oasis.opendocument.spreadsheet',
      confirmButtonText: context.l10n.saveOds,
      mode: mode,
    );
  }

  Future<PersistResult> _persistCloud({
    required CloudEditorDocumentTarget target,
  }) async {
    final sheetData = _buildSheetDataForPersist();
    final format = _documentImportedFormat ?? SheetFileFormat.csv;
    final bytes = target.mimeType == GoogleDriveSyncService.googleSheetsMimeType
        ? Uint8List(0)
        : SheetFileService.buildBytes(sheetData);
    final mimeType = _mimeTypeForFormat(format);
    final fileName = _documentSuggestedFileName(
      defaultExtension: SheetFileService.defaultExtensionForFormat(format),
    );

    final metadata = await ref
        .read(cloudDocumentServiceProvider)
        .persistDocument(
          existingFile: CloudFileMetadata(
            provider: target.provider,
            id: target.fileId,
            name: target.fileName,
            mimeType: target.mimeType,
          ),
          fileName: fileName,
          bytes: bytes,
          outputMimeType: mimeType,
          sheetData: sheetData,
        );
    if (format == SheetFileFormat.csv) {
      await TypeHintCache.rememberCsvTypes(
        fileName: metadata.name,
        path: metadata.id,
        valueTypes: _documentValueTypes,
      );
    }
    setState(() {
      _documentImportedFileName = metadata.name;
      _documentImportedPath = null;
      _documentDocumentTarget = CloudEditorDocumentTarget(
        provider: metadata.provider,
        fileId: metadata.id,
        fileName: metadata.name,
        mimeType: metadata.mimeType,
      );
    });

    return PersistResult(
      locationLabel:
          '${ref.read(cloudDocumentServiceProvider).providerLabel(metadata.provider)} (${metadata.name})',
      overwroteExistingFile: true,
      usedAppDocumentsFallback: false,
      savedPath: metadata.id,
      resolvedFileName: metadata.name,
    );
  }

  SheetData _buildSheetDataForPersist() {
    return SheetData(
      fileName: _documentImportedFileName ?? 'calcrow_sheet',
      path: _documentImportedPath,
      format: _documentImportedFormat ?? SheetFileFormat.csv,
      headers: _documentHeaders,
      valueTypes: _documentValueTypes,
      readOnlyColumns: _documentReadOnlyColumns,
      rows: _documentRows,
      hasCachedValueTypes: _documentHasCachedValueTypes,
      csvDelimiter: _documentCsvDelimiter,
      hasTypeRow: _documentHasTypeRow,
      headerRowIndex: _documentHeaderRowIndex,
      startColumnIndex: _documentStartColumnIndex,
      xlsxSheetName: _documentImportedSheetName,
      workbook: _documentImportedWorkbook,
      sourceBytes: _documentImportedSourceBytes,
    );
  }

  String _mimeTypeForFormat(SheetFileFormat format) {
    return SheetFileService.mimeTypeForFormat(format);
  }

  Future<PersistResult> _persistBytes({
    required Uint8List bytes,
    required String fileName,
    required XTypeGroup typeGroup,
    required String mimeType,
    required String confirmButtonText,
    required PersistMode mode,
  }) async {
    final preferredSafTreeUri = await _preferredSafTreeUri();
    final result = await _sheetPersistenceService.persistBytes(
      PersistRequest(
        bytes: bytes,
        fileName: fileName,
        typeGroup: typeGroup,
        mimeType: mimeType,
        confirmButtonText: confirmButtonText,
        existingPath: _documentImportedPath,
        preferredSafTreeUri: preferredSafTreeUri,
        mode: mode,
      ),
    );
    await TypeHintCache.rememberCsvTypes(
      fileName: result.resolvedFileName,
      path: result.savedPath,
      valueTypes: _documentValueTypes,
    );
    setState(() {
      _documentImportedPath = result.savedPath;
      _documentImportedFileName = result.resolvedFileName;
      _documentDocumentTarget = LocalEditorDocumentTarget(
        existingPath: result.savedPath,
      );
    });
    return result;
  }

  Future<String?> _preferredSafTreeUri() async {
    if (!ServiceLocator.isSetup) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final settings = await (() async {
      try {
        return await ref
            .read(userRepositoryProvider)
            .getUserSettings(session.uid);
      } catch (_) {
        return null;
      }
    })();
    if (settings == null) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final uri = settings.safTreeUri;
    if (uri == null || uri.isEmpty) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    return uri;
  }

  String _documentSuggestedFileName({String? defaultExtension}) {
    final current = _documentImportedFileName?.trim();
    final currentFormat = _documentImportedFormat ?? SheetFileFormat.csv;
    if (currentFormat == SheetFileFormat.gsheet) {
      if (current == null || current.isEmpty) {
        return 'calcrow_sheet';
      }
      return current;
    }
    final extension =
        defaultExtension ??
        SheetFileService.defaultExtensionForFormat(currentFormat);
    if (current == null || current.isEmpty) {
      return 'calcrow_sheet.$extension';
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
        confirmButtonText: context.l10n.importCsv,
      );

      if (!mounted || file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotReadCSVFileContent)),
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
          SnackBar(content: Text(context.l10n.theSelectedCSVIsEmpty)),
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
      final currentHeaders = ref.read(sheetPreviewProvider).headers;
      ref
          .read(sheetPreviewProvider.notifier)
          .update(
            (preview) => preview.copyWith(
              headers: parsedHeader.isNotEmpty ? parsedHeader : currentHeaders,
              rows: _allRows.take(_previewRowLimit).toList(),
              fileName: file.name,
              rowCount: _allRows.length,
            ),
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.importedRows(file.name, _allRows.length)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.importFailed('$error'))),
      );
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
    ref
        .read(sheetPreviewProvider.notifier)
        .update(
          (preview) => preview.copyWith(
            headers: headers,
            rows: const <List<String>>[],
            fileName: _importedFileName,
            rowCount: 0,
          ),
        );
  }

  void _saveRow() {
    final messenger = ScaffoldMessenger.of(context);
    final headers = _allRows.isNotEmpty
        ? ref.read(sheetPreviewProvider).headers
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
    ref
        .read(sheetPreviewProvider.notifier)
        .update(
          (preview) => preview.copyWith(
            headers: headers,
            rows: _allRows.take(_previewRowLimit).toList(),
            rowCount: _allRows.length,
          ),
        );

    messenger.showSnackBar(
      SnackBar(content: Text(context.l10n.newRowSubmitted)),
    );
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
    ).showSnackBar(SnackBar(content: Text(context.l10n.editorCleared)));
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
    return FieldTypeGuesser.isDateHeaderName(header);
  }

  DateTime? _parseDateFromCellValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    DateTime? tryBuild(int year, int month, int day) {
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      final parsed = DateTime(year, month, day);
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      return parsed;
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
        SnackBar(
          content: Text(
            context.l10n.widgetLayoutIsLockedBecauseThisCSVAlreadyHasEntries,
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
      ref
          .read(sheetPreviewProvider.notifier)
          .update((preview) => preview.copyWith(headers: headers));
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
    final headers = ref.read(sheetPreviewProvider).headers;
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
        SnackBar(content: Text(context.l10n.noEntryFoundForThisDate)),
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
    final headers = ref.read(sheetPreviewProvider).headers;

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
          context.l10n.loadedSameDateEntry(nextIndex + 1, matches.length),
        ),
      ),
    );
  }

  void _loadNextSameDateEntry() {
    final matches = _sameDateRowIndices();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noEntryFoundForThisDate)),
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
            SnackBar(content: Text(context.l10n.createNewEntryMode)),
          );
          return;
        }
        nextIndex = currentPos - 1;
      }
    }

    final targetRowIndex = matches[nextIndex];
    final targetRow = _allRows[targetRowIndex];
    final headers = ref.read(sheetPreviewProvider).headers;

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
          padding: AppLayoutConstants.pageContentPadding,
          children: [
            _TopHeader(
              isAdvancedMode: _isAdvancedMode,
              showBackButton: _isAdvancedMode || _hasDocumentSchema,
              showModeSwitch: false,
              headerTitle: _headerTitle,
              setupDone: _setupDone,
              widgetOptions: _widgetBlocks,
              visibleWidgets: _visibleWidgets,
              trailingActions: !_isAdvancedMode && _hasDocumentSchema
                  ? [
                      if (_showFieldTypes)
                        IconButton(
                          tooltip: context.l10n.hideFieldTypes,
                          onPressed: _toggleFieldTypes,
                          style: AppLayoutConstants.pageHeaderControlStyle(),
                          icon: AnimatedBuilder(
                            animation: _typeTogglePulse,
                            builder: (context, child) {
                              final pulse = _typeTogglePulse.value;
                              return Transform.scale(
                                scale: 1 + (pulse * 0.16),
                                child: Icon(
                                  Icons.accessibility_new_rounded,
                                  color: Color.lerp(
                                    theme.colorScheme.error,
                                    Colors.redAccent,
                                    pulse,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      PopupMenuButton<_EditorAdjustAction>(
                        key: const ValueKey('editor-overflow-menu'),
                        tooltip: context.l10n.adjust,
                        padding: EdgeInsets.zero,
                        style: AppLayoutConstants.pageHeaderControlStyle(),
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: _handleEditorMenuAction,
                        itemBuilder: _editorMenuItems,
                      ),
                      if (!_showsInlineSaveStatus)
                        _buildDocumentSaveStatusButton(theme),
                    ]
                  : const <Widget>[],
              onBack: _handleBack,
              onToggleMode: _toggleMode,
              onToggleWidget: _setupDone ? _toggleWidget : null,
            ),
            const SizedBox(height: AppLayoutConstants.pageHeaderBottomSpacing),
            if (!_isAdvancedMode) ...[
              _buildView(theme),
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
                          context.l10n.openingDocument,
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

  Widget _buildView(ThemeData theme) {
    if (!_hasDocumentSchema) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: TriangleLoadingIndicator(size: 20, strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.openingDocument,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasDocumentControllersReady) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: TriangleLoadingIndicator(size: 18, strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(child: Text(context.l10n.preparingEditorFields)),
            ],
          ),
        ),
      );
    }

    final dateColumn = _documentDateColumnIndex();
    final validPendingTypeSelectionColumns =
        _documentPendingTypeSelectionColumns
            .where(
              (index) =>
                  index >= 0 &&
                  index < _documentHeaders.length &&
                  index < _documentValueTypes.length,
            )
            .toList();
    final hasPendingTypeSelection = validPendingTypeSelectionColumns.isNotEmpty;
    final isSheetDocumentSource =
        _documentImportedFormat == SheetFileFormat.xlsx ||
        _documentImportedFormat == SheetFileFormat.ods ||
        _documentImportedFormat == SheetFileFormat.gsheet;
    final pendingTypeSelectionMessage = isSheetDocumentSource
        ? context.l10n.setDatatypesCalculatedFieldsReadOnly
        : context.l10n.noUsableTypeRowPickFormats;
    final canCreateOpenEndDateRow = _modeBehavior.showsDateOpenEndActions;
    final prefillDate = dateColumn == null
        ? DateTime.now()
        : _documentCurrentEditorDate(dateColumn);
    final availablePrefills = _documentPrefills
        .where((prefill) => prefill.isAvailableOn(prefillDate))
        .toList(growable: false);

    return Column(
      children: [
        if (hasPendingTypeSelection) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.confirmFieldFormats,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pendingTypeSelectionMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ...validPendingTypeSelectionColumns.map((index) {
                    return _buildPendingTypeSelector(index);
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _confirmPendingTypes,
                      child: Text(context.l10n.useTheseFormats),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!hasPendingTypeSelection) ...[
          if (availablePrefills.isNotEmpty) ...[
            DocumentPrefillSelector(
              label: context.l10n.prefill,
              prefills: availablePrefills,
              onSelected: _applyDocumentPrefill,
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List<Widget>.generate(_documentHeaders.length, (
                  index,
                ) {
                  final header = _documentHeaders[index];
                  final type = index < _documentValueTypes.length
                      ? _documentValueTypes[index]
                      : 'text';
                  if (index >= _documentControllers.length) {
                    return const SizedBox.shrink();
                  }
                  final isFormulaField =
                      index < _documentReadOnlyColumns.length &&
                      _documentReadOnlyColumns[index];
                  if (isFormulaField) {
                    return const SizedBox.shrink();
                  }
                  final isReadOnly = _isFixedDateField(index);
                  final isDurationField =
                      _isDurationType(type) || _isTimespanField(header);
                  final normalizedType = type.trim().toLowerCase();
                  final helperType = _localizedEditorTypeLabelFor(
                    context.l10n,
                    type,
                  );
                  final helperText = _showFieldTypes
                      ? isReadOnly
                            ? context.l10n.typeLabelFixed(helperType)
                            : isDurationField
                            ? context.l10n.typeLabelHoursAndMinutes(helperType)
                            : context.l10n.typeLabel(helperType)
                      : null;
                  final inputField = Focus(
                    onFocusChange: _handleDocumentFieldFocusChanged,
                    child: TypeBasedInputField(
                      controller: _documentControllers[index],
                      labelText: header,
                      rawType: type,
                      readOnly: isReadOnly,
                      forceDuration: isDurationField,
                      helperText: helperText,
                      minLines: header.toLowerCase().contains('note') ? 2 : 1,
                      maxLines: header.toLowerCase().contains('note') ? 4 : 1,
                      parseDate: _parseDateFromCellValue,
                      formatDate: _formatDate,
                      onChanged: () {
                        _handleDocumentFieldChanged();
                        if (normalizedType == 'date' ||
                            normalizedType == 'time' ||
                            _isBooleanType(normalizedType)) {
                          unawaited(_requestDocumentSave());
                        }
                      },
                    ),
                  );
                  return Padding(
                    key: ValueKey<String>(
                      '${_documentEditingRowIndex}_${index}_$header',
                    ),
                    padding: EdgeInsets.only(
                      bottom: index == _documentHeaders.length - 1 ? 0 : 10,
                    ),
                    child: isReadOnly && index == dateColumn
                        ? Row(
                            children: [
                              Expanded(child: inputField),
                              const SizedBox(width: 8),
                              IconButton(
                                key: const ValueKey(
                                  'clear-document-input-fields',
                                ),
                                tooltip: context.l10n.clearEditableFields,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 42,
                                  height: 42,
                                ),
                                onPressed: _clearEditableFields,
                                icon: const Icon(
                                  Icons.backspace_outlined,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildDocumentSaveStatusButton(theme),
                            ],
                          )
                        : inputField,
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
                    child: OutlinedButton(
                      onPressed: _pickFromCurrentSheetForMode,
                      child: Text(_modeBehavior.pickButtonLabel(context.l10n)),
                    ),
                  ),
                  if (_modeBehavior.showsTextEntryActions) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _createNewTextEntry,
                        child: Text(context.l10n.newLabel),
                      ),
                    ),
                  ] else if (canCreateOpenEndDateRow) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _createNewDateOpenEndRow,
                        child: Text(context.l10n.newLabel),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _clearEditableFields,
                      tooltip: context.l10n.clearEditableFields,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentSaveStatusButton(ThemeData theme) {
    final allChangesSaved =
        !_isDocumentSaving && !_hasUnsavedRowEdits && !_documentSaveFailed;
    return IconButton(
      key: const ValueKey('document-save-status'),
      tooltip: context.l10n.save,
      style: AppLayoutConstants.pageHeaderControlStyle(),
      onPressed: _handleSaveStatusPressed,
      icon: Icon(
        _isDocumentSaving ? Icons.sync_rounded : Icons.save_rounded,
        color: allChangesSaved ? Colors.green : theme.colorScheme.error,
      ),
    );
  }

  Widget _buildPendingTypeSelector(int index) {
    final header = _documentHeaders[index];
    final currentType = _editorTypeOptionFor(_documentValueTypes[index]);
    final typeOptions = _modeBehavior.typeOptionsForColumn(this, index);
    final selectedType = typeOptions.contains(currentType)
        ? currentType
        : typeOptions.first;
    final typeDropdown = TypeDropdownList<String>(
      key: ValueKey<String>(
        'field-type-options-$index-${typeOptions.join(',')}',
      ),
      initialValue: selectedType,
      labelText: header,
      options: typeOptions,
      labelFor: (type) => _pendingTypeLabel(
        localizations: context.l10n,
        index: index,
        type: type,
      ),
      iconFor: TypeDropdownList.iconForTypeLabel,
      onChanged: (value) => _handlePendingTypeChanged(index, value),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: typeDropdown,
    );
  }

  String _pendingTypeLabel({
    required AppLocalizations localizations,
    required int index,
    required String type,
  }) {
    if (type == 'money') {
      if (FieldTypeGuesser.isMoneyType(_documentValueTypes[index])) {
        return _localizedEditorTypeLabelFor(
          localizations,
          _documentValueTypes[index],
        );
      }
      return localizations.money;
    }
    return type;
  }

  bool _isTimeType(String rawType) {
    return rawType.trim().toLowerCase().contains('time');
  }

  bool _isDurationType(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type.contains('duration') || type.contains('timespan');
  }

  bool _isBooleanType(String rawType) {
    return FieldTypeGuesser.isBooleanType(rawType);
  }

  String _initialControllerValue({
    required int columnIndex,
    required List<String> values,
  }) {
    final value = columnIndex < values.length ? values[columnIndex].trim() : '';
    if (columnIndex >= _documentValueTypes.length ||
        !_isBooleanType(_documentValueTypes[columnIndex])) {
      return value;
    }
    if (value.isEmpty) return '';
    if (value.toUpperCase() == 'TRUE') return 'TRUE';
    if (value.toUpperCase() == 'FALSE') return 'FALSE';
    return value;
  }

  bool _looksLikeDurationValue(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return true;
    return RegExp(r'^\d+([.,]\d+)?$').hasMatch(value) ||
        RegExp(r'^\d{1,3}:\d{2}(:\d{2})?$').hasMatch(value);
  }

  bool _isTimespanField(String header) {
    final value = header.trim().toLowerCase();
    return value.contains('pause') || value.contains('break');
  }

  bool _isFixedDateField(int columnIndex) {
    return (_documentOpenMode == EditorOpenMode.dateBased ||
            _documentOpenMode == EditorOpenMode.dateBasedOpenEnd) &&
        columnIndex == _documentDateColumnIndex();
  }

  Widget _buildSetupView(ThemeData theme) {
    final setupTip = _supportsLocalFileEditing
        ? context.l10n.localEditingTip
        : context.l10n.cloudEditingTip;

    return Column(
      children: [
        _SetupCard(
          title: context.l10n.createNewCSV,
          subtitle: context.l10n.startFromAFreshMonthlySheet,
          icon: Icons.arrow_forward_ios_rounded,
          onTap: _createNewCsv,
        ),
        const SizedBox(height: 10),
        if (_supportsLocalFileEditing) ...[
          _SetupCard(
            title: context.l10n.selectLocalFile,
            subtitle:
                _importedFileName ??
                context.l10n.openAnExistingCsvFromThisDevice,
            icon: Icons.folder_open_rounded,
            onTap: _importCsv,
          ),
          const SizedBox(height: 14),
        ],
        Text(setupTip, style: theme.textTheme.bodyMedium),
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
                      label: Text(context.l10n.previous),
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
                  tooltip: context.l10n.clearEditor,
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
      if (_hasDocumentSchema) {
        final fileName = _documentImportedFileName?.trim();
        return fileName == null || fileName.isEmpty
            ? context.l10n.editor
            : fileName;
      }
      return context.l10n.getStarted;
    }
    return _setupDone
        ? context.l10n.calcrowDailyEditor
        : context.l10n.getStarted;
  }

  void _handleBack() {
    if (!_isAdvancedMode) {
      if (_hasDocumentSchema) {
        _exitEditor();
        if (widget.onBackToSelection != null) {
          widget.onBackToSelection!();
        } else if (widget.showBackToSelection) {
          Navigator.of(context).maybePop();
        }
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
        _documentTextSelectionColumnIndex = null;
        _documentTextSelectionValue = null;
      }
    });
  }

  void _exitEditor() {
    final oldControllers = _documentControllers;
    setState(() {
      _documentImportedFileName = null;
      _documentImportedPath = null;
      _documentImportedSheetName = null;
      _documentImportedFormat = null;
      _documentCsvDelimiter = ',';
      _documentHasTypeRow = false;
      _documentHasCachedValueTypes = false;
      _documentHeaderRowIndex = 0;
      _documentStartColumnIndex = 0;
      _documentHeaders = const <String>[];
      _documentValueTypes = const <String>[];
      _documentReadOnlyColumns = const <bool>[];
      _documentRows = const <List<String>>[];
      _documentPrefills = const <DocumentPrefill>[];
      _documentPrefillKey = null;
      _documentControllers = const <TextEditingController>[];
      _documentEditingRowIndex = 0;
      _documentImportedWorkbook = null;
      _documentImportedSourceBytes = null;
      _documentDocumentTarget = null;
      _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _documentTextSelectionColumnIndex = null;
      _documentTextSelectionValue = null;
      _isOpeningDocument = false;
      _documentSaveFailed = false;
      _saveDocumentAgain = false;
      _showQueuedSaveError = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
    ref
        .read(sheetPreviewProvider.notifier)
        .update(
          (preview) => preview.copyWith(
            clearSelectedRowIndex: true,
            clearOnSaveAsIs: true,
          ),
        );
  }
}

class _EditorTargetSelection {
  const _EditorTargetSelection({
    required this.usedDateColumn,
    required this.foundMatchingDateRow,
    required this.targetRowIndex,
  });

  final bool usedDateColumn;
  final bool foundMatchingDateRow;
  final int targetRowIndex;
}

class _OpeningSelection {
  const _OpeningSelection({
    required this.targetRowIndex,
    required this.textColumnIndex,
    required this.textValue,
  });

  final int targetRowIndex;
  final int? textColumnIndex;
  final String? textValue;
}

class _TextTargetSelection {
  const _TextTargetSelection({
    required this.columnIndex,
    required this.rowIndex,
    required this.value,
  });

  final int columnIndex;
  final int rowIndex;
  final String value;
}

abstract class EditorDocumentTarget {
  const EditorDocumentTarget();
}

class LocalEditorDocumentTarget extends EditorDocumentTarget {
  const LocalEditorDocumentTarget({required this.existingPath});

  final String? existingPath;
}

class CloudEditorDocumentTarget extends EditorDocumentTarget {
  const CloudEditorDocumentTarget({
    required this.provider,
    required this.fileId,
    required this.fileName,
    required this.mimeType,
  });

  final CloudSyncProvider provider;
  final String fileId;
  final String fileName;
  final String mimeType;
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.isAdvancedMode,
    required this.showBackButton,
    required this.showModeSwitch,
    required this.headerTitle,
    required this.setupDone,
    required this.widgetOptions,
    required this.visibleWidgets,
    required this.trailingActions,
    required this.onBack,
    required this.onToggleMode,
    required this.onToggleWidget,
  });

  final bool isAdvancedMode;
  final bool showBackButton;
  final bool showModeSwitch;
  final String headerTitle;
  final bool setupDone;
  final List<_WidgetBlock> widgetOptions;
  final Set<_WidgetBlock> visibleWidgets;
  final List<Widget> trailingActions;
  final VoidCallback onBack;
  final VoidCallback onToggleMode;
  final ValueChanged<_WidgetBlock>? onToggleWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          Transform.translate(
            offset: const Offset(
              0,
              AppLayoutConstants.pageHeaderControlVerticalOffset,
            ),
            child: IconButton(
              tooltip: context.l10n.back,
              onPressed: onBack,
              alignment: Alignment.topLeft,
              style: AppLayoutConstants.pageHeaderControlStyle(),
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppLayoutConstants.pageHeaderIconRadius,
                ),
                child: Image.asset(
                  'assets/images/AppIcon_1024_square.png',
                  key: const ValueKey('editor-app-icon'),
                  width: AppLayoutConstants.pageHeaderIconSize,
                  height: AppLayoutConstants.pageHeaderIconSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppLayoutConstants.pageHeaderIconGap),
        ],
        Expanded(
          child: Text(
            headerTitle,
            key: const ValueKey('editor-page-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pageTitle,
          ),
        ),
        if (isAdvancedMode && setupDone)
          _alignedHeaderControl(
            PopupMenuButton<_WidgetBlock>(
              tooltip: context.l10n.manageWidgets,
              padding: EdgeInsets.zero,
              style: AppLayoutConstants.pageHeaderControlStyle(),
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
          ),
        if (isAdvancedMode && setupDone) const SizedBox(width: 6),
        if (showModeSwitch)
          _alignedHeaderControl(
            TextButton(
              onPressed: onToggleMode,
              child: Text(isAdvancedMode ? 'Advanced' : 'Core'),
            ),
          ),
        if (showModeSwitch) const SizedBox(width: 6),
        ...trailingActions.map(_alignedHeaderControl),
      ],
    );
  }

  static Widget _alignedHeaderControl(Widget child) {
    return Transform.translate(
      offset: const Offset(
        0,
        AppLayoutConstants.pageHeaderControlVerticalOffset,
      ),
      child: SizedBox(
        height: AppLayoutConstants.pageHeaderIconSize,
        child: child,
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
  final VoidCallback? onTap;

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
