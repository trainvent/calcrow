import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveAuthException implements Exception {
  const GoogleDriveAuthException(this.message);

  final String message;
}

class GoogleDriveLinkResult {
  const GoogleDriveLinkResult({
    required this.email,
    required this.accessToken,
  });

  final String email;
  final String accessToken;
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

  GoogleSignIn? _googleSignIn;

  Future<GoogleDriveLinkResult> linkAccount() async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      final account = await signIn.signIn();
      if (account == null) {
        throw const GoogleDriveAuthException('Google sign-in was canceled.');
      }
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) {
        throw const GoogleDriveAuthException(
          'Could not get Drive API access token.',
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
      throw GoogleDriveAuthException('Google linking failed: $error');
    }
  }

  Future<http.Client> getAuthenticatedClient() async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      var account = signIn.currentUser;
      account ??= await signIn.signInSilently();
      if (account == null) {
        throw const GoogleDriveAuthException(
          'Google account is not linked in this session.',
        );
      }
      final headers = await account.authHeaders;
      return GoogleAuthClient(headers);
    } catch (error) {
      if (error is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException('Failed to get authenticated client: $error');
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

  GoogleSignIn _buildGoogleSignIn() {
    const configuredWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final webClientId = configuredWebClientId.trim();
    return GoogleSignIn(
      clientId: kIsWeb && webClientId.isNotEmpty ? webClientId : null,
      scopes: const <String>[
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
  }
}
