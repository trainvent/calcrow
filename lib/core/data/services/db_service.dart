import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class DbService {
  DbService(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const String _verificationCollection = 'email_verification_codes';

  Future<void> createUserIfMissing({
    required String uid,
    required String email,
  }) async {
    final userRef = _firestore.collection(_usersCollection).doc(uid);
    final snapshot = await userRef.get();
    if (snapshot.exists) return;

    await userRef.set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'settings': {
        'defaultDateFormat': 'YYYY-MM-DD',
      },
    });
  }

  Future<void> markEmailVerified({required String uid}) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'emailVerified': true,
      'emailVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isUserEmailVerified(String uid) async {
    final snapshot = await _firestore.collection(_usersCollection).doc(uid).get();
    final data = snapshot.data();
    if (data == null) return false;
    final verified = data['emailVerified'];
    return verified is bool ? verified : false;
  }

  Stream<bool> watchUserEmailVerified(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return false;
      final verified = data['emailVerified'];
      return verified is bool ? verified : false;
    });
  }

  Stream<Map<String, dynamic>?> watchUserSettings(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final settings = data['settings'];
      if (settings is Map<String, dynamic>) return settings;
      return null;
    });
  }

  Future<Map<String, dynamic>?> getUserSettings(String uid) async {
    final snapshot = await _firestore.collection(_usersCollection).doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    final settings = data['settings'];
    if (settings is Map<String, dynamic>) return settings;
    return null;
  }

  Future<void> setGoogleDriveLink({
    required String uid,
    required String email,
  }) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'googleDriveLinked': true,
        'googleDriveEmail': email,
        'googleDriveLinkedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearGoogleDriveLink({required String uid}) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'googleDriveLinked': false,
        'googleDriveEmail': FieldValue.delete(),
        'googleDriveLinkedAt': FieldValue.delete(),
        'googleDriveSyncFileId': FieldValue.delete(),
        'googleDriveSyncFileName': FieldValue.delete(),
        'googleDriveSyncMimeType': FieldValue.delete(),
        'googleDriveLastSyncedAt': FieldValue.delete(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setGoogleDriveSyncFile({
    required String uid,
    required String fileId,
    required String fileName,
    required String mimeType,
  }) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'googleDriveSyncFileId': fileId,
        'googleDriveSyncFileName': fileName,
        'googleDriveSyncMimeType': mimeType,
        'googleDriveLastSyncedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setSafFolderUri({
    required String uid,
    required String treeUri,
  }) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'safTreeUri': treeUri,
        'safTreeUpdatedAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearSafFolderUri({required String uid}) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'safTreeUri': FieldValue.delete(),
        'safTreeUpdatedAt': FieldValue.delete(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> issueEmailVerificationCode({required String uid}) async {
    final code = _randomSixDigitCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    await _firestore.collection(_verificationCollection).doc(uid).set({
      'code': code,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  Future<bool> verifyEmailCode({
    required String uid,
    required String inputCode,
  }) async {
    final ref = _firestore.collection(_verificationCollection).doc(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return false;

    final code = data['code'];
    final expiresAt = data['expiresAt'];
    if (code is! String || expiresAt is! Timestamp) return false;
    if (expiresAt.toDate().isBefore(DateTime.now())) return false;
    if (code != inputCode) return false;

    await ref.delete();
    return true;
  }

  String _randomSixDigitCode() {
    final random = Random.secure();
    final value = random.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }
}
