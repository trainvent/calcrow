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

class WebDavSavedEntry {
  const WebDavSavedEntry({
    required this.id,
    required this.serverUrl,
    required this.username,
  });

  final String id;
  final String serverUrl;
  final String username;

  static WebDavSavedEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final serverUrl = UserSettingsData._readTrimmed(raw['serverUrl']);
    final username = UserSettingsData._readTrimmed(raw['username']);
    if (serverUrl == null || username == null) return null;
    final id =
        UserSettingsData._readTrimmed(raw['id']) ??
        _legacyWebDavEntryId(serverUrl: serverUrl, username: username);
    return WebDavSavedEntry(id: id, serverUrl: serverUrl, username: username);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'serverUrl': serverUrl,
      'username': username,
    };
  }
}

String _legacyWebDavEntryId({
  required String serverUrl,
  required String username,
}) {
  final key =
      '${serverUrl.trim().toLowerCase()}|${username.trim().toLowerCase()}';
  final hash = key.hashCode.abs().toRadixString(16);
  return 'legacy_$hash';
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
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
    this.webDavEntries = const <WebDavSavedEntry>[],
    this.webDavActiveEntryId,
    this.webDavServerUrl,
    this.webDavUsername,
    this.webDavPassword,
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
  final List<WebDavSavedEntry> webDavEntries;
  final String? webDavActiveEntryId;
  final String? webDavServerUrl;
  final String? webDavUsername;
  final String? webDavPassword;
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
    final legacyWebDavServerUrl = _readTrimmed(settings['webDavServerUrl']);
    final legacyWebDavUsername = _readTrimmed(settings['webDavUsername']);
    final webDavEntries = _parseWebDavEntries(
      settings['webDavEntries'],
      legacyServerUrl: legacyWebDavServerUrl,
      legacyUsername: legacyWebDavUsername,
    );
    final configuredWebDavActiveEntryId = _readTrimmed(
      settings['webDavActiveEntryId'],
    );
    final activeWebDavEntry =
        _firstWhereOrNull(
          webDavEntries,
          (entry) => entry.id == configuredWebDavActiveEntryId,
        ) ??
        (webDavEntries.isEmpty ? null : webDavEntries.first);
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
      webDavLinked: webDavLinked || activeWebDavEntry != null,
      webDavEntries: webDavEntries,
      webDavActiveEntryId: activeWebDavEntry?.id,
      webDavServerUrl: activeWebDavEntry?.serverUrl ?? legacyWebDavServerUrl,
      webDavUsername: activeWebDavEntry?.username ?? legacyWebDavUsername,
      webDavPassword: settings['webDavPassword'] as String?,
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

  static List<WebDavSavedEntry> _parseWebDavEntries(
    Object? raw, {
    required String? legacyServerUrl,
    required String? legacyUsername,
  }) {
    final parsed = <WebDavSavedEntry>[];
    if (raw is List) {
      for (final candidate in raw) {
        final entry = WebDavSavedEntry.fromMap(candidate);
        if (entry == null) continue;
        if (parsed.any((existing) => existing.id == entry.id)) continue;
        parsed.add(entry);
      }
    }
    if (parsed.isNotEmpty) return parsed;
    if (legacyServerUrl == null || legacyUsername == null) {
      return const <WebDavSavedEntry>[];
    }
    return <WebDavSavedEntry>[
      WebDavSavedEntry(
        id: _legacyWebDavEntryId(
          serverUrl: legacyServerUrl,
          username: legacyUsername,
        ),
        serverUrl: legacyServerUrl,
        username: legacyUsername,
      ),
    ];
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
    required String password,
  }) {
    return _dbService.setWebDavLink(
      uid: uid,
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  Future<void> clearWebDavLinked({required String uid}) {
    return _dbService.clearWebDavLink(uid: uid);
  }

  Future<void> upsertWebDavEntry({
    required String uid,
    required WebDavSavedEntry entry,
    required String password,
  }) async {
    final settings = await getUserSettings(uid);
    final entries = List<WebDavSavedEntry>.from(settings.webDavEntries);
    final existingIndex = entries.indexWhere(
      (candidate) => candidate.id == entry.id,
    );
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }
    await _persistWebDavEntries(
      uid: uid,
      entries: entries,
      activeEntryId: entry.id,
      activePassword: password,
      clearSyncFileSelection: true,
    );
  }

  Future<void> selectWebDavEntry({
    required String uid,
    required String entryId,
    required String activePassword,
  }) async {
    final settings = await getUserSettings(uid);
    if (settings.webDavEntries.isEmpty) {
      throw StateError('No saved WebDAV entries found.');
    }
    final activeEntry = _firstWhereOrNull(
      settings.webDavEntries,
      (entry) => entry.id == entryId,
    );
    if (activeEntry == null) {
      throw StateError('Selected WebDAV entry could not be found.');
    }
    await _persistWebDavEntries(
      uid: uid,
      entries: settings.webDavEntries,
      activeEntryId: activeEntry.id,
      activePassword: activePassword,
      clearSyncFileSelection: true,
    );
  }

  Future<void> removeWebDavEntry({
    required String uid,
    required String entryId,
  }) async {
    final settings = await getUserSettings(uid);
    final remainingEntries = settings.webDavEntries
        .where((entry) => entry.id != entryId)
        .toList();
    if (remainingEntries.isEmpty) {
      await clearWebDavLinked(uid: uid);
      return;
    }
    final nextActiveEntry =
        _firstWhereOrNull(
          remainingEntries,
          (entry) => entry.id == settings.webDavActiveEntryId,
        ) ??
        remainingEntries.first;
    await _persistWebDavEntries(
      uid: uid,
      entries: remainingEntries,
      activeEntryId: nextActiveEntry.id,
      activePassword: null,
      clearSyncFileSelection: true,
    );
  }

  Future<void> _persistWebDavEntries({
    required String uid,
    required List<WebDavSavedEntry> entries,
    required String activeEntryId,
    required String? activePassword,
    required bool clearSyncFileSelection,
  }) async {
    final activeEntry = _firstWhereOrNull(
      entries,
      (entry) => entry.id == activeEntryId,
    );
    if (activeEntry == null) {
      throw StateError('Active WebDAV entry could not be found.');
    }

    await _firestore.collection(_usersCollection).doc(uid).set({
      'settings': {
        'cloudSyncProvider': cloudSyncProviderToSettings(
          CloudSyncProvider.webDav,
        ),
        'webDavLinked': true,
        'webDavEntries': entries.map((entry) => entry.toMap()).toList(),
        'webDavActiveEntryId': activeEntry.id,
        'webDavServerUrl': activeEntry.serverUrl,
        'webDavUsername': activeEntry.username,
        'webDavPassword': activePassword ?? FieldValue.delete(),
        'webDavLinkedAt': FieldValue.serverTimestamp(),
        if (clearSyncFileSelection) ...<String, dynamic>{
          'webDavSyncFilePath': FieldValue.delete(),
          'webDavSyncFileName': FieldValue.delete(),
          'webDavSyncMimeType': FieldValue.delete(),
          'webDavLastSyncedAt': FieldValue.delete(),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
