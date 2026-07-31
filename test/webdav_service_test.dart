import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:calcrow/core/data/services/webdav_service.dart';

void main() {
  group('WebDavService error classification', () {
    test('creates a folder with MKCOL and returns browser metadata', () async {
      late http.BaseRequest capturedRequest;
      final service = WebDavService(
        secureStorage: _MemorySecureStorage(),
        client: _FakeClient((request) async {
          capturedRequest = request;
          return _response(statusCode: 201);
        }),
        isWebBuildOverride: false,
      );
      await service.saveCredentialsWithoutValidation(
        uid: 'u1',
        serverUrl: 'https://cloud.example.com/dav/user/',
        username: 'user',
        password: 'pw',
      );

      final folder = await service.createFolder(
        uid: 'u1',
        relativePath: 'Projects/Calcrow',
        name: 'Calcrow',
      );

      expect(capturedRequest.method, 'MKCOL');
      expect(
        capturedRequest.url.toString(),
        'https://cloud.example.com/dav/user/Projects/Calcrow/',
      );
      expect(folder.path, 'Projects/Calcrow');
      expect(folder.name, 'Calcrow');
      expect(folder.isFolder, isTrue);
    });

    test('classifies web fetch/XHR failure as browserBlocked', () async {
      final service = WebDavService(
        secureStorage: _MemorySecureStorage(),
        client: _FakeClient((_) async {
          throw Exception('XMLHttpRequest error: Failed to fetch');
        }),
        isWebBuildOverride: true,
      );

      await expectLater(
        () => service.linkAccount(
          uid: 'u1',
          serverUrl: 'https://cloud.example.com/remote.php/dav/files/user/',
          username: 'user',
          password: 'pw',
        ),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.kind, 'kind', WebDavErrorKind.browserBlocked)
              .having((e) => e.requestMethod, 'requestMethod', 'PROPFIND'),
        ),
      );
    });

    test('classifies 401 as auth', () async {
      final service = WebDavService(
        secureStorage: _MemorySecureStorage(),
        client: _FakeClient((_) async => _response(statusCode: 401)),
        isWebBuildOverride: true,
      );

      await expectLater(
        () => service.linkAccount(
          uid: 'u1',
          serverUrl: 'https://cloud.example.com/remote.php/dav/files/user/',
          username: 'user',
          password: 'pw',
        ),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.kind, 'kind', WebDavErrorKind.auth)
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('classifies 405 as methodNotAllowed with URL hint', () async {
      final service = WebDavService(
        secureStorage: _MemorySecureStorage(),
        client: _FakeClient((_) async => _response(statusCode: 405)),
        isWebBuildOverride: true,
      );

      await expectLater(
        () => service.linkAccount(
          uid: 'u1',
          serverUrl: 'https://cloud.example.com/remote.php/dav/files/user/',
          username: 'user',
          password: 'pw',
        ),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.kind, 'kind', WebDavErrorKind.methodNotAllowed)
              .having((e) => e.statusCode, 'statusCode', 405),
        ),
      );
    });

    test('classifies other HTTP status as http', () async {
      final service = WebDavService(
        secureStorage: _MemorySecureStorage(),
        client: _FakeClient((_) async => _response(statusCode: 500)),
        isWebBuildOverride: true,
      );

      await expectLater(
        () => service.linkAccount(
          uid: 'u1',
          serverUrl: 'https://cloud.example.com/remote.php/dav/files/user/',
          username: 'user',
          password: 'pw',
        ),
        throwsA(
          isA<WebDavException>()
              .having((e) => e.kind, 'kind', WebDavErrorKind.http)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}

http.StreamedResponse _response({required int statusCode, String body = ''}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
  );
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
      return;
    }
    _store[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}
