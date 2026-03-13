import 'package:firebase_auth/firebase_auth.dart';

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
  AuthService(this._auth);

  final FirebaseAuth _auth;

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

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
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
