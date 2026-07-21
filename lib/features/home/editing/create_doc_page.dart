import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:calcrow/app/widgets/templates_dialogue.dart';
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:calcrow/core/sheet_type_logic/field_type.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_service.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/features/home/editing/define_prefills_page.dart';
import 'package:calcrow/features/home/editing/widgets/moving_tile_widget.dart';
import 'package:calcrow/app/widgets/type_dropdown_list.dart';

class DocumentDraft {
  const DocumentDraft({
    required this.fileName,
    required this.format,
    required this.headers,
    required this.valueTypes,
    this.prefills = const <DocumentPrefill>[],
    this.xlsxSheetName,
  });

  final String fileName;
  final SheetFileFormat format;
  final List<String> headers;
  final List<String> valueTypes;
  final List<DocumentPrefill> prefills;
  final String? xlsxSheetName;
}

class CreateDocPage extends StatefulWidget {
  const CreateDocPage({super.key, this.initialSetup});

  final CreateDocInitialSetup? initialSetup;

  @override
  State<CreateDocPage> createState() => _CreateDocPageState();
}

enum LogbookSeparation { monthly, yearly }

class CreateDocInitialSetup {
  const CreateDocInitialSetup({
    required this.separation,
    required this.createdAt,
  });

  final LogbookSeparation separation;
  final DateTime createdAt;

  String get xlsxSheetName {
    return switch (separation) {
      LogbookSeparation.monthly => _monthName(createdAt.month),
      LogbookSeparation.yearly => createdAt.year.toString(),
    };
  }

  int? get fileNameYearSuffix {
    return fileNameYearSuffixFor(SheetFileFormat.xlsx);
  }

  int? fileNameYearSuffixFor(SheetFileFormat format) {
    return switch ((separation, format)) {
      (LogbookSeparation.monthly, SheetFileFormat.xlsx) => createdAt.year,
      (LogbookSeparation.monthly, SheetFileFormat.ods) => createdAt.year,
      (LogbookSeparation.yearly, SheetFileFormat.csv) => createdAt.year,
      _ => null,
    };
  }

  SheetFileFormat get initialFormat {
    return switch (separation) {
      LogbookSeparation.monthly => SheetFileFormat.xlsx,
      LogbookSeparation.yearly => SheetFileFormat.csv,
    };
  }

  bool get allowsCsv => separation != LogbookSeparation.monthly;

  static String _monthName(int month) {
    return const <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
  }
}

class _CreateDocPageState extends State<CreateDocPage> {
  final TextEditingController _fileNameController = TextEditingController(
    text: 'calcrow_sheet',
  );
  final List<_ColumnDraft> _columns = <_ColumnDraft>[
    _ColumnDraft(header: 'Date', type: FieldType.date),
    _ColumnDraft(header: 'Start', type: FieldType.time),
    _ColumnDraft(header: 'End', type: FieldType.time),
    _ColumnDraft(header: 'Pause', type: FieldType.duration),
    _ColumnDraft(header: 'Notes', type: FieldType.text),
  ];
  late SheetFileFormat _format;
  bool _isArranging = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _format = widget.initialSetup?.initialFormat ?? SheetFileFormat.csv;
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    for (final column in _columns) {
      column.dispose();
    }
    super.dispose();
  }

  void _addColumn() {
    setState(() {
      _columns.add(_ColumnDraft(header: '', type: FieldType.text));
      _errorText = null;
    });
  }

  void _removeColumn(int index) {
    if (_columns.length <= 1) return;
    final removed = _columns.removeAt(index);
    removed.dispose();
    setState(() {
      if (_columns.length <= 1) _isArranging = false;
      _errorText = null;
    });
  }

  void _moveColumn(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _columns.length || fromIndex == toIndex) {
      return;
    }
    setState(() {
      final moved = _columns.removeAt(fromIndex);
      _columns.insert(toIndex, moved);
      _errorText = null;
    });
  }

  void _enterArrangeMode() {
    if (_isArranging || _columns.length <= 1) return;
    setState(() => _isArranging = true);
  }

  void _setFormat(SheetFileFormat format) {
    if (format == _format) return;
    if (format == SheetFileFormat.csv &&
        widget.initialSetup?.allowsCsv == false) {
      return;
    }
    setState(() {
      _format = format;
      _errorText = null;
    });
  }

  Future<void> _openTemplates() async {
    final template = await showDialog<DocumentTemplate>(
      context: context,
      builder: (context) => TemplatesDialogue(templates: documentTemplates),
    );
    if (!mounted || template == null) return;
    _applyTemplate(template, context.l10n);
  }

  void _applyTemplate(
    DocumentTemplate template,
    AppLocalizations localizations,
  ) {
    for (final column in _columns) {
      column.dispose();
    }
    setState(() {
      _fileNameController.text = template.fileName;
      _columns
        ..clear()
        ..addAll(
          template.columns.map(
            (column) => _ColumnDraft(
              header: column.header(localizations),
              type: column.type,
              currencyCode: column.currencyCode,
            ),
          ),
        );
      _isArranging = false;
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    final headers = _columns
        .map((column) => column.headerController.text.trim())
        .where((header) => header.isNotEmpty)
        .toList();
    final valueTypes = _columns
        .where((column) => column.headerController.text.trim().isNotEmpty)
        .map(_valueTypeForColumn)
        .toList();

    if (headers.isEmpty) {
      setState(() => _errorText = context.l10n.addAtLeastOneColumn);
      return;
    }
    final normalizedHeaders = headers.map((header) => header.toLowerCase());
    if (normalizedHeaders.toSet().length != headers.length) {
      setState(() => _errorText = context.l10n.columnNamesMustBeUnique);
      return;
    }
    if (!valueTypes.any((type) => type == 'date')) {
      setState(() => _errorText = context.l10n.datesOpenEndNeedsOneDateColumn);
      return;
    }

    final prefills = await Navigator.of(context).push<List<DocumentPrefill>>(
      MaterialPageRoute(
        builder: (context) =>
            DefinePrefillsPage(headers: headers, valueTypes: valueTypes),
      ),
    );
    if (!mounted || prefills == null) return;

    Navigator.of(context).pop(
      DocumentDraft(
        fileName: _fileNameWithFormat(
          _fileNameController.text,
          _format,
          yearSuffix: widget.initialSetup?.fileNameYearSuffixFor(_format),
        ),
        format: _format,
        headers: headers,
        valueTypes: valueTypes,
        prefills: prefills,
        xlsxSheetName:
            _format == SheetFileFormat.xlsx || _format == SheetFileFormat.ods
            ? widget.initialSetup?.xlsxSheetName
            : null,
      ),
    );
  }

  String _valueTypeForColumn(_ColumnDraft column) {
    if (column.type == FieldType.money) {
      return FieldTypeGuesser.moneyType(column.currencyCode);
    }
    return column.type.value;
  }

  String _fileNameWithFormat(
    String value,
    SheetFileFormat format, {
    int? yearSuffix,
  }) {
    final extension = _extensionForFormat(format);
    final baseName = _baseFileName(value);
    final resolvedBaseName = baseName.isEmpty ? 'calcrow_sheet' : baseName;
    if (yearSuffix == null || resolvedBaseName.endsWith('_$yearSuffix')) {
      return '$resolvedBaseName.$extension';
    }
    return '${resolvedBaseName}_$yearSuffix.$extension';
  }

  String _fileNameSuffixForFormat(String value, SheetFileFormat format) {
    final extension = _extensionForFormat(format);
    final yearSuffix = widget.initialSetup?.fileNameYearSuffixFor(format);
    final baseName = _baseFileName(value);
    if (yearSuffix == null || baseName.endsWith('_$yearSuffix')) {
      return '.$extension';
    }
    return '_$yearSuffix.$extension';
  }

  String _baseFileName(String value) {
    return value.trim().replaceFirst(
      RegExp(r'\.(csv|xlsx|ods)$', caseSensitive: false),
      '',
    );
  }

  String _extensionForFormat(SheetFileFormat format) {
    return SheetFileService.defaultExtensionForFormat(format);
  }

  void _handleFileNameChanged(String value) {
    final normalized = _baseFileName(value);
    if (normalized != value) {
      _fileNameController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    setState(() => _errorText = null);
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

  Future<void> _handleColumnTypeChanged(
    _ColumnDraft column,
    FieldType nextType,
  ) async {
    var nextCurrencyCode = column.currencyCode;
    if (nextType == FieldType.money) {
      final selectedCurrencyCode = await _pickCurrencyCode(nextCurrencyCode);
      if (!mounted) return;
      if (selectedCurrencyCode == null && column.type != FieldType.money) {
        return;
      }
      nextCurrencyCode = selectedCurrencyCode ?? nextCurrencyCode;
    }
    setState(() {
      column.type = nextType;
      column.currencyCode = FieldTypeGuesser.normalizeCurrencyCode(
        nextCurrencyCode,
      );
      _errorText = null;
    });
  }

  String _typeLabelForColumn(FieldType type, _ColumnDraft column) {
    if (type == FieldType.money) {
      final currencyCode = FieldTypeGuesser.normalizeCurrencyCode(
        column.currencyCode,
      );
      return 'money ($currencyCode)';
    }
    return type.value;
  }

  Widget _buildColumnEditor(int index) {
    final column = _columns[index];
    final headerField = TextField(
      controller: column.headerController,
      decoration: InputDecoration(
        labelText: context.l10n.columnNumber(index + 1),
      ),
      onChanged: (_) {
        if (_errorText != null) {
          setState(() => _errorText = null);
        }
      },
    );
    final typeField = TypeDropdownList<FieldType>(
      initialValue: column.type,
      labelText: context.l10n.type,
      options: FieldType.createOptions,
      labelFor: (type) => _typeLabelForColumn(type, column),
      iconFor: TypeDropdownList.iconForFieldType,
      onChanged: (value) => _handleColumnTypeChanged(column, value),
    );
    final removeButton = IconButton(
      tooltip: context.l10n.removeColumn,
      onPressed: _columns.length <= 1 ? null : () => _removeColumn(index),
      icon: const Icon(Icons.remove_circle_outline_rounded),
    );

    return MovingTileWidget(
      isArranging: _isArranging,
      canMoveUp: index > 0,
      canMoveDown: index < _columns.length - 1,
      onEnterArrangeMode: _enterArrangeMode,
      onMoveUp: () => _moveColumn(index, index - 1),
      onMoveDown: () => _moveColumn(index, index + 1),
      showBottomSeparator: index < _columns.length - 1,
      compactChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerField,
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: typeField),
              const SizedBox(width: 8),
              removeButton,
            ],
          ),
        ],
      ),
      expandedChildren: [
        Expanded(flex: 3, child: headerField),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: typeField),
        const SizedBox(width: 8),
        removeButton,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createDocument),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openTemplates,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: Text(context.l10n.templates),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _fileNameController,
                      decoration: InputDecoration(
                        labelText: context.l10n.fileName,
                        suffixText: _fileNameSuffixForFormat(
                          _fileNameController.text,
                          _format,
                        ),
                      ),
                      onChanged: _handleFileNameChanged,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<SheetFileFormat>(
                      segments: <ButtonSegment<SheetFileFormat>>[
                        if (widget.initialSetup?.allowsCsv != false)
                          ButtonSegment<SheetFileFormat>(
                            value: SheetFileFormat.csv,
                            label: Text(context.l10n.csv),
                            icon: Icon(Icons.table_rows_outlined),
                          ),
                        ButtonSegment<SheetFileFormat>(
                          value: SheetFileFormat.xlsx,
                          label: Text(context.l10n.xlsx),
                          icon: Icon(Icons.grid_on_rounded),
                        ),
                        ButtonSegment<SheetFileFormat>(
                          value: SheetFileFormat.ods,
                          label: Text(context.l10n.ods),
                          icon: Icon(Icons.grid_view_rounded),
                        ),
                      ],
                      selected: <SheetFileFormat>{_format},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        _setFormat(selection.first);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.fields,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _isArranging
                              ? context.l10n.finishArranging
                              : context.l10n.arrangeFields,
                          onPressed: _columns.length <= 1
                              ? null
                              : () => setState(
                                  () => _isArranging = !_isArranging,
                                ),
                          icon: Icon(
                            _isArranging
                                ? Icons.check_rounded
                                : Icons.swap_vert_rounded,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addColumn,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.l10n.addField),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List<Widget>.generate(
                      _columns.length,
                      _buildColumnEditor,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(context.l10n.continueLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnDraft {
  _ColumnDraft({
    required String header,
    required this.type,
    String currencyCode = FieldTypeGuesser.defaultCurrencyCode,
  }) : currencyCode = FieldTypeGuesser.normalizeCurrencyCode(currencyCode),
       headerController = TextEditingController(text: header);

  final TextEditingController headerController;
  FieldType type;
  String currencyCode;

  void dispose() {
    headerController.dispose();
  }
}

//!TODO Add support for creating ODS files once ODS generation does not require a source document.
