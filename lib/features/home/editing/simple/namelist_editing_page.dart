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

class _NamelistEditingModeBehavior extends _SimpleEditingModeBehavior {
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
  Future<_SimpleOpeningSelection?> resolveOpening(
    _EditingPageBaseState state,
    SimpleSheetData sheetData,
  ) async {
    if (state._cachedFirstColumnBlocksTextBasedOpening(sheetData)) {
      state._showCachedTypeMismatchSnackBar(
        'Cached field types do not match Namelist.',
      );
      return null;
    }
    return const _SimpleOpeningSelection(
      targetRowIndex: 0,
      textColumnIndex: null,
      textValue: null,
    );
  }

  @override
  void afterLoaded(_EditingPageBaseState state) {
    if (state._simpleRows.isNotEmpty) {
      state._beginSimpleTextEntryRowPick();
    }
  }

  @override
  void handleSheetPreviewRowPick(_EditingPageBaseState state, int rowIndex) {
    state._selectNamelistPreviewRow(rowIndex);
  }

  @override
  Future<void> pickFromCurrentSheet(_EditingPageBaseState state) async {
    state._beginSimpleTextEntryRowPick();
  }
}
