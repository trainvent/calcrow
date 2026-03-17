import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/data/di/service_locator.dart';
import '../../../core/data/services/auth_service.dart';

enum _AuthStep { signIn, register, verifyEmail, forgotPassword }

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

class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key});

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  _AuthStep _step = _AuthStep.signIn;
  bool _isLoading = false;
  String? _errorText;
  String? _pendingUid;
  String? _pendingEmail;
  String? _debugCode;
  bool _isUsingLocalDebugVerification = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Email and password are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = await ServiceLocator.authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await ServiceLocator.dbService.createUserIfMissing(
        uid: session.uid,
        email: session.email,
      );

      final firestoreVerified = await ServiceLocator.dbService
          .isUserEmailVerified(session.uid);
      if (session.emailVerified || firestoreVerified) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      await _startVerificationFlow(session: session, issueNewCode: true);
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = _readableAuthError(error));
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Sign in failed', error, stackTrace);
      setState(() => _errorText = 'Could not sign in right now.');
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
      setState(() => _errorText = 'Email, password and confirmation are required.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = await ServiceLocator.authService
          .registerWithEmailAndPassword(email: email, password: password);
      await ServiceLocator.dbService.createUserIfMissing(
        uid: session.uid,
        email: session.email,
      );

      await _startVerificationFlow(session: session, issueNewCode: true);
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(() => _errorText = _readableAuthError(error));
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Register failed', error, stackTrace);
      setState(() => _errorText = 'Could not create your account right now.');
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
        await ServiceLocator.authService.sendEmailVerificationCode();
        _isUsingLocalDebugVerification = false;
      } catch (error, stackTrace) {
        _reportError('Send verification code failed', error, stackTrace);
        if (!kDebugMode) rethrow;
        code = await ServiceLocator.dbService.issueEmailVerificationCode(
          uid: session.uid,
        );
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
      setState(() => _errorText = 'Missing verification context. Sign in again.');
      return;
    }
    if (code.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (_isUsingLocalDebugVerification) {
        final isValid = await ServiceLocator.dbService.verifyEmailCode(
          uid: uid,
          inputCode: code,
        );

        if (!isValid) {
          setState(() => _errorText = 'Code is invalid or expired.');
          return;
        }
      } else {
        await ServiceLocator.authService.verifyEmailCode(code: code);
      }

      await ServiceLocator.dbService.markEmailVerified(uid: uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Verify code failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Verify code failed', error, stackTrace);
      setState(() => _errorText = 'Could not verify code right now.');
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
      setState(() => _errorText = 'Missing verification context. Sign in again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final session = ServiceLocator.authService.currentSession;
      if (session == null) {
        throw const AuthServiceException(code: 'user-not-found');
      }
      await _startVerificationFlow(session: session, issueNewCode: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code reissued.')),
      );
    } on FirebaseException catch (error, stackTrace) {
      _reportError('Resend code failed', error, stackTrace);
      setState(() => _errorText = _readableFirebaseError(error));
    } catch (error, stackTrace) {
      _reportError('Resend code failed', error, stackTrace);
      setState(() => _errorText = 'Could not resend code.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Email is required.');
      return;
    }

    if (kDebugMode) {
      final inputCode = _codeController.text.trim();
      if (inputCode.length != 6) {
        setState(() => _errorText = 'Enter the 6-digit code.');
        return;
      }
      if (_debugCode == null || inputCode != _debugCode) {
        setState(() => _errorText = 'Code is invalid or expired.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ServiceLocator.authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
      setState(() {
        _step = _AuthStep.signIn;
        _debugCode = null;
        _codeController.clear();
      });
    } on AuthServiceException catch (error, stackTrace) {
      _reportError('Password reset failed', error, stackTrace);
      setState(() => _errorText = _readableAuthError(error));
    } catch (error, stackTrace) {
      _reportError('Password reset failed', error, stackTrace);
      setState(() => _errorText = 'Could not send password reset email.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _newDebugSixDigitCode() {
    final random = Random.secure();
    final value = random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titleForStep, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(_subtitleForStep, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 18),
              if (_step != _AuthStep.verifyEmail) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                if (_step != _AuthStep.forgotPassword) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
              ],
              if (_step == _AuthStep.register) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Confirm password'),
                ),
              ],
              if (_step == _AuthStep.verifyEmail) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-digit code',
                    hintText: _pendingEmail == null
                        ? null
                        : 'Sent to $_pendingEmail',
                  ),
                ),
                if (kDebugMode && _debugCode != null)
                  Text(
                    'Debug code: $_debugCode',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
              if (_step == _AuthStep.forgotPassword && kDebugMode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    hintText: 'Use the debug code below',
                  ),
                ),
                if (_debugCode != null)
                  Text(
                    'Debug code: $_debugCode',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
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
                          _AuthStep.forgotPassword => _sendPasswordReset,
                        },
                  child: Text(_primaryButtonLabel),
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
                  child: const Text('Create account'),
                ),
              if (_step == _AuthStep.signIn)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _step = _AuthStep.forgotPassword;
                          _errorText = null;
                          _codeController.clear();
                          _debugCode = kDebugMode ? _newDebugSixDigitCode() : null;
                        }),
                  child: const Text('Forgot password?'),
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
                        }),
                  child: const Text('I already have an account'),
                ),
              if (_step == _AuthStep.verifyEmail)
                TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Resend code'),
                ),
              if (_step == _AuthStep.forgotPassword)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _step = _AuthStep.signIn;
                          _errorText = null;
                          _debugCode = null;
                          _codeController.clear();
                        }),
                  child: const Text('Back to sign in'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _titleForStep {
    switch (_step) {
      case _AuthStep.signIn:
        return 'Sign in';
      case _AuthStep.register:
        return 'Create account';
      case _AuthStep.verifyEmail:
        return 'Verify email';
      case _AuthStep.forgotPassword:
        return 'Reset password';
    }
  }

  String get _subtitleForStep {
    switch (_step) {
      case _AuthStep.signIn:
        return 'Use your email and password.';
      case _AuthStep.register:
        return 'Create your account and continue to setup.';
      case _AuthStep.verifyEmail:
        return 'Enter the 6-digit verification code.';
      case _AuthStep.forgotPassword:
        return kDebugMode
            ? 'Use your debug 6-digit code, then we will send a reset link.'
            : 'We will send a password reset link to your email.';
    }
  }

  String get _primaryButtonLabel {
    switch (_step) {
      case _AuthStep.signIn:
        return 'Sign in';
      case _AuthStep.register:
        return 'Register';
      case _AuthStep.verifyEmail:
        return 'Verify';
      case _AuthStep.forgotPassword:
        return 'Send reset email';
    }
  }

  String _readableAuthError(AuthServiceException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Email/password auth is disabled in Firebase Auth settings.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for Firebase Auth.';
      case 'admin-restricted-operation':
        return 'This auth operation is restricted by Firebase project settings.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'Firebase web config is invalid for this app/environment.';
      case 'internal-error':
      case 'unknown':
        return 'Auth setup issue (${error.code}). Check Firebase Auth provider and authorized domains.';
      case 'network-request-failed':
        return 'Network error. Check connection and try again.';
      case 'unauthenticated':
        return 'Your session expired. Sign in again and request a new code.';
      case 'not-found':
        return 'No active code was found. Request a new code.';
      case 'deadline-exceeded':
        return 'That code has expired. Request a new one.';
      case 'resource-exhausted':
        return 'Too many failed attempts. Request a new code.';
      case 'invalid-email':
        return 'Email address format is invalid.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-argument':
        return 'The code was not accepted. Check it and try again.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        final message = error.message?.trim();
        if (message == null || message.isEmpty || message.toLowerCase() == 'error') {
          return 'Authentication failed (${error.code}).';
        }
        return '$message (${error.code})';
    }
  }

  String _readableFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied by Firestore rules.';
      case 'unavailable':
        return 'Service temporarily unavailable. Try again.';
      case 'network-request-failed':
        return 'Network error. Check connection and try again.';
      default:
        final message = error.message?.trim();
        if (message == null || message.isEmpty || message.toLowerCase() == 'error') {
          return 'Request failed (${error.code}).';
        }
        return '$message (${error.code})';
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
