import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../../../../core/data/di/service_locator.dart';
import '../../../../core/data/services/auth_service.dart';
import '../../../../core/data/services/google_drive_auth_service.dart';
import '../../../../core/data/services/google_drive_sync_service.dart';
import '../../../../core/data/services/simple_sheet_persistence_service.dart';
import '../../../auth/presentation/sign_in_sheet.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const String _safTestFileName = 'calcrow_saf_test.txt';
  bool _isLinkingGoogle = false;
  bool _isUpdatingSafFolder = false;
  static final SafStream _safStream = SafStream();
  static final SafUtil _safUtil = SafUtil();
  final SimpleSheetPersistenceService _sheetPersistenceService =
      SimpleSheetPersistenceService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<AuthSession?>(
      stream: ServiceLocator.authService.authStateChanges(),
      initialData: ServiceLocator.authService.currentSession,
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('Settings', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Use calcrow offline without login. Sign in only when you want sync.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            if (session == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text('Using guest mode'),
                  subtitle: const Text('Sign in is optional and enables sync.'),
                  trailing: TextButton(
                    onPressed: () => _openSignInSheet(context),
                    child: const Text('Sign in'),
                  ),
                ),
              ),
            if (session == null) ...[
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_special_outlined),
                      title: const Text('Manage SAF folder'),
                      subtitle: Text(_safFolderSubtitle(null)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isUpdatingSafFolder
                                  ? null
                                  : () => _setSafFolder(),
                              child: const Text('Set'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isUpdatingSafFolder
                                  ? null
                                  : () => _testSafFolder(settings: null),
                              child: const Text('Test'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isUpdatingSafFolder
                                  ? null
                                  : () => _revertSafTest(settings: null),
                              child: const Text('Untest'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton(
                              onPressed: _isUpdatingSafFolder
                                  ? null
                                  : () => _clearSafFolder(),
                              child: const Text('Clear'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isUpdatingSafFolder)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Guest mode stores SAF folder only for this app session.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (session != null)
              StreamBuilder<Map<String, dynamic>?>(
                stream: ServiceLocator.dbService.watchUserSettings(session.uid),
                builder: (context, snapshot) {
                  final settings = snapshot.data;
                  final dateFormat =
                      (settings?['defaultDateFormat'] as String?) ??
                      'YYYY-MM-DD';

                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.date_range_outlined),
                          title: const Text('Default date format'),
                          subtitle: Text(dateFormat),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.cloud_done_outlined),
                          title: Text('Cloud backup'),
                          subtitle: Text('Connected'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.link_rounded),
                          title: const Text('Link Google account'),
                          subtitle: Text(_googleDriveSubtitle(settings)),
                          trailing: _isLinkingGoogle
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton(
                                  onPressed: () => _toggleGoogleLink(
                                    session: session,
                                    currentlyLinked: _isGoogleDriveLinked(
                                      settings,
                                    ),
                                  ),
                                  child: Text(
                                    _isGoogleDriveLinked(settings)
                                        ? 'Unlink'
                                        : 'Link',
                                  ),
                                ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.folder_special_outlined),
                          title: const Text('Manage SAF folder'),
                          subtitle: Text(_safFolderSubtitle(settings)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () => _setSafFolder(session: session),
                                  child: const Text('Set'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () =>
                                            _testSafFolder(settings: settings),
                                  child: const Text('Test'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () =>
                                            _revertSafTest(settings: settings),
                                  child: const Text('Test Revert'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () => _clearSafFolder(session: session),
                                  child: const Text('Clear'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isUpdatingSafFolder)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.lock_outline_rounded),
                          title: Text('Privacy policy'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded),
                          title: const Text('Sign out'),
                          onTap: () => ServiceLocator.authService.signOut(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  bool _isGoogleDriveLinked(Map<String, dynamic>? settings) {
    final linked = settings?['googleDriveLinked'];
    return linked is bool ? linked : false;
  }

  String _googleDriveSubtitle(Map<String, dynamic>? settings) {
    final linked = _isGoogleDriveLinked(settings);
    if (!linked) {
      return 'Sign in with Google and grant Drive read/write permissions.';
    }
    final syncFile = (settings?['googleDriveSyncFileName'] as String?)?.trim();
    if (syncFile != null && syncFile.isNotEmpty) {
      return 'Syncing with $syncFile';
    }
    final email = (settings?['googleDriveEmail'] as String?)?.trim();
    if (email != null && email.isNotEmpty) {
      return 'Linked as $email';
    }
    return 'Google Drive connected';
  }

  String _safFolderSubtitle(Map<String, dynamic>? settings) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'Available on Android only.';
    }
    final uri = (settings?['safTreeUri'] as String?)?.trim();
    final runtimeUri = SimpleSheetPersistenceService.runtimeSafTreeUri;
    final effectiveUri = (uri == null || uri.isEmpty) ? runtimeUri : uri;
    if (effectiveUri == null || effectiveUri.isEmpty) {
      return 'No SAF folder configured.';
    }
    return effectiveUri;
  }

  Future<void> _toggleGoogleLink({
    required AuthSession session,
    required bool currentlyLinked,
  }) async {
    if (_isLinkingGoogle) return;

    final messenger = ScaffoldMessenger.of(context);
    final uid = session.uid;

    setState(() => _isLinkingGoogle = true);
    try {
      if (currentlyLinked) {
        await ServiceLocator.googleDriveAuthService.unlinkAccount();
        await ServiceLocator.dbService.clearGoogleDriveLink(uid: uid);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Google account unlinked.')),
        );
      } else {
        final linkResult = await ServiceLocator.googleDriveAuthService
            .linkAccount();
        final client = await ServiceLocator.googleDriveAuthService
            .getAuthenticatedClient();
        final initialBytes = Uint8List.fromList(
          utf8.encode('Date,Start,End,Break (min),Notes\n'),
        );
        late final GoogleDriveFileMetadata syncFile;
        try {
          syncFile = await ServiceLocator.googleDriveSyncService.createSyncFile(
            authenticatedClient: client,
            fileName: 'calcrow_sync.csv',
            bytes: initialBytes,
            mimeType: 'text/csv',
          );
        } finally {
          client.close();
        }
        await ServiceLocator.dbService.setGoogleDriveLink(
          uid: uid,
          email: linkResult.email,
        );
        await ServiceLocator.dbService.setGoogleDriveSyncFile(
          uid: uid,
          fileId: syncFile.id,
          fileName: syncFile.name,
          mimeType: syncFile.mimeType,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Google linked: ${linkResult.email}. Sync file: ${syncFile.name}',
            ),
          ),
        );
      }
    } on GoogleDriveAuthException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Google link failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLinkingGoogle = false);
      }
    }
  }

  Future<void> _setSafFolder({AuthSession? session}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      messenger.showSnackBar(
        const SnackBar(content: Text('SAF folder setup is Android-only.')),
      );
      return;
    }
    setState(() => _isUpdatingSafFolder = true);
    try {
      final pickedDirectory = await _safUtil.pickDirectory(
        writePermission: true,
        persistablePermission: true,
      );
      final treeUri = pickedDirectory?.uri.trim();
      if (treeUri == null || treeUri.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('SAF folder selection canceled.')),
        );
        return;
      }
      final normalizedTreeUri = treeUri.trim();
      if (!_sheetPersistenceService.canUseSafTreeUri(normalizedTreeUri)) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not acquire a writable SAF folder URI.'),
          ),
        );
        return;
      }
      if (session != null) {
        await ServiceLocator.dbService.setSafFolderUri(
          uid: session.uid,
          treeUri: normalizedTreeUri,
        );
      }
      SimpleSheetPersistenceService.setRuntimeSafTreeUri(normalizedTreeUri);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            session == null
                ? 'SAF folder saved for this app session.'
                : 'SAF folder saved in settings.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not set SAF folder: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSafFolder = false);
      }
    }
  }

  Future<void> _testSafFolder({required Map<String, dynamic>? settings}) async {
    final messenger = ScaffoldMessenger.of(context);
    final treeUri =
        (settings?['safTreeUri'] as String?)?.trim() ??
        SimpleSheetPersistenceService.runtimeSafTreeUri;
    if (treeUri == null || treeUri.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No SAF folder configured.')),
      );
      return;
    }
    setState(() => _isUpdatingSafFolder = true);
    try {
      final bytes = Uint8List.fromList(
        utf8.encode('calcrow SAF test ${DateTime.now().toIso8601String()}\n'),
      );
      final created = await _safStream.writeFileBytes(
        treeUri,
        _safTestFileName,
        'text/plain',
        bytes,
        overwrite: true,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'SAF test write successful (${created.fileName ?? _safTestFileName}).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'SAF test failed. Re-pick folder from a writable location: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSafFolder = false);
      }
    }
  }

  Future<void> _revertSafTest({required Map<String, dynamic>? settings}) async {
    final messenger = ScaffoldMessenger.of(context);
    final treeUri =
        (settings?['safTreeUri'] as String?)?.trim() ??
        SimpleSheetPersistenceService.runtimeSafTreeUri;
    if (treeUri == null || treeUri.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No SAF folder configured.')),
      );
      return;
    }
    setState(() => _isUpdatingSafFolder = true);
    try {
      final existing = await _safUtil.child(treeUri, <String>[
        _safTestFileName,
      ]);
      if (existing == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No SAF test file to delete.')),
        );
        return;
      }
      await _safUtil.delete(existing.uri, false);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('SAF test file deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete SAF test file: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSafFolder = false);
      }
    }
  }

  Future<void> _clearSafFolder({AuthSession? session}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingSafFolder = true);
    try {
      if (session != null) {
        await ServiceLocator.dbService.clearSafFolderUri(uid: session.uid);
      }
      SimpleSheetPersistenceService.setRuntimeSafTreeUri(null);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('SAF folder cleared.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not clear SAF folder: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingSafFolder = false);
      }
    }
  }

  Future<void> _openSignInSheet(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SignInSheet(),
    );
  }
}
