part of 'editing_page_base.dart';

class LogbookEditingPage extends EditingPageBase {
  const LogbookEditingPage({
    super.key,
    required super.initialSheetData,
    required super.initialDocumentTarget,
    super.initialSuccessMessage,
    super.showBackToSelection = false,
    super.onBackToSelection,
    super.sheetPersistenceService,
  }) : super(initialOpenMode: EditorOpenMode.dateBasedOpenEnd);
}

class _LogbookEditingModeBehavior extends _EditingModeBehavior {
  const _LogbookEditingModeBehavior();

  @override
  EditorOpenMode get openMode => EditorOpenMode.dateBasedOpenEnd;

  @override
  String get pickButtonLabel => 'Pick';

  @override
  bool get showsDateOpenEndActions => true;

  @override
  String get requiredFirstColumnType => 'date';

  @override
  Future<_OpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SimpleSheetData sheetData,
  ) async {
    if (state._cachedFirstColumnBlocksDateBasedOpening(sheetData)) {
      state._showCachedTypeMismatchSnackBar(
        'Cached field types do not match Logbook.',
      );
      return null;
    }
    final selection = state._selectEditorTargetRowForSheetData(sheetData);
    if (!selection.usedDateColumn) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(
          content: Text('Date-based open-end needs a detected date column.'),
        ),
      );
      return null;
    }
    return _OpeningSelection(
      targetRowIndex: selection.targetRowIndex,
      textColumnIndex: null,
      textValue: null,
    );
  }

  @override
  void handleSheetPreviewRowPick(_EditingPageBaseState state, int rowIndex) {
    state._selectLogbookPreviewRow(rowIndex);
  }

  @override
  Future<void> pickFromCurrentSheet(_EditingPageBaseState state) async {
    await state._pickTodayEntryFromCurrentSheet();
  }
}
