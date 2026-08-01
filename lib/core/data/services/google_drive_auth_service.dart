import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveAuthException implements Exception {
  const GoogleDriveAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleDriveLinkResult {
  const GoogleDriveLinkResult({required this.email, required this.accessToken});

  final String email;
  final String accessToken;
}

class GoogleIdentitySignInResult {
  const GoogleIdentitySignInResult({
    required this.email,
    required this.idToken,
    required this.accessToken,
  });

  final String email;
  final String? idToken;
  final String? accessToken;
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveAuthService {
  GoogleDriveAuthService();

  static const List<String> _driveScopes = <String>[
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  GoogleSignIn? _googleSignIn;

  Stream<GoogleIdentitySignInResult> identitySignIns() {
    final signIn = _googleSignIn ??= _buildGoogleSignIn();
    return signIn.onCurrentUserChanged
        .where((account) => account != null)
        .asyncMap((account) => _identityResult(account!));
  }

  Future<GoogleIdentitySignInResult> signInForIdentity() async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      final account = await signIn.signIn();
      if (account == null) {
        throw const GoogleDriveAuthException('google-sign-in-canceled');
      }
      return _identityResult(account);
    } catch (error) {
      if (error is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException(
        'Google sign-in failed (${error.runtimeType}): $error',
      );
    }
  }

  Future<GoogleIdentitySignInResult> _identityResult(
    GoogleSignInAccount account,
  ) async {
    final auth = await account.authentication;
    if ((auth.idToken == null || auth.idToken!.isEmpty) &&
        (auth.accessToken == null || auth.accessToken!.isEmpty)) {
      throw const GoogleDriveAuthException(
        'Google identity tokens are unavailable.',
      );
    }
    final email = account.email.trim();
    if (email.isEmpty) {
      throw const GoogleDriveAuthException(
        'Google account email is unavailable.',
      );
    }
    return GoogleIdentitySignInResult(
      email: email,
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
  }

  Future<GoogleDriveLinkResult> linkAccount() async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      final account = signIn.currentUser ?? await signIn.signIn();
      if (account == null) {
        throw const GoogleDriveAuthException(
          'Google Drive authorization was canceled.',
        );
      }
      final granted = await signIn.requestScopes(_driveScopes);
      if (!granted) {
        throw const GoogleDriveAuthException(
          'Google Drive authorization was canceled.',
        );
      }
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) {
        throw const GoogleDriveAuthException(
          'Could not get Drive API access token. Check Android OAuth SHA-1 setup, OAuth consent, and refresh google-services.json.',
        );
      }
      final email = account.email.trim();
      if (email.isEmpty) {
        throw const GoogleDriveAuthException(
          'Google account email is unavailable.',
        );
      }
      return GoogleDriveLinkResult(email: email, accessToken: token);
    } catch (error) {
      if (error is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException(
        'Google Drive authorization failed (${error.runtimeType}): $error',
      );
    }
  }

  Future<http.Client> getAuthenticatedClient() async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      var account = signIn.currentUser;
      account ??= await signIn.signInSilently();
      account ??= await signIn.signIn();
      if (account == null) {
        throw const GoogleDriveAuthException(
          'Google Drive is not connected in this session. Connect Google Drive again to refresh access.',
        );
      }
      if (!await signIn.canAccessScopes(_driveScopes)) {
        final granted = await signIn.requestScopes(_driveScopes);
        if (!granted) {
          throw const GoogleDriveAuthException(
            'Google Drive authorization was canceled.',
          );
        }
      }
      final headers = await account.authHeaders;
      if (headers.isEmpty) {
        throw const GoogleDriveAuthException(
          'Google auth headers are empty. Check OAuth client setup and Drive scope consent.',
        );
      }
      return GoogleAuthClient(headers);
    } catch (error) {
      if (error is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException(
        'Failed to get authenticated client (${error.runtimeType}): $error',
      );
    }
  }

  Future<void> unlinkAccount() async {
    final signIn = _googleSignIn;
    if (signIn == null) return;
    try {
      await signIn.disconnect();
    } catch (_) {
      await signIn.signOut();
    }
  }

  Future<void> signOutAccount() async {
    final signIn = _googleSignIn;
    if (signIn == null) return;
    try {
      await signIn.signOut();
    } catch (_) {
      // Firebase sign-out must still be allowed if Google session cleanup fails.
    }
  }

  GoogleSignIn _buildGoogleSignIn() {
    const configuredWebClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
    );
    const configuredIosClientId = String.fromEnvironment('IOS_OAUTH_CLIENT_ID');
    final webClientId = configuredWebClientId.trim();
    final iosClientId = configuredIosClientId.trim();
    return GoogleSignIn(
      clientId: _clientIdForCurrentPlatform(
        webClientId: webClientId,
        iosClientId: iosClientId,
      ),
      scopes: const <String>['email'],
    );
  }

  String? _clientIdForCurrentPlatform({
    required String webClientId,
    required String iosClientId,
  }) {
    if (kIsWeb) return webClientId.isEmpty ? null : webClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosClientId.isEmpty ? null : iosClientId;
    }
    return null;
  }
}
