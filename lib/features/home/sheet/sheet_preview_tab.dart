import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sheet_preview_store.dart';

class SheetPreviewTab extends StatefulWidget {
  const SheetPreviewTab({super.key});

  @override
  State<SheetPreviewTab> createState() => _SheetPreviewTabState();
}

class _SheetPreviewTabState extends State<SheetPreviewTab> {
  static const int _maxPreviewRows = 100;
  static const int _maxPreviewColumns = 15;
  static const Duration _rowPickConfirmDelay = Duration(milliseconds: 260);

  int? _confirmingRowIndex;

  Future<void> _confirmRowPick(int rowIndex) async {
    if (_confirmingRowIndex != null) return;
    setState(() => _confirmingRowIndex = rowIndex);
    await Future<void>.delayed(_rowPickConfirmDelay);
    if (!mounted) return;
    if (SheetPreviewStore.rowPickRequest.value?.canPick(rowIndex) != true) {
      setState(() => _confirmingRowIndex = null);
      return;
    }
    SheetPreviewStore.pickRow(rowIndex);
    setState(() => _confirmingRowIndex = null);
  }

  Future<void> _confirmNewEntryPick() async {
    if (_confirmingRowIndex != null) return;
    setState(
      () => _confirmingRowIndex = SheetPreviewStore.createNewEntryPickIndex,
    );
    await Future<void>.delayed(_rowPickConfirmDelay);
    if (!mounted) return;
    if (SheetPreviewStore.rowPickRequest.value?.allowCreateNewEntry != true) {
      setState(() => _confirmingRowIndex = null);
      return;
    }
    SheetPreviewStore.pickNewEntry();
    setState(() => _confirmingRowIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<SheetPreviewData>(
      valueListenable: SheetPreviewStore.notifier,
      builder: (context, preview, _) {
        return ValueListenableBuilder<SheetPreviewRowPickRequest?>(
          valueListenable: SheetPreviewStore.rowPickRequest,
          builder: (context, rowPickRequest, _) {
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
            final tableHeight = (MediaQuery.sizeOf(context).height * 0.48)
                .clamp(220.0, 420.0);
            final minTableWidth = math.max(
              (previewHeaders.length * 140).toDouble(),
              560.0,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rowPickRequest?.title ?? 'Sheet Preview',
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                      if (rowPickRequest != null)
                        TextButton.icon(
                          onPressed: SheetPreviewStore.cancelRowPick,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rowPickRequest != null) ...[
                    Text(
                      rowPickRequest.subtitle,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ] else if (preview.fileName != null) ...[
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
                      'No file selected yet.',
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
                                    showCheckboxColumn: false,
                                    columns: <DataColumn>[
                                      if (rowPickRequest != null)
                                        const DataColumn(
                                          label: SizedBox(width: 28),
                                        ),
                                      ...previewHeaders.map(
                                        (label) =>
                                            DataColumn(label: Text(label)),
                                      ),
                                    ],
                                    rows: _buildPreviewRows(
                                      previewRows: previewRows,
                                      previewHeaders: previewHeaders,
                                      hasRows: hasRows,
                                      rowPickRequest: rowPickRequest,
                                    ),
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
      },
    );
  }

  List<DataRow> _buildPreviewRows({
    required List<List<String>> previewRows,
    required List<String> previewHeaders,
    required bool hasRows,
    required SheetPreviewRowPickRequest? rowPickRequest,
  }) {
    final rows = <DataRow>[
      for (final entry
          in (hasRows
                  ? previewRows
                  : rowPickRequest == null
                  ? <List<String>>[
                      List<String>.filled(previewHeaders.length, '-'),
                    ]
                  : const <List<String>>[])
              .indexed)
        _buildPreviewDataRow(
          rowIndex: entry.$1,
          row: entry.$2,
          previewHeaders: previewHeaders,
          rowPickRequest: rowPickRequest,
        ),
    ];

    if (rowPickRequest?.allowCreateNewEntry == true) {
      rows.add(
        DataRow(
          onSelectChanged: (_) => _confirmNewEntryPick(),
          cells: <DataCell>[
            DataCell(
              _NewEntryIndicator(
                confirming:
                    _confirmingRowIndex ==
                    SheetPreviewStore.createNewEntryPickIndex,
              ),
            ),
            ...List<DataCell>.generate(
              previewHeaders.length,
              (index) => DataCell(
                index == 0
                    ? Text(rowPickRequest!.createNewEntryLabel)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  DataRow _buildPreviewDataRow({
    required int rowIndex,
    required List<String> row,
    required List<String> previewHeaders,
    required SheetPreviewRowPickRequest? rowPickRequest,
  }) {
    final canPick = rowPickRequest?.canPick(rowIndex) ?? false;
    return DataRow(
      onSelectChanged: canPick ? (_) => _confirmRowPick(rowIndex) : null,
      cells: <DataCell>[
        if (rowPickRequest != null)
          DataCell(
            canPick
                ? _RowPickIndicator(confirming: _confirmingRowIndex == rowIndex)
                : const SizedBox(width: 26, height: 26),
          ),
        ...List<DataCell>.generate(
          previewHeaders.length,
          (index) => DataCell(Text(index < row.length ? row[index] : '-')),
        ),
      ],
    );
  }
}

class _NewEntryIndicator extends StatelessWidget {
  const _NewEntryIndicator({required this.confirming});

  final bool confirming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Create new entry',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: confirming
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.primary,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 18,
          color: confirming
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}

class _RowPickIndicator extends StatelessWidget {
  const _RowPickIndicator({required this.confirming});

  final bool confirming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Pick row',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 26,
        height: 26,
        padding: EdgeInsets.all(confirming ? 2 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: confirming ? theme.colorScheme.primaryContainer : null,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: confirming ? 1 : 0,
          child: ClipOval(
            child: SvgPicture.asset(
              'assets/images/LeLogo.svg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
