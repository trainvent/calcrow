import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:saf_util/saf_util.dart';

import 'package:calcrow/app/presentation/web_link_opener_stub.dart'
    if (dart.library.html) 'package:calcrow/app/presentation/web_link_opener_web.dart';
import 'package:calcrow/core/constants/internal_constants.dart';
import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/core/data/services/auth_service.dart';
import 'package:calcrow/core/data/services/google_drive_auth_service.dart';
import 'package:calcrow/core/data/services/google_drive_sync_service.dart';
import 'package:calcrow/core/data/services/purchases_service.dart';
import 'package:calcrow/core/data/services/sheet_persistence_service.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:calcrow/core/data/services/webdav_service.dart';
import 'package:calcrow/features/auth/sign_in_sheet.dart';

import 'data_collection_page.dart';
import 'webdav_error_presentation.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const String _googleDriveLogTag = 'CalcrowGoogleDrive';
  bool _isLinkingGoogle = false;
  bool _isLinkingWebDav = false;
  bool _isOpeningRevenueCat = false;
  bool _isChangingPassword = false;
  bool _isUpdatingSafFolder = false;
  static final SafUtil _safUtil = SafUtil();
  final SheetPersistenceService _sheetPersistenceService =
      SheetPersistenceService();

  bool get _showSafFolderSettings =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
            LText('Settings', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 12),
            if (session == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const LText('Signed out'),
                  subtitle: const LText('Sign in to use Calcrow.'),
                  trailing: TextButton(
                    onPressed: () => _openSignInSheet(context),
                    child: const LText('Sign in'),
                  ),
                ),
              ),
            if (session == null && _showSafFolderSettings) ...[
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_special_outlined),
                      title: const LText('Manage SAF folder'),
                      subtitle: LText(_safFolderSubtitle(null)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildSafActionGrid(
                        setButton: OutlinedButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _setSafFolder(),
                          child: const LText('Set'),
                        ),
                        clearButton: TextButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _clearSafFolder(),
                          child: const LText('Clear'),
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
                      child: LText(
                        'Sign in to save this Android folder setting to your account.',
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
                              title: const LText('Active cloud provider'),
                              trailing: DropdownButtonHideUnderline(
                                child: DropdownButton<CloudSyncProvider>(
                                  value: _selectedCloudProvider(settings),
                                  hint: const LText('Choose'),
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
                                              child: LText(
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
                              title: const LText('Connect Google Drive'),
                              subtitle: LText(_googleDriveSubtitle(settings)),
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
                                      child: LText(
                                        _isGoogleDriveLinked(settings)
                                            ? 'Unlink'
                                            : 'Link',
                                      ),
                                    ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.storage_rounded),
                              title: const LText('Link WebDAV / Nextcloud'),
                              subtitle: LText(_webDavSubtitle(settings)),
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
                                      child: LText(
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
                      if (_showSafFolderSettings) ...[
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.folder_special_outlined,
                                ),
                                title: const LText('Manage SAF folder'),
                                subtitle: LText(_safFolderSubtitle(settings)),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: _buildSafActionGrid(
                                  setButton: OutlinedButton(
                                    onPressed: _isUpdatingSafFolder
                                        ? null
                                        : () => _setSafFolder(session: session),
                                    child: const LText('Set'),
                                  ),
                                  clearButton: TextButton(
                                    onPressed: _isUpdatingSafFolder
                                        ? null
                                        : () =>
                                              _clearSafFolder(session: session),
                                    child: const LText('Clear'),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Card(
                        child: Column(
                          children: [
                            _buildSectionHeader(
                              context,
                              title: 'Account Settings',
                              subtitle:
                                  'Manage your subscription, privacy, and account access.',
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.alternate_email),
                              title: const LText('Signed in as'),
                              subtitle: session.email.trim().isEmpty
                                  ? const LText('No email available.')
                                  : Text(session.email),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.workspace_premium_outlined,
                              ),
                              title: const LText('Entitlement'),
                              subtitle: LText(
                                settings?.isPro == true
                                    ? 'Pro enabled.'
                                    : 'Open subscription and purchase options.',
                              ),
                              trailing: _isOpeningRevenueCat
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _isOpeningRevenueCat
                                  ? null
                                  : () => _openRevenueCatEntitlementFlow(
                                      session: session,
                                      isPro: settings?.isPro == true,
                                    ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined),
                              title: const LText('Data collection'),
                              subtitle: const LText(
                                'Manage separate consent for usage analytics and crash or performance diagnostics.',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: _openDataCollectionPage,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.password_rounded),
                              title: const LText('Change password'),
                              subtitle: const LText(
                                'Send a reset code to your signed-in email.',
                              ),
                              trailing: _isChangingPassword
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _isChangingPassword
                                  ? null
                                  : () =>
                                        _openChangePasswordFlow(session.email),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout_rounded),
                              title: const LText('Sign out'),
                              onTap: () => ServiceLocator.authService.signOut(),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.delete_outline_rounded),
                              title: const LText('Delete account'),
                              subtitle: const LText(
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
                  title: const LText('Data collection'),
                  subtitle: const LText(
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

  bool _isWebDavLinked(UserSettingsData? settings) {
    if (settings == null) return false;
    return settings.webDavLinked || settings.webDavEntries.isNotEmpty;
  }

  List<WebDavSavedEntry> _webDavEntries(UserSettingsData? settings) {
    return settings?.webDavEntries ?? const <WebDavSavedEntry>[];
  }

  CloudSyncProvider? _selectedCloudProvider(UserSettingsData? settings) {
    if (settings == null) return null;
    return ServiceLocator.cloudDocumentService.activeProviderFromSettings(
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
      return 'Grant Drive read/write permissions for cloud document sync.';
    }
    final email = settings?.googleDriveEmail;
    if (email != null && email.isNotEmpty) {
      return 'Linked as $email';
    }
    return 'Connected to Google Drive';
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
    return ServiceLocator.cloudDocumentService.providerLabel(provider);
  }

  String _safFolderSubtitle(UserSettingsData? settings) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'Available on Android only.';
    }
    final uri = settings?.safTreeUri;
    final runtimeUri = SheetPersistenceService.runtimeSafTreeUri;
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
          LText(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          LText(subtitle, style: theme.textTheme.bodyMedium),
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

  Future<void> _openChangePasswordFlow(String email) async {
    final normalizedEmail = email.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (normalizedEmail.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: LText('No account email is available.')),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await ServiceLocator.authService.sendPasswordResetCode(
        email: normalizedEmail,
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText(_readablePasswordResetError(error))),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: LText('Could not send password reset code.')),
      );
      return;
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: LText('Password reset code sent to $normalizedEmail.')),
    );
    await _showChangePasswordDialog(normalizedEmail);
  }

  Future<void> _showChangePasswordDialog(String email) async {
    final didUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePasswordDialog(
        email: email,
        readablePasswordResetError: _readablePasswordResetError,
      ),
    );

    if (didUpdate == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LText('Password updated.')));
    }
  }

  String _readablePasswordResetError(AuthServiceException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'not-found':
        return 'No active reset code was found. Request a new one.';
      case 'failed-precondition':
        return 'That reset code is no longer valid. Request a new one.';
      default:
        return _readableAuthError(error);
    }
  }

  String _readableAuthError(AuthServiceException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Network error. Check connection and try again.';
      case 'invalid-email':
        return 'Email address format is invalid.';
      case 'invalid-argument':
        return 'The code was not accepted. Check it and try again.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Authentication failed (${error.code}).';
    }
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
          const SnackBar(content: LText('Google account unlinked.')),
        );
      } else {
        late final GoogleDriveLinkResult linkResult;
        try {
          linkResult = await ServiceLocator.googleDriveAuthService
              .linkAccount();
        } on GoogleDriveAuthException catch (error) {
          throw GoogleDriveAuthException(
            'Google Drive authorization failed: ${error.message}',
          );
        }

        http.Client? client;
        try {
          client = await ServiceLocator.googleDriveAuthService
              .getAuthenticatedClient();
        } on GoogleDriveAuthException catch (error) {
          throw GoogleDriveAuthException(
            'Authenticated client step failed: ${error.message}',
          );
        } finally {
          client?.close();
        }
        await ServiceLocator.userRepository.setGoogleDriveLinked(
          uid: uid,
          email: linkResult.email,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: LText(
              'Google Drive connected: ${linkResult.email}. Choose a Drive file next.',
            ),
          ),
        );
      }
    } on GoogleDriveAuthException catch (error) {
      debugPrint(
        '$_googleDriveLogTag settings link auth error: ${error.message}',
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText(error.message)));
    } on GoogleDriveSyncException catch (error) {
      debugPrint(
        '$_googleDriveLogTag settings link sync error: ${error.message}',
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText(error.message)));
    } catch (error) {
      debugPrint('$_googleDriveLogTag settings link unexpected error: $error');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('Google link failed: $error')),
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
            const SnackBar(content: LText('All WebDAV entries unlinked.')),
          );
          break;
      }
    } on WebDavException catch (error) {
      if (!mounted) return;
      showWebDavErrorSnackBar(context: context, error: error);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('WebDAV update failed: $error')),
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
        content: LText(
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
        const SnackBar(content: LText('This WebDAV entry is already active.')),
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
        content: LText(
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
      SnackBar(content: LText('WebDAV entry removed: ${selected.username}.')),
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
          content: LText(
            '${_cloudProviderLabel(provider)} is now the active cloud provider.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('Could not update cloud provider: $error')),
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
          title: const LText('Manage WebDAV entries'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(dialogContext).pop(_WebDavManagementAction.add);
              },
              child: const LText('Add WebDAV entry'),
            ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.select);
                },
                child: const LText('Select active entry'),
              ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.remove);
                },
                child: const LText('Remove one entry'),
              ),
            if (hasEntries)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(_WebDavManagementAction.unlinkAll);
                },
                child: const LText('Unlink all entries'),
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
          title: LText(title),
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
              child: const LText('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final id = selectedId.value;
                if (id == null) return;
                final selectedEntry = entries.where((entry) => entry.id == id);
                if (selectedEntry.isEmpty) return;
                Navigator.of(dialogContext).pop(selectedEntry.first);
              },
              child: const LText('Confirm'),
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
              title: const LText('Enter app password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText('Password required for $username'),
                  const SizedBox(height: 4),
                  Text(serverUrl, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.tr('App password'),
                      errorText: errorText.isEmpty
                          ? null
                          : context.tr(errorText),
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
                  child: const LText('Cancel'),
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
                  child: const LText('Confirm'),
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
              title: const LText('Link WebDAV / Nextcloud'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: serverUrlController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: context.tr('WebDAV URL'),
                        hintText:
                            'https://cloud.example.com/remote.php/dav/files/you/',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.tr('Username'),
                      ),
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
                        labelText: context.tr('App password'),
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
                      const LText(
                        'If phone works but web fails, this is usually CORS/TLS on the WebDAV server.',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: scanQrCode,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        label: const LText('Scan passkey QR'),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      LText(
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
                  child: const LText('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final result = buildResultOrShowError();
                    if (result != null) {
                      Navigator.of(dialogContext).pop(result);
                    }
                  },
                  child: const LText('Link'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _openRevenueCatEntitlementFlow({
    required AuthSession session,
    required bool isPro,
  }) async {
    if (!mounted) return;
    setState(() => _isOpeningRevenueCat = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PurchasesService.instance.syncAppUser(
        session.uid,
        email: session.email,
      );
      await PurchasesService.instance.refreshCustomerInfo();
      if (isPro) {
        await PurchasesService.instance.presentCustomerCenter();
      } else {
        await PurchasesService.instance.presentPaywall();
      }
      await PurchasesService.instance.refreshCustomerInfo();
    } on PurchasesServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: LText(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('Could not open subscription options: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningRevenueCat = false);
      }
    }
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
          content: LText(
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
        const SnackBar(content: LText('SAF folder setup is Android-only.')),
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
          const SnackBar(content: LText('SAF folder selection canceled.')),
        );
        return;
      }
      final normalizedTreeUri = treeUri.trim();
      if (!_sheetPersistenceService.canUseSafTreeUri(normalizedTreeUri)) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: LText('Could not acquire a writable SAF folder URI.'),
          ),
        );
        return;
      }
      SheetPersistenceService.setRuntimeSafTreeUri(normalizedTreeUri);
      var syncedToSettings = session == null;
      if (session != null) {
        try {
          await ServiceLocator.dbService.setSafFolderUri(
            uid: session.uid,
            treeUri: normalizedTreeUri,
          );
          syncedToSettings = true;
        } catch (_) {
          syncedToSettings = false;
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: LText(
            syncedToSettings
                ? (session == null
                      ? 'SAF folder saved for this app session.'
                      : 'SAF folder saved in settings.')
                : 'SAF folder saved for this app session. Settings sync failed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('Could not set SAF folder: $error')),
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
      SheetPersistenceService.setRuntimeSafTreeUri(null);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: LText('SAF folder cleared.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: LText('Could not clear SAF folder: $error')),
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

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.email,
    required this.readablePasswordResetError,
  });

  final String email;
  final String Function(AuthServiceException error) readablePasswordResetError;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    final validationError = _validationError(
      code: code,
      password: password,
      confirm: confirm,
    );

    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ServiceLocator.authService.resetPasswordWithCode(
        email: widget.email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = widget.readablePasswordResetError(error);
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not reset password right now.';
        _isSubmitting = false;
      });
    }
  }

  String? _validationError({
    required String code,
    required String password,
    required String confirm,
  }) {
    if (code.length != 6) {
      return 'Enter the 6-digit code.';
    }
    if (password.isEmpty || confirm.isEmpty) {
      return 'New password and confirmation are required.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (password != confirm) {
      return 'Passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const LText('Change password'),
      content: SingleChildScrollView(
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LText('Enter the code sent to ${widget.email}.'),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('Reset code'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !_isSubmitting,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.tr('New password'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                enabled: !_isSubmitting,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.tr('Confirm new password'),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                LText(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const LText('Update'),
        ),
      ],
    );
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
      appBar: AppBar(title: const LText('Scan passkey QR')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
