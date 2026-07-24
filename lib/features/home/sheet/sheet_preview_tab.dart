import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sheet_preview_store.dart';

class SheetPreviewTab extends ConsumerStatefulWidget {
  const SheetPreviewTab({super.key});

  @override
  ConsumerState<SheetPreviewTab> createState() => _SheetPreviewTabState();
}

class _SheetPreviewTabState extends ConsumerState<SheetPreviewTab> {
  static const int _maxPreviewRows = 100;
  static const int _maxPreviewColumns = 15;
  static const Duration _rowPickConfirmDelay = Duration(milliseconds: 260);

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  Object? _lastAutoScrollSignature;
  int? _confirmingRowIndex;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialScrollToBottom(SheetPreviewData preview) {
    if (preview.rows.isEmpty) return;
    final signature = (
      preview.fileName,
      preview.rowCount,
      identityHashCode(preview.rows),
    );
    if (_lastAutoScrollSignature == signature) return;
    _lastAutoScrollSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalScrollController.hasClients) return;
      _verticalScrollController.jumpTo(
        _verticalScrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _confirmRowPick(int rowIndex) async {
    if (_confirmingRowIndex != null) return;
    setState(() => _confirmingRowIndex = rowIndex);
    await Future<void>.delayed(_rowPickConfirmDelay);
    if (!mounted) return;
    if (ref.read(sheetPreviewRowPickProvider)?.canPick(rowIndex) != true) {
      setState(() => _confirmingRowIndex = null);
      return;
    }
    ref.read(sheetPreviewActionsProvider.notifier).pickRow(rowIndex);
    setState(() => _confirmingRowIndex = null);
  }

  Future<void> _confirmNewEntryPick() async {
    if (_confirmingRowIndex != null) return;
    setState(() => _confirmingRowIndex = createNewEntryPickIndex);
    await Future<void>.delayed(_rowPickConfirmDelay);
    if (!mounted) return;
    if (ref.read(sheetPreviewRowPickProvider)?.allowCreateNewEntry != true) {
      setState(() => _confirmingRowIndex = null);
      return;
    }
    ref.read(sheetPreviewActionsProvider.notifier).pickNewEntry();
    setState(() => _confirmingRowIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = ref.watch(sheetPreviewProvider);
    final rowPickRequest = ref.watch(sheetPreviewRowPickProvider);
    _scheduleInitialScrollToBottom(preview);
    final previewHeaders = preview.headers.take(_maxPreviewColumns).toList();
    final previewStartRowIndex = math.max(
      0,
      preview.rows.length - _maxPreviewRows,
    );
    final previewRows = preview.rows.indexed
        .skip(previewStartRowIndex)
        .map(
          (entry) => (
            entry.$1,
            List<String>.generate(
              previewHeaders.length,
              (index) => index < entry.$2.length ? entry.$2[index] : '-',
            ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  rowPickRequest?.title ?? context.l10n.sheetPreview,
                  style: theme.textTheme.headlineLarge,
                ),
              ),
              if (rowPickRequest != null)
                TextButton.icon(
                  onPressed: ref
                      .read(sheetPreviewActionsProvider.notifier)
                      .cancelRowPick,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(context.l10n.cancel),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (rowPickRequest != null) ...[
            Text(rowPickRequest.subtitle, style: theme.textTheme.bodyLarge),
          ] else if (preview.fileName != null) ...[
            Text(
              preview.fileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.previewRowCount(preview.rowCount),
                  style: theme.textTheme.bodyMedium,
                ),
                if (hasRows) ...[
                  Text(' (', style: theme.textTheme.bodyMedium),
                  Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  Text(
                    ' > ${previewStartRowIndex + 1})',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                Text(
                  ' • ${context.l10n.previewColumnCount(previewHeaders.length)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ] else
            Text(
              context.l10n.noFileLoadedYet,
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
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        thickness: 2,
                        radius: const Radius.circular(1),
                        interactive: false,
                        scrollbarOrientation: ScrollbarOrientation.right,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            thickness: 2,
                            radius: const Radius.circular(1),
                            interactive: false,
                            scrollbarOrientation: ScrollbarOrientation.bottom,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
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
                                      (label) => DataColumn(label: Text(label)),
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
  }

  List<DataRow> _buildPreviewRows({
    required List<(int, List<String>)> previewRows,
    required List<String> previewHeaders,
    required bool hasRows,
    required SheetPreviewRowPickRequest? rowPickRequest,
  }) {
    final rows = <DataRow>[
      for (final entry
          in (hasRows
              ? previewRows
              : rowPickRequest == null
              ? <(int, List<String>)>[
                  (0, List<String>.filled(previewHeaders.length, '-')),
                ]
              : const <(int, List<String>)>[]))
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
                confirming: _confirmingRowIndex == createNewEntryPickIndex,
              ),
            ),
            ...List<DataCell>.generate(
              previewHeaders.length,
              (index) => DataCell(
                index == 0
                    ? Text(rowPickRequest!.createNewEntryLabel!)
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
      label: context.l10n.createNewEntry,
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
      label: context.l10n.pickRow,
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
