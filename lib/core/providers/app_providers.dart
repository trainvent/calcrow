import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/di/service_locator.dart';
import '../data/services/ads_consent_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/cloud_document_service.dart';
import '../data/services/db_service.dart';
import '../data/services/diagnostics_service.dart';
import '../data/services/google_drive_auth_service.dart';
import '../data/services/google_drive_sync_service.dart';
import '../data/services/local_document_service.dart';
import '../data/services/purchases_service.dart';
import '../data/services/user_repository.dart';
import '../data/services/webdav_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => ServiceLocator.authService,
);
final dbServiceProvider = Provider<DbService>(
  (ref) => ServiceLocator.dbService,
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => ServiceLocator.userRepository,
);
final localDocumentServiceProvider = Provider<LocalDocumentService>(
  (ref) => ServiceLocator.localDocumentService,
);
final cloudDocumentServiceProvider = Provider<CloudDocumentService>(
  (ref) => ServiceLocator.cloudDocumentService,
);
final googleDriveAuthServiceProvider = Provider<GoogleDriveAuthService>(
  (ref) => ServiceLocator.googleDriveAuthService,
);
final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>(
  (ref) => ServiceLocator.googleDriveSyncService,
);
final webDavServiceProvider = Provider<WebDavService>(
  (ref) => ServiceLocator.webDavService,
);
final purchasesServiceProvider = Provider<PurchasesService>(
  (ref) => ServiceLocator.purchasesService,
);
final adsConsentServiceProvider = Provider<AdsConsentService>(
  (ref) => ServiceLocator.adsConsentService,
);
final diagnosticsServiceProvider = Provider<DiagnosticsService>(
  (ref) => ServiceLocator.diagnosticsService,
);

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  if (!ServiceLocator.isSetup) return Stream<AuthSession?>.value(null);
  return ref.watch(authServiceProvider).authStateChanges();
});

final userSettingsProvider = StreamProvider.family<UserSettingsData, String>((
  ref,
  uid,
) {
  return ref.watch(userRepositoryProvider).watchUserSettings(uid);
});

final emailVerifiedProvider = StreamProvider.family<bool, String>((ref, uid) {
  return ref.watch(dbServiceProvider).watchUserEmailVerified(uid);
});

final entitlementTierProvider = StreamProvider<EntitlementTier>((ref) {
  return ref.watch(purchasesServiceProvider).entitlementStream;
});

class LanguagePreference extends Notifier<String?> {
  static const supportedLanguageCodes = <String>{'en', 'de'};

  @override
  String? build() => null;

  void setLanguageCode(String? value) {
    state = supportedLanguageCodes.contains(value) ? value : null;
  }
}

final languagePreferenceProvider =
    NotifierProvider<LanguagePreference, String?>(LanguagePreference.new);

final effectiveLanguageCodeProvider = Provider<String?>((ref) {
  final override = ref.watch(languagePreferenceProvider);
  if (override != null) return override;
  final session = ref.watch(authSessionProvider).asData?.value;
  if (session == null) return null;
  return ref
      .watch(userSettingsProvider(session.uid))
      .asData
      ?.value
      .languageCode;
});

final effectiveLocaleProvider = Provider<Locale?>((ref) {
  final languageCode = ref.watch(effectiveLanguageCodeProvider);
  return languageCode == null ? null : Locale(languageCode);
});

final appServiceCoordinatorProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (previous, next) {
    final session = next.asData?.value;
    unawaited(
      ref
          .read(purchasesServiceProvider)
          .syncAppUser(session?.uid, email: session?.email)
          .then(
            (_) => ref.read(purchasesServiceProvider).refreshCustomerInfo(),
          ),
    );
  }, fireImmediately: true);

  ref.listen<AsyncValue<EntitlementTier>>(entitlementTierProvider, (
    previous,
    next,
  ) {
    final tier = next.asData?.value;
    final session = ref.read(authSessionProvider).asData?.value;
    if (tier == null || session == null) return;
    unawaited(
      ref
          .read(userRepositoryProvider)
          .setIsPro(uid: session.uid, isPro: tier == EntitlementTier.pro),
    );
  });
});
