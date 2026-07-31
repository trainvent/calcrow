import 'dart:async';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:saf_util/saf_util.dart';
import 'package:trainvent_general/trainvent_general.dart';

import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/cloud_document_service.dart';
import 'package:calcrow/core/data/services/local_document_service.dart';
import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_models.dart';
import 'package:calcrow/core/sheet_type_logic/sheet_file_service.dart';
import 'package:calcrow/core/sheet_type_logic/type_hint_cache.dart';
import 'package:calcrow/core/sheet_type_logic/xlsx_codec.dart';
import 'package:calcrow/core/theme/app_text_styles.dart';
import 'package:calcrow/core/theme/app_layout_constants.dart';
import 'package:calcrow/core/prefills/document_prefill.dart';
import 'package:calcrow/core/prefills/document_prefill_cache.dart';
import 'package:calcrow/app/widgets/dual_text_button.dart';
import 'package:calcrow/app/widgets/select_page_dialogue.dart';

import 'create_doc_page.dart';
import 'choose_file_location_page.dart';
import 'editing_pages/editing_page_base.dart';

enum _SetupAction { open, create }

enum _LocalCreateTarget { currentSafFolder, pickSafFolder }

enum _DocumentSource { local, cloud }

class _SheetSelectionCanceled implements Exception {
  const _SheetSelectionCanceled();
}

class SelectionPage extends ConsumerStatefulWidget {
  const SelectionPage({super.key});

  @override
  ConsumerState<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends ConsumerState<SelectionPage> {
  List<XTypeGroup> get _localDocumentTypeGroups => <XTypeGroup>[
    XTypeGroup(label: context.l10n.csv, extensions: const <String>['csv']),
    XTypeGroup(label: context.l10n.xlsx, extensions: const <String>['xlsx']),
    XTypeGroup(label: context.l10n.ods, extensions: const <String>['ods']),
  ];

  static final SafUtil _safUtil = SafUtil();

  final SheetPersistenceService _sheetPersistenceService =
      SheetPersistenceService();

  EditorOpenMode _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
  _SetupAction _documentSetupAction = _SetupAction.open;
  _DocumentSource _documentDocumentSource = _DocumentSource.local;
  LocalDocumentSelection? _selectedLocalDocument;
  String? _documentImportedFileName;
  String? _documentImportedPath;
  Uint8List? _documentImportedSourceBytes;
  bool _rememberLocalDocumentForReopen = false;
  bool _isOpeningDocument = false;
  bool _isChoosingLocalDocument = false;
  bool _isChoosingCloudFile = false;
  CloudFileMetadata? _pendingCloudFileSelection;
  Widget? _activeEditor;

  bool get _supportsLocalFileEditing =>
      kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  _DocumentSource get _effectiveDocumentSource {
    if (!_supportsLocalFileEditing &&
        _documentDocumentSource == _DocumentSource.local) {
      return _DocumentSource.cloud;
    }
    return _documentDocumentSource;
  }

  bool get _hasRememberedLocalDocument =>
      _rememberLocalDocumentForReopen &&
      (_documentImportedPath?.trim().isNotEmpty == true ||
          (_documentImportedSourceBytes?.isNotEmpty ?? false)) &&
      (_documentImportedFileName?.trim().isNotEmpty == true);

  Future<void> _runWithDocumentOpeningIndicator(
    Future<void> Function() action,
  ) async {
    if (_isOpeningDocument) return;
    setState(() => _isOpeningDocument = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isOpeningDocument = false);
    }
  }

  Future<SheetData> _parseSheetData({
    required Uint8List bytes,
    required String fileName,
    required String? path,
    String? mimeType,
  }) async {
    final format = SheetFileService.detectFormat(
      fileName: fileName,
      path: path,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (format == SheetFileFormat.xlsx) {
      final inspection = XlsxSheetCodec.inspectSheets(
        bytes: bytes,
        fileName: fileName,
        path: path,
      );
      if (inspection.sheetCount > 1) {
        final monthSuggestion = _documentOpenMode == EditorOpenMode.textBased
            ? null
            : XlsxSheetCodec.suggestCurrentMonthSheet(
                bytes: bytes,
                fileName: fileName,
                preferredLanguageCode: Localizations.localeOf(
                  context,
                ).languageCode,
              );
        final compatibleSheets = inspection.sheets.where((sheet) {
          return switch (_documentOpenMode) {
            EditorOpenMode.dateBased ||
            EditorOpenMode.dateBasedOpenEnd => sheet.hasDateColumn,
            EditorOpenMode.textBased => sheet.hasEditableTextColumn,
          };
        }).toList();
        if (compatibleSheets.isEmpty) {
          throw FormatException(
            context.l10n.noCompatibleWorksheetsForOpeningMode(
              _documentOpenModeLabel(context.l10n, _documentOpenMode),
            ),
          );
        }
        if (!mounted) throw const _SheetSelectionCanceled();
        SheetData? createdSheetData;
        final selectedSheetName = await showSelectPageDialogue(
          context: context,
          title: context.l10n.chooseWorksheet,
          description: context.l10n.onlyCompatibleWorksheetsShown(
            _documentOpenModeLabel(context.l10n, _documentOpenMode),
          ),
          cancelLabel: context.l10n.cancel,
          detailsBuilder: (entryCount, headerRowNumber) => context.l10n
              .worksheetEntryAndHeaderDetails(entryCount, headerRowNumber),
          options: compatibleSheets
              .map(
                (sheet) => SelectPageOption(
                  name: sheet.name,
                  entryCount: sheet.entryCount,
                  headerRowNumber: sheet.headerRowIndex + 1,
                ),
              )
              .toList(),
          createOptionTooltip: monthSuggestion == null
              ? null
              : context.l10n.createCurrentMonthWorksheet,
          onCreateOption: monthSuggestion == null
              ? null
              : () async {
                  final shouldCreate = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(
                        context.l10n.createWorksheetNamed(
                          monthSuggestion.targetSheetName,
                        ),
                      ),
                      content: Text(
                        context.l10n.createMonthlyWorksheetConfirmation(
                          monthSuggestion.targetSheetName,
                          monthSuggestion.sourceSheetName,
                          monthSuggestion.year,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(context.l10n.tryCreateWorksheet),
                        ),
                      ],
                    ),
                  );
                  if (shouldCreate != true || !mounted) return null;
                  try {
                    createdSheetData = XlsxSheetCodec.createCurrentMonthSheet(
                      bytes: bytes,
                      fileName: fileName,
                      path: path,
                      preferredLanguageCode: Localizations.localeOf(
                        context,
                      ).languageCode,
                    );
                    return createdSheetData?.xlsxSheetName;
                  } catch (error) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.couldNotCreateCurrentMonthWorksheet(
                              error.toString(),
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  }
                },
        );
        if (!mounted || selectedSheetName == null) {
          throw const _SheetSelectionCanceled();
        }
        if (createdSheetData != null) return createdSheetData!;
        return SheetFileService.parse(
          bytes: bytes,
          fileName: fileName,
          path: path,
          mimeType: mimeType,
          xlsxSheetName: selectedSheetName,
        );
      }
    }
    return SheetFileService.parse(
      bytes: bytes,
      fileName: fileName,
      path: path,
      mimeType: mimeType,
    );
  }

  Future<void> _pushEditor({
    required SheetData sheetData,
    required EditorDocumentTarget target,
    String? successMessage,
  }) async {
    if (!mounted) return;
    if (_handleCachedTypeMismatchBeforeOpening(
      sheetData: sheetData,
      target: target,
    )) {
      return;
    }
    setState(() {
      _activeEditor = _buildEditingPage(
        sheetData: sheetData,
        target: target,
        successMessage: successMessage,
      );
    });
  }

  Widget _buildEditingPage({
    required SheetData sheetData,
    required EditorDocumentTarget target,
    String? successMessage,
  }) {
    return switch (_documentOpenMode) {
      EditorOpenMode.dateBased => DiaryEditingPage(
        initialSheetData: sheetData,
        initialDocumentTarget: target,
        initialSuccessMessage: successMessage,
        showBackToSelection: true,
        onBackToSelection: _returnToSelection,
      ),
      EditorOpenMode.dateBasedOpenEnd => LogbookEditingPage(
        initialSheetData: sheetData,
        initialDocumentTarget: target,
        initialSuccessMessage: successMessage,
        showBackToSelection: true,
        onBackToSelection: _returnToSelection,
      ),
      EditorOpenMode.textBased => NamelistEditingPage(
        initialSheetData: sheetData,
        initialDocumentTarget: target,
        initialSuccessMessage: successMessage,
        showBackToSelection: true,
        onBackToSelection: _returnToSelection,
      ),
    };
  }

  bool _handleCachedTypeMismatchBeforeOpening({
    required SheetData sheetData,
    required EditorDocumentTarget target,
  }) {
    if (!sheetData.hasCachedValueTypes || sheetData.valueTypes.isEmpty) {
      return false;
    }
    final firstCachedType = sheetData.valueTypes.first.trim().toLowerCase();
    final message = switch (_documentOpenMode) {
      EditorOpenMode.dateBasedOpenEnd when firstCachedType != 'date' =>
        'Cached field types do not match Logbook.',
      EditorOpenMode.textBased when firstCachedType != 'text' =>
        'Cached field types do not match Namelist.',
      _ => null,
    };
    if (message == null) return false;
    _showCachedTypeMismatchSnackBar(
      sheetData: sheetData,
      target: target,
      message: message,
    );
    return true;
  }

  void _showCachedTypeMismatchSnackBar({
    required SheetData sheetData,
    required EditorDocumentTarget target,
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Expanded(child: Text(message, maxLines: 2)),
            IconButton(
              tooltip: context.l10n.clearCachedFieldTypes,
              icon: const Icon(Icons.cleaning_services_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                unawaited(_confirmClearCachedTypeHints(sheetData, target));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCachedTypeHints(
    SheetData sheetData,
    EditorDocumentTarget target,
  ) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.clearCachedFieldTypes2),
        content: Text(
          context.l10n.clearRememberedFieldTypes(sheetData.fileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.cleaning_services_rounded),
            label: Text(context.l10n.clearCache),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      await _clearCachedTypeHintsForSheet(sheetData, target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cachedFieldTypesCleared)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotClearCachedFieldTypes('$error')),
        ),
      );
    }
  }

  Future<void> _clearCachedTypeHintsForSheet(
    SheetData sheetData,
    EditorDocumentTarget target,
  ) async {
    if (target is CloudEditorDocumentTarget) {
      await ref
          .read(cloudDocumentServiceProvider)
          .clearTypeHints(
            file: CloudFileMetadata(
              provider: target.provider,
              id: target.fileId,
              name: target.fileName,
              mimeType: target.mimeType,
            ),
          );
      return;
    }
    await TypeHintCache.clearCsvTypes(
      fileName: sheetData.fileName,
      path: sheetData.path,
    );
  }

  void _returnToSelection() {
    if (!mounted) return;
    setState(() => _activeEditor = null);
  }

  Future<void> _chooseLocalDocument() async {
    if (!_supportsLocalFileEditing) return;
    if (_isChoosingLocalDocument || _isOpeningDocument) return;
    setState(() {
      _documentSetupAction = _SetupAction.open;
      _documentDocumentSource = _DocumentSource.local;
      _isChoosingLocalDocument = true;
    });
    try {
      final selection = await ref
          .read(localDocumentServiceProvider)
          .pickDocumentForEditor(
            acceptedTypeGroups: _localDocumentTypeGroups,
            readXFilePath: _readXFilePath,
            confirmButtonText: context.l10n.openDocument,
          );
      if (!mounted || selection == null) return;
      setState(() => _cacheSelectedLocalDocument(selection));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectedLocalDocument(selection.fileName)),
        ),
      );
    } on LocalDocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.localizedMessage(context.l10n))),
      );
    } on UnsupportedError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.couldNotSelectDocument(error.message ?? '$error'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotSelectDocument('$error'))),
      );
    } finally {
      if (mounted) setState(() => _isChoosingLocalDocument = false);
    }
  }

  void _cacheSelectedLocalDocument(LocalDocumentSelection selection) {
    _selectedLocalDocument = selection;
    _documentImportedFileName = selection.fileName;
    _documentImportedPath = selection.existingPath;
    _documentImportedSourceBytes = selection.bytes;
    _rememberLocalDocumentForReopen = true;
  }

  Future<void> _openOrChooseLocalDocument() async {
    if (!_supportsLocalFileEditing) return;
    if (!_hasRememberedLocalDocument) {
      await _importLocalDocument();
      return;
    }

    await _runWithDocumentOpeningIndicator(() async {
      try {
        final result = await ref
            .read(localDocumentServiceProvider)
            .reopenDocumentForEditor(
              fileName: _documentImportedFileName!,
              existingPath: _documentImportedPath,
              cachedBytes: _documentImportedSourceBytes,
              parseSheetData: _parseSheetData,
            );
        if (!mounted) return;
        await _pushEditor(
          sheetData: result.sheetData,
          target: LocalEditorDocumentTarget(existingPath: result.existingPath),
          successMessage: context.l10n.openedLocalDocument(
            result.sheetData.fileName,
          ),
        );
      } on _SheetSelectionCanceled {
        return;
      } on LocalDocumentException {
        if (!mounted) return;
        setState(() => _rememberLocalDocumentForReopen = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldNotReopenTheRememberedLocalFileChooseItAgain,
            ),
          ),
        );
        await _importLocalDocument();
      } catch (_) {
        if (!mounted) return;
        setState(() => _rememberLocalDocumentForReopen = false);
        await _importLocalDocument();
      }
    });
  }

  Future<void> _importLocalDocument() async {
    await _runWithDocumentOpeningIndicator(() async {
      try {
        var selection = _selectedLocalDocument;
        if (selection == null) {
          selection = await ref
              .read(localDocumentServiceProvider)
              .pickDocumentForEditor(
                acceptedTypeGroups: _localDocumentTypeGroups,
                readXFilePath: _readXFilePath,
                confirmButtonText: context.l10n.openDocument,
              );
          if (!mounted || selection == null) return;
          _cacheSelectedLocalDocument(selection);
        }
        final result = await ref
            .read(localDocumentServiceProvider)
            .openSelectedDocumentForEditor(
              selection: selection,
              parseSheetData: _parseSheetData,
            );
        if (!mounted) return;

        final sheetData = result.sheetData;
        final sheetName = sheetData.xlsxSheetName ?? context.l10n.defaultLabel;
        final sourceLabel = switch (sheetData.format) {
          SheetFileFormat.csv => context.l10n.loadedEntries(
            sheetData.fileName,
            sheetData.rows.length,
          ),
          SheetFileFormat.xlsx =>
            result.hasSafTarget
                ? context.l10n.loadedEntriesFromTabSafReady(
                    sheetData.fileName,
                    sheetData.rows.length,
                    sheetName,
                  )
                : context.l10n.loadedEntriesFromTabSafMissing(
                    sheetData.fileName,
                    sheetData.rows.length,
                    sheetName,
                  ),
          SheetFileFormat.ods =>
            result.hasSafTarget
                ? context.l10n.loadedEntriesFromSheetSafReady(
                    sheetData.fileName,
                    sheetData.rows.length,
                    sheetName,
                  )
                : context.l10n.loadedEntriesFromSheetSafMissing(
                    sheetData.fileName,
                    sheetData.rows.length,
                    sheetName,
                  ),
          SheetFileFormat.gsheet => context.l10n.loadedGoogleSheetEntries(
            sheetData.fileName,
            sheetData.rows.length,
            sheetName,
          ),
        };
        await _pushEditor(
          sheetData: sheetData,
          target: LocalEditorDocumentTarget(existingPath: result.existingPath),
          successMessage: sourceLabel,
        );
      } on _SheetSelectionCanceled {
        return;
      } on LocalDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.localizedMessage(context.l10n))),
        );
      } on UnsupportedError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.importFailed(error.message ?? '$error')),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.importFailed('$error'))),
        );
      }
    });
  }

  Future<void> _openCloudDocument({required CloudFileMetadata file}) async {
    await _runWithDocumentOpeningIndicator(() async {
      try {
        final result = await ref
            .read(cloudDocumentServiceProvider)
            .openDocument(file: file, parseSheetData: _parseSheetData);
        if (!mounted) return;
        await _pushEditor(
          sheetData: result.sheetData,
          target: CloudEditorDocumentTarget(
            provider: result.file.provider,
            fileId: result.file.id,
            fileName: result.file.name,
            mimeType: result.file.mimeType,
          ),
          successMessage: context.l10n.openedCloudDocument(
            ref
                .read(cloudDocumentServiceProvider)
                .providerLabel(result.file.provider),
            result.file.name,
          ),
        );
      } on _SheetSelectionCanceled {
        return;
      } on CloudDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.localizedMessage(context.l10n))),
        );
      } on UnsupportedError catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldNotOpenCloudDocument(error.message ?? '$error'),
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotOpenCloudDocument('$error')),
          ),
        );
      }
    });
  }

  Future<void> _openOrChooseCloudSyncFile() async {
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      await _chooseCloudSyncFile(openAfterSelection: true);
      return;
    }

    try {
      final settings = await ref
          .read(userRepositoryProvider)
          .getUserSettings(session.uid);
      final selectedFile = ref
          .read(cloudDocumentServiceProvider)
          .selectedSyncFileFromSettings(settings);
      if (selectedFile == null) {
        await _chooseCloudSyncFile(openAfterSelection: true);
        return;
      }

      await _openCloudDocument(file: selectedFile);
    } catch (_) {
      await _chooseCloudSyncFile(openAfterSelection: true);
    }
  }

  Future<void> _chooseCloudSyncFile({bool openAfterSelection = false}) async {
    if (_isChoosingCloudFile) return;

    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.connectACloudProviderInSettingsFirst),
        ),
      );
      return;
    }

    setState(() {
      _documentSetupAction = _SetupAction.open;
      _isChoosingCloudFile = true;
    });
    try {
      final settings = await ref
          .read(userRepositoryProvider)
          .getUserSettings(session.uid);
      final provider = ref
          .read(cloudDocumentServiceProvider)
          .activeProviderFromSettings(settings);
      if (provider == null) {
        throw const CloudDocumentException(
          'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.',
        );
      }

      if (!mounted) return;
      final selection = await showDialog<_CloudFileSelection>(
        context: context,
        builder: (context) => _CloudFilePickerDialog(
          provider: provider,
          selectedFileId: ref
              .read(cloudDocumentServiceProvider)
              .selectedSyncFileFromSettings(settings)
              ?.id,
        ),
      );
      if (selection == null) return;

      if (selection.createNew) {
        final createdFile = await ref
            .read(cloudDocumentServiceProvider)
            .createSyncFile(parentFolderId: selection.folderId);
        await ref
            .read(cloudDocumentServiceProvider)
            .setSelectedSyncFile(file: createdFile);
        if (openAfterSelection) {
          await _openCloudDocument(file: createdFile);
        }
        return;
      }

      final selectedFile = selection.file;
      if (selectedFile == null) {
        await ref.read(cloudDocumentServiceProvider).clearSelectedSyncFile();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.rememberedCloudSyncFileCleared)),
        );
        return;
      }

      await ref
          .read(cloudDocumentServiceProvider)
          .setSelectedSyncFile(file: selectedFile);
      if (openAfterSelection) {
        await _openCloudDocument(file: selectedFile);
      }
    } on CloudDocumentException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.localizedMessage(context.l10n))),
      );
    } finally {
      if (mounted) setState(() => _isChoosingCloudFile = false);
    }
  }

  Future<String> _cloudDocumentSubtitle(AppLocalizations localizations) async {
    return ref.read(cloudDocumentServiceProvider).buildSubtitle(localizations);
  }

  Future<_DocumentPromptData> _documentDocumentPromptData() async {
    final localizations = context.l10n;
    if (!ServiceLocator.isSetup) {
      return _DocumentPromptData(
        localSubtitle: _defaultLocalDocumentSubtitle(localizations),
        cloudSubtitle: localizations.connectACloudProviderInSettingsFirst,
        hasSelectedCloudFile: false,
        hasRememberedLocalFile: _hasRememberedLocalDocument,
      );
    }
    final pendingCloudFile = _pendingCloudFileSelection;
    if (pendingCloudFile != null) {
      return _DocumentPromptData(
        localSubtitle: _defaultLocalDocumentSubtitle(localizations),
        cloudSubtitle: switch (pendingCloudFile.provider) {
          CloudSyncProvider.googleDrive =>
            localizations.manageGoogleDriveSyncFile(pendingCloudFile.name),
          CloudSyncProvider.webDav => localizations.manageWebDavSyncFile(
            pendingCloudFile.name,
          ),
        },
        hasSelectedCloudFile: true,
        hasRememberedLocalFile: _hasRememberedLocalDocument,
      );
    }
    final session = ref.read(authServiceProvider).currentSession;
    UserSettingsData? settings;
    if (session != null) {
      settings = await ref
          .read(userRepositoryProvider)
          .getUserSettings(session.uid);
    }
    final selectedCloudFile = settings == null
        ? null
        : ref
              .read(cloudDocumentServiceProvider)
              .selectedSyncFileFromSettings(settings);
    final cloudSubtitle = settings == null
        ? localizations.connectACloudProviderInSettingsFirst
        : await _cloudDocumentSubtitle(localizations);
    return _DocumentPromptData(
      localSubtitle: _hasRememberedLocalDocument
          ? localizations.selectedLocalFile(_documentImportedFileName!)
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? localizations.openACSVXLSXOrODSDocument
          : localizations
                .openCSVXLSXOrODSCalcrowDetectsTheFileTypeAutomatically,
      cloudSubtitle: cloudSubtitle,
      hasSelectedCloudFile: selectedCloudFile != null,
      hasRememberedLocalFile: _hasRememberedLocalDocument,
    );
  }

  String _defaultLocalDocumentSubtitle(AppLocalizations localizations) {
    if (_hasRememberedLocalDocument) {
      return localizations.selectedLocalFile(_documentImportedFileName!);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return localizations.openACSVXLSXOrODSDocument;
    }
    return localizations.openCSVXLSXOrODSCalcrowDetectsTheFileTypeAutomatically;
  }

  Future<void> _openSelectedDocument() async {
    setState(() {
      _documentSetupAction = _SetupAction.open;
    });
    switch (_effectiveDocumentSource) {
      case _DocumentSource.local:
        await _openOrChooseLocalDocument();
      case _DocumentSource.cloud:
        await _openOrChooseCloudSyncFile();
    }
  }

  Future<void> _chooseCloudDocument() async {
    setState(() {
      _documentSetupAction = _SetupAction.open;
      _documentDocumentSource = _DocumentSource.cloud;
    });

    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      await _chooseCloudSyncFile();
      return;
    }

    try {
      final settings = await ref
          .read(userRepositoryProvider)
          .getUserSettings(session.uid);
      final selectedFile = ref
          .read(cloudDocumentServiceProvider)
          .selectedSyncFileFromSettings(settings);
      if (selectedFile == null) {
        await _chooseCloudSyncFile();
      }
    } catch (_) {
      await _chooseCloudSyncFile();
    }
  }

  Future<void> _createDocument() async {
    setState(() {
      _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _documentSetupAction = _SetupAction.create;
    });
    final createdAt = DateTime.now();
    final separation = await _pickLogbookSeparation(createdAt);
    if (!mounted || separation == null) return;
    final initialSetup = CreateDocInitialSetup(
      separation: separation,
      createdAt: createdAt,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CreateDocPage(
          initialSetup: initialSetup,
          showLocalLocation: _supportsLocalFileEditing,
          onCreate: _createDocumentFromDraft,
        ),
      ),
    );
    if (!mounted) return;
    if (_activeEditor == null) {
      setState(() => _documentSetupAction = _SetupAction.open);
    }
  }

  Future<LogbookSeparation?> _pickLogbookSeparation(DateTime createdAt) {
    final monthlySetup = CreateDocInitialSetup(
      separation: LogbookSeparation.monthly,
      createdAt: createdAt,
    );
    final yearlySetup = CreateDocInitialSetup(
      separation: LogbookSeparation.yearly,
      createdAt: createdAt,
    );
    return showDialog<LogbookSeparation>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(context.l10n.sheetSeparation),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(LogbookSeparation.monthly),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(context.l10n.monthly),
                subtitle: Text(
                  context.l10n.multiSheetStartsWith(monthlySetup.xlsxSheetName),
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(LogbookSeparation.yearly),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(context.l10n.yearly),
                subtitle: Text(
                  context.l10n.yearTabsStartWith(yearlySetup.xlsxSheetName),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _createDocumentFromDraft(DocumentDraft draft) async {
    setState(() {
      _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
      _documentSetupAction = _SetupAction.create;
    });
    final sheetData = SheetData(
      fileName: draft.fileName,
      path: null,
      format: draft.format,
      headers: draft.headers,
      valueTypes: draft.valueTypes,
      readOnlyColumns: List<bool>.filled(draft.headers.length, false),
      rows: const <List<String>>[],
      csvDelimiter: ',',
      hasTypeRow: false,
      headerRowIndex: 0,
      startColumnIndex: 0,
      xlsxSheetName: draft.xlsxSheetName,
      workbook: _workbookForDraft(draft),
    );
    return switch (draft.destination) {
      CreateDestination.local => _createLocalDocument(
        sheetData,
        draft.prefills,
      ),
      CreateDestination.cloud => _createCloudDocument(
        sheetData,
        draft.prefills,
      ),
    };
  }

  Future<bool> _createLocalDocument(
    SheetData sheetData,
    List<DocumentPrefill> prefills,
  ) async {
    final localizations = context.l10n;
    try {
      final bytes = SheetFileService.buildBytes(sheetData);
      final preferredSafTreeUri = await _safTreeUriForNewLocalDocument();
      if (!mounted) return false;
      final result = await _sheetPersistenceService.persistBytes(
        PersistRequest(
          bytes: bytes,
          fileName: sheetData.fileName,
          typeGroup: _typeGroupForFormat(sheetData.format),
          mimeType: _mimeTypeForFormat(sheetData.format),
          confirmButtonText: _createConfirmButtonTextForFormat(
            context.l10n,
            sheetData.format,
          ),
          preferredSafTreeUri: preferredSafTreeUri,
          mode: preferredSafTreeUri == null
              ? PersistMode.asIs
              : PersistMode.safPreferred,
        ),
      );
      if (!mounted) return false;

      await TypeHintCache.rememberCsvTypes(
        fileName: result.resolvedFileName,
        path: result.savedPath,
        valueTypes: sheetData.valueTypes,
      );
      await _rememberDocumentPrefills(
        documentKey: documentPrefillKey(result.resolvedFileName),
        fileName: result.resolvedFileName,
        prefills: prefills,
      );

      await _pushEditor(
        sheetData: _copySheetData(
          sheetData,
          fileName: result.resolvedFileName,
          path: result.savedPath,
          sourceBytes: bytes,
        ),
        target: LocalEditorDocumentTarget(existingPath: result.savedPath),
        successMessage: localizations.createdFile(result.resolvedFileName),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _documentSetupAction = _SetupAction.open);
      if (error is StateError && error.message == 'Save canceled.') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.createDocumentCanceled)),
        );
        return false;
      }
      if (error is StateError &&
          error.message == 'Could not acquire a writable SAF folder URI.') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotAcquireAWritableSAFFolderURI),
          ),
        );
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotCreateLocalDocument('$error')),
        ),
      );
      return false;
    }
  }

  Future<bool> _createCloudDocument(
    SheetData sheetData,
    List<DocumentPrefill> prefills,
  ) async {
    final localizations = context.l10n;
    final folder = await _pickCloudCreateFolder();
    if (!mounted || folder == null) return false;

    var created = false;
    await _runWithDocumentOpeningIndicator(() async {
      try {
        final bytes = SheetFileService.buildBytes(sheetData);
        final metadata = await ref
            .read(cloudDocumentServiceProvider)
            .createDocument(
              fileName: sheetData.fileName,
              bytes: bytes,
              mimeType: _mimeTypeForFormat(sheetData.format),
              parentFolderId: folder.id,
            );
        await ref
            .read(cloudDocumentServiceProvider)
            .setSelectedSyncFile(file: metadata);
        if (!mounted) return;

        await TypeHintCache.rememberCsvTypes(
          fileName: metadata.name,
          path: metadata.id,
          valueTypes: sheetData.valueTypes,
        );
        await ref
            .read(cloudDocumentServiceProvider)
            .rememberTypeHints(
              file: metadata,
              valueTypes: sheetData.valueTypes,
            );
        await _rememberDocumentPrefills(
          documentKey: documentPrefillKey(metadata.name),
          fileName: metadata.name,
          prefills: prefills,
        );

        await _pushEditor(
          sheetData: _copySheetData(
            sheetData,
            fileName: metadata.name,
            path: null,
            sourceBytes: bytes,
          ),
          target: CloudEditorDocumentTarget(
            provider: metadata.provider,
            fileId: metadata.id,
            fileName: metadata.name,
            mimeType: metadata.mimeType,
          ),
          successMessage: localizations.createdFileInFolder(
            metadata.name,
            folder.name,
          ),
        );
        created = true;
      } on CloudDocumentException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.localizedMessage(context.l10n))),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotCreateCloudDocument('$error')),
          ),
        );
      }
    });
    return created;
  }

  Future<void> _rememberDocumentPrefills({
    required String documentKey,
    required String fileName,
    required List<DocumentPrefill> prefills,
  }) async {
    if (prefills.isEmpty) return;
    try {
      await DocumentPrefillCache.write(documentKey, prefills);
    } catch (_) {
      // A cache failure should not prevent document creation.
    }
    if (!ServiceLocator.isSetup) return;
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) return;
    try {
      await ref
          .read(userRepositoryProvider)
          .rememberDocumentPrefills(
            uid: session.uid,
            documentKey: documentKey,
            fileName: fileName,
            prefills: prefills,
          );
    } catch (_) {
      // The local cache remains available when remote persistence fails.
    }
  }

  Future<_CloudFolderPickResult?> _pickCloudCreateFolder() async {
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.connectACloudProviderInSettingsFirst),
        ),
      );
      return null;
    }

    try {
      final settings = await ref
          .read(userRepositoryProvider)
          .getUserSettings(session.uid);
      if (!mounted) return null;
      final provider = ref
          .read(cloudDocumentServiceProvider)
          .activeProviderFromSettings(settings);
      if (provider == null) {
        throw const CloudDocumentException(
          'No cloud provider is active. Choose Google Drive or WebDAV in Settings first.',
        );
      }
      return showDialog<_CloudFolderPickResult>(
        context: context,
        builder: (context) => _CloudFolderPickerDialog(provider: provider),
      );
    } on CloudDocumentException catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.localizedMessage(context.l10n))),
      );
      return null;
    }
  }

  Future<void> _setRecentOpeningConfiguration() async {
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.signInToUseRecentOpeningConfigurations),
        ),
      );
      return;
    }

    final settings = await ref
        .read(userRepositoryProvider)
        .getUserSettings(session.uid);
    if (!mounted) return;
    final configs = settings.recentOpenConfigs;
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.noRecentOpeningConfigurationsSavedYet),
        ),
      );
      return;
    }

    final selected = await showDialog<RecentOpenConfig>(
      context: context,
      builder: (dialogContext) => _RecentConfigDialog(configs: configs),
    );
    if (!mounted || selected == null) return;
    await _applyRecentOpenConfig(selected);
  }

  Future<void> _applyRecentOpenConfig(RecentOpenConfig config) async {
    final openMode = _documentOpenModeFromName(config.openMode);
    final source = _documentDocumentSourceFromRecent(config.source);
    final provider = config.source == RecentDocumentSource.googleDrive
        ? CloudSyncProvider.googleDrive
        : CloudSyncProvider.webDav;
    final selectedCloudFile =
        source == _DocumentSource.cloud && config.fileId != null
        ? CloudFileMetadata(
            provider: provider,
            id: config.fileId!,
            name: config.fileName,
            mimeType: config.mimeType ?? 'text/csv',
          )
        : null;
    setState(() {
      _documentOpenMode = openMode;
      _documentDocumentSource = source;
      _pendingCloudFileSelection = selectedCloudFile;
      if (source == _DocumentSource.local) {
        _documentImportedFileName = config.fileName;
        _documentImportedPath = config.path;
        _documentImportedSourceBytes = null;
        _selectedLocalDocument = null;
        _rememberLocalDocumentForReopen = config.path?.isNotEmpty == true;
      } else {
        _rememberLocalDocumentForReopen = false;
        _documentImportedPath = null;
        _documentImportedSourceBytes = null;
        _selectedLocalDocument = null;
      }
    });

    if (selectedCloudFile != null) {
      final session = ref.read(authServiceProvider).currentSession;
      try {
        if (session != null) {
          await ref
              .read(userRepositoryProvider)
              .setCloudSyncProvider(uid: session.uid, provider: provider);
        }
        await ref
            .read(cloudDocumentServiceProvider)
            .setSelectedSyncFile(file: selectedCloudFile);
      } finally {
        if (mounted &&
            identical(_pendingCloudFileSelection, selectedCloudFile)) {
          setState(() => _pendingCloudFileSelection = null);
        }
      }
    }
  }

  EditorOpenMode _documentOpenModeFromName(String name) {
    return EditorOpenMode.values.firstWhere(
      (candidate) => candidate.name == name,
      orElse: () => EditorOpenMode.dateBased,
    );
  }

  excel_pkg.Excel? _workbookForDraft(DocumentDraft draft) {
    if (draft.format != SheetFileFormat.xlsx) return null;

    final workbook = excel_pkg.Excel.createExcel();
    final sheetName = draft.xlsxSheetName?.trim();
    if (sheetName == null || sheetName.isEmpty) {
      return workbook;
    }

    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }
    workbook.setDefaultSheet(sheetName);
    return workbook;
  }

  _DocumentSource _documentDocumentSourceFromRecent(
    RecentDocumentSource source,
  ) {
    return switch (source) {
      RecentDocumentSource.local => _DocumentSource.local,
      RecentDocumentSource.googleDrive ||
      RecentDocumentSource.webDav => _DocumentSource.cloud,
    };
  }

  String _documentOpenModeLabel(
    AppLocalizations localizations,
    EditorOpenMode mode,
  ) {
    return switch (mode) {
      EditorOpenMode.dateBased => localizations.diary,
      EditorOpenMode.dateBasedOpenEnd => localizations.logbook,
      EditorOpenMode.textBased => localizations.namelist,
    };
  }

  String _documentOpenModeDescription(
    AppLocalizations localizations,
    EditorOpenMode mode,
  ) {
    return switch (mode) {
      EditorOpenMode.dateBased =>
        localizations.openTheExistingRowForTodayAndKeepOneEntryPerDay,
      EditorOpenMode.dateBasedOpenEnd =>
        localizations.openTodayIfItExistsOtherwiseStartANewRowForToday,
      EditorOpenMode.textBased =>
        localizations.chooseAnExistingNamedEntryFromATextColumnAndEditThatRow,
    };
  }

  String _documentOpenModeTableHint(
    AppLocalizations localizations,
    EditorOpenMode mode,
  ) {
    return switch (mode) {
      EditorOpenMode.dateBased =>
        localizations.yourTableNeedsADateColumnWithOnePreparedRowPerDay,
      EditorOpenMode.dateBasedOpenEnd =>
        localizations.yourTableNeedsADateColumnCalcrowCanAddTodayAsANewRow,
      EditorOpenMode.textBased =>
        localizations.yourTableNeedsAnEditableTextColumnWithTheEntryNames,
    };
  }

  void _showOpenModeInfo(EditorOpenMode selectedMode) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);
        final modes = EditorOpenMode.values;

        return AlertDialog(
          title: Text(context.l10n.openingModes),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final mode in modes) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _documentOpenModeLabel(context.l10n, mode),
                          style: dialogTheme.textTheme.titleSmall,
                        ),
                      ),
                      if (mode == selectedMode)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: dialogTheme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_documentOpenModeDescription(context.l10n, mode)),
                  const SizedBox(height: 4),
                  Text(
                    _documentOpenModeTableHint(context.l10n, mode),
                    style: dialogTheme.textTheme.bodySmall?.copyWith(
                      color: dialogTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (mode != modes.last) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.gotIt),
            ),
          ],
        );
      },
    );
  }

  void _forgetRememberedLocalDocument() {
    setState(() {
      _rememberLocalDocumentForReopen = false;
      _documentImportedPath = null;
      _documentImportedSourceBytes = null;
      _selectedLocalDocument = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.rememberedLocalFileClearedPickAFileAgainAnytime,
        ),
      ),
    );
  }

  Future<void> _clearSelectedCloudSyncFile() async {
    try {
      await ref.read(cloudDocumentServiceProvider).clearSelectedSyncFile();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.rememberedCloudSyncFileCleared)),
      );
    } on CloudDocumentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.localizedMessage(context.l10n))),
      );
    }
  }

  Future<String?> _safTreeUriForNewLocalDocument() async {
    final preferredSafTreeUri = await _preferredSafTreeUri();
    if (!mounted) return preferredSafTreeUri;
    if (!_isAndroidPlatform ||
        preferredSafTreeUri == null ||
        preferredSafTreeUri.isEmpty) {
      return preferredSafTreeUri;
    }
    final target = await showDialog<_LocalCreateTarget>(
      context: context,
      builder: (context) => const _LocalCreateTargetDialog(),
    );
    if (!mounted) return null;
    switch (target) {
      case null:
        throw StateError('Save canceled.');
      case _LocalCreateTarget.currentSafFolder:
        return preferredSafTreeUri;
      case _LocalCreateTarget.pickSafFolder:
        return _pickSafTreeUriForNewDocument();
    }
  }

  Future<String?> _pickSafTreeUriForNewDocument() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_isAndroidPlatform) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.safFolderSetupIsAndroidOnly)),
      );
      return null;
    }
    final pickedDirectory = await _safUtil.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    final treeUri = pickedDirectory?.uri.trim();
    if (treeUri == null || treeUri.isEmpty) {
      throw StateError('Save canceled.');
    }
    final normalizedTreeUri = treeUri.trim();
    if (!_sheetPersistenceService.canUseSafTreeUri(normalizedTreeUri)) {
      throw StateError('Could not acquire a writable SAF folder URI.');
    }
    return normalizedTreeUri;
  }

  Future<String?> _preferredSafTreeUri() async {
    if (!ServiceLocator.isSetup) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final session = ref.read(authServiceProvider).currentSession;
    if (session == null) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final settings = await (() async {
      try {
        return await ref
            .read(userRepositoryProvider)
            .getUserSettings(session.uid);
      } catch (_) {
        return null;
      }
    })();
    if (settings == null) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    final uri = settings.safTreeUri;
    if (uri == null || uri.isEmpty) {
      return SheetPersistenceService.runtimeSafTreeUri;
    }
    return uri;
  }

  SheetData _copySheetData(
    SheetData data, {
    required String fileName,
    required String? path,
    required Uint8List? sourceBytes,
  }) {
    return SheetData(
      fileName: fileName,
      path: path,
      format: data.format,
      headers: data.headers,
      valueTypes: data.valueTypes,
      readOnlyColumns: data.readOnlyColumns,
      rows: data.rows,
      pendingTypeSelectionColumns: data.pendingTypeSelectionColumns,
      hasCachedValueTypes: data.hasCachedValueTypes,
      csvDelimiter: data.csvDelimiter,
      hasTypeRow: data.hasTypeRow,
      headerRowIndex: data.headerRowIndex,
      startColumnIndex: data.startColumnIndex,
      xlsxSheetName: data.xlsxSheetName,
      workbook: data.workbook,
      sourceBytes: sourceBytes,
    );
  }

  String? _readXFilePath(XFile file) {
    try {
      final path = file.path.trim();
      if (path.isEmpty) return null;
      if (SheetPersistenceService.isTemporaryPath(path)) return null;
      return path;
    } catch (_) {
      return null;
    }
  }

  String _mimeTypeForFormat(SheetFileFormat format) {
    return SheetFileService.mimeTypeForFormat(format);
  }

  XTypeGroup _typeGroupForFormat(SheetFileFormat format) {
    switch (format) {
      case SheetFileFormat.csv:
        return XTypeGroup(
          label: context.l10n.csv,
          extensions: const <String>['csv'],
        );
      case SheetFileFormat.xlsx:
      case SheetFileFormat.gsheet:
        return XTypeGroup(
          label: context.l10n.xlsx,
          extensions: const <String>['xlsx'],
        );
      case SheetFileFormat.ods:
        return XTypeGroup(
          label: context.l10n.ods,
          extensions: const <String>['ods'],
        );
    }
  }

  String _createConfirmButtonTextForFormat(
    AppLocalizations localizations,
    SheetFileFormat format,
  ) {
    switch (format) {
      case SheetFileFormat.csv:
        return localizations.createCSV;
      case SheetFileFormat.xlsx:
      case SheetFileFormat.gsheet:
        return localizations.createXLSX;
      case SheetFileFormat.ods:
        return localizations.createODS;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEditor = _activeEditor;
    if (activeEditor != null) {
      return activeEditor;
    }

    final theme = Theme.of(context);
    final isCreateMode = _documentSetupAction == _SetupAction.create;
    final setupOpenMode = isCreateMode
        ? EditorOpenMode.dateBasedOpenEnd
        : _documentOpenMode;
    final openModeItems = isCreateMode
        ? <DropdownMenuItem<EditorOpenMode>>[
            DropdownMenuItem(
              value: EditorOpenMode.dateBasedOpenEnd,
              child: Text(
                _documentOpenModeLabel(
                  context.l10n,
                  EditorOpenMode.dateBasedOpenEnd,
                ),
              ),
            ),
          ]
        : EditorOpenMode.values
              .map(
                (mode) => DropdownMenuItem<EditorOpenMode>(
                  value: mode,
                  child: Text(_documentOpenModeLabel(context.l10n, mode)),
                ),
              )
              .toList();

    return Stack(
      children: [
        ListView(
          padding: AppLayoutConstants.pageContentPadding,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(
                    0,
                    AppLayoutConstants.pageHeaderControlVerticalOffset,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pageHeaderIconRadius,
                    ),
                    child: Image.asset(
                      'assets/images/AppIcon_1024_square.png',
                      key: const ValueKey('selector-app-icon'),
                      width: AppLayoutConstants.pageHeaderIconSize,
                      height: AppLayoutConstants.pageHeaderIconSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: AppLayoutConstants.pageHeaderIconGap),
                Expanded(
                  child: Text(
                    context.l10n.selector,
                    key: const ValueKey('selector-page-title'),
                    style: AppTextStyles.pageTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutConstants.pageHeaderBottomSpacing),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.openingMode,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.explainOpeningModes,
                          onPressed: () => _showOpenModeInfo(setupOpenMode),
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EditorOpenMode>(
                      initialValue: setupOpenMode,
                      decoration: InputDecoration(
                        labelText: context.l10n.howToOpenTheSheet,
                      ),
                      items: openModeItems,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _documentOpenMode = isCreateMode
                              ? EditorOpenMode.dateBasedOpenEnd
                              : value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<_DocumentPromptData>(
              future: _documentDocumentPromptData(),
              builder: (context, snapshot) {
                final data =
                    snapshot.data ??
                    _DocumentPromptData(
                      localSubtitle: context.l10n.openCSVXLSXOrODS,
                      cloudSubtitle:
                          context.l10n.chooseOrCreateTheActiveCloudSyncFile,
                      hasSelectedCloudFile: false,
                      hasRememberedLocalFile: false,
                    );
                return Column(
                  children: [
                    _ChooseDocumentCard(
                      selected: _documentSetupAction == _SetupAction.open,
                      selectedSource: _effectiveDocumentSource,
                      localSubtitle: data.localSubtitle,
                      cloudSubtitle: data.cloudSubtitle,
                      isChoosingLocalDocument: _isChoosingLocalDocument,
                      isChoosingCloudFile: _isChoosingCloudFile,
                      hasRememberedLocalFile: data.hasRememberedLocalFile,
                      hasSelectedCloudFile: data.hasSelectedCloudFile,
                      showLocalDocument: _supportsLocalFileEditing,
                      onSelected: () => setState(
                        () => _documentSetupAction = _SetupAction.open,
                      ),
                      onChooseLocal: data.hasRememberedLocalFile
                          ? () => setState(() {
                              _documentSetupAction = _SetupAction.open;
                              _documentDocumentSource = _DocumentSource.local;
                            })
                          : _chooseLocalDocument,
                      onChooseCloud: _chooseCloudDocument,
                      onClearLocal: _forgetRememberedLocalDocument,
                      onClearCloud: _clearSelectedCloudSyncFile,
                    ),
                    const SizedBox(height: 14),
                    _CreateDocumentCard(
                      selected: _documentSetupAction == _SetupAction.create,
                      onSelected: () => setState(() {
                        _documentSetupAction = _SetupAction.create;
                        _documentOpenMode = EditorOpenMode.dateBasedOpenEnd;
                      }),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DualTextButton(
                  secondaryLabel: context.l10n.setRecent,
                  secondaryIcon: Icons.history,
                  onSecondaryPressed: _setRecentOpeningConfiguration,
                  primaryLabel: _documentSetupAction == _SetupAction.open
                      ? context.l10n.openAction
                      : context.l10n.createAction,
                  onPrimaryPressed:
                      _isOpeningDocument ||
                          _isChoosingCloudFile ||
                          (_documentSetupAction == _SetupAction.open &&
                              _effectiveDocumentSource ==
                                  _DocumentSource.local &&
                              !_hasRememberedLocalDocument)
                      ? null
                      : _documentSetupAction == _SetupAction.open
                      ? _openSelectedDocument
                      : _createDocument,
                ),
              ),
            ),
          ],
        ),
        if (_isOpeningDocument)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.82),
                child: const Center(child: TriangleLoadingIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _DocumentPromptData {
  const _DocumentPromptData({
    required this.localSubtitle,
    required this.cloudSubtitle,
    required this.hasSelectedCloudFile,
    required this.hasRememberedLocalFile,
  });

  final String localSubtitle;
  final String cloudSubtitle;
  final bool hasSelectedCloudFile;
  final bool hasRememberedLocalFile;
}

class _RecentConfigDialog extends StatelessWidget {
  const _RecentConfigDialog({required this.configs});

  final List<RecentOpenConfig> configs;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.setRecent),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: configs
              .map(
                (config) => ListTile(
                  leading: Icon(_iconForSource(config.source)),
                  title: Text(config.fileName),
                  subtitle: Text(
                    '${_sourceLabel(context.l10n, config.source)} – ${_openModeLabel(context.l10n, config.openMode)}',
                  ),
                  onTap: () => Navigator.of(context).pop(config),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }

  static IconData _iconForSource(RecentDocumentSource source) {
    return switch (source) {
      RecentDocumentSource.local => Icons.folder_open_rounded,
      RecentDocumentSource.googleDrive ||
      RecentDocumentSource.webDav => Icons.cloud_outlined,
    };
  }

  static String _sourceLabel(
    AppLocalizations localizations,
    RecentDocumentSource source,
  ) {
    return switch (source) {
      RecentDocumentSource.local => localizations.local,
      RecentDocumentSource.googleDrive => localizations.googleDrive,
      RecentDocumentSource.webDav => localizations.webDav,
    };
  }

  static String _openModeLabel(
    AppLocalizations localizations,
    String openMode,
  ) {
    return switch (openMode) {
      'dateBased' => localizations.diary,
      'dateBasedOpenEnd' => localizations.logbook,
      'textBased' => localizations.namelist,
      _ => localizations.openingMode,
    };
  }
}

class _ChooseDocumentCard extends StatelessWidget {
  const _ChooseDocumentCard({
    required this.selected,
    required this.selectedSource,
    required this.localSubtitle,
    required this.cloudSubtitle,
    required this.isChoosingLocalDocument,
    required this.isChoosingCloudFile,
    required this.hasRememberedLocalFile,
    required this.hasSelectedCloudFile,
    required this.showLocalDocument,
    required this.onSelected,
    required this.onChooseLocal,
    required this.onChooseCloud,
    required this.onClearLocal,
    required this.onClearCloud,
  });

  final bool selected;
  final _DocumentSource selectedSource;
  final String localSubtitle;
  final String cloudSubtitle;
  final bool isChoosingLocalDocument;
  final bool isChoosingCloudFile;
  final bool hasRememberedLocalFile;
  final bool hasSelectedCloudFile;
  final bool showLocalDocument;
  final VoidCallback onSelected;
  final VoidCallback onChooseLocal;
  final VoidCallback onChooseCloud;
  final VoidCallback onClearLocal;
  final VoidCallback onClearCloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.chooseDocument,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (showLocalDocument)
                _DocumentSourceTile(
                  selected: selectedSource == _DocumentSource.local,
                  title: context.l10n.localDocument,
                  subtitle: localSubtitle,
                  icon: Icons.folder_open_rounded,
                  trailing: isChoosingLocalDocument
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: TriangleLoadingIndicator(
                            size: 22,
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                  onTap: onChooseLocal,
                  clearAction: hasRememberedLocalFile
                      ? _InlineSetupAction(
                          icon: Icons.clear,
                          tooltip: context.l10n.clearRememberedLocalFile,
                          onTap: onClearLocal,
                        )
                      : null,
                ),
              _DocumentSourceTile(
                selected: selectedSource == _DocumentSource.cloud,
                title: context.l10n.cloudDocument,
                subtitle: cloudSubtitle,
                icon: Icons.cloud_outlined,
                trailing: isChoosingCloudFile
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: TriangleLoadingIndicator(
                          size: 22,
                          strokeWidth: 2,
                        ),
                      )
                    : null,
                onTap: onChooseCloud,
                clearAction: hasSelectedCloudFile
                    ? _InlineSetupAction(
                        icon: Icons.clear,
                        tooltip: context.l10n.clearRememberedCloudFile,
                        onTap: onClearCloud,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateDocumentCard extends StatelessWidget {
  const _CreateDocumentCard({required this.selected, required this.onSelected});

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.36)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.createDocument,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DocumentSourceTile(
                selected: selected,
                title: context.l10n.createNew,
                subtitle: context.l10n.defineColumnsAndFieldTypesForAFreshSheet,
                icon: Icons.add_circle_outline_rounded,
                onTap: onSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentSourceTile extends StatelessWidget {
  const _DocumentSourceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.clearAction,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? clearAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.check_circle_rounded : icon),
      title: Text(title),
      subtitle: Row(
        children: [
          if (clearAction != null) ...[clearAction!, const SizedBox(width: 8)],
          Expanded(child: Text(subtitle)),
        ],
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: selected ? theme.colorScheme.primary : null,
          ),
      onTap: onTap,
    );
  }
}

class _LocalCreateTargetDialog extends StatelessWidget {
  const _LocalCreateTargetDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chooseSAFFolder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: Text(context.l10n.useCurrentSAFFolder),
            subtitle: Text(context.l10n.saveIntoTheFolderConfiguredInSettings),
            onTap: () =>
                Navigator.of(context).pop(_LocalCreateTarget.currentSafFolder),
          ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(context.l10n.pickSAFFolder),
            subtitle: Text(context.l10n.chooseAWritableAndroidFolder),
            onTap: () =>
                Navigator.of(context).pop(_LocalCreateTarget.pickSafFolder),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }
}

class _CloudFileSelection {
  const _CloudFileSelection._({
    this.file,
    this.createNew = false,
    this.folderId,
  });

  const _CloudFileSelection.pick(CloudFileMetadata file) : this._(file: file);

  const _CloudFileSelection.clear() : this._();

  const _CloudFileSelection.createNew({String? folderId})
    : this._(createNew: true, folderId: folderId);

  final CloudFileMetadata? file;
  final bool createNew;
  final String? folderId;
}

class _CloudFolderNode {
  const _CloudFolderNode({required this.id, required this.name});

  final String? id;
  final String name;
}

class _CloudFolderPickResult {
  const _CloudFolderPickResult({required this.id, required this.name});

  final String? id;
  final String name;
}

class _CloudBrowserShell extends StatelessWidget {
  const _CloudBrowserShell({
    required this.title,
    required this.folderStack,
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onNavigateToFolder,
    required this.onRefresh,
    required this.body,
    required this.actions,
  });

  final String title;
  final List<_CloudFolderNode> folderStack;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onNavigateToFolder;
  final VoidCallback onRefresh;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final content = SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 24,
          isCompact ? 12 : 20,
          isCompact ? 16 : 24,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: context.l10n.refreshFolder,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: folderStack.length,
                separatorBuilder: (context, index) =>
                    const Icon(Icons.chevron_right_rounded, size: 18),
                itemBuilder: (context, index) {
                  final isCurrent = index == folderStack.length - 1;
                  return TextButton.icon(
                    onPressed: isCurrent
                        ? null
                        : () => onNavigateToFolder(index),
                    icon: Icon(
                      index == 0 ? Icons.cloud_outlined : Icons.folder_outlined,
                      size: 18,
                    ),
                    label: Text(folderStack[index].name),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SearchBar(
              key: const ValueKey('cloud-browser-search'),
              controller: searchController,
              hintText: context.l10n.searchThisFolder,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (query.isNotEmpty)
                  IconButton(
                    tooltip: context.l10n.clearSearch,
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: body),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );

    if (isCompact) return Dialog.fullscreen(child: content);
    final height = (MediaQuery.sizeOf(context).height - 48)
        .clamp(420.0, 720.0)
        .toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(width: 880, height: height, child: content),
    );
  }
}

class _CloudFolderPickerDialog extends ConsumerStatefulWidget {
  const _CloudFolderPickerDialog({required this.provider});

  final CloudSyncProvider provider;

  @override
  ConsumerState<_CloudFolderPickerDialog> createState() =>
      _CloudFolderPickerDialogState();
}

class _CloudFolderPickerDialogState
    extends ConsumerState<_CloudFolderPickerDialog> {
  List<CloudBrowserEntry> _entries = const <CloudBrowserEntry>[];
  List<_CloudFolderNode> _folderStack = const <_CloudFolderNode>[];
  bool _isLoading = true;
  bool _initialized = false;
  String? _errorText;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String? get _currentFolderId => _folderStack.last.id;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _folderStack = <_CloudFolderNode>[
      _CloudFolderNode(
        id: null,
        name: widget.provider == CloudSyncProvider.googleDrive
            ? context.l10n.myDrive
            : context.l10n.webDavRoot,
      ),
    ];
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final entries = await ref
          .read(cloudDocumentServiceProvider)
          .listFolderEntries(folderId: _currentFolderId);
      if (!mounted) return;
      setState(() {
        _entries = entries.where((entry) => entry.isFolder).toList();
      });
    } on CloudDocumentException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFolder(CloudBrowserEntry entry) {
    setState(() {
      _folderStack = <_CloudFolderNode>[
        ..._folderStack,
        _CloudFolderNode(id: entry.id, name: entry.name),
      ];
      _query = '';
      _searchController.clear();
    });
    unawaited(_loadFolder());
  }

  void _navigateToFolder(int index) {
    if (index < 0 || index >= _folderStack.length - 1) return;
    setState(() {
      _folderStack = _folderStack.sublist(0, index + 1);
      _query = '';
      _searchController.clear();
    });
    unawaited(_loadFolder());
  }

  void _useCurrentFolder() {
    Navigator.of(context).pop(
      _CloudFolderPickResult(
        id: _currentFolderId,
        name: _folderStack.last.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleEntries = normalizedQuery.isEmpty
        ? _entries
        : _entries
              .where(
                (entry) => entry.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);
    final body = _isLoading
        ? const Center(child: TriangleLoadingIndicator())
        : _errorText != null
        ? Center(child: SelectableText(_errorText!))
        : visibleEntries.isEmpty
        ? Center(
            child: Text(
              normalizedQuery.isEmpty
                  ? context.l10n.thisFolderHasNoSubfolders
                  : context.l10n.noMatchingFolders,
              textAlign: TextAlign.center,
            ),
          )
        : ListView.separated(
            key: const ValueKey('cloud-folder-results'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: visibleEntries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              return ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(entry.name),
                subtitle: Text(context.l10n.folder),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openFolder(entry),
              );
            },
          );
    return _CloudBrowserShell(
      title: context.l10n.chooseFolder,
      folderStack: _folderStack,
      searchController: _searchController,
      query: _query,
      onSearchChanged: (value) => setState(() => _query = value),
      onNavigateToFolder: _navigateToFolder,
      onRefresh: _loadFolder,
      body: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading || _errorText != null
              ? null
              : _useCurrentFolder,
          child: Text(context.l10n.useThisFolder),
        ),
      ],
    );
  }
}

class _CloudFilePickerDialog extends ConsumerStatefulWidget {
  const _CloudFilePickerDialog({
    required this.provider,
    required this.selectedFileId,
  });

  final CloudSyncProvider provider;
  final String? selectedFileId;

  @override
  ConsumerState<_CloudFilePickerDialog> createState() =>
      _CloudFilePickerDialogState();
}

class _CloudFilePickerDialogState
    extends ConsumerState<_CloudFilePickerDialog> {
  List<CloudBrowserEntry> _entries = const <CloudBrowserEntry>[];
  List<_CloudFolderNode> _folderStack = const <_CloudFolderNode>[];
  bool _isLoading = true;
  bool _initialized = false;
  String? _errorText;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String? get _currentFolderId => _folderStack.last.id;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _folderStack = <_CloudFolderNode>[
      _CloudFolderNode(
        id: null,
        name: widget.provider == CloudSyncProvider.googleDrive
            ? context.l10n.myDrive
            : context.l10n.webDavRoot,
      ),
    ];
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final entries = await ref
          .read(cloudDocumentServiceProvider)
          .listFolderEntries(folderId: _currentFolderId);
      if (!mounted) return;
      setState(() => _entries = entries);
    } on CloudDocumentException catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.localizedMessage(context.l10n));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFolder(CloudBrowserEntry entry) {
    setState(() {
      _folderStack = <_CloudFolderNode>[
        ..._folderStack,
        _CloudFolderNode(id: entry.id, name: entry.name),
      ];
      _query = '';
      _searchController.clear();
    });
    unawaited(_loadFolder());
  }

  void _navigateToFolder(int index) {
    if (index < 0 || index >= _folderStack.length - 1) return;
    setState(() {
      _folderStack = _folderStack.sublist(0, index + 1);
      _query = '';
      _searchController.clear();
    });
    unawaited(_loadFolder());
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleEntries = normalizedQuery.isEmpty
        ? _entries
        : _entries
              .where(
                (entry) => entry.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);
    final body = _isLoading
        ? const Center(child: TriangleLoadingIndicator())
        : _errorText != null
        ? Center(child: SelectableText(_errorText!))
        : visibleEntries.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                normalizedQuery.isEmpty
                    ? context
                          .l10n
                          .thisFolderHasNoSupportedCSVXLSXOrODSFilesYetOpenAnotherFolderOrCreateANewSyncFileHere
                    : context.l10n.noMatchingFilesOrFolders,
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView.separated(
            key: const ValueKey('cloud-file-results'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: visibleEntries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = visibleEntries[index];
              final isSelected = entry.id == widget.selectedFileId;
              return ListTile(
                selected: isSelected,
                leading: Icon(
                  entry.isFolder
                      ? Icons.folder_rounded
                      : isSelected
                      ? Icons.check_circle_rounded
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(entry.name),
                subtitle: Text(
                  entry.isFolder
                      ? context.l10n.folder
                      : _mimeLabel(context.l10n, entry.mimeType),
                ),
                trailing: entry.isFolder
                    ? const Icon(Icons.chevron_right_rounded)
                    : null,
                onTap: () {
                  if (entry.isFolder) {
                    _openFolder(entry);
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(_CloudFileSelection.pick(entry.asFileMetadata()));
                },
              );
            },
          );
    return _CloudBrowserShell(
      title: context.l10n.chooseSyncFile,
      folderStack: _folderStack,
      searchController: _searchController,
      query: _query,
      onSearchChanged: (value) => setState(() => _query = value),
      onNavigateToFolder: _navigateToFolder,
      onRefresh: _loadFolder,
      body: body,
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _CloudFileSelection.clear()),
          child: Text(context.l10n.clear),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_CloudFileSelection.createNew(folderId: _currentFolderId)),
          child: Text(context.l10n.createNew2),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }

  static String _mimeLabel(AppLocalizations localizations, String mimeType) {
    switch (mimeType) {
      case 'text/csv':
        return localizations.csv;
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return localizations.xlsx;
      case 'application/vnd.oasis.opendocument.spreadsheet':
        return localizations.ods;
      case GoogleDriveSyncService.googleSheetsMimeType:
        return localizations.googleSheets;
      default:
        return mimeType;
    }
  }
}

class _InlineSetupAction extends StatelessWidget {
  const _InlineSetupAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
