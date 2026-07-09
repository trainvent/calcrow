part of 'editing_page_base.dart';

class NamelistEditingPage extends EditingPageBase {
  const NamelistEditingPage({
    super.key,
    required super.initialSheetData,
    required super.initialDocumentTarget,
    super.initialSuccessMessage,
    super.showBackToSelection = false,
    super.onBackToSelection,
    super.sheetPersistenceService,
  }) : super(initialOpenMode: EditorOpenMode.textBased);
}

class _NamelistEditingModeBehavior extends _EditingModeBehavior {
  const _NamelistEditingModeBehavior();

  @override
  EditorOpenMode get openMode => EditorOpenMode.textBased;

  @override
  String get pickButtonLabel => 'Pick';

  @override
  bool get showsTextEntryActions => true;

  @override
  String get requiredFirstColumnType => 'text';

  @override
  Future<_OpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SimpleSheetData sheetData,
  ) async {
    if (state._cachedFirstColumnBlocksTextBasedOpening(sheetData)) {
      state._showCachedTypeMismatchSnackBar(
        'Cached field types do not match Namelist.',
      );
      return null;
    }
    return const _OpeningSelection(
      targetRowIndex: 0,
      textColumnIndex: null,
      textValue: null,
    );
  }

  @override
  void afterLoaded(_EditingPageBaseState state) {
    if (state._documentRows.isNotEmpty) {
      state._beginTextEntryRowPick();
    }
  }

  @override
  void handleSheetPreviewRowPick(_EditingPageBaseState state, int rowIndex) {
    state._selectNamelistPreviewRow(rowIndex);
  }

  @override
  Future<void> handleSheetPreviewNewEntryPick(
    _EditingPageBaseState state,
  ) async {
    await state._createNewTextEntry();
  }

  @override
  Future<void> pickFromCurrentSheet(_EditingPageBaseState state) async {
    state._beginTextEntryRowPick();
  }
}
