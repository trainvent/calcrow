import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:saf_stream/saf_stream.dart';
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
  static const String _safTestFileName = 'calcrow_saf_test.txt';
  static const String _googleDriveLogTag = 'CalcrowGoogleDrive';
  bool _isLinkingGoogle = false;
  bool _isLinkingWebDav = false;
  bool _isUpdatingAdvancedFeatures = false;
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
                        testButton: OutlinedButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _testSafFolder(settings: null),
                          child: const Text('Test'),
                        ),
                        setButton: OutlinedButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _setSafFolder(),
                          child: const Text('Set'),
                        ),
                        revertButton: OutlinedButton(
                          onPressed: _isUpdatingSafFolder
                              ? null
                              : () => _revertSafTest(settings: null),
                          child: const Text('Untest'),
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
                              subtitle: Text(
                                _activeCloudProviderSubtitle(settings),
                              ),
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
                                      onPressed: () => _toggleWebDavLink(
                                        session: session,
                                        currentlyLinked: _isWebDavLinked(
                                          settings,
                                        ),
                                        settings: settings,
                                      ),
                                      child: Text(
                                        _isWebDavLinked(settings)
                                            ? 'Unlink'
                                            : 'Link',
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
                                testButton: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () =>
                                            _testSafFolder(settings: settings),
                                  child: const Text('Test'),
                                ),
                                revertButton: OutlinedButton(
                                  onPressed: _isUpdatingSafFolder
                                      ? null
                                      : () =>
                                            _revertSafTest(settings: settings),
                                  child: const Text('Test Revert'),
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
    return settings?.webDavLinked == true;
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
    final linked = _isWebDavLinked(settings);
    if (!linked) {
      return 'Connect a WebDAV or Nextcloud folder using its WebDAV URL.';
    }
    final username = settings?.webDavUsername;
    final serverUrl = settings?.webDavServerUrl;
    if (username != null && username.isNotEmpty && serverUrl != null) {
      final host = Uri.tryParse(serverUrl)?.host;
      if (host != null && host.isNotEmpty) {
        return 'Linked as $username on $host';
      }
      return 'Linked as $username';
    }
    return 'WebDAV connected';
  }

  String _cloudProviderLabel(CloudSyncProvider provider) {
    return ServiceLocator.simpleCloudDocumentService.providerLabel(provider);
  }

  String _activeCloudProviderSubtitle(UserSettingsData? settings) {
    final provider = _selectedCloudProvider(settings);
    if (provider == null) {
      return 'Link Google Drive or WebDAV first.';
    }
    return 'Used for Edit Cloud Document and auto cloud save.';
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
    required Widget testButton,
    required Widget revertButton,
    required Widget clearButton,
  }) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: testButton),
            const SizedBox(width: 8),
            Expanded(child: setButton),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(child: revertButton),
            const SizedBox(width: 8),
            Expanded(child: clearButton),
          ],
        ),
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

  Future<void> _toggleWebDavLink({
    required AuthSession session,
    required bool currentlyLinked,
    required UserSettingsData? settings,
  }) async {
    if (_isLinkingWebDav) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLinkingWebDav = true);
    try {
      if (currentlyLinked) {
        await ServiceLocator.webDavService.clearCredentials(uid: session.uid);
        await ServiceLocator.userRepository.clearWebDavLinked(uid: session.uid);
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('WebDAV account unlinked.')),
        );
        return;
      }

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
      await ServiceLocator.userRepository.setWebDavLinked(
        uid: session.uid,
        serverUrl: linkedAccount.serverUrl,
        username: linkedAccount.username,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'WebDAV linked: ${linkedAccount.username} on ${linkedAccount.hostLabel}.',
          ),
        ),
      );
    } on WebDavException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('WebDAV link failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLinkingWebDav = false);
      }
    }
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

  Future<_WebDavFormResult?> _showWebDavDialog({
    String? initialServerUrl,
    String? initialUsername,
  }) async {
    var serverUrl = initialServerUrl ?? '';
    var username = initialUsername ?? '';
    var password = '';
    var obscurePassword = true;
    String? errorText;

    final result = await showDialog<_WebDavFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Link WebDAV / Nextcloud'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: serverUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (value) => serverUrl = value,
                      decoration: const InputDecoration(
                        labelText: 'WebDAV URL',
                        hintText:
                            'https://cloud.example.com/remote.php/dav/files/you/',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: username,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => username = value,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      obscureText: obscurePassword,
                      onChanged: (value) => password = value,
                      onFieldSubmitted: (_) {
                        final trimmedServerUrl = serverUrl.trim();
                        final trimmedUsername = username.trim();
                        if (trimmedServerUrl.isEmpty ||
                            trimmedUsername.isEmpty ||
                            password.isEmpty) {
                          setDialogState(() {
                            errorText =
                                'Enter the WebDAV URL, username, and app password.';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(
                          _WebDavFormResult(
                            serverUrl: trimmedServerUrl,
                            username: trimmedUsername,
                            password: password,
                          ),
                        );
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
                    final trimmedServerUrl = serverUrl.trim();
                    final trimmedUsername = username.trim();
                    if (trimmedServerUrl.isEmpty ||
                        trimmedUsername.isEmpty ||
                        password.isEmpty) {
                      setDialogState(() {
                        errorText =
                            'Enter the WebDAV URL, username, and app password.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _WebDavFormResult(
                        serverUrl: trimmedServerUrl,
                        username: trimmedUsername,
                        password: password,
                      ),
                    );
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
    await PurchasesService.instance.syncAppUser(session.uid);
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

  Future<void> _testSafFolder({required UserSettingsData? settings}) async {
    final messenger = ScaffoldMessenger.of(context);
    final treeUri =
        settings?.safTreeUri ?? SimpleSheetPersistenceService.runtimeSafTreeUri;
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

  Future<void> _revertSafTest({required UserSettingsData? settings}) async {
    final messenger = ScaffoldMessenger.of(context);
    final treeUri =
        settings?.safTreeUri ?? SimpleSheetPersistenceService.runtimeSafTreeUri;
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
