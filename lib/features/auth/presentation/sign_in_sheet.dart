import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/data/di/service_locator.dart';
import '../../../core/data/services/auth_service.dart';

enum _AuthStep { signIn, register, verifyEmail }

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
    } on AuthServiceException catch (error) {
      setState(() => _errorText = _readableAuthError(error));
    } catch (_) {
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
    } on AuthServiceException catch (error) {
      setState(() => _errorText = _readableAuthError(error));
    } catch (_) {
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

    try {
      await ServiceLocator.authService.sendEmailVerification();
    } catch (_) {
      // Keep flow available even if default Firebase verification mail fails.
    }

    String? code;
    if (issueNewCode) {
      code = await ServiceLocator.dbService.issueEmailVerificationCode(
        uid: session.uid,
      );
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
      final isValid = await ServiceLocator.dbService.verifyEmailCode(
        uid: uid,
        inputCode: code,
      );

      if (!isValid) {
        setState(() => _errorText = 'Code is invalid or expired.');
        return;
      }

      await ServiceLocator.dbService.markEmailVerified(uid: uid);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
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
    } catch (_) {
      setState(() => _errorText = 'Could not resend code.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
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
                        }),
                  child: const Text('Create account'),
                ),
              if (_step == _AuthStep.register)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _step = _AuthStep.signIn;
                          _errorText = null;
                        }),
                  child: const Text('I already have an account'),
                ),
              if (_step == _AuthStep.verifyEmail)
                TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Resend code'),
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
    }
  }

  String _readableAuthError(AuthServiceException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email address format is invalid.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
}
