import 'package:flutter_riverpod/flutter_riverpod.dart';

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

const int createNewEntryPickIndex = -1;

class SheetPreviewNotifier extends Notifier<SheetPreviewData> {
  @override
  SheetPreviewData build() => SheetPreviewData.initial();

  void setData(SheetPreviewData data) => state = data;

  void update(SheetPreviewData Function(SheetPreviewData current) updateData) {
    state = updateData(state);
  }
}

final sheetPreviewProvider =
    NotifierProvider<SheetPreviewNotifier, SheetPreviewData>(
      SheetPreviewNotifier.new,
    );

class SheetPreviewRowPickNotifier
    extends Notifier<SheetPreviewRowPickRequest?> {
  @override
  SheetPreviewRowPickRequest? build() => null;

  void setRequest(SheetPreviewRowPickRequest? request) => state = request;
}

final sheetPreviewRowPickProvider =
    NotifierProvider<SheetPreviewRowPickNotifier, SheetPreviewRowPickRequest?>(
      SheetPreviewRowPickNotifier.new,
    );

class SheetPreviewIntEventNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void emit(int? value) => state = value;
}

final sheetPreviewRequestedTabProvider =
    NotifierProvider<SheetPreviewIntEventNotifier, int?>(
      SheetPreviewIntEventNotifier.new,
    );
final sheetPreviewPickedRowProvider =
    NotifierProvider<SheetPreviewIntEventNotifier, int?>(
      SheetPreviewIntEventNotifier.new,
    );

class SheetPreviewActions extends Notifier<void> {
  @override
  void build() {}

  void beginRowPick(SheetPreviewRowPickRequest request) {
    ref.read(sheetPreviewRowPickProvider.notifier).setRequest(request);
    ref.read(sheetPreviewPickedRowProvider.notifier).emit(null);
    ref.read(sheetPreviewRequestedTabProvider.notifier).emit(1);
  }

  void pickRow(int rowIndex) {
    ref.read(sheetPreviewPickedRowProvider.notifier).emit(rowIndex);
    ref.read(sheetPreviewRowPickProvider.notifier).setRequest(null);
    ref.read(sheetPreviewRequestedTabProvider.notifier).emit(0);
  }

  void pickNewEntry() => pickRow(createNewEntryPickIndex);

  void cancelRowPick() {
    ref.read(sheetPreviewRowPickProvider.notifier).setRequest(null);
    ref.read(sheetPreviewRequestedTabProvider.notifier).emit(0);
  }
}

final sheetPreviewActionsProvider = NotifierProvider<SheetPreviewActions, void>(
  SheetPreviewActions.new,
);
