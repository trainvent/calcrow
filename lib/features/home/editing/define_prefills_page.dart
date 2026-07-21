import 'package:flutter/material.dart';

import 'package:calcrow/app/widgets/app_header_bottom_sheet.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/type_based_input_field.dart';
import 'package:calcrow/app/widgets/weekday_picker_widget.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/l10n/app_localizations.dart';

class DefinePrefillsPage extends StatefulWidget {
  const DefinePrefillsPage({
    super.key,
    required this.headers,
    required this.valueTypes,
    this.initialPrefills = const <DocumentPrefill>[],
  });

  final List<String> headers;
  final List<String> valueTypes;
  final List<DocumentPrefill> initialPrefills;

  @override
  State<DefinePrefillsPage> createState() => _DefinePrefillsPageState();
}

class _DefinePrefillsPageState extends State<DefinePrefillsPage> {
  late final List<DocumentPrefill> _prefills = List<DocumentPrefill>.from(
    widget.initialPrefills,
  );

  Map<String, String> get _editableFields {
    return <String, String>{
      for (var index = 0; index < widget.headers.length; index++)
        if (index >= widget.valueTypes.length ||
            widget.valueTypes[index].trim().toLowerCase() != 'date')
          widget.headers[index]: index < widget.valueTypes.length
              ? widget.valueTypes[index]
              : 'text',
    };
  }

  Future<void> _addPrefill() async {
    final prefill = await _showPrefillEditor();
    if (!mounted || prefill == null) return;
    setState(() => _prefills.add(prefill));
  }

  Future<void> _editPrefill(int index) async {
    final prefill = await _showPrefillEditor(initial: _prefills[index]);
    if (!mounted || prefill == null) return;
    setState(() => _prefills[index] = prefill);
  }

  Future<DocumentPrefill?> _showPrefillEditor({DocumentPrefill? initial}) {
    return showAppHeaderBottomSheet<DocumentPrefill>(
      context: context,
      builder: (context) => _PrefillEditorSheet(
        key: const ValueKey('prefill-editor-sheet'),
        valueTypes: _editableFields,
        initial: initial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.definePrefills)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.definePrefillsDescription,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addPrefill,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.addPrefill),
          ),
          const SizedBox(height: 12),
          if (_prefills.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.noPrefillsYet),
              ),
            )
          else
            for (var index = 0; index < _prefills.length; index++)
              Card(
                child: ListTile(
                  onTap: () => _editPrefill(index),
                  title: Text(_prefills[index].name),
                  subtitle: Text(_prefillSummary(context, _prefills[index])),
                  trailing: IconButton(
                    tooltip: context.l10n.deletePrefill,
                    onPressed: () => setState(() => _prefills.removeAt(index)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).pop(List<DocumentPrefill>.unmodifiable(_prefills)),
          icon: const Icon(Icons.check_rounded),
          label: Text(context.l10n.createDocument),
        ),
      ),
    );
  }

  String _prefillSummary(BuildContext context, DocumentPrefill prefill) {
    final values = prefill.values.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' · ');
    final days =
        prefill.weekdays.length == WeekdayPickerWidget.allWeekdays.length
        ? context.l10n.everyDay
        : (prefill.weekdays.toList()..sort())
              .map((day) => _shortWeekdayLabel(context, day))
              .join(', ');
    return '$values\n$days';
  }
}

class _PrefillEditorSheet extends StatefulWidget {
  const _PrefillEditorSheet({
    super.key,
    required this.valueTypes,
    this.initial,
  });

  final Map<String, String> valueTypes;
  final DocumentPrefill? initial;

  @override
  State<_PrefillEditorSheet> createState() => _PrefillEditorSheetState();
}

class _PrefillEditorSheetState extends State<_PrefillEditorSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final Map<String, TextEditingController> _valueControllers = {
    for (final header in widget.valueTypes.keys)
      header: TextEditingController(text: widget.initial?.values[header]),
  };
  late final Set<int> _selectedWeekdays = widget.initial == null
      ? Set<int>.from(WeekdayPickerWidget.allWeekdays)
      : <int>{...widget.initial!.weekdays};
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final values = <String, String>{
      for (final entry in _valueControllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
    if (name.isEmpty || values.isEmpty) {
      setState(() => _errorText = context.l10n.prefillNeedsNameAndValue);
      return;
    }
    Navigator.of(context).pop(
      DocumentPrefill(name: name, values: values, weekdays: _selectedWeekdays),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppHeaderBottomSheet(
      closeTooltip: context.l10n.cancel,
      header: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.prefillName,
          isDense: true,
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.valuesToPrefill,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final entry in _valueControllers.entries) ...[
            TypeBasedInputField(
              controller: entry.value,
              labelText: entry.key,
              rawType: widget.valueTypes[entry.key] ?? 'text',
              forceDuration: _isLegacyDurationField(
                entry.key,
                widget.valueTypes[entry.key] ?? 'text',
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(
            context.l10n.showPrefillOn,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          WeekdayPickerWidget(
            selectedWeekdays: _selectedWeekdays,
            onChanged: (weekdays) {
              setState(() {
                _selectedWeekdays
                  ..clear()
                  ..addAll(weekdays);
              });
            },
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      footer: FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check_rounded),
        label: Text(context.l10n.save),
      ),
    );
  }
}

bool _isLegacyDurationField(String header, String rawType) {
  final type = rawType.trim().toLowerCase();
  if (type.contains('duration') || type.contains('timespan')) return true;
  final normalizedHeader = header.trim().toLowerCase();
  return normalizedHeader.contains('pause') ||
      normalizedHeader.contains('break');
}

String _shortWeekdayLabel(BuildContext context, int weekday) {
  return switch (weekday) {
    DateTime.monday => context.l10n.mondayShort,
    DateTime.tuesday => context.l10n.tuesdayShort,
    DateTime.wednesday => context.l10n.wednesdayShort,
    DateTime.thursday => context.l10n.thursdayShort,
    DateTime.friday => context.l10n.fridayShort,
    DateTime.saturday => context.l10n.saturdayShort,
    DateTime.sunday => context.l10n.sundayShort,
    _ => '',
  };
}
