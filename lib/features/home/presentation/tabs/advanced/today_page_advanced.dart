import 'dart:convert';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../sheet_preview_store.dart';
import 'advanced_widgets/notes_widget.dart';
import 'advanced_widgets/row_definement_widget.dart';
import 'advanced_widgets/smart_data_widget.dart';
import 'advanced_widgets/wellbeing_widget.dart';
import 'advanced_widgets/workhours_widget.dart';
import '../simple/widgets/select_time_widget.dart';
import '../simple/widgets/timespan_widget.dart';

enum _WidgetBlock { rowDefinement, workhours, smartData, wellbeing, notes }

class TodayPageAdvanced extends StatefulWidget {
  const TodayPageAdvanced({super.key});

  @override
  State<TodayPageAdvanced> createState() => _TodayPageAdvancedState();
}

class _TodayPageAdvancedState extends State<TodayPageAdvanced> {
  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv'],
  );
  static const XTypeGroup _xlsxTypeGroup = XTypeGroup(
    label: 'XLSX',
    extensions: <String>['xlsx'],
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
  List<String> _simpleHeaders = const <String>[];
  List<String> _simpleValueTypes = const <String>[];
  List<bool> _simpleReadOnlyColumns = const <bool>[];
  List<List<String>> _simpleRows = const <List<String>>[];
  List<TextEditingController> _simpleControllers =
      const <TextEditingController>[];
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

  @override
  void initState() {
    super.initState();
    _isAdvancedMode = true;
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

  Future<void> _importCsvForSimple() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[_csvTypeGroup],
        confirmButtonText: 'Open CSV',
      );
      if (!mounted || file == null) return;

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
      if (lines.length < 2) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Simple mode expects line 1 headers and line 2 value types.',
            ),
          ),
        );
        return;
      }

      final delimiter = _detectDelimiter(lines[0]);
      final headers = _splitCsvLine(lines[0], delimiter: delimiter);
      final secondLineValues = _splitCsvLine(lines[1], delimiter: delimiter);
      if (headers.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('CSV header row is empty.')),
        );
        return;
      }

      final hasTypeRow = _looksLikeTypeRow(secondLineValues);
      final valueTypes = hasTypeRow
          ? List<String>.generate(
              headers.length,
              (index) => index < secondLineValues.length
                  ? _normalizeTypeLabel(secondLineValues[index])
                  : 'text',
            )
          : _inferSimpleTypes(
              headers.length,
              lines
                  .skip(1)
                  .map((line) => _splitCsvLine(line, delimiter: delimiter))
                  .take(20)
                  .toList(),
            );

      final rows = lines
          .skip(hasTypeRow ? 2 : 1)
          .map(
            (line) => _normalizeRowToWidth(
              _splitCsvLine(line, delimiter: delimiter),
              headers.length,
            ),
          )
          .toList();

      _loadSimpleProfileData(
        fileName: file.name,
        headers: headers,
        valueTypes: valueTypes,
        readOnlyColumns: List<bool>.filled(headers.length, false),
        rows: rows,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Loaded ${file.name} (${rows.length} entries).'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }

  Future<void> _importXlsxForSimple() async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[_xlsxTypeGroup],
        confirmButtonText: 'Open XLSX',
      );
      if (!mounted || file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not read XLSX file content.')),
        );
        return;
      }

      final excel = excel_pkg.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The selected XLSX has no sheets.')),
        );
        return;
      }

      final sheetName = excel.getDefaultSheet() ?? excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The selected XLSX sheet is empty.')),
        );
        return;
      }

      final rawRows = sheet.rows
          .map((row) => row.map((cell) => _xlsxCellToString(cell)).toList())
          .where((row) => row.any((value) => value.trim().isNotEmpty))
          .toList();
      if (rawRows.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('The selected XLSX sheet is empty.')),
        );
        return;
      }

      final width = rawRows.fold<int>(
        0,
        (maxWidth, row) => row.length > maxWidth ? row.length : maxWidth,
      );
      final normalizedRows = rawRows
          .map((row) => _normalizeRowToWidth(row, width))
          .toList();

      final rawHeaders = normalizedRows.first;
      final firstEmptyHeaderIndex = rawHeaders.indexWhere(
        (value) => value.trim().isEmpty,
      );
      final headerCount = firstEmptyHeaderIndex >= 0
          ? firstEmptyHeaderIndex
          : rawHeaders.length;
      if (headerCount == 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('First row has no header titles.')),
        );
        return;
      }

      final headers = rawHeaders
          .take(headerCount)
          .map((value) => value.trim())
          .toList();
      final rows = normalizedRows
          .skip(1)
          .map((row) => row.take(headerCount).toList())
          .toList();
      final valueTypes = _inferSimpleTypes(
        headerCount,
        rows.take(20).toList(),
        headers: headers,
      );
      final readOnlyColumns = List<bool>.filled(headerCount, false);
      for (final row in sheet.rows.skip(1)) {
        for (var col = 0; col < headerCount && col < row.length; col++) {
          final cell = row[col];
          final value = cell?.value;
          if (value is excel_pkg.FormulaCellValue) {
            readOnlyColumns[col] = true;
            continue;
          }
          if (_looksLikeFormulaExpression(value?.toString() ?? '')) {
            readOnlyColumns[col] = true;
          }
        }
      }

      _loadSimpleProfileData(
        fileName: file.name,
        headers: headers,
        valueTypes: valueTypes,
        readOnlyColumns: readOnlyColumns,
        rows: rows,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Loaded ${file.name} (${rows.length} entries).'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('XLSX import failed: $error')));
    }
  }

  void _loadSimpleProfileData({
    required String fileName,
    required List<String> headers,
    required List<String> valueTypes,
    required List<bool> readOnlyColumns,
    required List<List<String>> rows,
  }) {
    setState(() {
      _simpleImportedFileName = fileName;
      _simpleHeaders = headers;
      _simpleValueTypes = valueTypes;
      _simpleReadOnlyColumns = readOnlyColumns;
      _simpleRows = rows;
    });

    _selectSimpleEditorTargetRow();
    _publishSimpleRowsToPreview();
  }

  String _xlsxCellToString(excel_pkg.Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    if (value is excel_pkg.DateCellValue) {
      return _formatDate(value.asDateTimeLocal());
    }
    if (value is excel_pkg.DateTimeCellValue) {
      return _formatDate(value.asDateTimeLocal());
    }
    if (value is excel_pkg.TimeCellValue) {
      return value.toString();
    }
    if (value is excel_pkg.IntCellValue) {
      return value.value.toString();
    }
    if (value is excel_pkg.DoubleCellValue) {
      return value.value.toString().replaceAll('.', ',');
    }
    if (value is num) {
      return value.toString().replaceAll('.', ',');
    }
    return value.toString().trim();
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
    final today = _formatDate(DateTime.now());
    int targetRowIndex = _simpleRows.length;

    if (dateColumn != null) {
      for (var i = _simpleRows.length - 1; i >= 0; i--) {
        final row = _simpleRows[i];
        if (dateColumn < row.length && row[dateColumn].trim() == today) {
          targetRowIndex = i;
          break;
        }
      }
    }

    final draft = targetRowIndex < _simpleRows.length
        ? _simpleRows[targetRowIndex]
        : List<String>.filled(_simpleHeaders.length, '');
    if (dateColumn != null && (draft[dateColumn].trim().isEmpty)) {
      draft[dateColumn] = today;
    }

    _replaceSimpleControllers(draft);
    setState(() {
      _simpleEditingRowIndex = targetRowIndex;
    });
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

  void _saveSimpleRow() {
    if (!_hasSimpleSchema ||
        _simpleControllers.length != _simpleHeaders.length) {
      return;
    }

    final updatedRow = _simpleControllers
        .map((controller) => controller.text.trim())
        .toList();
    final nextRows = List<List<String>>.from(_simpleRows);

    if (_simpleEditingRowIndex < nextRows.length) {
      nextRows[_simpleEditingRowIndex] = _normalizeRowToWidth(
        updatedRow,
        _simpleHeaders.length,
      );
    } else {
      nextRows.add(_normalizeRowToWidth(updatedRow, _simpleHeaders.length));
    }

    setState(() {
      _simpleRows = nextRows;
      if (_simpleEditingRowIndex >= _simpleRows.length) {
        _simpleEditingRowIndex = _simpleRows.length - 1;
      }
    });
    _publishSimpleRowsToPreview();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Simple row saved.')));
  }

  void _clearSimpleEditableFields() {
    final dateColumn = _simpleDateColumnIndex();
    for (var i = 0; i < _simpleControllers.length; i++) {
      if (i == dateColumn || _simpleReadOnlyColumns[i]) continue;
      _simpleControllers[i].clear();
    }
    setState(() {});
  }

  void _publishSimpleRowsToPreview() {
    SheetPreviewStore.notifier.value = SheetPreviewStore.notifier.value
        .copyWith(
          headers: _simpleHeaders,
          rows: _simpleRows.take(_previewRowLimit).toList(),
          fileName: _simpleImportedFileName,
          rowCount: _simpleRows.length,
        );
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

  bool _looksLikeTypeRow(List<String> values) {
    if (values.isEmpty) return false;
    var matches = 0;
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (_isKnownTypeToken(normalized)) {
        matches++;
      }
    }
    return matches >= (values.length / 2).ceil();
  }

  bool _isKnownTypeToken(String type) {
    if (type.contains('date')) return true;
    if (type.contains('time')) return true;
    if (type.contains('int')) return true;
    if (type.contains('double')) return true;
    if (type.contains('decimal')) return true;
    if (type.contains('number')) return true;
    if (type.contains('num')) return true;
    if (type.contains('bool')) return true;
    if (type.contains('text')) return true;
    if (type.contains('string')) return true;
    if (type.contains('currency')) return true;
    if (type.contains('money')) return true;
    if (type.contains('email')) return true;
    if (type.contains('phone')) return true;
    return false;
  }

  List<String> _inferSimpleTypes(
    int width,
    List<List<String>> sampleRows, {
    List<String>? headers,
  }) {
    return List<String>.generate(width, (index) {
      if (headers != null &&
          index < headers.length &&
          _isDateHeaderName(headers[index])) {
        return 'date';
      }
      for (final row in sampleRows) {
        if (index >= row.length) continue;
        final value = row[index].trim();
        if (value.isEmpty) continue;
        if (_looksLikeDateValue(value)) return 'date';
        if (_looksLikeTimeValue(value)) return 'time';
        if (_looksLikeDecimalValue(value)) return 'decimal';
        if (_looksLikeIntegerValue(value)) return 'int';
        return 'text';
      }
      return 'text';
    });
  }

  String _normalizeTypeLabel(String raw) {
    final type = raw.trim().toLowerCase();
    if (type.contains('date')) return 'date';
    if (type.contains('time')) return 'time';
    if (type.contains('int')) return 'int';
    if (type.contains('double') ||
        type.contains('decimal') ||
        type.contains('number')) {
      return 'decimal';
    }
    if (type.contains('email')) return 'email';
    if (type.contains('phone')) return 'phone';
    return 'text';
  }

  bool _looksLikeDateValue(String value) {
    final compact = value.trim();
    return RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2,4}$').hasMatch(compact) ||
        RegExp(r'^\d{4}[./-]\d{1,2}[./-]\d{1,2}$').hasMatch(compact);
  }

  bool _looksLikeTimeValue(String value) {
    final compact = value.trim().toLowerCase();
    return RegExp(r'^\d{1,2}:\d{2}(:\d{2})?(\s?(am|pm))?$').hasMatch(compact);
  }

  bool _looksLikeIntegerValue(String value) {
    return RegExp(r'^[+-]?\d+$').hasMatch(value.trim());
  }

  bool _looksLikeDecimalValue(String value) {
    final compact = value.trim();
    return RegExp(r'^[+-]?\d+[.,]\d+$').hasMatch(compact);
  }

  bool _isDateHeaderName(String header) {
    final value = header.trim().toLowerCase();
    return value == 'date' ||
        value == 'datum' ||
        value == 'tag' ||
        value == 'data' ||
        value == 'fecha';
  }

  bool _looksLikeFormulaExpression(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    if (compact.startsWith('=')) return true;
    return RegExp(r'^[A-Z]{1,3}\d+\s*=').hasMatch(compact);
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
    return ListView(
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
    );
  }

  Widget _buildSimpleView(ThemeData theme) {
    if (!_hasSimpleSchema) {
      return Column(
        children: [
          _SetupCard(
            title: 'Open Existing CSV',
            subtitle: 'Line 1 = field names, line 2 = value types',
            icon: Icons.folder_open_rounded,
            onTap: _importCsvForSimple,
          ),
          const SizedBox(height: 10),
          _SetupCard(
            title: 'Open Existing XLSX',
            subtitle: 'Use first sheet and first row as field profile',
            icon: Icons.grid_on_rounded,
            onTap: _importXlsxForSimple,
          ),
          const SizedBox(height: 10),
          Text(
            'Simple mode will auto-jump to today\'s row if a date column exists, otherwise it opens a new row at the bottom.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
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
    final targetLabel = isEditingExisting
        ? 'Editing row ${_simpleEditingRowIndex + 1} of ${_simpleRows.length}'
        : 'Editing new row at bottom';

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
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _importCsvForSimple,
                  child: const Text('Open Another'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List<Widget>.generate(_simpleHeaders.length, (index) {
                final header = _simpleHeaders[index];
                final type = _simpleValueTypes[index];
                final isDateField = index == dateColumn;
                final isFormulaField = _simpleReadOnlyColumns[index];
                final isReadOnly = isDateField || isFormulaField;
                final isTimespanField = _isSimpleTimespanField(header);
                final keyboardType = _keyboardForSimpleType(type);
                final helperText =
                    'Type: $type${isDateField
                        ? ' (fixed)'
                        : isFormulaField
                        ? ' (calculated)'
                        : ''}';
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _simpleHeaders.length - 1 ? 0 : 10,
                  ),
                  child: !isReadOnly && isTimespanField
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
              }),
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
                    onPressed: _saveSimpleRow,
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
    if (type.contains('date') || type.contains('time')) {
      return TextInputType.datetime;
    }
    return TextInputType.text;
  }

  bool _isSimpleTimeType(String rawType) {
    return rawType.trim().toLowerCase().contains('time');
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
          title: 'Connect With Existing CSV',
          subtitle: 'Reuse your current log and continue editing',
          icon: Icons.link_rounded,
          onTap: _importCsv,
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
    return _setupDone ? 'CSVrow Daily Editor' : 'Get Started';
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
      _simpleHeaders = const <String>[];
      _simpleValueTypes = const <String>[];
      _simpleReadOnlyColumns = const <bool>[];
      _simpleRows = const <List<String>>[];
      _simpleControllers = const <TextEditingController>[];
      _simpleEditingRowIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in oldControllers) {
        controller.dispose();
      }
    });
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
