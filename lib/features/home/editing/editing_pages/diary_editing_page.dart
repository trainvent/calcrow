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
  String pickButtonLabel(AppLocalizations localizations) =>
      localizations.jumpToday;

  @override
  Future<_OpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SheetData sheetData,
  ) async {
    final selection = state._selectEditorTargetRowForSheetData(sheetData);
    if (!selection.usedDateColumn || !selection.foundMatchingDateRow) {
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(
          content: Text(
            state.context.l10n.dateBasedOpeningBlocked(
              _EditingPageBaseState._formatDate(DateTime.now()),
            ),
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
    if (state._allowsAnyDate) {
      await state._pickTodayEntryFromCurrentSheet();
      return;
    }
    state._selectEditorTargetRow();
  }
}
