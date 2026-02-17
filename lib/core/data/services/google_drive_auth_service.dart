import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Future<String> getAccessToken({bool interactiveIfNeeded = false}) async {
    try {
      final signIn = _googleSignIn ??= _buildGoogleSignIn();
      GoogleSignInAccount? account = signIn.currentUser;
      account ??= await signIn.signInSilently();
      if (account == null && interactiveIfNeeded) {
        account = await signIn.signIn();
      }
      if (account == null) {
        throw const GoogleDriveAuthException(
          'Google account is not linked in this session. Re-link Google Drive.',
        );
      }

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) {
        throw const GoogleDriveAuthException(
          'Could not refresh Drive API access token.',
        );
      }
      return token;
    } catch (error) {
      if (error is GoogleDriveAuthException) rethrow;
      throw GoogleDriveAuthException('Google token refresh failed: $error');
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
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (kIsWeb && webClientId.isEmpty) {
      throw const GoogleDriveAuthException(
        'Missing web OAuth client id. Set --dart-define=GOOGLE_WEB_CLIENT_ID=...',
      );
    }
    return GoogleSignIn(
      clientId: kIsWeb ? webClientId : null,
      scopes: const <String>[
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ],
    );
  }
}
