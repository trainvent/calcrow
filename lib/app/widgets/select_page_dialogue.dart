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
