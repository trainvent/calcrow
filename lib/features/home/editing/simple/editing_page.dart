import 'dart:async';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcrow/app/widgets/triangle_loading_indicator.dart';
import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/notes_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/row_definement_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/smart_data_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/wellbeing_widget.dart';
import 'package:calcrow/features/home/editing/advanced/widgets/workhours_widget.dart';
import 'package:calcrow/core/data/services/simple_cloud_document_service.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/simple_sheet_persistence_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/simple_type_hint_cache.dart';
import 'package:calcrow/features/home/sheet/sheet_preview_store.dart';
import 'package:calcrow/features/home/editing/simple/widgets/select_time_widget.dart';
import 'package:calcrow/features/home/editing/simple/widgets/timespan_widget.dart';
import 'package:open_filex/open_filex.dart';

enum _WidgetBlock { rowDefinement, workhours, smartData, wellbeing, notes }

enum SimpleEditorOpenMode { dateBased, dateBasedOpenEnd, textBased }

class EditingPage extends StatefulWidget {
  const EditingPage({
    super.key,
    required this.initialSheetData,
    required this.initialDocumentTarget,
    required this.initialOpenMode,
    this.initialSuccessMessage,
    this.showBackToSelection = false,
    this.onBackToSelection,
  });

  final SimpleSheetData initialSheetData;
  final SimpleEditorDocumentTarget initialDocumentTarget;
  final SimpleEditorOpenMode initialOpenMode;
  final String? initialSuccessMessage;
  final bool showBackToSelection;
  final VoidCallback? onBackToSelection;

  @override
  State<EditingPage> createState() => _EditingPageState();
}

class _EditingPageState extends State<EditingPage> {
  static const MethodChannel _platformChannel = MethodChannel(
    'de.lemarq.calcrow/file_open',
  );

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
  int _simpleHeaderRowIndex = 0;
  int _simpleStartColumnIndex = 0;
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
  SimpleEditorDocumentTarget? _simpleDocumentTarget;
  SimpleEditorOpenMode _simpleOpenMode = SimpleEditorOpenMode.dateBasedOpenEnd;
  int? _simpleTextSelectionColumnIndex;
  String? _simpleTextSelectionValue;

  @override
  void initState() {
    super.initState();
    _isAdvancedMode = false;
    _simpleOpenMode = widget.initialOpenMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadInitialSimpleDocument());
    });
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

  Future<void> _loadInitialSimpleDocument() async {
    final loaded = await _loadSimpleProfileData(
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

    final path = _simpleImportedPath?.trim();
    if (_simpleDocumentTarget is LocalSimpleEditorDocumentTarget &&
        path != null &&
        path.isNotEmpty) {
      final opened = await _openLocalFileExternally(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        opened
            ? const SnackBar(content: Text('Opened document in another app.'))
            : const SnackBar(
                content: Text('Could not open the file in another app.'),
              ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Choose a document from Get Started.')),
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
    final format = _simpleImportedFormat ?? SimpleFileFormat.csv;
    return SimpleSheetFileService.mimeTypeForFormat(format);
  }

  Future<bool> _loadSimpleProfileData(
    SimpleSheetData sheetData, {
    SimpleEditorDocumentTarget? target,
  }) async {
    final selection = await _resolveSimpleOpeningSelection(sheetData);
    if (!mounted || selection == null) return false;

    setState(() {
      _simpleImportedFileName = sheetData.fileName;
      _simpleImportedPath = sheetData.path;
      _simpleImportedFormat = sheetData.format;
      _simpleCsvDelimiter = sheetData.csvDelimiter;
      _simpleHasTypeRow = sheetData.hasTypeRow;
      _simpleHeaderRowIndex = sheetData.headerRowIndex;
      _simpleStartColumnIndex = sheetData.startColumnIndex;
      _simpleImportedSheetName = sheetData.xlsxSheetName;
      _simpleHeaders = sheetData.headers;
      _simpleValueTypes = sheetData.valueTypes;
      _simpleReadOnlyColumns = sheetData.readOnlyColumns;
      _simplePendingTypeSelectionColumns =
          sheetData.pendingTypeSelectionColumns;
      _simpleRows = sheetData.rows;
      _simpleImportedWorkbook = sheetData.workbook;
      _simpleImportedSourceBytes = sheetData.sourceBytes;
      _simpleDocumentTarget =
          target ??
          LocalSimpleEditorDocumentTarget(existingPath: sheetData.path);
      _simpleTextSelectionColumnIndex = selection.textColumnIndex;
      _simpleTextSelectionValue = selection.textValue;
    });

    _selectSimpleEditorTargetRow(
      preferredRowIndex: selection.targetRowIndex,
      preserveSelectedTextTarget: true,
    );
    _publishSimpleRowsToPreview();
    unawaited(_rememberSimpleOpenConfiguration(sheetData, target: target));
    return true;
  }

  Future<void> _rememberSimpleOpenConfiguration(
    SimpleSheetData sheetData, {
    SimpleEditorDocumentTarget? target,
  }) async {
    if (!ServiceLocator.isSetup) return;
    final session = ServiceLocator.authService.currentSession;
    if (session == null) return;

    final openMode = _simpleOpenMode.name;
    final fileName = sheetData.fileName.trim().isEmpty
        ? 'document'
        : sheetData.fileName.trim();
    SimpleRecentOpenConfig? config;
    if (target is CloudSimpleEditorDocumentTarget) {
      config = SimpleRecentOpenConfig(
        source: switch (target.provider) {
          CloudSyncProvider.googleDrive =>
            SimpleRecentDocumentSource.googleDrive,
          CloudSyncProvider.webDav => SimpleRecentDocumentSource.webDav,
        },
        fileName: target.fileName,
        openMode: openMode,
        fileId: target.fileId,
        mimeType: target.mimeType,
      );
    } else {
      final path =
          (target is LocalSimpleEditorDocumentTarget
                  ? target.existingPath
                  : sheetData.path)
              ?.trim();
      if (path != null && path.isNotEmpty) {
        config = SimpleRecentOpenConfig(
          source: SimpleRecentDocumentSource.local,
          fileName: fileName,
          openMode: openMode,
          path: path,
        );
      }
    }

    if (config == null) return;
    try {
      await ServiceLocator.userRepository.rememberSimpleOpenConfig(
        uid: session.uid,
        config: config,
      );
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

  Future<_SimpleOpeningSelection?> _resolveSimpleOpeningSelection(
    SimpleSheetData sheetData,
  ) async {
    switch (_simpleOpenMode) {
      case SimpleEditorOpenMode.dateBased:
        final selection = _selectSimpleEditorTargetRowForSheetData(sheetData);
        if (!selection.usedDateColumn || !selection.foundMatchingDateRow) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Date-based opening is blocked because ${_formatDate(DateTime.now())} was not found in the detected date column.',
              ),
            ),
          );
          return null;
        }
        return _SimpleOpeningSelection(
          targetRowIndex: selection.targetRowIndex,
          textColumnIndex: null,
          textValue: null,
        );
      case SimpleEditorOpenMode.dateBasedOpenEnd:
        final selection = _selectSimpleEditorTargetRowForSheetData(sheetData);
        if (!selection.usedDateColumn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Date-based open-end needs a detected date column.',
              ),
            ),
          );
          return null;
        }
        return _SimpleOpeningSelection(
          targetRowIndex: selection.targetRowIndex,
          textColumnIndex: null,
          textValue: null,
        );
      case SimpleEditorOpenMode.textBased:
        final textSelection = await _showSimpleTextEntryPicker(sheetData);
        if (textSelection == null) return null;
        return _SimpleOpeningSelection(
          targetRowIndex: textSelection.rowIndex,
          textColumnIndex: textSelection.columnIndex,
          textValue: textSelection.value,
        );
    }
  }

  _SimpleEditorTargetSelection _selectSimpleEditorTargetRow({
    int? preferredRowIndex,
    bool preserveSelectedTextTarget = false,
  }) {
    if (!_hasSimpleSchema) {
      return const _SimpleEditorTargetSelection(
        usedDateColumn: false,
        foundMatchingDateRow: false,
        targetRowIndex: 0,
      );
    }

    final dateColumn = _simpleDateColumnIndex();
    final today = DateTime.now();
    int targetRowIndex = _simpleRows.length;
    var foundMatchingDateRow = false;

    if (preferredRowIndex != null &&
        preferredRowIndex >= 0 &&
        preferredRowIndex <= _simpleRows.length) {
      targetRowIndex = preferredRowIndex;
      if (preferredRowIndex < _simpleRows.length) {
        foundMatchingDateRow =
            dateColumn != null &&
            dateColumn < _simpleRows[preferredRowIndex].length &&
            (() {
              final rowDate = _parseDateFromCellValue(
                _simpleRows[preferredRowIndex][dateColumn],
              );
              return rowDate != null && _isSameCalendarDate(rowDate, today);
            })();
      }
    } else if (dateColumn != null) {
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
        foundMatchingDateRow = true;
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
    if (preserveSelectedTextTarget &&
        _simpleTextSelectionColumnIndex != null &&
        _simpleTextSelectionValue != null) {
      final selectionColumn = _simpleTextSelectionColumnIndex!;
      final selectionValue = _simpleTextSelectionValue!.trim();
      if (selectionValue.isNotEmpty &&
          selectionColumn < draft.length &&
          draft[selectionColumn].trim().isEmpty) {
        draft[selectionColumn] = selectionValue;
      }
    }
    if (dateColumn != null && (draft[dateColumn].trim().isEmpty)) {
      draft[dateColumn] = _formatDate(today);
    }

    _replaceSimpleControllers(draft);
    setState(() {
      _simpleEditingRowIndex = targetRowIndex;
      if (!preserveSelectedTextTarget) {
        _simpleTextSelectionColumnIndex = null;
        _simpleTextSelectionValue = null;
      }
    });
    return _SimpleEditorTargetSelection(
      usedDateColumn: dateColumn != null,
      foundMatchingDateRow: foundMatchingDateRow,
      targetRowIndex: targetRowIndex,
    );
  }

  _SimpleEditorTargetSelection _selectSimpleEditorTargetRowForSheetData(
    SimpleSheetData sheetData,
  ) {
    if (sheetData.headers.isEmpty) {
      return const _SimpleEditorTargetSelection(
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
      return const _SimpleEditorTargetSelection(
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
          return _SimpleEditorTargetSelection(
            usedDateColumn: true,
            foundMatchingDateRow: true,
            targetRowIndex: rowIndex,
          );
        }
      }
    }

    return _SimpleEditorTargetSelection(
      usedDateColumn: true,
      foundMatchingDateRow: fallbackMatchIndex != null,
      targetRowIndex: fallbackMatchIndex ?? sheetData.rows.length,
    );
  }

  List<int> _simpleTextSelectableColumnsForSheetData(
    SimpleSheetData sheetData,
  ) {
    return _simpleTextSelectableColumnsForSheetDataInternal(sheetData);
  }

  List<int> _simpleDateGuidingColumnsForSheetData(SimpleSheetData sheetData) {
    final dateColumn = _dateColumnIndexForSheetData(sheetData);
    return _simpleTextSelectableColumnsForSheetDataInternal(
      sheetData,
      excludedColumnIndex: dateColumn,
    );
  }

  List<int> _simpleTextSelectableColumnsForSheetDataInternal(
    SimpleSheetData sheetData, {
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

  int? _dateColumnIndexForSheetData(SimpleSheetData sheetData) {
    final typeIndex = sheetData.valueTypes.indexWhere(
      (type) => type.trim().toLowerCase() == 'date',
    );
    if (typeIndex >= 0) return typeIndex;
    final headerIndex = sheetData.headers.indexWhere(
      (header) => _isDateHeaderName(header),
    );
    if (headerIndex >= 0) return headerIndex;
    return null;
  }

  bool _supportsTextBasedOpening(String rawType) {
    final type = rawType.trim().toLowerCase();
    return type.isEmpty ||
        type.contains('text') ||
        type.contains('email') ||
        type.contains('phone');
  }

  List<String> _simpleDistinctTextValuesForSheetData(
    SimpleSheetData sheetData, {
    required int columnIndex,
    bool Function(List<String> row)? rowFilter,
  }) {
    final values = <String>{};
    for (final row in sheetData.rows) {
      if (rowFilter != null && !rowFilter(row)) continue;
      if (columnIndex >= row.length) continue;
      final value = row[columnIndex].trim();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  int? _findSimpleRowIndexForTextValue(
    SimpleSheetData sheetData, {
    required int columnIndex,
    required String value,
    bool Function(List<String> row)? rowFilter,
  }) {
    for (var rowIndex = 0; rowIndex < sheetData.rows.length; rowIndex++) {
      final row = sheetData.rows[rowIndex];
      if (rowFilter != null && !rowFilter(row)) continue;
      if (columnIndex >= row.length) continue;
      if (row[columnIndex].trim() == value) {
        return rowIndex;
      }
    }
    return null;
  }

  Future<_SimpleTextTargetSelection?> _showSimpleTextEntryPicker(
    SimpleSheetData sheetData,
  ) async {
    final candidateColumns = _simpleTextSelectableColumnsForSheetData(
      sheetData,
    );
    if (candidateColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Text-based opening needs at least one editable text column with entry names.',
          ),
        ),
      );
      return null;
    }

    final initialColumnIndex =
        (_simpleTextSelectionColumnIndex != null &&
            candidateColumns.contains(_simpleTextSelectionColumnIndex))
        ? _simpleTextSelectionColumnIndex!
        : candidateColumns.first;

    final result = await showDialog<_SimpleTextTargetSelection>(
      context: context,
      builder: (dialogContext) {
        var selectedColumnIndex = initialColumnIndex;
        var availableValues = _simpleDistinctTextValuesForSheetData(
          sheetData,
          columnIndex: selectedColumnIndex,
        );
        String? selectedValue =
            (_simpleTextSelectionValue != null &&
                availableValues.contains(_simpleTextSelectionValue))
            ? _simpleTextSelectionValue
            : (availableValues.isEmpty ? null : availableValues.first);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Open column entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedColumnIndex,
                    decoration: const InputDecoration(labelText: 'Entry field'),
                    items: candidateColumns
                        .map(
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(sheetData.headers[index]),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedColumnIndex = value;
                        availableValues = _simpleDistinctTextValuesForSheetData(
                          sheetData,
                          columnIndex: selectedColumnIndex,
                        );
                        selectedValue = availableValues.isEmpty
                            ? null
                            : availableValues.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (availableValues.isEmpty)
                    const Text(
                      'No non-empty entries were found in this field yet.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedValue,
                      decoration: const InputDecoration(
                        labelText: 'Entry name',
                      ),
                      items: availableValues
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedValue = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedValue == null
                      ? null
                      : () {
                          final rowIndex = _findSimpleRowIndexForTextValue(
                            sheetData,
                            columnIndex: selectedColumnIndex,
                            value: selectedValue!,
                          );
                          if (rowIndex == null) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'The selected entry could not be found anymore.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(
                            _SimpleTextTargetSelection(
                              columnIndex: selectedColumnIndex,
                              rowIndex: rowIndex,
                              value: selectedValue!,
                            ),
                          );
                        },
                  child: const Text('Open Entry'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<_SimpleTextTargetSelection?> _showSimpleTodayEntryPicker(
    SimpleSheetData sheetData,
  ) async {
    final dateColumn = _dateColumnIndexForSheetData(sheetData);
    if (dateColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date-based open-end needs a detected date column.'),
        ),
      );
      return null;
    }

    final targetDate = _simpleCurrentEditorDate(dateColumn);
    bool rowFilter(List<String> row) {
      if (dateColumn >= row.length) return false;
      final rowDate = _parseDateFromCellValue(row[dateColumn]);
      return rowDate != null && _isSameCalendarDate(rowDate, targetDate);
    }

    final candidateColumns = _simpleDateGuidingColumnsForSheetData(sheetData);
    if (candidateColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick Row needs at least one editable text column.'),
        ),
      );
      return null;
    }

    final initialColumnIndex =
        (_simpleTextSelectionColumnIndex != null &&
            candidateColumns.contains(_simpleTextSelectionColumnIndex))
        ? _simpleTextSelectionColumnIndex!
        : candidateColumns.first;

    final result = await showDialog<_SimpleTextTargetSelection>(
      context: context,
      builder: (dialogContext) {
        var selectedColumnIndex = initialColumnIndex;
        var availableValues = _simpleDistinctTextValuesForSheetData(
          sheetData,
          columnIndex: selectedColumnIndex,
          rowFilter: rowFilter,
        );
        String? selectedValue =
            (_simpleTextSelectionValue != null &&
                availableValues.contains(_simpleTextSelectionValue))
            ? _simpleTextSelectionValue
            : (availableValues.isEmpty ? null : availableValues.first);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Open today entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedColumnIndex,
                    decoration: const InputDecoration(
                      labelText: 'Guiding field',
                    ),
                    items: candidateColumns
                        .map(
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(sheetData.headers[index]),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedColumnIndex = value;
                        availableValues = _simpleDistinctTextValuesForSheetData(
                          sheetData,
                          columnIndex: selectedColumnIndex,
                          rowFilter: rowFilter,
                        );
                        selectedValue = availableValues.isEmpty
                            ? null
                            : availableValues.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (availableValues.isEmpty)
                    const Text(
                      'No entries for this date were found in this field yet.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedValue,
                      decoration: const InputDecoration(
                        labelText: 'Today entry',
                      ),
                      items: availableValues
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedValue = value;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedValue == null
                      ? null
                      : () {
                          final rowIndex = _findSimpleRowIndexForTextValue(
                            sheetData,
                            columnIndex: selectedColumnIndex,
                            value: selectedValue!,
                            rowFilter: rowFilter,
                          );
                          if (rowIndex == null) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'The selected entry could not be found anymore.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(
                            _SimpleTextTargetSelection(
                              columnIndex: selectedColumnIndex,
                              rowIndex: rowIndex,
                              value: selectedValue!,
                            ),
                          );
                        },
                  child: const Text('Open Entry'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  DateTime _simpleCurrentEditorDate(int dateColumn) {
    if (dateColumn >= 0 && dateColumn < _simpleControllers.length) {
      final parsed = _parseDateFromCellValue(
        _simpleControllers[dateColumn].text,
      );
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  bool _rowHasEditableEmptyCell(List<String> row, {required int dateColumn}) {
    for (var i = 0; i < _simpleHeaders.length; i++) {
      final isReadOnly =
          i < _simpleReadOnlyColumns.length && _simpleReadOnlyColumns[i];
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
      if (_simpleTextSelectionColumnIndex != null &&
          _simpleTextSelectionColumnIndex! < _simpleHeaders.length &&
          _simpleEditingRowIndex >= 0 &&
          _simpleEditingRowIndex < _simpleRows.length &&
          _simpleTextSelectionColumnIndex! <
              _simpleRows[_simpleEditingRowIndex].length) {
        final nextValue =
            _simpleRows[_simpleEditingRowIndex][_simpleTextSelectionColumnIndex!]
                .trim();
        _simpleTextSelectionValue = nextValue.isEmpty ? null : nextValue;
      }
    });
    _publishSimpleRowsToPreview();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saveResult = await _persistSimpleSheet(mode: mode);
      if (!mounted) return;
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
    if (_simpleOpenMode != SimpleEditorOpenMode.dateBased) {
      return null;
    }
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
      final isReadOnly =
          i < _simpleReadOnlyColumns.length && _simpleReadOnlyColumns[i];
      if (i == dateColumn || isReadOnly) continue;
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

  Future<void> _pickSimpleTextEntryFromCurrentSheet() async {
    final selection = await _showSimpleTextEntryPicker(
      _buildSimpleSheetDataForPersist(),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _simpleTextSelectionColumnIndex = selection.columnIndex;
      _simpleTextSelectionValue = selection.value;
    });
    _selectSimpleEditorTargetRow(
      preferredRowIndex: selection.rowIndex,
      preserveSelectedTextTarget: true,
    );
  }

  Future<void> _pickSimpleTodayEntryFromCurrentSheet() async {
    final selection = await _showSimpleTodayEntryPicker(
      _buildSimpleSheetDataForPersist(),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _simpleTextSelectionColumnIndex = selection.columnIndex;
      _simpleTextSelectionValue = selection.value;
    });
    _selectSimpleEditorTargetRow(
      preferredRowIndex: selection.rowIndex,
      preserveSelectedTextTarget: true,
    );
  }

  void _createNewSimpleTextEntry() {
    final candidateColumns = _simpleTextSelectableColumnsForSheetData(
      _buildSimpleSheetDataForPersist(),
    );
    if (candidateColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Text-based opening needs at least one editable text column for new entries.',
          ),
        ),
      );
      return;
    }

    final textColumnIndex =
        (_simpleTextSelectionColumnIndex != null &&
            candidateColumns.contains(_simpleTextSelectionColumnIndex))
        ? _simpleTextSelectionColumnIndex!
        : candidateColumns.first;
    final draft = List<String>.filled(_simpleHeaders.length, '');
    _replaceSimpleControllers(draft);
    setState(() {
      _simpleEditingRowIndex = _simpleRows.length;
      _simpleTextSelectionColumnIndex = textColumnIndex;
      _simpleTextSelectionValue = null;
    });
  }

  void _createNewSimpleDateOpenEndRow() {
    final dateColumn = _simpleDateColumnIndex();
    if (dateColumn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date-based open-end needs a detected date column.'),
        ),
      );
      return;
    }

    final draft = List<String>.filled(_simpleHeaders.length, '');
    draft[dateColumn] = _formatDate(DateTime.now());
    _replaceSimpleControllers(draft);
    setState(() {
      _simpleEditingRowIndex = _simpleRows.length;
      _simpleTextSelectionColumnIndex = null;
      _simpleTextSelectionValue = null;
    });
  }

  Future<SimplePersistResult> _persistSimpleSheet({
    required SimplePersistMode mode,
  }) async {
    final target = _simpleDocumentTarget;
    if (target is CloudSimpleEditorDocumentTarget) {
      return _persistSimpleCloud(target: target);
    }
    final format = _simpleImportedFormat;
    if (format == SimpleFileFormat.xlsx) {
      return _persistSimpleXlsx(mode: mode);
    }
    if (format == SimpleFileFormat.ods) {
      return _persistSimpleOds(mode: mode);
    }
    if (format == SimpleFileFormat.gsheet) {
      return _persistSimpleCloud(
        target: _simpleDocumentTarget as CloudSimpleEditorDocumentTarget,
      );
    }
    return _persistSimpleCsv(mode: mode);
  }

  Future<SimplePersistResult> _persistSimpleCsv({
    required SimplePersistMode mode,
  }) async {
    final bytes = SimpleSheetFileService.buildBytes(
      _buildSimpleSheetDataForPersist(),
    );
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
    final bytes = SimpleSheetFileService.buildBytes(
      _buildSimpleSheetDataForPersist(),
    );

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
    final bytes = SimpleSheetFileService.buildBytes(
      _buildSimpleSheetDataForPersist(),
    );

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

  Future<SimplePersistResult> _persistSimpleCloud({
    required CloudSimpleEditorDocumentTarget target,
  }) async {
    final simpleData = _buildSimpleSheetDataForPersist();
    final format = _simpleImportedFormat ?? SimpleFileFormat.csv;
    final bytes = target.mimeType == GoogleDriveSyncService.googleSheetsMimeType
        ? Uint8List(0)
        : SimpleSheetFileService.buildBytes(simpleData);
    final mimeType = _mimeTypeForFormat(format);
    final fileName = _simpleSuggestedFileName(
      defaultExtension: SimpleSheetFileService.defaultExtensionForFormat(
        format,
      ),
    );

    final metadata = await ServiceLocator.simpleCloudDocumentService
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
          simpleData: simpleData,
        );
    if (format == SimpleFileFormat.csv) {
      await SimpleTypeHintCache.rememberCsvTypes(
        fileName: metadata.name,
        path: metadata.id,
        valueTypes: _simpleValueTypes,
      );
    }
    setState(() {
      _simpleImportedFileName = metadata.name;
      _simpleImportedPath = null;
      _simpleDocumentTarget = CloudSimpleEditorDocumentTarget(
        provider: metadata.provider,
        fileId: metadata.id,
        fileName: metadata.name,
        mimeType: metadata.mimeType,
      );
    });

    return SimplePersistResult(
      locationLabel:
          '${ServiceLocator.simpleCloudDocumentService.providerLabel(metadata.provider)} (${metadata.name})',
      overwroteExistingFile: true,
      usedAppDocumentsFallback: false,
      savedPath: metadata.id,
      resolvedFileName: metadata.name,
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
      headerRowIndex: _simpleHeaderRowIndex,
      startColumnIndex: _simpleStartColumnIndex,
      xlsxSheetName: _simpleImportedSheetName,
      workbook: _simpleImportedWorkbook,
      sourceBytes: _simpleImportedSourceBytes,
    );
  }

  String _mimeTypeForFormat(SimpleFileFormat format) {
    return SimpleSheetFileService.mimeTypeForFormat(format);
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
    await SimpleTypeHintCache.rememberCsvTypes(
      fileName: result.resolvedFileName,
      path: result.savedPath,
      valueTypes: _simpleValueTypes,
    );
    setState(() {
      _simpleImportedPath = result.savedPath;
      _simpleImportedFileName = result.resolvedFileName;
      _simpleDocumentTarget = LocalSimpleEditorDocumentTarget(
        existingPath: result.savedPath,
      );
    });
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

  String _simpleSuggestedFileName({String? defaultExtension}) {
    final current = _simpleImportedFileName?.trim();
    final currentFormat = _simpleImportedFormat ?? SimpleFileFormat.csv;
    if (currentFormat == SimpleFileFormat.gsheet) {
      if (current == null || current.isEmpty) {
        return 'calcrow_sheet';
      }
      return current;
    }
    final extension =
        defaultExtension ??
        SimpleSheetFileService.defaultExtensionForFormat(currentFormat);
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
              showBackButton: _isAdvancedMode || _hasSimpleSchema,
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Opening document...', style: theme.textTheme.bodyMedium),
            ],
          ),
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
    final validPendingTypeSelectionColumns = _simplePendingTypeSelectionColumns
        .where(
          (index) =>
              index >= 0 &&
              index < _simpleHeaders.length &&
              index < _simpleValueTypes.length,
        )
        .toList();
    final hasPendingTypeSelection = validPendingTypeSelectionColumns.isNotEmpty;
    final targetLabel = isEditingExisting
        ? 'Editing row ${_simpleEditingRowIndex + 1} of ${_simpleRows.length}'
        : 'Editing new row at bottom';
    final selectedTextFieldLabel =
        _simpleTextSelectionColumnIndex != null &&
            _simpleTextSelectionColumnIndex! < _simpleHeaders.length
        ? _simpleHeaders[_simpleTextSelectionColumnIndex!]
        : null;
    final selectedTextTargetLabel =
        selectedTextFieldLabel != null && _simpleTextSelectionValue != null
        ? '$selectedTextFieldLabel: ${_simpleTextSelectionValue!}'
        : null;
    final isSheetDocumentSource =
        _simpleImportedFormat == SimpleFileFormat.xlsx ||
        _simpleImportedFormat == SimpleFileFormat.ods ||
        _simpleImportedFormat == SimpleFileFormat.gsheet;
    final sheetName = _simpleImportedSheetName?.trim();
    final activeSheetLabel = isSheetDocumentSource
        ? ((sheetName == null || sheetName.isEmpty) ? 'default' : sheetName)
        : null;
    final pendingTypeSelectionMessage = isSheetDocumentSource
        ? 'Set Datatypes and bear in mind that calculated fields are read-only.'
        : 'This file has no usable type row yet. Pick the editable field formats once before saving.';
    final canOpenLocalDocumentFromCard =
        (_supportsLocalFileEditing && _simpleDocumentTarget == null) ||
        (_supportsLocalFileEditing &&
            _simpleDocumentTarget is LocalSimpleEditorDocumentTarget);
    final canCreateOpenEndDateRow =
        _simpleOpenMode == SimpleEditorOpenMode.dateBasedOpenEnd;

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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _simpleImportedFileName == null
                                  ? targetLabel
                                  : '${_simpleImportedFileName!} - $targetLabel',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (activeSheetLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Active sheet: $activeSheetLabel',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (selectedTextTargetLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Selected entry: $selectedTextTargetLabel',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (canOpenLocalDocumentFromCard)
                  TextButton(
                    onPressed: _openLocalDocumentFolderOrDocument,
                    child: Text(
                      _simpleDocumentTarget is LocalSimpleEditorDocumentTarget
                          ? 'Open'
                          : 'Open Document',
                    ),
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
                  ...validPendingTypeSelectionColumns.map((index) {
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
                final type = index < _simpleValueTypes.length
                    ? _simpleValueTypes[index]
                    : 'text';
                if (index >= _simpleControllers.length) {
                  return const SizedBox.shrink();
                }
                final isDateField = index == dateColumn;
                final isFormulaField =
                    index < _simpleReadOnlyColumns.length &&
                    _simpleReadOnlyColumns[index];
                if (isFormulaField) {
                  return const SizedBox.shrink();
                }
                final isReadOnly = _isFixedSimpleDateField(index);
                final isDurationField =
                    _isSimpleDurationType(type) ||
                    _isSimpleTimespanField(header);
                final keyboardType = _keyboardForSimpleType(type);
                final helperText = 'Type: $type${isReadOnly ? ' (fixed)' : ''}';
                return Padding(
                  key: ValueKey<int>(index),
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
                      : !isReadOnly && type.trim().toLowerCase() == 'date'
                      ? TextField(
                          controller: _simpleControllers[index],
                          readOnly: true,
                          onTap: () => _pickSimpleDateValue(index),
                          decoration: InputDecoration(
                            labelText: header,
                            hintText: _hintForSimpleType(
                              type,
                              isDateField: isDateField,
                            ),
                            helperText: helperText,
                            suffixIcon: IconButton(
                              tooltip: 'Select date',
                              onPressed: () => _pickSimpleDateValue(index),
                              icon: const Icon(Icons.calendar_today_rounded),
                            ),
                          ),
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
                    onPressed: _simpleOpenMode == SimpleEditorOpenMode.textBased
                        ? _pickSimpleTextEntryFromCurrentSheet
                        : _simpleOpenMode ==
                              SimpleEditorOpenMode.dateBasedOpenEnd
                        ? _pickSimpleTodayEntryFromCurrentSheet
                        : _selectSimpleEditorTargetRow,
                    child: Text(
                      _simpleOpenMode == SimpleEditorOpenMode.textBased
                          ? 'Pick Entry'
                          : _simpleOpenMode ==
                                SimpleEditorOpenMode.dateBasedOpenEnd
                          ? 'Pick Row'
                          : 'Jump Today',
                    ),
                  ),
                ),
                if (_simpleOpenMode == SimpleEditorOpenMode.textBased) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: hasPendingTypeSelection
                          ? null
                          : _createNewSimpleTextEntry,
                      child: const Text('New Entry'),
                    ),
                  ),
                ] else if (canCreateOpenEndDateRow) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: hasPendingTypeSelection
                          ? null
                          : _createNewSimpleDateOpenEndRow,
                      child: const Text('New Row'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearSimpleEditableFields,
                    tooltip: 'Clear editable fields',
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
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

  bool _isFixedSimpleDateField(int columnIndex) {
    return (_simpleOpenMode == SimpleEditorOpenMode.dateBased ||
            _simpleOpenMode == SimpleEditorOpenMode.dateBasedOpenEnd) &&
        columnIndex == _simpleDateColumnIndex();
  }

  Future<void> _pickSimpleDateValue(int columnIndex) async {
    if (columnIndex < 0 || columnIndex >= _simpleControllers.length) return;

    final currentValue = _simpleControllers[columnIndex].text.trim();
    final initialDate = _parseDateFromCellValue(currentValue) ?? DateTime.now();
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100);
    final safeInitialDate = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
        ? lastDate
        : initialDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (!mounted || selectedDate == null) return;

    _simpleControllers[columnIndex].text = _formatDate(selectedDate);
    setState(() {});
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
    final setupTip = _supportsLocalFileEditing
        ? 'Tip: pick a local file first, then edit daily rows. For cloud-based files, connect Google Drive or WebDAV in Settings and use Edit Cloud Document here.'
        : 'Tip: connect Google Drive or WebDAV in Settings, then use Edit Cloud Document here.';

    return Column(
      children: [
        _SetupCard(
          title: 'Create New CSV',
          subtitle: 'Start from a fresh monthly sheet',
          icon: Icons.arrow_forward_ios_rounded,
          onTap: _createNewCsv,
        ),
        const SizedBox(height: 10),
        if (_supportsLocalFileEditing) ...[
          _SetupCard(
            title: 'Select Local File',
            subtitle:
                _importedFileName ?? 'Open an existing CSV from this device',
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
        _simpleTextSelectionColumnIndex = null;
        _simpleTextSelectionValue = null;
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
      _simpleHeaderRowIndex = 0;
      _simpleStartColumnIndex = 0;
      _simpleHeaders = const <String>[];
      _simpleValueTypes = const <String>[];
      _simpleReadOnlyColumns = const <bool>[];
      _simpleRows = const <List<String>>[];
      _simpleControllers = const <TextEditingController>[];
      _simpleEditingRowIndex = 0;
      _simpleImportedWorkbook = null;
      _simpleImportedSourceBytes = null;
      _simpleDocumentTarget = null;
      _simpleOpenMode = SimpleEditorOpenMode.dateBasedOpenEnd;
      _simpleTextSelectionColumnIndex = null;
      _simpleTextSelectionValue = null;
      _isOpeningDocument = false;
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

class _SimpleEditorTargetSelection {
  const _SimpleEditorTargetSelection({
    required this.usedDateColumn,
    required this.foundMatchingDateRow,
    required this.targetRowIndex,
  });

  final bool usedDateColumn;
  final bool foundMatchingDateRow;
  final int targetRowIndex;
}

class _SimpleOpeningSelection {
  const _SimpleOpeningSelection({
    required this.targetRowIndex,
    required this.textColumnIndex,
    required this.textValue,
  });

  final int targetRowIndex;
  final int? textColumnIndex;
  final String? textValue;
}

class _SimpleTextTargetSelection {
  const _SimpleTextTargetSelection({
    required this.columnIndex,
    required this.rowIndex,
    required this.value,
  });

  final int columnIndex;
  final int rowIndex;
  final String value;
}

abstract class SimpleEditorDocumentTarget {
  const SimpleEditorDocumentTarget();
}

class LocalSimpleEditorDocumentTarget extends SimpleEditorDocumentTarget {
  const LocalSimpleEditorDocumentTarget({required this.existingPath});

  final String? existingPath;
}

class CloudSimpleEditorDocumentTarget extends SimpleEditorDocumentTarget {
  const CloudSimpleEditorDocumentTarget({
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
            if (showBackButton) ...[
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 10),
            ],
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
