import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'sheet_preview_store.dart';

class SheetPreviewTab extends StatelessWidget {
  const SheetPreviewTab({super.key});

  static const int _maxPreviewRows = 100;
  static const int _maxPreviewColumns = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<SheetPreviewData>(
      valueListenable: SheetPreviewStore.notifier,
      builder: (context, preview, _) {
        final previewHeaders = preview.headers
            .take(_maxPreviewColumns)
            .toList();
        final previewRows = preview.rows
            .take(_maxPreviewRows)
            .map(
              (row) => List<String>.generate(
                previewHeaders.length,
                (index) => index < row.length ? row[index] : '-',
              ),
            )
            .toList();
        final hasRows = previewRows.isNotEmpty;
        final tableHeight = (MediaQuery.sizeOf(context).height * 0.48).clamp(
          220.0,
          420.0,
        );
        final minTableWidth = math.max(
          (previewHeaders.length * 140).toDouble(),
          560.0,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sheet Preview', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              if (preview.fileName != null) ...[
                Text(
                  preview.fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${preview.rowCount} rows • ${previewHeaders.length} columns',
                  style: theme.textTheme.bodyMedium,
                ),
              ] else
                Text(
                  'No file loaded yet. Import/create from the Today tab.',
                  style: theme.textTheme.bodyLarge,
                ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRect(
                          child: InteractiveViewer(
                            constrained: false,
                            panEnabled: true,
                            scaleEnabled: false,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: math.max(
                                  constraints.maxWidth,
                                  minTableWidth,
                                ),
                                minHeight: math.max(
                                  constraints.maxHeight,
                                  tableHeight,
                                ),
                              ),
                              child: DataTable(
                                columns: previewHeaders
                                    .map(
                                      (label) => DataColumn(label: Text(label)),
                                    )
                                    .toList(),
                                rows:
                                    (hasRows
                                            ? previewRows
                                            : <List<String>>[
                                                List<String>.filled(
                                                  previewHeaders.length,
                                                  '-',
                                                ),
                                              ])
                                        .map(
                                          (row) => DataRow(
                                            cells: List<DataCell>.generate(
                                              previewHeaders.length,
                                              (index) => DataCell(
                                                Text(
                                                  index < row.length
                                                      ? row[index]
                                                      : '-',
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
