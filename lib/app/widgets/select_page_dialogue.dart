import 'package:flutter/material.dart';
import 'package:trainvent_general/trainvent_general.dart';

class SelectPageOption {
  const SelectPageOption({
    required this.name,
    required this.entryCount,
    required this.headerRowNumber,
  });

  final String name;
  final int entryCount;
  final int headerRowNumber;
}

class CreateMonthSheetSelection {
  const CreateMonthSheetSelection({
    required this.sourceSheetName,
    required this.targetSheetName,
  });

  final String sourceSheetName;
  final String targetSheetName;
}

Future<CreateMonthSheetSelection?> showCreateMonthSheetDialogue({
  required BuildContext context,
  required String title,
  required String description,
  required String blueprintLabel,
  required String recommendedBlueprintLabel,
  required String newSheetNameLabel,
  required String requiredNameError,
  required String duplicateNameError,
  required String invalidNameError,
  required String cancelLabel,
  required String createLabel,
  required List<String> blueprintSheetNames,
  required List<String> existingSheetNames,
  required String initialBlueprintSheetName,
  required String initialNewSheetName,
}) {
  return showDialog<CreateMonthSheetSelection>(
    context: context,
    builder: (context) => _CreateMonthSheetDialogue(
      title: title,
      description: description,
      blueprintLabel: blueprintLabel,
      recommendedBlueprintLabel: recommendedBlueprintLabel,
      newSheetNameLabel: newSheetNameLabel,
      requiredNameError: requiredNameError,
      duplicateNameError: duplicateNameError,
      invalidNameError: invalidNameError,
      cancelLabel: cancelLabel,
      createLabel: createLabel,
      blueprintSheetNames: blueprintSheetNames,
      existingSheetNames: existingSheetNames,
      initialBlueprintSheetName: initialBlueprintSheetName,
      initialNewSheetName: initialNewSheetName,
    ),
  );
}

class _CreateMonthSheetDialogue extends StatefulWidget {
  const _CreateMonthSheetDialogue({
    required this.title,
    required this.description,
    required this.blueprintLabel,
    required this.recommendedBlueprintLabel,
    required this.newSheetNameLabel,
    required this.requiredNameError,
    required this.duplicateNameError,
    required this.invalidNameError,
    required this.cancelLabel,
    required this.createLabel,
    required this.blueprintSheetNames,
    required this.existingSheetNames,
    required this.initialBlueprintSheetName,
    required this.initialNewSheetName,
  });

  final String title;
  final String description;
  final String blueprintLabel;
  final String recommendedBlueprintLabel;
  final String newSheetNameLabel;
  final String requiredNameError;
  final String duplicateNameError;
  final String invalidNameError;
  final String cancelLabel;
  final String createLabel;
  final List<String> blueprintSheetNames;
  final List<String> existingSheetNames;
  final String initialBlueprintSheetName;
  final String initialNewSheetName;

  @override
  State<_CreateMonthSheetDialogue> createState() =>
      _CreateMonthSheetDialogueState();
}

class _CreateMonthSheetDialogueState extends State<_CreateMonthSheetDialogue> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedBlueprint;

  @override
  void initState() {
    super.initState();
    _selectedBlueprint = widget.initialBlueprintSheetName;
    _nameController = TextEditingController(text: widget.initialNewSheetName);
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialNewSheetName.length,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return widget.requiredNameError;
    if (RegExp(r"[\\/*?:\[\]]").hasMatch(name) ||
        name.startsWith("'") ||
        name.endsWith("'")) {
      return widget.invalidNameError;
    }
    final normalized = name.toLowerCase();
    if (widget.existingSheetNames.any(
      (existing) => existing.trim().toLowerCase() == normalized,
    )) {
      return widget.duplicateNameError;
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      CreateMonthSheetSelection(
        sourceSheetName: _selectedBlueprint,
        targetSheetName: _nameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBlueprint,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.blueprintLabel,
                    helperText: widget.recommendedBlueprintLabel,
                    prefixIcon: const Icon(Icons.content_copy_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.blueprintSheetNames
                      .map(
                        (name) => DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _selectedBlueprint = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 31,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: widget.newSheetNameLabel,
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validateName,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: Text(widget.createLabel),
        ),
      ],
    );
  }
}

Future<String?> showSelectPageDialogue({
  required BuildContext context,
  required String title,
  required String description,
  required String cancelLabel,
  required String Function(int entryCount, int headerRowNumber) detailsBuilder,
  required List<SelectPageOption> options,
  String? createOptionTooltip,
  Future<String?> Function()? onCreateOption,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SelectPageDialogue(
      title: title,
      description: description,
      cancelLabel: cancelLabel,
      detailsBuilder: detailsBuilder,
      options: options,
      createOptionTooltip: createOptionTooltip,
      onCreateOption: onCreateOption,
    ),
  );
}

class SelectPageDialogue extends StatefulWidget {
  const SelectPageDialogue({
    super.key,
    required this.title,
    required this.description,
    required this.cancelLabel,
    required this.detailsBuilder,
    required this.options,
    this.createOptionTooltip,
    this.onCreateOption,
  });

  final String title;
  final String description;
  final String cancelLabel;
  final String Function(int entryCount, int headerRowNumber) detailsBuilder;
  final List<SelectPageOption> options;
  final String? createOptionTooltip;
  final Future<String?> Function()? onCreateOption;

  @override
  State<SelectPageDialogue> createState() => _SelectPageDialogueState();
}

class _SelectPageDialogueState extends State<SelectPageDialogue> {
  bool _isCreating = false;

  Future<void> _createOption() async {
    final callback = widget.onCreateOption;
    if (callback == null || _isCreating) return;
    setState(() => _isCreating = true);
    try {
      final createdOption = await callback();
      if (!mounted || createdOption == null) return;
      Navigator.of(context).pop(createdOption);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          if (widget.onCreateOption != null)
            IconButton(
              tooltip: widget.createOptionTooltip,
              onPressed: _isCreating ? null : _createOption,
              icon: _isCreating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: TriangleLoadingIndicator(size: 20, strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  return ListTile(
                    leading: const Icon(Icons.table_chart_outlined),
                    title: Text(option.name),
                    subtitle: Text(
                      widget.detailsBuilder(
                        option.entryCount,
                        option.headerRowNumber,
                      ),
                    ),
                    onTap: _isCreating
                        ? null
                        : () => Navigator.of(context).pop(option.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
      ],
    );
  }
}
