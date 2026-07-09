import 'package:flutter/material.dart';
import 'package:calcrow/app/widgets/templates_dialogue.dart';
import 'package:calcrow/core/sheet_type_logic/field_type.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_file_service.dart';
import 'package:calcrow/features/home/editing/widgets/moving_tile_widget.dart';

class DocumentDraft {
  const DocumentDraft({
    required this.fileName,
    required this.format,
    required this.headers,
    required this.valueTypes,
  });

  final String fileName;
  final SimpleFileFormat format;
  final List<String> headers;
  final List<String> valueTypes;
}

class CreateDocPage extends StatefulWidget {
  const CreateDocPage({super.key});

  @override
  State<CreateDocPage> createState() => _CreateDocPageState();
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
  SimpleFileFormat _format = SimpleFileFormat.csv;
  bool _isArranging = false;
  String? _errorText;

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

  void _setFormat(SimpleFileFormat format) {
    if (format == _format || format == SimpleFileFormat.ods) return;
    setState(() {
      _format = format;
      _errorText = null;
    });
  }

  Future<void> _openTemplates() async {
    final template = await showDialog<DocumentTemplate>(
      context: context,
      builder: (context) =>
          const TemplatesDialogue(templates: documentTemplates),
    );
    if (!mounted || template == null) return;
    _applyTemplate(template);
  }

  void _applyTemplate(DocumentTemplate template) {
    for (final column in _columns) {
      column.dispose();
    }
    setState(() {
      _fileNameController.text = template.fileName;
      _columns
        ..clear()
        ..addAll(
          template.columns.map(
            (column) => _ColumnDraft(header: column.header, type: column.type),
          ),
        );
      _isArranging = false;
      _errorText = null;
    });
  }

  void _submit() {
    final fileName = _fileNameWithFormat(_fileNameController.text, _format);
    final headers = _columns
        .map((column) => column.headerController.text.trim())
        .where((header) => header.isNotEmpty)
        .toList();
    final valueTypes = _columns
        .where((column) => column.headerController.text.trim().isNotEmpty)
        .map((column) => column.type.value)
        .toList();

    if (headers.isEmpty) {
      setState(() => _errorText = 'Add at least one column.');
      return;
    }
    final normalizedHeaders = headers.map((header) => header.toLowerCase());
    if (normalizedHeaders.toSet().length != headers.length) {
      setState(() => _errorText = 'Column names must be unique.');
      return;
    }
    if (!valueTypes.any((type) => type == 'date')) {
      setState(() => _errorText = 'Dates open end needs one date column.');
      return;
    }

    Navigator.of(context).pop(
      DocumentDraft(
        fileName: fileName,
        format: _format,
        headers: headers,
        valueTypes: valueTypes,
      ),
    );
  }

  String _fileNameWithFormat(String value, SimpleFileFormat format) {
    final extension = _extensionForFormat(format);
    final baseName = _baseFileName(value);
    return '${baseName.isEmpty ? 'calcrow_sheet' : baseName}.$extension';
  }

  String _baseFileName(String value) {
    return value.trim().replaceFirst(
      RegExp(r'\.(csv|xlsx|ods)$', caseSensitive: false),
      '',
    );
  }

  String _extensionForFormat(SimpleFileFormat format) {
    return SimpleSheetFileService.defaultExtensionForFormat(format);
  }

  void _handleFileNameChanged(String value) {
    final normalized = _baseFileName(value);
    if (normalized != value) {
      _fileNameController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Widget _buildColumnEditor(int index) {
    final column = _columns[index];
    final headerField = TextField(
      controller: column.headerController,
      decoration: InputDecoration(labelText: 'Column ${index + 1}'),
      onChanged: (_) {
        if (_errorText != null) {
          setState(() => _errorText = null);
        }
      },
    );
    final typeField = DropdownButtonFormField<FieldType>(
      initialValue: column.type,
      decoration: const InputDecoration(labelText: 'Type'),
      items: FieldType.createOptions
          .map(
            (type) => DropdownMenuItem<FieldType>(
              value: type,
              child: Text(type.value),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          column.type = value;
          _errorText = null;
        });
      },
    );
    final removeButton = IconButton(
      tooltip: 'Remove column',
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
        title: const Text('Create Document'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openTemplates,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Templates'),
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
                        labelText: 'File name',
                        suffixText: '.${_extensionForFormat(_format)}',
                      ),
                      onChanged: _handleFileNameChanged,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<SimpleFileFormat>(
                      segments: const <ButtonSegment<SimpleFileFormat>>[
                        ButtonSegment<SimpleFileFormat>(
                          value: SimpleFileFormat.csv,
                          label: Text('CSV'),
                          icon: Icon(Icons.table_rows_outlined),
                        ),
                        ButtonSegment<SimpleFileFormat>(
                          value: SimpleFileFormat.xlsx,
                          label: Text('XLSX'),
                          icon: Icon(Icons.grid_on_rounded),
                        ),
                        ButtonSegment<SimpleFileFormat>(
                          value: SimpleFileFormat.ods,
                          label: Text('ODS later'),
                          icon: Icon(Icons.pending_outlined),
                          enabled: false,
                        ),
                      ],
                      selected: <SimpleFileFormat>{_format},
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
                            'Fields',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _isArranging
                              ? 'Finish arranging'
                              : 'Arrange fields',
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
                          label: const Text('Add field'),
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
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Continue'),
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
  _ColumnDraft({required String header, required this.type})
    : headerController = TextEditingController(text: header);

  final TextEditingController headerController;
  FieldType type;

  void dispose() {
    headerController.dispose();
  }
}

//!TODO Add support for creating ODS files once ODS generation does not require a source document.
