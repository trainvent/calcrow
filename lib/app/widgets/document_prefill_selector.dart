import 'package:flutter/material.dart';

import 'package:calcrow/core/prefills/document_prefill.dart';

class DocumentPrefillSelector extends StatelessWidget {
  const DocumentPrefillSelector({
    super.key,
    required this.label,
    required this.prefills,
    required this.onSelected,
  });

  final String label;
  final List<DocumentPrefill> prefills;
  final ValueChanged<DocumentPrefill> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < prefills.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      OutlinedButton(
                        key: ValueKey(
                          'document-prefill-${prefills[index].name}',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => onSelected(prefills[index]),
                        child: Text(prefills[index].name),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
