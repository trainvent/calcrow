import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:saf_util/saf_util.dart';

import '../../../../../core/data/di/service_locator.dart';
import '../../../../../core/data/services/auth_service.dart';
import '../../../../../core/data/services/google_drive_auth_service.dart';
import '../../../../../core/data/services/google_drive_sync_service.dart';
import '../../../../../core/data/services/purchases_service.dart';
import '../../../../../core/data/services/simple_sheet_persistence_service.dart';
import '../../../../../core/data/services/user_repository.dart';
import '../../../../../core/data/services/webdav_service.dart';
import 'data_collection_page.dart';
import 'entitlement_page.dart';
import 'webdav_error_presentation.dart';
import '../../../../auth/presentation/sign_in_sheet.dart';
import '../../../../../app/presentation/web_link_opener_stub.dart'
    if (dart.library.html) '../../../../../app/presentation/web_link_opener_web.dart';
import '../../../../../core/constants/internal_constants.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const String _googleDriveLogTag = 'CalcrowGoogleDrive';
  bool _isLinkingGoogle = false;
  bool _isLinkingWebDav = false;
  bool _isUpdatingAdvancedFeatures = false;
  bool _isUpdatingSafFolder = false;
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
            const SizedBox(height: 12),
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
                      child: _buildSafActionGrid(
                        setButton: OutlinedButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _setSafFolder(),
                          child: const Text('Set'),
                        ),
                        clearButton: TextButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _clearSafFolder(),
                          child: const Text('Clear'),
                        ),
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
              StreamBuilder<UserSettingsData>(
                stream: ServiceLocator.userRepository.watchUserSettings(
                  session.uid,
                ),
                builder: (context, snapshot) {
                  final settings = snapshot.data;

                  return Column(
                    children: [
                      Card(
                        child: Column(
                          children: [
                            _buildSectionHeader(
                              context,
                              title: 'Cloud Settings',
                              subtitle:
                                  'Manage Google Drive and WebDAV connections.',
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.cloud_sync_outlined),
                              title: const Text('Active cloud provider'),
                              trailing: DropdownButtonHideUnderline(
                                child: DropdownButton<CloudSyncProvider>(
                                  value: _selectedCloudProvider(settings),
                                  hint: const Text('Choose'),
                                  onChanged:
                                      _availableCloudProviders(settings).isEmpty
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          _setCloudSyncProvider(
                                            session: session,
                                            provider: value,
                                          );
                                        },
                                  items: _availableCloudProviders(settings)
                                      .map(
                                        (provider) =>
                                            DropdownMenuItem<CloudSyncProvider>(
                                              value: provider,
                                              child: Text(
                                                _cloudProviderLabel(provider),
                                              ),
                                            ),
                                      )
                                      .toList(),
                                ),
                              ),
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
                              leading: const Icon(Icons.storage_rounded),
                              title: const Text('Link WebDAV / Nextcloud'),
                              subtitle: Text(_webDavSubtitle(settings)),
                              trailing: _isLinkingWebDav
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: () => _manageWebDavEntries(
                                        session: session,
                                        settings: settings,
                                      ),
                                      child: Text(
                                        _webDavEntries(settings).isEmpty
                                            ? 'Link'
                                            : 'Manage',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.workspace_premium_outlined,
                              ),
                              title: const Text('Entitlement'),
                              subtitle: Text(
                                settings?.isPro == true
                                    ? 'Pro enabled.'
                                    : 'Open subscription and purchase options.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  _openEntitlementScreen(session: session),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.folder_special_outlined,
                              ),
                              title: const Text('Manage SAF folder'),
                              subtitle: Text(_safFolderSubtitle(settings)),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _buildSafActionGrid(
                                setButton: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () => _setSafFolder(session: session),
                                  child: const Text('Set'),
                                ),
                                clearButton: TextButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () => _clearSafFolder(session: session),
                                  child: const Text('Clear'),
                                ),
                              ),
                            ),
                            if (_isUpdatingSafFolder)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.tune_rounded),
                              title: const Text('Advanced features'),
                              subtitle: const Text(
                                'Show the advanced Today layout for power-user tools.',
                              ),
                              value: _advancedFeaturesEnabled(settings),
                              onChanged: _isUpdatingAdvancedFeatures
                                  ? null
                                  : (value) => _setAdvancedFeaturesEnabled(
                                      session: session,
                                      enabled: value,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined),
                              title: const Text('Data collection'),
                              subtitle: const Text(
                                'Manage separate consent for usage analytics and crash or performance diagnostics.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _openDataCollectionPage,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout_rounded),
                              title: const Text('Sign out'),
                              onTap: () => ServiceLocator.authService.signOut(),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.delete_outline_rounded),
                              title: const Text('Delete account'),
                              subtitle: const Text(
                                'Open the permanent account deletion flow.',
                              ),
                              onTap: _openDeleteAccountPage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (session == null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Data collection'),
                  subtitle: const Text(
                    'Manage separate consent for usage analytics and crash or performance diagnostics.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _openDataCollectionPage,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  bool _isGoogleDriveLinked(UserSettingsData? settings) {
    return settings?.googleDriveLinked == true;
  }

  bool _advancedFeaturesEnabled(UserSettingsData? settings) {
    return settings?.advancedFeaturesEnabled == true;
  }

  bool _isWebDavLinked(UserSettingsData? settings) {
    if (settings == null) return false;
    return settings.webDavLinked || settings.webDavEntries.isNotEmpty;
  }

  List<WebDavSavedEntry> _webDavEntries(UserSettingsData? settings) {
    return settings?.webDavEntries ?? const <WebDavSavedEntry>[];
  }

  CloudSyncProvider? _selectedCloudProvider(UserSettingsData? settings) {
    if (settings == null) return null;
    return ServiceLocator.simpleCloudDocumentService.activeProviderFromSettings(
      settings,
    );
  }

  List<CloudSyncProvider> _availableCloudProviders(UserSettingsData? settings) {
    if (settings == null) return const <CloudSyncProvider>[];
    return <CloudSyncProvider>[
      if (_isGoogleDriveLinked(settings)) CloudSyncProvider.googleDrive,
      if (_isWebDavLinked(settings)) CloudSyncProvider.webDav,
    ];
  }

  String _googleDriveSubtitle(UserSettingsData? settings) {
    final linked = _isGoogleDriveLinked(settings);
    if (!linked) {
      return 'Sign in with Google and grant Drive read/write permissions.';
    }
    final email = settings?.googleDriveEmail;
    if (email != null && email.isNotEmpty) {
      return 'Linked as $email';
    }
    return 'Google Drive connected';
  }

  String _webDavSubtitle(UserSettingsData? settings) {
    final entries = _webDavEntries(settings);
    if (entries.isEmpty) {
      return 'Connect a WebDAV or Nextcloud folder using its WebDAV URL.';
    }
    final activeEntryId = settings?.webDavActiveEntryId;
    final activeEntry =
        entries.where((entry) => entry.id == activeEntryId).isEmpty
        ? entries.first
        : entries.firstWhere((entry) => entry.id == activeEntryId);
    final username = activeEntry.username;
    final serverUrl = activeEntry.serverUrl;
    if (username.isNotEmpty) {
      final host = Uri.tryParse(serverUrl)?.host;
      if (host != null && host.isNotEmpty) {
        if (entries.length == 1) {
          return 'Linked as $username on $host';
        }
        return '${entries.length} WebDAV entries. Active: $username on $host';
      }
      if (entries.length == 1) {
        return 'Linked as $username';
      }
      return '${entries.length} WebDAV entries. Active: $username';
    }
    return 'WebDAV connected';
  }

  String _cloudProviderLabel(CloudSyncProvider provider) {
    return ServiceLocator.simpleCloudDocumentService.providerLabel(provider);
  }

  Future<void> _setAdvancedFeaturesEnabled({
    required AuthSession session,
    required bool enabled,
  }) async {
    if (_isUpdatingAdvancedFeatures) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingAdvancedFeatures = true);
    try {
      await ServiceLocator.dbService.setAdvancedFeaturesEnabled(
        uid: session.uid,
        enabled: enabled,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Advanced features enabled.'
                : 'Advanced features disabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update advanced features: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAdvancedFeatures = false);
      }
    }
  }

  String _safFolderSubtitle(UserSettingsData? settings) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'Available on Android only.';
    }
    final uri = settings?.safTreeUri;
    final runtimeUri = SimpleSheetPersistenceService.runtimeSafTreeUri;
    final effectiveUri = (uri == null || uri.isEmpty) ? runtimeUri : uri;
    if (effectiveUri == null || effectiveUri.isEmpty) {
      return 'No SAF folder configured.';
    }
    return effectiveUri;
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildSafActionGrid({
    required Widget setButton,
    required Widget clearButton,
  }) {
    return Row(
      children: <Widget>[
        Expanded(child: setButton),
        const SizedBox(width: 8),
        Expanded(child: clearButton),
      ],
    );
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
        await ServiceLocator.userRepository.clearGoogleDriveLinked(uid: uid);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Google account unlinked.')),
        );
      } else {
        late final GoogleDriveLinkResult linkResult;
        try {
          linkResult = await ServiceLocator.googleDriveAuthService
              .linkAccount();
        } on GoogleDriveAuthException catch (error) {
          throw GoogleDriveAuthException(
            'Sign-in step failed: ${error.message}',
          );
        }

        late final http.Client client;
        try {
          client = await ServiceLocator.googleDriveAuthService
              .getAuthenticatedClient();
        } on GoogleDriveAuthException catch (error) {
          throw GoogleDriveAuthException(
            'Authenticated client step failed: ${error.message}',
          );
        } finally {
          client.close();
        }
        await ServiceLocator.userRepository.setGoogleDriveLinked(
          uid: uid,
          email: linkResult.email,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Google linked: ${linkResult.email}. Choose a Drive file next.',
            ),
          ),
        );
      }
    } on GoogleDriveAuthException catch (error) {
      debugPrint(
        '$_googleDriveLogTag settings link auth error: ${error.message}',
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on GoogleDriveSyncException catch (error) {
      debugPrint(
        '$_googleDriveLogTag settings link sync error: ${error.message}',
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      debugPrint('$_googleDriveLogTag settings link unexpected error: $error');
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

  Future<void> _manageWebDavEntries({
    required AuthSession session,
    required UserSettingsData? settings,
  }) async {
    if (_isLinkingWebDav) return;
    final existingEntries = _webDavEntries(settings);
    final action = await _showWebDavManagementActionDialog(
      hasEntries: existingEntries.isNotEmpty,
    );
    if (action == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLinkingWebDav = true);
    try {
      switch (action) {
        case _WebDavManagementAction.add:
          await _addWebDavEntry(session: session, settings: settings);
          break;
        case _WebDavManagementAction.select:
          await _selectWebDavEntry(session: session, settings: settings);
          break;
        case _WebDavManagementAction.remove:
          await _removeWebDavEntry(session: session, settings: settings);
          break;
        case _WebDavManagementAction.unlinkAll:
          await _unlinkAllWebDavEntries(session: session);
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('All WebDAV entries unlinked.')),
          );
          break;
      }
    } on WebDavException catch (error) {
      if (!mounted) return;
      showWebDavErrorSnackBar(context: context, error: error);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('WebDAV update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLinkingWebDav = false);
      }
    }
  }

  Future<void> _addWebDavEntry({
    required AuthSession session,
    required UserSettingsData? settings,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final connectionDetails = await _showWebDavDialog(
      initialServerUrl: settings?.webDavServerUrl,
      initialUsername: settings?.webDavUsername,
    );
    if (connectionDetails == null) {
      return;
    }

    final linkedAccount = await ServiceLocator.webDavService.linkAccount(
      uid: session.uid,
      serverUrl: connectionDetails.serverUrl,
      username: connectionDetails.username,
      password: connectionDetails.password,
    );
    final entry = WebDavSavedEntry(
      id: _buildWebDavEntryId(),
      serverUrl: linkedAccount.serverUrl,
      username: linkedAccount.username,
    );
    await ServiceLocator.webDavService.saveEntryPassword(
      uid: session.uid,
      entryId: entry.id,
      password: connectionDetails.password,
    );
    await ServiceLocator.userRepository.upsertWebDavEntry(
      uid: session.uid,
      entry: entry,
      password: connectionDetails.password,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'WebDAV entry added: ${linkedAccount.username} on ${linkedAccount.hostLabel}.',
        ),
      ),
    );
  }

  Future<void> _selectWebDavEntry({
    required AuthSession session,
    required UserSettingsData? settings,
  }) async {
    final entries = _webDavEntries(settings);
    if (entries.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final selected = await _showWebDavEntryPickerDialog(
      title: 'Select WebDAV entry',
      entries: entries,
      activeEntryId: settings?.webDavActiveEntryId,
    );
    if (selected == null) {
      return;
    }
    if (settings?.webDavActiveEntryId == selected.id) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This WebDAV entry is already active.')),
      );
      return;
    }

    var password = await ServiceLocator.webDavService.readEntryPassword(
      uid: session.uid,
      entryId: selected.id,
    );
    if ((password == null || password.isEmpty) &&
        settings?.webDavServerUrl == selected.serverUrl &&
        settings?.webDavUsername == selected.username &&
        (settings?.webDavPassword?.isNotEmpty ?? false)) {
      password = settings!.webDavPassword;
    }
    if (password == null || password.isEmpty) {
      final enteredPassword = await _showWebDavPasswordDialog(
        username: selected.username,
        serverUrl: selected.serverUrl,
      );
      if (enteredPassword == null || enteredPassword.isEmpty) {
        return;
      }
      password = enteredPassword;
      await ServiceLocator.webDavService.saveEntryPassword(
        uid: session.uid,
        entryId: selected.id,
        password: password,
      );
    }

    await ServiceLocator.webDavService.saveCredentialsWithoutValidation(
      uid: session.uid,
      serverUrl: selected.serverUrl,
      username: selected.username,
      password: password,
    );
    await ServiceLocator.userRepository.selectWebDavEntry(
      uid: session.uid,
      entryId: selected.id,
      activePassword: password,
    );
    if (!mounted) return;
    final host = Uri.tryParse(selected.serverUrl)?.host;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          host == null || host.isEmpty
              ? 'WebDAV entry active: ${selected.username}.'
              : 'WebDAV entry active: ${selected.username} on $host.',
        ),
      ),
    );
  }

  Future<void> _removeWebDavEntry({
    required AuthSession session,
    required UserSettingsData? settings,
  }) async {
    final entries = _webDavEntries(settings);
    if (entries.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final selected = await _showWebDavEntryPickerDialog(
      title: 'Remove WebDAV entry',
      entries: entries,
      activeEntryId: settings?.webDavActiveEntryId,
    );
    if (selected == null) {
      return;
    }
    await ServiceLocator.webDavService.clearEntryPassword(
      uid: session.uid,
      entryId: selected.id,
    );
    await ServiceLocator.userRepository.removeWebDavEntry(
      uid: session.uid,
      entryId: selected.id,
    );
    if (entries.length == 1) {
      await ServiceLocator.webDavService.clearCredentials(uid: session.uid);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('WebDAV entry removed: ${selected.username}.')),
    );
  }

  Future<void> _unlinkAllWebDavEntries({required AuthSession session}) async {
    final settings = await ServiceLocator.userRepository.getUserSettings(
      session.uid,
    );
    for (final entry in settings.webDavEntries) {
      await ServiceLocator.webDavService.clearEntryPassword(
        uid: session.uid,
        entryId: entry.id,
      );
    }
    await ServiceLocator.webDavService.clearCredentials(uid: session.uid);
    await ServiceLocator.userRepository.clearWebDavLinked(uid: session.uid);
  }

  String _buildWebDavEntryId() {
    return 'wd_${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _setCloudSyncProvider({
    required AuthSession session,
    required CloudSyncProvider provider,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ServiceLocator.userRepository.setCloudSyncProvider(
        uid: session.uid,
        provider: provider,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_cloudProviderLabel(provider)} is now the active cloud provider.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not update cloud provider: $error')),
      );
    }
  }

  Future<_WebDavManagementAction?> _showWebDavManagementActionDialog({
    required bool hasEntries,
  }) {
    return showDialog<_WebDavManagementAction>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Manage WebDAV entries'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop(_WebDavManagementAction.add);
              },
              child: const Text('Add WebDAV entry'),
            ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.select);
                },
                child: const Text('Select active entry'),
              ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.remove);
                },
                child: const Text('Remove one entry'),
              ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.unlinkAll);
                },
                child: const Text('Unlink all entries'),
              ),
          ],
        );
      },
    );
  }

  Future<WebDavSavedEntry?> _showWebDavEntryPickerDialog({
    required String title,
    required List<WebDavSavedEntry> entries,
    String? activeEntryId,
  }) {
    return showDialog<WebDavSavedEntry>(
      context: context,
      builder: (dialogContext) {
        final selectedId = ValueNotifier<String?>(
          activeEntryId ?? (entries.isEmpty ? null : entries.first.id),
        );
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: ValueListenableBuilder<String?>(
              valueListenable: selectedId,
              builder: (context, value, _) {
                return ListView(
                  shrinkWrap: true,
                  children: entries.map((entry) {
                    final host = Uri.tryParse(entry.serverUrl)?.host;
                    final subtitle = host == null || host.isEmpty
                        ? entry.serverUrl
                        : '${entry.username} on $host';
                    final isSelected = value == entry.id;
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(entry.username),
                      subtitle: Text(subtitle),
                      onTap: () {
                        selectedId.value = entry.id;
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final id = selectedId.value;
                if (id == null) return;
                final selectedEntry = entries.where((entry) => entry.id == id);
                if (selectedEntry.isEmpty) return;
                Navigator.of(dialogContext).pop(selectedEntry.first);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showWebDavPasswordDialog({
    required String username,
    required String serverUrl,
  }) async {
    final controller = TextEditingController();
    var obscurePassword = true;
    var errorText = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter app password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Password required for $username'),
                  const SizedBox(height: 4),
                  Text(serverUrl, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'App password',
                      errorText: errorText.isEmpty ? null : errorText,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      final password = controller.text.trim();
                      if (password.isEmpty) {
                        setDialogState(() {
                          errorText = 'App password is required.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(password);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final password = controller.text.trim();
                    if (password.isEmpty) {
                      setDialogState(() {
                        errorText = 'App password is required.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<_WebDavFormResult?> _showWebDavDialog({
    String? initialServerUrl,
    String? initialUsername,
  }) async {
    final serverUrlController = TextEditingController(
      text: initialServerUrl ?? '',
    );
    final usernameController = TextEditingController(
      text: initialUsername ?? '',
    );
    final passwordController = TextEditingController();
    var obscurePassword = true;
    String? errorText;

    final result = await showDialog<_WebDavFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> scanQrCode() async {
              if (kIsWeb ||
                  (defaultTargetPlatform != TargetPlatform.android &&
                      defaultTargetPlatform != TargetPlatform.iOS)) {
                setDialogState(() {
                  errorText = 'QR scan is available on Android and iOS only.';
                });
                return;
              }
              final scannedPayload = await Navigator.of(dialogContext)
                  .push<String>(
                    MaterialPageRoute(
                      builder: (context) => const _WebDavQrScannerPage(),
                    ),
                  );
              if (!dialogContext.mounted || scannedPayload == null) {
                return;
              }
              _ParsedWebDavQrPayload? parsed;
              try {
                parsed = _parseWebDavQrPayload(scannedPayload);
              } catch (_) {
                parsed = null;
              }
              if (parsed == null) {
                final scannedServerUrl = _parseWebDavServerUrlOnly(
                  scannedPayload,
                );
                if (scannedServerUrl != null) {
                  setDialogState(() {
                    serverUrlController.text = scannedServerUrl;
                    errorText =
                        'Server URL imported from QR. Enter username and app password to continue.';
                  });
                  return;
                }
                final scannedPassword = _parseWebDavPasswordOnly(
                  scannedPayload,
                );
                if (scannedPassword != null) {
                  setDialogState(() {
                    passwordController.text = scannedPassword;
                    errorText =
                        'App password imported from QR. Enter server URL and username to continue.';
                  });
                  return;
                }
                setDialogState(() {
                  errorText =
                      'QR code was read, but the format is not supported. Use URL, username, and app password fields.';
                });
                return;
              }
              final parsedPayload = parsed;
              setDialogState(() {
                serverUrlController.text = parsedPayload.serverUrl;
                usernameController.text = parsedPayload.username;
                passwordController.text = parsedPayload.password;
                errorText = null;
              });
            }

            _WebDavFormResult? buildResultOrShowError() {
              final trimmedServerUrl = serverUrlController.text.trim();
              final trimmedUsername = usernameController.text.trim();
              final password = passwordController.text;
              if (trimmedServerUrl.isEmpty ||
                  trimmedUsername.isEmpty ||
                  password.isEmpty) {
                setDialogState(() {
                  errorText =
                      'Enter the WebDAV URL, username, and app password.';
                });
                return null;
              }
              return _WebDavFormResult(
                serverUrl: trimmedServerUrl,
                username: trimmedUsername,
                password: password,
              );
            }

            return AlertDialog(
              title: const Text('Link WebDAV / Nextcloud'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: serverUrlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV URL',
                        hintText:
                            'https://cloud.example.com/remote.php/dav/files/you/',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onFieldSubmitted: (_) {
                        final result = buildResultOrShowError();
                        if (result != null) {
                          Navigator.of(dialogContext).pop(result);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'App password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'If phone works but web fails, this is usually CORS/TLS on the WebDAV server.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: scanQrCode,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        label: const Text('Scan passkey QR'),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final result = buildResultOrShowError();
                    if (result != null) {
                      Navigator.of(dialogContext).pop(result);
                    }
                  },
                  child: const Text('Link'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _openEntitlementScreen({required AuthSession session}) async {
    if (!mounted) return;
    await PurchasesService.instance.syncAppUser(
      session.uid,
      email: session.email,
    );
    await PurchasesService.instance.refreshCustomerInfo();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EntitlementPage()));
  }

  Future<void> _openDataCollectionPage() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DataCollectionPage()));
  }

  void _openDeleteAccountPage() {
    if (kIsWeb) {
      openSameTabUrl('/delete-account/');
      return;
    }
    openExternalUrl(IConst.deleteAccountUrl).then((opened) {
      if (!mounted || opened) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Open ${IConst.deleteAccountUrl} in a browser to continue.',
          ),
        ),
      );
    });
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
    await showSignInSheet<bool>(context);
  }
}

class _WebDavFormResult {
  const _WebDavFormResult({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

enum _WebDavManagementAction { add, select, remove, unlinkAll }

class _ParsedWebDavQrPayload {
  const _ParsedWebDavQrPayload({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

_ParsedWebDavQrPayload? _parseWebDavQrPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final fromNextcloudLogin = _parseWebDavQrNextcloudLogin(trimmed);
  if (fromNextcloudLogin != null) {
    return fromNextcloudLogin;
  }

  final fromJson = _parseWebDavQrJson(trimmed);
  if (fromJson != null) {
    return fromJson;
  }

  final fromUri = _parseWebDavQrUri(trimmed);
  if (fromUri != null) {
    return fromUri;
  }

  final fromKv = _parseWebDavQrKeyValue(trimmed);
  if (fromKv != null) {
    return fromKv;
  }

  return null;
}

_ParsedWebDavQrPayload? _parseWebDavQrNextcloudLogin(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'nc' && scheme != 'nextcloud') {
    return null;
  }

  var payload = raw.substring(raw.indexOf('://') + 3).trim();
  if (payload.startsWith('login/')) {
    payload = payload.substring('login/'.length);
  }
  if (payload.isEmpty) {
    return null;
  }

  final values = <String, dynamic>{};
  for (final part in payload.split('&')) {
    final chunk = Uri.decodeComponent(part.trim());
    if (chunk.isEmpty) {
      continue;
    }

    final equalsIndex = chunk.indexOf('=');
    final colonIndex = chunk.indexOf(':');
    var splitAt = equalsIndex;
    if (splitAt < 0 || (colonIndex >= 0 && colonIndex < splitAt)) {
      splitAt = colonIndex;
    }
    if (splitAt <= 0) {
      continue;
    }

    final rawKey = chunk.substring(0, splitAt).trim();
    final key = rawKey.contains('/')
        ? rawKey.substring(rawKey.lastIndexOf('/') + 1).toLowerCase()
        : rawKey.toLowerCase();
    final value = chunk.substring(splitAt + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    values[key] = value;
  }

  final serverUrl = _firstMapValue(values, <String>[
    'server',
    'serverurl',
    'url',
    'webdavurl',
    'endpoint',
  ]);
  final username = _firstMapValue(values, <String>[
    'username',
    'user',
    'login',
    'email',
  ]);
  final password = _firstMapValue(values, <String>[
    'password',
    'pass',
    'apppassword',
    'passkey',
    'token',
  ]);

  final normalizedServerUrl = _normalizeNextcloudWebDavServerUrl(
    serverUrl: serverUrl,
    username: username,
  );

  return _buildParsedWebDavPayload(
    serverUrl: normalizedServerUrl,
    username: username,
    password: password,
  );
}

_ParsedWebDavQrPayload? _parseWebDavQrJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final serverUrl = _firstMapValue(decoded, <String>[
      'serverUrl',
      'url',
      'webdavUrl',
      'endpoint',
    ]);
    final username = _firstMapValue(decoded, <String>[
      'username',
      'user',
      'login',
      'email',
    ]);
    final password = _firstMapValue(decoded, <String>[
      'password',
      'pass',
      'appPassword',
      'passkey',
      'token',
    ]);
    return _buildParsedWebDavPayload(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  } catch (_) {
    return null;
  }
}

_ParsedWebDavQrPayload? _parseWebDavQrUri(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' &&
      scheme != 'https' &&
      scheme != 'webdav' &&
      scheme != 'webdavs') {
    return null;
  }

  String? username;
  String? password;
  if (uri.userInfo.isNotEmpty) {
    final split = uri.userInfo.split(':');
    username = Uri.decodeComponent(split.first);
    if (split.length > 1) {
      password = Uri.decodeComponent(split.sublist(1).join(':'));
    }
  }
  username ??= _queryValue(uri, <String>['username', 'user', 'login', 'email']);
  password ??= _queryValue(uri, <String>[
    'password',
    'pass',
    'appPassword',
    'token',
  ]);

  final normalizedUri = uri.replace(userInfo: '');
  final serverUrl = normalizedUri.toString();

  return _buildParsedWebDavPayload(
    serverUrl: serverUrl,
    username: username,
    password: password,
  );
}

_ParsedWebDavQrPayload? _parseWebDavQrKeyValue(String raw) {
  String normalizeInput(String input) {
    if (input.contains('\n') || input.contains(';')) {
      return input;
    }
    if (input.contains('&')) {
      return input.replaceAll('&', '\n');
    }
    return input;
  }

  final lines = normalizeInput(raw)
      .split(RegExp(r'[\n;]'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return null;
  }

  final values = <String, dynamic>{};
  for (final line in lines) {
    final separatorIndex = line.indexOf('=');
    final colonIndex = line.indexOf(':');
    int splitAt = separatorIndex;
    if (splitAt < 0 || (colonIndex >= 0 && colonIndex < splitAt)) {
      splitAt = colonIndex;
    }
    if (splitAt <= 0) {
      continue;
    }
    final key = line.substring(0, splitAt).trim().toLowerCase();
    final value = line.substring(splitAt + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    values[key] = value;
  }

  final serverUrl = _firstMapValue(values, <String>[
    'serverurl',
    'url',
    'webdavurl',
    'endpoint',
    'host',
  ]);
  final username = _firstMapValue(values, <String>[
    'username',
    'user',
    'login',
    'email',
  ]);
  final password = _firstMapValue(values, <String>[
    'password',
    'pass',
    'apppassword',
    'passkey',
    'token',
  ]);

  return _buildParsedWebDavPayload(
    serverUrl: serverUrl,
    username: username,
    password: password,
  );
}

String? _firstMapValue(Map<String, dynamic> map, List<String> keys) {
  final normalized = <String, dynamic>{};
  for (final entry in map.entries) {
    normalized[entry.key.toLowerCase()] = entry.value;
  }
  for (final key in keys) {
    final value = normalized[key.toLowerCase()];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null) {
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

String? _queryValue(Uri uri, List<String> keys) {
  final keySet = keys.map((key) => key.toLowerCase()).toSet();
  for (final entry in uri.queryParameters.entries) {
    if (!keySet.contains(entry.key.toLowerCase())) {
      continue;
    }
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  for (final key in keys) {
    final value = uri.queryParameters[key];
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

_ParsedWebDavQrPayload? _buildParsedWebDavPayload({
  required String? serverUrl,
  required String? username,
  required String? password,
}) {
  if (serverUrl == null || username == null || password == null) {
    return null;
  }
  final parsedUri = Uri.tryParse(serverUrl);
  if (parsedUri == null || !parsedUri.hasScheme) {
    return null;
  }
  final scheme = parsedUri.scheme.toLowerCase();
  if (scheme != 'http' &&
      scheme != 'https' &&
      scheme != 'webdav' &&
      scheme != 'webdavs') {
    return null;
  }
  return _ParsedWebDavQrPayload(
    serverUrl: serverUrl,
    username: username,
    password: password,
  );
}

String? _parseWebDavServerUrlOnly(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' &&
      scheme != 'https' &&
      scheme != 'webdav' &&
      scheme != 'webdavs') {
    return null;
  }
  if (uri.host.trim().isEmpty) {
    return null;
  }
  return uri.replace(userInfo: '').toString();
}

String? _parseWebDavPasswordOnly(String raw) {
  final token = raw.trim();
  if (token.isEmpty) {
    return null;
  }
  if (token.contains(' ') || token.contains('\n')) {
    return null;
  }
  final looksLikeUrl = Uri.tryParse(token)?.hasScheme == true;
  if (looksLikeUrl) {
    return null;
  }
  if (token.length < 6) {
    return null;
  }
  return token;
}

String? _normalizeNextcloudWebDavServerUrl({
  required String? serverUrl,
  required String? username,
}) {
  if (serverUrl == null || username == null) {
    return serverUrl;
  }
  final parsed = Uri.tryParse(serverUrl.trim());
  final cleanUsername = username.trim();
  if (parsed == null || cleanUsername.isEmpty || !parsed.hasScheme) {
    return serverUrl;
  }
  final normalizedPath = parsed.path.trim();
  if (normalizedPath.isNotEmpty && normalizedPath != '/') {
    return serverUrl;
  }
  final encodedUsername = Uri.encodeComponent(cleanUsername);
  return parsed
      .replace(path: '/remote.php/dav/files/$encodedUsername/')
      .toString();
}

class _WebDavQrScannerPage extends StatefulWidget {
  const _WebDavQrScannerPage();

  @override
  State<_WebDavQrScannerPage> createState() => _WebDavQrScannerPageState();
}

class _WebDavQrScannerPageState extends State<_WebDavQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _didCaptureCode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_didCaptureCode) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      _didCaptureCode = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan passkey QR')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
