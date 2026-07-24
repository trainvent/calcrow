import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:calcrow/app/presentation/web_link_opener_stub.dart'
    if (dart.library.html) 'package:calcrow/app/presentation/web_link_opener_web.dart';
import 'package:calcrow/core/constants/internal_constants.dart';
import 'package:calcrow/core/data/services/auth_service.dart';
import 'package:calcrow/core/providers/app_providers.dart';

enum _AuthStep {
  signIn,
  register,
  verifyEmail,
  forgotPassword,
  resetPasswordConfirm,
}

typedef _LocalizedText = String Function(AppLocalizations localizations);

Future<T?> showSignInSheet<T>(BuildContext context) {
  return showGeneralDialog<T>(
    context: context,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _AuthSheetRoute();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class SignInSheet extends ConsumerStatefulWidget {
  const SignInSheet({super.key});

  @override
  ConsumerState<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<SignInSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _resetPasswordController =
      TextEditingController();
  final TextEditingController _resetConfirmPasswordController =
      TextEditingController();

  _AuthStep _step = _AuthStep.signIn;
  bool _isLoading = false;
  _LocalizedText? _errorText;
  String? _pendingUid;
  String? _pendingEmail;
  String? _debugCode;
  bool _isUsingLocalDebugVerification = false;
  bool _acceptedLegalTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = (l10n) => l10n.emailAndPasswordAreRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = await ref
          .read(authServiceProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      await ref
          .read(dbServiceProvider)
          .createUserIfMissing(uid: session.uid, email: session.email);
      // Sign-in should not trigger onboarding verification again.
      // Keep legacy users unblocked by setting our app-level verified flag.
      await ref.read(dbServiceProvider).markEmailVerified(uid: session.uid);
      TextInput.finishAutofillContext(shouldSave: true);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = _readableAuthError(error));
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = (l10n) => l10n.couldNotSignInRightNow);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(
        () =>
            _errorText = (l10n) => l10n.emailPasswordAndConfirmationAreRequired,
      );
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = (l10n) => l10n.passwordsDoNotMatch);
      return;
    }
    if (password.length < 6) {
      setState(
        () => _errorText = (l10n) => l10n.passwordMustBeAtLeast6Characters,
      );
      return;
    }
    if (!_acceptedLegalTerms) {
      setState(
        () => _errorText = (l10n) => l10n
            .acceptTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicyToCreateAnAccount,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = await ref
          .read(authServiceProvider)
          .registerWithEmailAndPassword(email: email, password: password);
      await ref
          .read(dbServiceProvider)
          .createUserIfMissing(uid: session.uid, email: session.email);
      TextInput.finishAutofillContext(shouldSave: true);

      await _startVerificationFlow(session: session, issueNewCode: true);
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(() => _errorText = _readableAuthError(error));
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(
        () => _errorText = (l10n) => l10n.couldNotCreateYourAccountRightNow,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startVerificationFlow({
    required AuthSession session,
    required bool issueNewCode,
  }) async {
    _pendingUid = session.uid;
    _pendingEmail = session.email;

    String? code;
    if (issueNewCode) {
      try {
        await ref.read(authServiceProvider).sendEmailVerificationCode();
        _isUsingLocalDebugVerification = false;
      } catch (error, stackTrace) {
        _reportError('Send verification code failed', error, stackTrace);
        if (!kDebugMode) rethrow;
        code = await ref
            .read(dbServiceProvider)
            .issueEmailVerificationCode(uid: session.uid);
        _isUsingLocalDebugVerification = true;
      }
    }

    if (!mounted) return;

    setState(() {
      _step = _AuthStep.verifyEmail;
      _errorText = null;
      _debugCode = kDebugMode ? code : null;
      _codeController.clear();
    });
  }

  Future<void> _verifyCode() async {
    if (_isLoading) return;

    final uid = _pendingUid;
    final code = _codeController.text.trim();
    if (uid == null) {
      setState(
        () => _errorText = (l10n) => l10n.missingVerificationContextSignInAgain,
      );
      return;
    }
    if (code.length != 6) {
      setState(() => _errorText = (l10n) => l10n.enterThe6DigitCode);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (_isUsingLocalDebugVerification) {
        final isValid = await ref
            .read(dbServiceProvider)
            .verifyEmailCode(uid: uid, inputCode: code);

        if (!isValid) {
          setState(() => _errorText = (l10n) => l10n.codeIsInvalidOrExpired);
          return;
        }
      } else {
        await ref.read(authServiceProvider).verifyEmailCode(code: code);
      }

      await ref.read(dbServiceProvider).markEmailVerified(uid: uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Verify code failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Verify code failed', error, stackTrace);
      setState(() => _errorText = (l10n) => l10n.couldNotVerifyCodeRightNow);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isLoading) return;

    final uid = _pendingUid;
    final email = _pendingEmail;
    if (uid == null || email == null) {
      setState(
        () => _errorText = (l10n) => l10n.missingVerificationContextSignInAgain,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = ref.read(authServiceProvider).currentSession;
      if (session == null) {
        throw const AuthServiceException(code: 'user-not-found');
      }
      await _startVerificationFlow(session: session, issueNewCode: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.verificationCodeReissued)),
      );
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Resend code failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Resend code failed', error, stackTrace);
      setState(() => _errorText = (l10n) => l10n.couldNotResendCode);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordResetCode() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = (l10n) => l10n.emailIsRequired);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordResetCode(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.passwordResetCodeSentTo(email))),
      );
      setState(() {
        _step = _AuthStep.resetPasswordConfirm;
        _codeController.clear();
        _resetPasswordController.clear();
        _resetConfirmPasswordController.clear();
      });
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Password reset code failed', error, stackTrace);
      setState(() => _errorText = _readablePasswordResetError(error));
    } catch (error, stackTrace) {
      _reportError('Password reset code failed', error, stackTrace);
      setState(() => _errorText = (l10n) => l10n.couldNotSendPasswordResetCode);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmPasswordReset() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _resetPasswordController.text.trim();
    final confirmPassword = _resetConfirmPasswordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorText = (l10n) => l10n.emailIsRequired);
      return;
    }
    if (code.length != 6) {
      setState(() => _errorText = (l10n) => l10n.enterThe6DigitCode);
      return;
    }
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(
        () => _errorText = (l10n) => l10n.newPasswordAndConfirmationAreRequired,
      );
      return;
    }
    if (newPassword.length < 6) {
      setState(
        () => _errorText = (l10n) => l10n.passwordMustBeAtLeast6Characters,
      );
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = (l10n) => l10n.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .resetPasswordWithCode(
            email: email,
            code: code,
            newPassword: newPassword,
          );
      TextInput.finishAutofillContext(shouldSave: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.passwordUpdatedYouCanSignInNow)),
      );
      setState(() {
        _step = _AuthStep.signIn;
        _codeController.clear();
        _resetPasswordController.clear();
        _resetConfirmPasswordController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Password reset confirm failed', error, stackTrace);
      setState(() => _errorText = _readablePasswordResetError(error));
    } catch (error, stackTrace) {
      _reportError('Password reset confirm failed', error, stackTrace);
      setState(() => _errorText = (l10n) => l10n.couldNotResetPasswordRightNow);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForStep(context.l10n),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitleForStep(context.l10n),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                if (_step != _AuthStep.verifyEmail) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    decoration: InputDecoration(labelText: context.l10n.email),
                  ),
                  if (_step != _AuthStep.forgotPassword &&
                      _step != _AuthStep.resetPasswordConfirm) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: _step == _AuthStep.register
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: context.l10n.password,
                      ),
                    ),
                  ],
                ],
                if (_step == _AuthStep.register) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.l10n.confirmPassword,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LegalAgreementControl(
                    value: _acceptedLegalTerms,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _acceptedLegalTerms = value ?? false;
                              if (_acceptedLegalTerms && _errorText != null) {
                                _errorText = null;
                              }
                            });
                          },
                  ),
                ],
                if (_step == _AuthStep.verifyEmail) ...[
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: context.l10n.message6DigitCode,
                      hintText: _pendingEmail == null
                          ? null
                          : context.l10n.sentTo(_pendingEmail!),
                    ),
                  ),
                  if (kDebugMode && _debugCode != null)
                    Text(
                      context.l10n.debugCode(_debugCode!),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                if (_step == _AuthStep.resetPasswordConfirm) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: context.l10n.message6DigitCode,
                      hintText: context.l10n.sentTo(
                        _emailController.text.trim(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _resetPasswordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.l10n.newPassword,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _resetConfirmPasswordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: context.l10n.confirmNewPassword,
                    ),
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!(context.l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : switch (_step) {
                            _AuthStep.signIn => _signIn,
                            _AuthStep.register => _register,
                            _AuthStep.verifyEmail => _verifyCode,
                            _AuthStep.forgotPassword => _sendPasswordResetCode,
                            _AuthStep.resetPasswordConfirm =>
                              _confirmPasswordReset,
                          },
                    child: Text(_primaryButtonLabel(context.l10n)),
                  ),
                ),
                const SizedBox(height: 8),
                if (_step == _AuthStep.signIn)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _step = _AuthStep.register;
                            _errorText = null;
                            _debugCode = null;
                            _codeController.clear();
                          }),
                    child: Text(context.l10n.createAccount),
                  ),
                if (_step == _AuthStep.signIn)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _step = _AuthStep.forgotPassword;
                            _errorText = null;
                            _codeController.clear();
                            _debugCode = null;
                            _resetPasswordController.clear();
                            _resetConfirmPasswordController.clear();
                          }),
                    child: Text(context.l10n.forgotPassword),
                  ),
                if (_step == _AuthStep.register)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _step = _AuthStep.signIn;
                            _errorText = null;
                            _debugCode = null;
                            _codeController.clear();
                            _acceptedLegalTerms = false;
                          }),
                    child: Text(context.l10n.iAlreadyHaveAnAccount),
                  ),
                if (_step == _AuthStep.verifyEmail)
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: Text(context.l10n.resendCode),
                  ),
                if (_step == _AuthStep.resetPasswordConfirm)
                  TextButton(
                    onPressed: _isLoading ? null : _sendPasswordResetCode,
                    child: Text(context.l10n.resendCode),
                  ),
                if (_step == _AuthStep.forgotPassword ||
                    _step == _AuthStep.resetPasswordConfirm)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _step = _AuthStep.signIn;
                            _errorText = null;
                            _debugCode = null;
                            _codeController.clear();
                            _resetPasswordController.clear();
                            _resetConfirmPasswordController.clear();
                          }),
                    child: Text(context.l10n.backToSignIn),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep(AppLocalizations localizations) {
    switch (_step) {
      case _AuthStep.signIn:
        return localizations.signIn;
      case _AuthStep.register:
        return localizations.createAccount;
      case _AuthStep.verifyEmail:
        return localizations.verifyEmail;
      case _AuthStep.forgotPassword:
      case _AuthStep.resetPasswordConfirm:
        return localizations.resetPassword;
    }
  }

  String _subtitleForStep(AppLocalizations localizations) {
    switch (_step) {
      case _AuthStep.signIn:
        return localizations.useYourEmailAndPassword;
      case _AuthStep.register:
        return localizations.createYourAccountAndContinueToSetup;
      case _AuthStep.verifyEmail:
        return localizations.enterThe6DigitVerificationCode;
      case _AuthStep.forgotPassword:
        return localizations.weWillSendA6DigitPasswordResetCodeToYourEmail;
      case _AuthStep.resetPasswordConfirm:
        return localizations.enterTheCodeFromYourEmailAndChooseANewPassword;
    }
  }

  String _primaryButtonLabel(AppLocalizations localizations) {
    switch (_step) {
      case _AuthStep.signIn:
        return localizations.signIn;
      case _AuthStep.register:
        return localizations.register;
      case _AuthStep.verifyEmail:
        return localizations.verify;
      case _AuthStep.forgotPassword:
        return localizations.sendResetCode;
      case _AuthStep.resetPasswordConfirm:
        return localizations.setNewPassword;
    }
  }

  _LocalizedText _readablePasswordResetError(AuthServiceException error) {
    switch (error.code) {
      case 'user-not-found':
        return (l10n) => l10n.noAccountFoundForThatEmail;
      case 'not-found':
        return (l10n) => l10n.noActiveResetCodeWasFoundRequestANewOne;
      case 'failed-precondition':
        return (l10n) => l10n.thatResetCodeIsNoLongerValidRequestANewOne;
      default:
        return _readableAuthError(error);
    }
  }

  _LocalizedText _readableAuthError(AuthServiceException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return (l10n) => l10n.emailPasswordAuthIsDisabledInFirebaseAuthSettings;
      case 'unauthorized-domain':
        return (l10n) => l10n.thisDomainIsNotAuthorizedForFirebaseAuth;
      case 'admin-restricted-operation':
        return (l10n) =>
            l10n.thisAuthOperationIsRestrictedByFirebaseProjectSettings;
      case 'invalid-api-key':
      case 'app-not-authorized':
        return (l10n) => l10n.firebaseWebConfigIsInvalidForThisAppEnvironment;
      case 'internal-error':
      case 'unknown':
        return (l10n) => l10n.authSetupIssue(error.code);
      case 'network-request-failed':
        return (l10n) => l10n.networkErrorCheckConnectionAndTryAgain;
      case 'unauthenticated':
        return (l10n) => l10n.yourSessionExpiredSignInAgainAndRequestANewCode;
      case 'not-found':
        return (l10n) => l10n.noActiveCodeWasFoundRequestANewCode;
      case 'deadline-exceeded':
        return (l10n) => l10n.thatCodeHasExpiredRequestANewOne;
      case 'resource-exhausted':
        return (l10n) => l10n.tooManyFailedAttemptsRequestANewCode;
      case 'invalid-email':
        return (l10n) => l10n.emailAddressFormatIsInvalid;
      case 'email-already-in-use':
        return (l10n) => l10n.thisEmailIsAlreadyInUse;
      case 'invalid-argument':
        return (l10n) => l10n.theCodeWasNotAcceptedCheckItAndTryAgain;
      case 'weak-password':
        return (l10n) => l10n.passwordIsTooWeak;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return (l10n) => l10n.emailOrPasswordIsIncorrect;
      case 'too-many-requests':
        return (l10n) => l10n.tooManyAttemptsTryAgainLater;
      default:
        return (l10n) => l10n.authenticationFailedWithCode(error.code);
    }
  }

  _LocalizedText _readableFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return (l10n) => l10n.permissionDeniedByFirestoreRules;
      case 'unavailable':
        return (l10n) => l10n.serviceTemporarilyUnavailableTryAgain;
      case 'network-request-failed':
        return (l10n) => l10n.networkErrorCheckConnectionAndTryAgain;
      default:
        return (l10n) => l10n.requestFailedWithCode(error.code);
    }
  }

  void _reportError(String context, Object error, StackTrace stackTrace) {
    final diagnostics = _diagnosticsForError(error);
    developer.log(
      '$context: $diagnostics',
      name: 'calcrow.auth',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('$context: $diagnostics');
    debugPrintStack(stackTrace: stackTrace);
  }

  String _diagnosticsForError(Object error) {
    if (error is AuthServiceException) {
      final message = error.message?.trim();
      if (message == null || message.isEmpty) {
        return 'AuthServiceException(code: ${error.code})';
      }
      return 'AuthServiceException(code: ${error.code}, message: $message)';
    }
    if (error is FirebaseException) {
      final message = error.message?.trim();
      if (message == null || message.isEmpty) {
        return 'FirebaseException(plugin: ${error.plugin}, code: ${error.code})';
      }
      return 'FirebaseException(plugin: ${error.plugin}, code: ${error.code}, message: $message)';
    }
    return error.toString();
  }
}

class _LegalAgreementControl extends StatelessWidget {
  const _LegalAgreementControl({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: value,
              onChanged: onChanged,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                context
                    .l10n
                    .iAgreeToTheTermsOfUsePrivacyPolicyAndAdsPrivacyPolicy,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => openExternalUrl(IConst.termsOfUseUrl),
                    child: Text(context.l10n.termsOfUse),
                  ),
                  TextButton(
                    onPressed: () => openExternalUrl(IConst.privacyPolicyUrl),
                    child: Text(context.l10n.privacyPolicy),
                  ),
                  TextButton(
                    onPressed: () =>
                        openExternalUrl(IConst.privacyPolicyAdsUrl),
                    child: Text(context.l10n.adsPrivacy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSheetRoute extends StatelessWidget {
  const _AuthSheetRoute();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.top - 24;

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: max(320, availableHeight),
                ),
                child: GestureDetector(
                  onTap: () {},
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 14,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: const SignInSheet(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
