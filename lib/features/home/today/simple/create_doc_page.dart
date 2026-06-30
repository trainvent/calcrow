import 'package:flutter/material.dart';

class SimpleDocumentDraft {
  const SimpleDocumentDraft({
    required this.fileName,
    required this.headers,
    required this.valueTypes,
  });

  final String fileName;
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
    'int',
    'decimal',
    'email',
    'phone',
  ];

  final TextEditingController _fileNameController = TextEditingController(
    text: 'calcrow_simple.csv',
  );
  final List<_SimpleColumnDraft> _columns = <_SimpleColumnDraft>[
    _SimpleColumnDraft(header: 'Date', type: 'date'),
    _SimpleColumnDraft(header: 'Start', type: 'time'),
    _SimpleColumnDraft(header: 'End', type: 'time'),
    _SimpleColumnDraft(header: 'Pause', type: 'duration'),
    _SimpleColumnDraft(header: 'Notes', type: 'text'),
  ];
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
    setState(() => _errorText = null);
  }

  void _submit() {
    final rawFileName = _fileNameController.text.trim();
    final fileName = rawFileName.isEmpty
        ? 'calcrow_simple.csv'
        : rawFileName.toLowerCase().endsWith('.csv')
        ? rawFileName
        : '$rawFileName.csv';
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
        headers: headers,
        valueTypes: valueTypes,
      ),
    );
  }

  Widget _buildColumnEditor(int index) {
    final column = _columns[index];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
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
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
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

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
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
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: headerField),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: typeField),
              const SizedBox(width: 8),
              removeButton,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Document')),
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
                      decoration: const InputDecoration(
                        labelText: 'File name',
                        suffixText: 'CSV',
                      ),
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
