import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/data/di/service_locator.dart';
import '../../../../core/data/services/auth_service.dart';
import '../../../../core/data/services/google_drive_auth_service.dart';
import '../../../../core/data/services/google_drive_sync_service.dart';
import '../../../auth/presentation/sign_in_sheet.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isLinkingGoogle = false;

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

  Future<void> _openSignInSheet(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const SignInSheet(),
    );
  }
}
