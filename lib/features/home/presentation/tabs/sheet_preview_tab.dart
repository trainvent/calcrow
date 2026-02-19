import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../sheet_preview_store.dart';

class SheetPreviewTab extends StatelessWidget {
  const SheetPreviewTab({super.key});

  static const XTypeGroup _csvTypeGroup = XTypeGroup(
    label: 'CSV',
    extensions: <String>['csv'],
  );
  static const int _maxPreviewRows = 100;
  static const int _maxPreviewColumns = 15;

  Future<void> _exportCsv(
    BuildContext context,
    SheetPreviewData preview,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final suggestedName = _suggestedExportName(preview.fileName);

    try {
      final location = await getSaveLocation(
        acceptedTypeGroups: <XTypeGroup>[_csvTypeGroup],
        suggestedName: suggestedName,
        confirmButtonText: 'Save CSV',
      );
      if (location == null) {
        return;
      }

      final csv = _buildCsv(preview);
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        name: suggestedName,
      );
      await file.saveTo(location.path);

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Exported CSV to ${location.path}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('CSV export failed: $error')),
      );
    }
  }

  static String _suggestedExportName(String? fileName) {
    final fallback = 'calcrow_export.csv';
    if (fileName == null || fileName.trim().isEmpty) return fallback;
    final trimmed = fileName.trim();
    if (trimmed.toLowerCase().endsWith('.csv')) return trimmed;
    return '$trimmed.csv';
  }

  static String _buildCsv(SheetPreviewData preview) {
    final buffer = StringBuffer()
      ..writeln(preview.headers.map(_escapeCsvCell).join(','));
    for (final row in preview.rows) {
      final normalized = List<String>.generate(
        preview.headers.length,
        (index) => index < row.length ? row[index] : '',
      );
      buffer.writeln(normalized.map(_escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  static String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    final mustQuote =
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n');
    return mustQuote ? '"$escaped"' : escaped;
  }

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
        final canSaveAsIs = preview.onSaveAsIs != null;
        final tableHeight = (MediaQuery.sizeOf(context).height * 0.48).clamp(
          220.0,
          420.0,
        );
        final minTableWidth = math.max(
          (previewHeaders.length * 140).toDouble(),
          560.0,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            Text('Sheet Preview', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              preview.fileName != null
                  ? 'File: ${preview.fileName} (${preview.rowCount} rows) • Showing first ${previewRows.length} rows / ${previewHeaders.length} columns'
                  : 'No file loaded yet. Import/create from the Today tab.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: tableHeight,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportCsv(context, preview),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export CSV'),
                  ),
                ),
                if (canSaveAsIs) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: hasRows
                          ? () async {
                              await preview.onSaveAsIs?.call();
                            }
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save as is'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
