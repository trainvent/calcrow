import 'package:flutter/material.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/simple_sheet_file_service.dart';
import 'package:calcrow/features/home/editing/simple/widgets/moving_tile_widget.dart';

class SimpleDocumentDraft {
  const SimpleDocumentDraft({
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
  static const List<String> _typeOptions = <String>[
    'text',
    'date',
    'time',
    'duration',
    'Number',
    'decimal',
    'email',
    'phone',
  ];
  static const _templates = <_SimpleDocumentTemplate>[
    _SimpleDocumentTemplate(
      name: 'Bruce Lee Workout',
      fileName: 'bruce_lee_workout',
      description:
          'Track training sessions without turning the sheet into a fitness app.',
      columns: <_SimpleTemplateColumn>[
        _SimpleTemplateColumn(header: 'Date', type: 'date'),
        _SimpleTemplateColumn(header: 'Exercise', type: 'text'),
        _SimpleTemplateColumn(header: 'Sets', type: 'Number'),
        _SimpleTemplateColumn(header: 'Reps', type: 'Number'),
        _SimpleTemplateColumn(header: 'Weight', type: 'decimal'),
        _SimpleTemplateColumn(header: 'Notes', type: 'text'),
      ],
    ),
    _SimpleDocumentTemplate(
      name: 'Guestlist',
      fileName: 'guestlist',
      description: 'Names, contacts, and RSVP status for an event.',
      columns: <_SimpleTemplateColumn>[
        _SimpleTemplateColumn(header: 'Invited on', type: 'date'),
        _SimpleTemplateColumn(header: 'Name', type: 'text'),
        _SimpleTemplateColumn(header: 'Email', type: 'email'),
        _SimpleTemplateColumn(header: 'Phone', type: 'phone'),
        _SimpleTemplateColumn(header: 'RSVP', type: 'text'),
        _SimpleTemplateColumn(header: 'Notes', type: 'text'),
      ],
    ),
    _SimpleDocumentTemplate(
      name: 'Workhours',
      fileName: 'workhours',
      description: 'A clean day-by-day timesheet with breaks and notes.',
      columns: <_SimpleTemplateColumn>[
        _SimpleTemplateColumn(header: 'Date', type: 'date'),
        _SimpleTemplateColumn(header: 'Start', type: 'time'),
        _SimpleTemplateColumn(header: 'End', type: 'time'),
        _SimpleTemplateColumn(header: 'Pause', type: 'duration'),
        _SimpleTemplateColumn(header: 'Notes', type: 'text'),
      ],
    ),
    _SimpleDocumentTemplate(
      name: 'Invoices',
      fileName: 'invoices',
      description: 'Basic invoice tracking with dates, clients, and totals.',
      columns: <_SimpleTemplateColumn>[
        _SimpleTemplateColumn(header: 'Date', type: 'date'),
        _SimpleTemplateColumn(header: 'Client', type: 'text'),
        _SimpleTemplateColumn(header: 'Invoice', type: 'text'),
        _SimpleTemplateColumn(header: 'Amount', type: 'decimal'),
        _SimpleTemplateColumn(header: 'Status', type: 'text'),
      ],
    ),
  ];

  final TextEditingController _fileNameController = TextEditingController(
    text: 'calcrow_simple',
  );
  final List<_SimpleColumnDraft> _columns = <_SimpleColumnDraft>[
    _SimpleColumnDraft(header: 'Date', type: 'date'),
    _SimpleColumnDraft(header: 'Start', type: 'time'),
    _SimpleColumnDraft(header: 'End', type: 'time'),
    _SimpleColumnDraft(header: 'Pause', type: 'duration'),
    _SimpleColumnDraft(header: 'Notes', type: 'text'),
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
      _columns.add(_SimpleColumnDraft(header: '', type: 'text'));
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
    final template = await showDialog<_SimpleDocumentTemplate>(
      context: context,
      builder: (context) => _TemplatePickerDialog(templates: _templates),
    );
    if (!mounted || template == null) return;
    _applyTemplate(template);
  }

  void _applyTemplate(_SimpleDocumentTemplate template) {
    for (final column in _columns) {
      column.dispose();
    }
    setState(() {
      _fileNameController.text = template.fileName;
      _columns
        ..clear()
        ..addAll(
          template.columns.map(
            (column) =>
                _SimpleColumnDraft(header: column.header, type: column.type),
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
        .map((column) => column.type)
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
      SimpleDocumentDraft(
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
    return '${baseName.isEmpty ? 'calcrow_simple' : baseName}.$extension';
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
    final typeField = DropdownButtonFormField<String>(
      initialValue: column.type,
      decoration: const InputDecoration(labelText: 'Type'),
      items: _typeOptions
          .map(
            (type) => DropdownMenuItem<String>(value: type, child: Text(type)),
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

class _SimpleColumnDraft {
  _SimpleColumnDraft({required String header, required this.type})
    : headerController = TextEditingController(text: header);

  final TextEditingController headerController;
  String type;

  void dispose() {
    headerController.dispose();
  }
}

class _SimpleDocumentTemplate {
  const _SimpleDocumentTemplate({
    required this.name,
    required this.fileName,
    required this.description,
    required this.columns,
  });

  final String name;
  final String fileName;
  final String description;
  final List<_SimpleTemplateColumn> columns;
}

class _SimpleTemplateColumn {
  const _SimpleTemplateColumn({required this.header, required this.type});

  final String header;
  final String type;
}

class _TemplatePickerDialog extends StatelessWidget {
  const _TemplatePickerDialog({required this.templates});

  final List<_SimpleDocumentTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Templates',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close templates',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a starting point. You can still rename, add, remove, and reorder fields before creating the document.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _TemplateOptionTile(template: templates[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOptionTile extends StatelessWidget {
  const _TemplateOptionTile({required this.template});

  final _SimpleDocumentTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _TemplateFieldPreview(
                columns: template.columns,
                iconForType: _iconForType,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'date':
        return Icons.calendar_today_outlined;
      case 'time':
        return Icons.schedule_rounded;
      case 'duration':
        return Icons.timer_outlined;
      case 'Number':
      case 'decimal':
        return Icons.pin_outlined;
      case 'email':
        return Icons.alternate_email_rounded;
      case 'phone':
        return Icons.phone_outlined;
      default:
        return Icons.text_fields_rounded;
    }
  }
}

class _TemplateFieldPreview extends StatelessWidget {
  const _TemplateFieldPreview({
    required this.columns,
    required this.iconForType,
  });

  final List<_SimpleTemplateColumn> columns;
  final IconData Function(String type) iconForType;

  @override
  Widget build(BuildContext context) {
    final chipStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++) ...[
            Chip(
              label: Text(columns[index].header),
              avatar: Icon(iconForType(columns[index].type), size: 18),
              visualDensity: VisualDensity.compact,
            ),
            if (index < columns.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );

    if (columns.length <= 5) return chipStrip;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.88, 1],
        ).createShader(bounds);
      },
      child: chipStrip,
    );
  }
}

//!TODO Add support for creating ODS files once ODS generation does not require a source document.
