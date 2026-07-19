import 'package:flutter/foundation.dart';

typedef SheetPreviewSaveAction = Future<void> Function();

class SheetPreviewRowPickRequest {
  const SheetPreviewRowPickRequest({
    required this.selectableRowIndexes,
    required this.title,
    required this.subtitle,
    this.allowCreateNewEntry = false,
    this.createNewEntryLabel,
  });

  final Set<int> selectableRowIndexes;
  final String title;
  final String subtitle;
  final bool allowCreateNewEntry;
  final String? createNewEntryLabel;

  bool canPick(int rowIndex) => selectableRowIndexes.contains(rowIndex);
}

class SheetPreviewData {
  const SheetPreviewData({
    required this.headers,
    required this.rows,
    required this.fileName,
    required this.rowCount,
    this.onSaveAsIs,
  });

  factory SheetPreviewData.initial() {
    return const SheetPreviewData(
      headers: <String>[
        'Date',
        'Start',
        'End',
        'Pause',
        'Mood',
        'Health',
        'Steps',
        'Notes',
      ],
      rows: <List<String>>[],
      fileName: null,
      rowCount: 0,
      onSaveAsIs: null,
    );
  }

  final List<String> headers;
  final List<List<String>> rows;
  final String? fileName;
  final int rowCount;
  final SheetPreviewSaveAction? onSaveAsIs;

  SheetPreviewData copyWith({
    List<String>? headers,
    List<List<String>>? rows,
    String? fileName,
    int? rowCount,
    SheetPreviewSaveAction? onSaveAsIs,
    bool clearFileName = false,
    bool clearOnSaveAsIs = false,
  }) {
    return SheetPreviewData(
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      rowCount: rowCount ?? this.rowCount,
      onSaveAsIs: clearOnSaveAsIs ? null : (onSaveAsIs ?? this.onSaveAsIs),
    );
  }
}

class SheetPreviewStore {
  static const int createNewEntryPickIndex = -1;

  static final ValueNotifier<SheetPreviewData> notifier =
      ValueNotifier<SheetPreviewData>(SheetPreviewData.initial());

  static final ValueNotifier<SheetPreviewRowPickRequest?> rowPickRequest =
      ValueNotifier<SheetPreviewRowPickRequest?>(null);

  static final ValueNotifier<int?> requestedTabIndex = ValueNotifier<int?>(
    null,
  );
  static final ValueNotifier<int?> pickedRowIndex = ValueNotifier<int?>(null);

  static void beginRowPick(SheetPreviewRowPickRequest request) {
    rowPickRequest.value = request;
    pickedRowIndex.value = null;
    requestedTabIndex.value = 1;
  }

  static void pickRow(int rowIndex) {
    pickedRowIndex.value = rowIndex;
    rowPickRequest.value = null;
    requestedTabIndex.value = 0;
  }

  static void pickNewEntry() {
    pickedRowIndex.value = createNewEntryPickIndex;
    rowPickRequest.value = null;
    requestedTabIndex.value = 0;
  }

  static void cancelRowPick() {
    rowPickRequest.value = null;
    requestedTabIndex.value = 0;
  }
}
