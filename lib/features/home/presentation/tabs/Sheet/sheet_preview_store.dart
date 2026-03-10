import 'package:flutter/foundation.dart';

typedef SheetPreviewSaveAction = Future<void> Function();

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
  static final ValueNotifier<SheetPreviewData> notifier =
      ValueNotifier<SheetPreviewData>(SheetPreviewData.initial());
}
