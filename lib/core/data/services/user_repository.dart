import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'db_service.dart';

enum CloudSyncProvider { googleDrive, webDav }

CloudSyncProvider? cloudSyncProviderFromSettings(Object? value) {
  switch ((value as String?)?.trim()) {
    case 'googleDrive':
      return CloudSyncProvider.googleDrive;
    case 'webDav':
      return CloudSyncProvider.webDav;
    default:
      return null;
  }
}

String cloudSyncProviderToSettings(CloudSyncProvider provider) {
  return switch (provider) {
    CloudSyncProvider.googleDrive => 'googleDrive',
    CloudSyncProvider.webDav => 'webDav',
  };
}

class UserSettingsData {
  const UserSettingsData({
    this.defaultDateFormat = 'YYYY-MM-DD',
    this.advancedFeaturesEnabled = false,
    this.isPro = false,
    this.cloudSyncProvider,
    this.googleDriveLinked = false,
    this.googleDriveEmail,
    this.googleDriveSyncFileId,
    this.googleDriveSyncFileName,
    this.googleDriveSyncMimeType,
    this.webDavLinked = false,
    this.webDavServerUrl,
    this.webDavUsername,
    this.webDavSyncFilePath,
    this.webDavSyncFileName,
    this.webDavSyncMimeType,
    this.safTreeUri,
  });

  final String defaultDateFormat;
  final bool advancedFeaturesEnabled;
  final bool isPro;
  final CloudSyncProvider? cloudSyncProvider;
  final bool googleDriveLinked;
  final String? googleDriveEmail;
  final String? googleDriveSyncFileId;
  final String? googleDriveSyncFileName;
  final String? googleDriveSyncMimeType;
  final bool webDavLinked;
  final String? webDavServerUrl;
  final String? webDavUsername;
  final String? webDavSyncFilePath;
  final String? webDavSyncFileName;
  final String? webDavSyncMimeType;
  final String? safTreeUri;

  factory UserSettingsData.fromMap(Map<String, dynamic>? map) {
    final settings = map ?? const <String, dynamic>{};
    final parsedCloudProvider = cloudSyncProviderFromSettings(
      settings['cloudSyncProvider'],
    );
    final googleDriveLinked = settings['googleDriveLinked'] == true;
    final webDavLinked = settings['webDavLinked'] == true;
    return UserSettingsData(
      defaultDateFormat:
          (settings['defaultDateFormat'] as String?)?.trim().isNotEmpty == true
          ? (settings['defaultDateFormat'] as String).trim()
          : 'YYYY-MM-DD',
      advancedFeaturesEnabled: settings['advancedFeaturesEnabled'] == true,
      isPro: settings['isPro'] == true,
      cloudSyncProvider:
          parsedCloudProvider ??
          (googleDriveLinked
              ? CloudSyncProvider.googleDrive
              : webDavLinked
              ? CloudSyncProvider.webDav
              : null),
      googleDriveLinked: googleDriveLinked,
      googleDriveEmail: _readTrimmed(settings['googleDriveEmail']),
      googleDriveSyncFileId: _readTrimmed(settings['googleDriveSyncFileId']),
      googleDriveSyncFileName: _readTrimmed(
        settings['googleDriveSyncFileName'],
      ),
      googleDriveSyncMimeType: _readTrimmed(
        settings['googleDriveSyncMimeType'],
      ),
      webDavLinked: webDavLinked,
      webDavServerUrl: _readTrimmed(settings['webDavServerUrl']),
      webDavUsername: _readTrimmed(settings['webDavUsername']),
      webDavSyncFilePath: _readTrimmed(settings['webDavSyncFilePath']),
      webDavSyncFileName: _readTrimmed(settings['webDavSyncFileName']),
      webDavSyncMimeType: _readTrimmed(settings['webDavSyncMimeType']),
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
      return _dbService
          .watchUserSettings(session.uid)
          .map(UserSettingsData.fromMap);
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

  Future<void> setIsPro({required String uid, required bool isPro}) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {'isPro': isPro},
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

  Future<void> setCloudSyncProvider({
    required String uid,
    required CloudSyncProvider provider,
  }) {
    return _dbService.setCloudSyncProvider(
      uid: uid,
      provider: cloudSyncProviderToSettings(provider),
    );
  }

  Future<void> setWebDavLinked({
    required String uid,
    required String serverUrl,
    required String username,
  }) {
    return _dbService.setWebDavLink(
      uid: uid,
      serverUrl: serverUrl,
      username: username,
    );
  }

  Future<void> clearWebDavLinked({required String uid}) {
    return _dbService.clearWebDavLink(uid: uid);
  }

  Future<void> setWebDavSyncFile({
    required String uid,
    required String path,
    required String fileName,
    required String mimeType,
  }) {
    return _dbService.setWebDavSyncFile(
      uid: uid,
      path: path,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<void> clearWebDavSyncFile({required String uid}) {
    return _dbService.clearWebDavSyncFile(uid: uid);
  }
}
