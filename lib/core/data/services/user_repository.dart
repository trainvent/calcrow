import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'db_service.dart';

class UserSettingsData {
  const UserSettingsData({
    this.defaultDateFormat = 'YYYY-MM-DD',
    this.advancedFeaturesEnabled = false,
    this.isPro = false,
    this.googleDriveLinked = false,
    this.googleDriveEmail,
    this.googleDriveSyncFileId,
    this.googleDriveSyncFileName,
    this.googleDriveSyncMimeType,
    this.safTreeUri,
  });

  final String defaultDateFormat;
  final bool advancedFeaturesEnabled;
  final bool isPro;
  final bool googleDriveLinked;
  final String? googleDriveEmail;
  final String? googleDriveSyncFileId;
  final String? googleDriveSyncFileName;
  final String? googleDriveSyncMimeType;
  final String? safTreeUri;

  factory UserSettingsData.fromMap(Map<String, dynamic>? map) {
    final settings = map ?? const <String, dynamic>{};
    return UserSettingsData(
      defaultDateFormat:
          (settings['defaultDateFormat'] as String?)?.trim().isNotEmpty == true
          ? (settings['defaultDateFormat'] as String).trim()
          : 'YYYY-MM-DD',
      advancedFeaturesEnabled: settings['advancedFeaturesEnabled'] == true,
      isPro: settings['isPro'] == true,
      googleDriveLinked: settings['googleDriveLinked'] == true,
      googleDriveEmail: _readTrimmed(settings['googleDriveEmail']),
      googleDriveSyncFileId: _readTrimmed(settings['googleDriveSyncFileId']),
      googleDriveSyncFileName: _readTrimmed(
        settings['googleDriveSyncFileName'],
      ),
      googleDriveSyncMimeType: _readTrimmed(
        settings['googleDriveSyncMimeType'],
      ),
      safTreeUri: _readTrimmed(settings['safTreeUri']),
    );
  }

  static String? _readTrimmed(Object? value) {
    final text = (value as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class UserRepository {
  UserRepository({
    required AuthService authService,
    required DbService dbService,
    required FirebaseFirestore firestore,
  }) : _authService = authService,
       _dbService = dbService,
       _firestore = firestore;

  final AuthService _authService;
  final DbService _dbService;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  Stream<UserSettingsData?> watchCurrentUserSettings() {
    return _authService.authStateChanges().asyncExpand((session) {
      if (session == null) {
        return Stream<UserSettingsData?>.value(null);
      }
      return _dbService.watchUserSettings(
        session.uid,
      ).map(UserSettingsData.fromMap);
    });
  }

  Stream<UserSettingsData> watchUserSettings(String uid) {
    return _dbService.watchUserSettings(uid).map(UserSettingsData.fromMap);
  }

  Future<UserSettingsData?> getCurrentUserSettings() async {
    final session = _authService.currentSession;
    if (session == null) return null;
    final settings = await _dbService.getUserSettings(session.uid);
    return UserSettingsData.fromMap(settings);
  }

  Future<UserSettingsData> getUserSettings(String uid) async {
    final settings = await _dbService.getUserSettings(uid);
    return UserSettingsData.fromMap(settings);
  }

  Future<void> setAdvancedFeaturesEnabled({
    required String uid,
    required bool enabled,
  }) {
    return _dbService.setAdvancedFeaturesEnabled(uid: uid, enabled: enabled);
  }

  Future<void> setIsPro({
    required String uid,
    required bool isPro,
  }) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'isPro': isPro,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setGoogleDriveLinked({
    required String uid,
    required String email,
  }) {
    return _dbService.setGoogleDriveLink(uid: uid, email: email);
  }

  Future<void> clearGoogleDriveLinked({required String uid}) {
    return _dbService.clearGoogleDriveLink(uid: uid);
  }

  Future<void> setGoogleDriveSyncFile({
    required String uid,
    required String fileId,
    required String fileName,
    required String mimeType,
  }) {
    return _dbService.setGoogleDriveSyncFile(
      uid: uid,
      fileId: fileId,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<void> clearGoogleDriveSyncFile({required String uid}) {
    return _dbService.clearGoogleDriveSyncFile(uid: uid);
  }
}
