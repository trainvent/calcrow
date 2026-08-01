import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calcrow/core/data/services/auth_service.dart';
import 'package:calcrow/core/data/services/google_drive_auth_service.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:calcrow/l10n/app_localizations.dart';

import 'google_continue_button.dart';

enum AuthEntryChoice { signIn, register, google }

Future<AuthEntryChoice?> showAuthChoiceSheet(BuildContext context) {
  return showModalBottomSheet<AuthEntryChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const AuthChoiceSheet(),
  );
}

class AuthChoiceSheet extends ConsumerStatefulWidget {
  const AuthChoiceSheet({super.key});

  @override
  ConsumerState<AuthChoiceSheet> createState() => _AuthChoiceSheetState();
}

class _AuthChoiceSheetState extends ConsumerState<AuthChoiceSheet> {
  StreamSubscription<GoogleIdentitySignInResult>? _googleIdentitySubscription;
  bool _isContinuingWithGoogle = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleIdentitySubscription = ref
          .read(googleDriveAuthServiceProvider)
          .identitySignIns()
          .listen(
            (identity) => unawaited(_runGoogleFlow(identity)),
            onError: (_) {
              if (mounted) {
                setState(
                  () => _errorText = context.l10n.couldNotContinueWithGoogle,
                );
              }
            },
          );
    }
  }

  @override
  void dispose() {
    unawaited(_googleIdentitySubscription?.cancel());
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (_isContinuingWithGoogle) return;
    try {
      final identity = await ref
          .read(googleDriveAuthServiceProvider)
          .signInForIdentity();
      await _runGoogleFlow(identity);
    } on GoogleDriveAuthException catch (error) {
      if (!mounted || error.message == 'google-sign-in-canceled') return;
      setState(() => _errorText = context.l10n.couldNotContinueWithGoogle);
    }
  }

  Future<void> _runGoogleFlow(GoogleIdentitySignInResult identity) async {
    if (_isContinuingWithGoogle) return;
    final googleAuth = ref.read(googleDriveAuthServiceProvider);
    final auth = ref.read(authServiceProvider);
    final database = ref.read(dbServiceProvider);
    final users = ref.read(userRepositoryProvider);
    setState(() {
      _isContinuingWithGoogle = true;
      _errorText = null;
    });

    try {
      final wantsDrive = await _askForDriveAccess(identity.email);
      GoogleDriveLinkResult? driveLink;
      if (wantsDrive == true) {
        try {
          driveLink = await googleAuth.linkAccount();
        } on GoogleDriveAuthException {
          if (!mounted) return;
          final continueWithoutDrive = await _askToContinueWithoutDrive();
          if (continueWithoutDrive != true) return;
        }
      }

      final session = await auth.signInWithGoogleCredential(
        idToken: identity.idToken,
        accessToken: identity.accessToken,
      );
      await database.createUserIfMissing(
        uid: session.uid,
        email: session.email,
      );
      await database.markEmailVerified(uid: session.uid);
      if (driveLink != null) {
        await users.setGoogleDriveLinked(
          uid: session.uid,
          email: driveLink.email,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(AuthEntryChoice.google);
    } on GoogleDriveAuthException catch (error) {
      if (!mounted) return;
      if (error.message != 'google-sign-in-canceled') {
        setState(() => _errorText = context.l10n.couldNotContinueWithGoogle);
      }
    } on AuthServiceException {
      if (!mounted) return;
      setState(() => _errorText = context.l10n.couldNotContinueWithGoogle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = context.l10n.couldNotContinueWithGoogle);
    } finally {
      if (mounted) setState(() => _isContinuingWithGoogle = false);
    }
  }

  Future<bool?> _askForDriveAccess(String email) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.useGoogleDriveWithThisAccount),
        content: Text(context.l10n.googleDriveAccessPrompt(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.notNow),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.add_to_drive_outlined),
            label: Text(context.l10n.enableGoogleDrive),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askToContinueWithoutDrive() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.googleDriveWasNotConnected),
        content: Text(context.l10n.googleDriveCanBeEnabledLater),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.back),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.continueWithoutDrive),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.continueToCalcrow,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.chooseHowYouWantToAccessYourAccount,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isContinuingWithGoogle
                    ? null
                    : () => Navigator.of(context).pop(AuthEntryChoice.signIn),
                child: Text(context.l10n.login),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isContinuingWithGoogle
                    ? null
                    : () => Navigator.of(context).pop(AuthEntryChoice.register),
                child: Text(context.l10n.register),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(context.l10n.or),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              GoogleContinueButton(
                isLoading: _isContinuingWithGoogle,
                label: context.l10n.continueWithGoogle,
                locale: Localizations.localeOf(context).toLanguageTag(),
                onPressed: _continueWithGoogle,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.googleSignInTermsNotice,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
