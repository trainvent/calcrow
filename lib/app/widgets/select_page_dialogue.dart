import 'package:flutter/material.dart';

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
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => SelectPageDialogue(
      title: title,
      description: description,
      cancelLabel: cancelLabel,
      detailsBuilder: detailsBuilder,
      options: options,
    ),
  );
}

class SelectPageDialogue extends StatelessWidget {
  const SelectPageDialogue({
    super.key,
    required this.title,
    required this.description,
    required this.cancelLabel,
    required this.detailsBuilder,
    required this.options,
  });

  final String title;
  final String description;
  final String cancelLabel;
  final String Function(int entryCount, int headerRowNumber) detailsBuilder;
  final List<SelectPageOption> options;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return ListTile(
                    leading: const Icon(Icons.table_chart_outlined),
                    title: Text(option.name),
                    subtitle: Text(
                      detailsBuilder(option.entryCount, option.headerRowNumber),
                    ),
                    onTap: () => Navigator.of(context).pop(option.name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ],
    );
  }
}
