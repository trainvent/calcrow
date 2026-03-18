import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthServiceException implements Exception {
  const AuthServiceException({required this.code, this.message});

  final String code;
  final String? message;
}

class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final bool emailVerified;
}

class AuthService {
  AuthService(this._auth, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<AuthSession?> authStateChanges() {
    return _auth.authStateChanges().map(_toSession);
  }

  AuthSession? get currentSession => _toSession(_auth.currentUser);

  Future<AuthSession> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final session = _toSession(credential.user);
      if (session == null) {
        throw const AuthServiceException(
          code: 'user-not-found',
          message: 'Registration completed without user context.',
        );
      }
      return session;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<AuthSession> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final session = _toSession(credential.user);
      if (session == null) {
        throw const AuthServiceException(
          code: 'user-not-found',
          message: 'Sign in completed without user context.',
        );
      }
      return session;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException(
        code: 'user-not-found',
        message: 'No signed in user found.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> sendEmailVerificationCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException(
        code: 'user-not-found',
        message: 'No signed in user found.',
      );
    }

    try {
      await _functions.httpsCallable('sendVerificationCode').call();
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> verifyEmailCode({required String code}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException(
        code: 'user-not-found',
        message: 'No signed in user found.',
      );
    }

    try {
      await _functions.httpsCallable('verifyCode').call({'code': code});
      await user.reload();
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordResetCode({required String email}) async {
    try {
      await _functions.httpsCallable('sendPasswordResetCode').call({
        'email': email,
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw const AuthServiceException(
          code: 'user-not-found',
          message: 'No user found with this email.',
        );
      }
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _functions.httpsCallable('resetPasswordWithCode').call({
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw const AuthServiceException(
          code: 'user-not-found',
          message: 'No user found with this email.',
        );
      }
      throw AuthServiceException(code: error.code, message: error.message);
    }
  }

  Future<void> signOut() => _auth.signOut();

  AuthSession? _toSession(User? user) {
    if (user == null) return null;
    return AuthSession(
      uid: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
    );
  }
}
