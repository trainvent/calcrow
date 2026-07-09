part of 'editing_page_base.dart';

class DiaryEditingPage extends EditingPageBase {
  const DiaryEditingPage({
    super.key,
    required super.initialSheetData,
    required super.initialDocumentTarget,
    super.initialSuccessMessage,
    super.showBackToSelection = false,
    super.onBackToSelection,
    super.sheetPersistenceService,
  }) : super(initialOpenMode: EditorOpenMode.dateBased);
}

class _DiaryEditingModeBehavior extends _EditingModeBehavior {
  const _DiaryEditingModeBehavior();

  @override
  EditorOpenMode get openMode => EditorOpenMode.dateBased;

  @override
  String get pickButtonLabel => 'Jump Today';

  @override
  Future<_OpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SimpleSheetData sheetData,
  ) async {
    final selection = state._selectEditorTargetRowForSheetData(sheetData);
    if (!selection.usedDateColumn || !selection.foundMatchingDateRow) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(
          content: Text(
            'Date-based opening is blocked because ${_EditingPageBaseState._formatDate(DateTime.now())} was not found in the detected date column.',
          ),
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
  Future<void> pickFromCurrentSheet(_EditingPageBaseState state) async {
    state._selectEditorTargetRow();
  }
}
