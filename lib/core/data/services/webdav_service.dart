import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class WebDavException implements Exception {
  const WebDavException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class WebDavLinkResult {
  const WebDavLinkResult({
    required this.serverUrl,
    required this.username,
    required this.hostLabel,
  });

  final String serverUrl;
  final String username;
  final String hostLabel;
}

class WebDavCredentials {
  const WebDavCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;
}

class WebDavFileMetadata {
  const WebDavFileMetadata({
    required this.path,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
  });

  final String path;
  final String name;
  final String mimeType;
  final DateTime? modifiedTime;
}

class WebDavBrowserEntry {
  const WebDavBrowserEntry({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.isFolder,
    this.modifiedTime,
  });

  final String path;
  final String name;
  final String mimeType;
  final bool isFolder;
  final DateTime? modifiedTime;

  WebDavFileMetadata asFileMetadata() {
    return WebDavFileMetadata(
      path: path,
      name: name,
      mimeType: mimeType,
      modifiedTime: modifiedTime,
    );
  }
}

class WebDavService {
  WebDavService({FlutterSecureStorage? secureStorage, http.Client? client})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _client = client ?? http.Client();

  final FlutterSecureStorage _secureStorage;
  final http.Client _client;

  static const String _serverUrlPrefix = 'webdav_server_url';
  static const String _usernamePrefix = 'webdav_username';
  static const String _passwordPrefix = 'webdav_password';
  static const String _entryPasswordPrefix = 'webdav_entry_password';
  static const List<String> supportedMimeTypes = <String>[
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.spreadsheet',
  ];

  Future<WebDavLinkResult> linkAccount({
    required String uid,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = _normalizeServerUrl(serverUrl);
    final requestedUri = Uri.tryParse(normalizedUrl);
    if (requestedUri == null ||
        !requestedUri.hasScheme ||
        requestedUri.host.isEmpty) {
      throw const WebDavException('Enter a valid WebDAV URL.');
    }

    final validatedUri = await _resolveAndValidateWebDavUri(
      uri: requestedUri,
      username: username.trim(),
      password: password,
    );
    final resolvedUrl = _normalizeServerUrl(validatedUri.toString());
    final resolvedUri = Uri.parse(resolvedUrl);
    await saveCredentialsWithoutValidation(
      uid: uid,
      serverUrl: resolvedUrl,
      username: username.trim(),
      password: password,
    );
    return WebDavLinkResult(
      serverUrl: resolvedUrl,
      username: username.trim(),
      hostLabel: resolvedUri.host,
    );
  }

  Future<Uri> _resolveAndValidateWebDavUri({
    required Uri uri,
    required String username,
    required String password,
  }) async {
    final candidates = <Uri>[
      uri,
      ..._commonWebDavFallbackUris(uri: uri, username: username),
    ];
    final seen = <String>{};
    WebDavException? lastMethodNotAllowed;

    for (final candidate in candidates) {
      final key = candidate.toString();
      if (!seen.add(key)) {
        continue;
      }
      try {
        await _validateConnection(
          uri: candidate,
          username: username,
          password: password,
        );
        return candidate;
      } on WebDavException catch (error) {
        if (error.statusCode == 405) {
          lastMethodNotAllowed = error;
          continue;
        }
        rethrow;
      }
    }

    if (lastMethodNotAllowed != null) {
      throw const WebDavException(
        'WebDAV endpoint rejected PROPFIND (405). Use the exact WebDAV folder URL. For Nextcloud, this is usually https://<host>/remote.php/dav/files/<username>/',
        statusCode: 405,
      );
    }

    throw const WebDavException('Could not validate the WebDAV URL.');
  }

  List<Uri> _commonWebDavFallbackUris({
    required Uri uri,
    required String username,
  }) {
    final normalizedPath = uri.path.trim();
    final hasSpecificPath = normalizedPath.isNotEmpty && normalizedPath != '/';
    if (hasSpecificPath || username.trim().isEmpty) {
      return const <Uri>[];
    }

    final encodedUsername = Uri.encodeComponent(username.trim());
    return <Uri>[
      uri.replace(path: '/remote.php/dav/files/$encodedUsername/'),
      uri.replace(path: '/remote.php/webdav/'),
    ];
  }

  Future<void> clearCredentials({required String uid}) async {
    await _secureStorage.delete(key: _serverUrlKey(uid));
    await _secureStorage.delete(key: _usernameKey(uid));
    await _secureStorage.delete(key: _passwordKey(uid));
  }

  Future<bool> hasCredentials({required String uid}) async {
    final serverUrl = await _secureStorage.read(key: _serverUrlKey(uid));
    final username = await _secureStorage.read(key: _usernameKey(uid));
    final password = await _secureStorage.read(key: _passwordKey(uid));
    return serverUrl != null &&
        username != null &&
        password != null &&
        serverUrl.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  Future<void> saveCredentialsWithoutValidation({
    required String uid,
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: _serverUrlKey(uid), value: serverUrl);
    await _secureStorage.write(key: _usernameKey(uid), value: username);
    await _secureStorage.write(key: _passwordKey(uid), value: password);
  }

  Future<void> saveEntryPassword({
    required String uid,
    required String entryId,
    required String password,
  }) async {
    await _secureStorage.write(
      key: _entryPasswordKey(uid, entryId),
      value: password,
    );
  }

  Future<String?> readEntryPassword({
    required String uid,
    required String entryId,
  }) {
    return _secureStorage.read(key: _entryPasswordKey(uid, entryId));
  }

  Future<void> clearEntryPassword({
    required String uid,
    required String entryId,
  }) async {
    await _secureStorage.delete(key: _entryPasswordKey(uid, entryId));
  }

  Future<WebDavCredentials> getCredentials({required String uid}) async {
    final serverUrl = await _secureStorage.read(key: _serverUrlKey(uid));
    final username = await _secureStorage.read(key: _usernameKey(uid));
    final password = await _secureStorage.read(key: _passwordKey(uid));
    if (serverUrl == null ||
        username == null ||
        password == null ||
        serverUrl.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      throw const WebDavException(
        'WebDAV credentials are missing on this device. Re-link the account in Settings.',
      );
    }
    return WebDavCredentials(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  Future<List<WebDavBrowserEntry>> listFolderEntries({
    required String uid,
    String? relativeFolderPath,
  }) async {
    final credentials = await getCredentials(uid: uid);
    late final Uri folderUri;
    try {
      folderUri = _resolveUri(
        baseUrl: credentials.serverUrl,
        relativePath: relativeFolderPath,
        ensureTrailingSlash: true,
      );
    } on FormatException {
      throw const WebDavException(
        'This WebDAV folder path contains unsupported characters.',
      );
    } on ArgumentError {
      throw const WebDavException(
        'This WebDAV folder path could not be opened.',
      );
    }
    final response = await _sendWebDavRequest(
      method: 'PROPFIND',
      uri: folderUri,
      username: credentials.username,
      password: credentials.password,
      headers: const <String, String>{'depth': '1'},
    );
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw WebDavException(
        'Could not list WebDAV folder (${response.statusCode}).',
      );
    }
    try {
      return _parseFolderEntries(
        responseBody: response.body,
        baseUri: folderUri,
        rootRelativePath: _normalizeRelativePath(relativeFolderPath),
      );
    } on XmlException {
      throw const WebDavException(
        'The WebDAV server returned an invalid folder response.',
      );
    } on FormatException {
      throw const WebDavException(
        'A file or folder name in this WebDAV directory uses unsupported characters.',
      );
    } on ArgumentError {
      throw const WebDavException(
        'This WebDAV folder contains an entry that could not be opened.',
      );
    }
  }

  Future<Uint8List> downloadFileBytes({
    required String uid,
    required String relativePath,
  }) async {
    final credentials = await getCredentials(uid: uid);
    late final Uri fileUri;
    try {
      fileUri = _resolveUri(
        baseUrl: credentials.serverUrl,
        relativePath: relativePath,
      );
    } on FormatException {
      throw const WebDavException(
        'This WebDAV file path contains unsupported characters.',
      );
    } on ArgumentError {
      throw const WebDavException('This WebDAV file path could not be opened.');
    }
    final response = await _sendWebDavRequest(
      method: 'GET',
      uri: fileUri,
      username: credentials.username,
      password: credentials.password,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException(
        'Could not download WebDAV file (${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  Future<WebDavFileMetadata> uploadFileBytes({
    required String uid,
    required String relativePath,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final credentials = await getCredentials(uid: uid);
    late final Uri fileUri;
    try {
      fileUri = _resolveUri(
        baseUrl: credentials.serverUrl,
        relativePath: relativePath,
      );
    } on FormatException {
      throw const WebDavException(
        'This WebDAV file path contains unsupported characters.',
      );
    } on ArgumentError {
      throw const WebDavException('This WebDAV file path could not be saved.');
    }
    final response = await _sendWebDavRequest(
      method: 'PUT',
      uri: fileUri,
      username: credentials.username,
      password: credentials.password,
      headers: <String, String>{'content-type': mimeType},
      bodyBytes: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebDavException(
        'Could not upload WebDAV file (${response.statusCode}).',
      );
    }
    return WebDavFileMetadata(
      path: _normalizeRelativePath(relativePath)!,
      name: _fileNameFromRelativePath(relativePath),
      mimeType: mimeType,
    );
  }

  Future<void> _validateConnection({
    required Uri uri,
    required String username,
    required String password,
  }) async {
    final request = http.Request('PROPFIND', uri)
      ..headers.addAll(<String, String>{
        'authorization': _basicAuth(username, password),
        'depth': '0',
      });

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (_) {
      throw const WebDavException(
        'Could not reach the WebDAV server. Check the URL and network access.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const WebDavException(
        'WebDAV sign-in failed. Check the username and app password.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 405) {
      throw const WebDavException(
        'WebDAV endpoint rejected PROPFIND (405).',
        statusCode: 405,
      );
    }
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw WebDavException(
        'WebDAV server responded with ${response.statusCode}. Check that the URL points to a valid WebDAV folder.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<http.Response> _sendWebDavRequest({
    required String method,
    required Uri uri,
    required String username,
    required String password,
    Map<String, String>? headers,
    Uint8List? bodyBytes,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll(<String, String>{
        'authorization': _basicAuth(username, password),
        ...?headers,
      });
    if (bodyBytes != null) {
      request.bodyBytes = bodyBytes;
    }
    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } catch (_) {
      throw const WebDavException(
        'Could not reach the WebDAV server. Check the URL and network access.',
      );
    }
    if (streamedResponse.statusCode == 401 ||
        streamedResponse.statusCode == 403) {
      throw const WebDavException(
        'WebDAV sign-in failed. Check the username and app password.',
      );
    }
    return http.Response.fromStream(streamedResponse);
  }

  List<WebDavBrowserEntry> _parseFolderEntries({
    required String responseBody,
    required Uri baseUri,
    required String? rootRelativePath,
  }) {
    final document = XmlDocument.parse(responseBody);
    final responses = document.findAllElements('d:response').isNotEmpty
        ? document.findAllElements('d:response')
        : document.findAllElements('response');
    final normalizedRoot = _normalizeRelativePath(rootRelativePath);
    final entries = <WebDavBrowserEntry>[];

    for (final response in responses) {
      final hrefElement =
          response.getElement('d:href') ?? response.getElement('href');
      if (hrefElement == null) continue;
      final href = Uri.decodeFull(hrefElement.innerText.trim());
      if (href.isEmpty) continue;
      final itemUri = baseUri.resolve(href);
      final relativePath = _relativePathFromUri(
        baseUri: Uri.parse(baseUri.toString()),
        itemUri: itemUri,
      );
      if (relativePath == null || relativePath.isEmpty) {
        continue;
      }
      final normalizedPath = _joinRelativePaths(
        rootRelativePath,
        _normalizeRelativePath(relativePath)!,
      );
      if (normalizedRoot != null && normalizedPath == normalizedRoot) {
        continue;
      }

      final props = <XmlElement>[
        ...response.findAllElements('d:prop'),
        ...response.findAllElements('prop'),
      ];
      final prop = props.isEmpty ? null : props.first;
      final resourceType =
          prop?.getElement('d:resourcetype') ??
          prop?.getElement('resourcetype');
      final isFolder =
          resourceType?.findElements('d:collection').isNotEmpty == true ||
          resourceType?.findElements('collection').isNotEmpty == true ||
          href.endsWith('/');
      final modifiedText =
          (prop?.getElement('d:getlastmodified') ??
                  prop?.getElement('getlastmodified'))
              ?.innerText
              .trim();
      final modifiedTime = modifiedText == null || modifiedText.isEmpty
          ? null
          : DateTime.tryParse(modifiedText);
      final normalizedFolderPath = isFolder
          ? _ensureTrailingSlash(normalizedPath)
          : normalizedPath;
      final name = _displayNameForPath(
        normalizedFolderPath,
        isFolder: isFolder,
      );
      final mimeType = isFolder
          ? 'application/webdav-folder'
          : _mimeTypeForFileName(name);
      if (!isFolder && !supportedMimeTypes.contains(mimeType)) {
        continue;
      }
      entries.add(
        WebDavBrowserEntry(
          path: normalizedFolderPath,
          name: name,
          mimeType: mimeType,
          isFolder: isFolder,
          modifiedTime: modifiedTime,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) {
        return a.isFolder ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  String _normalizeServerUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  String _basicAuth(String username, String password) {
    final token = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $token';
  }

  Uri _resolveUri({
    required String baseUrl,
    String? relativePath,
    bool ensureTrailingSlash = false,
  }) {
    final normalizedBase = _normalizeServerUrl(baseUrl);
    final normalizedRelativePath = _normalizeRelativePath(relativePath);
    final baseUri = Uri.parse(normalizedBase);
    final uri = normalizedRelativePath == null
        ? baseUri
        : baseUri.resolveUri(
            Uri(pathSegments: normalizedRelativePath.split('/')),
          );
    if (!ensureTrailingSlash) return uri;
    final text = uri.toString();
    return Uri.parse(text.endsWith('/') ? text : '$text/');
  }

  String? _normalizeRelativePath(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  }

  String _ensureTrailingSlash(String path) {
    return path.endsWith('/') ? path : '$path/';
  }

  String _joinRelativePaths(String? parent, String child) {
    final normalizedChild = _normalizeRelativePath(child) ?? child;
    final normalizedParent = _normalizeRelativePath(parent);
    if (normalizedParent == null || normalizedParent.isEmpty) {
      return normalizedChild;
    }
    final parentPrefix = _ensureTrailingSlash(normalizedParent);
    return '$parentPrefix$normalizedChild';
  }

  String _fileNameFromRelativePath(String path) {
    final normalized = _normalizeRelativePath(path) ?? path;
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last;
  }

  String _displayNameForPath(String path, {required bool isFolder}) {
    final normalized = isFolder && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last;
  }

  String? _relativePathFromUri({required Uri baseUri, required Uri itemUri}) {
    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final itemSegments = itemUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (itemSegments.length < baseSegments.length) return null;
    var commonSegments = 0;
    while (commonSegments < baseSegments.length &&
        commonSegments < itemSegments.length &&
        baseSegments[commonSegments] == itemSegments[commonSegments]) {
      commonSegments++;
    }
    final remaining = itemSegments.sublist(commonSegments);
    if (remaining.isEmpty) return null;
    final relative = remaining.join('/');
    return itemUri.path.endsWith('/') ? '$relative/' : relative;
  }

  String _mimeTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ods')) {
      return 'application/vnd.oasis.opendocument.spreadsheet';
    }
    return 'text/csv';
  }

  String _serverUrlKey(String uid) => '$_serverUrlPrefix:$uid';
  String _usernameKey(String uid) => '$_usernamePrefix:$uid';
  String _passwordKey(String uid) => '$_passwordPrefix:$uid';
  String _entryPasswordKey(String uid, String entryId) =>
      '$_entryPasswordPrefix:$uid:$entryId';
}
