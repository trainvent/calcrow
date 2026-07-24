import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/constants/internal_constants.dart';
import 'core/data/di/service_locator.dart';
import 'core/data/services/diagnostics_service.dart';
import 'core/data/services/ads_consent_service.dart';
import 'core/data/services/purchases_service.dart';
import 'core/providers/app_providers.dart';

// ...

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialThemeMode = await loadStoredThemeMode();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  ServiceLocator.setup();
  await installDiagnosticsErrorHandlers();
  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(initialThemeMode)],
      child: const CalcrowApp(),
    ),
  );
  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  await _runStartupStep('ads', () async {
    await AdsConsentService.instance.init();
    if (AdsConsentService.instance.isSupported) {
      await MobileAds.instance.initialize();
    }
  });
  await _runStartupStep('diagnostics', () async {
    await ServiceLocator.diagnosticsService.init();
  });
  await _runStartupStep('purchases', () async {
    await PurchasesService.instance.init(
      apiKey: _revenueCatApiKeyForCurrentBuild(),
      appUserId: ServiceLocator.authService.currentSession?.uid,
      appUserEmail: ServiceLocator.authService.currentSession?.email,
    );
  });
}

Future<void> _runStartupStep(
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error, stackTrace) {
    log(
      'Optional startup step failed: $label',
      error: error,
      stackTrace: stackTrace,
    );
    unawaited(
      ServiceLocator.diagnosticsService.recordError(
        error,
        stackTrace,
        reason: 'Optional startup step failed: $label',
      ),
    );
  }
}

String _revenueCatApiKeyForCurrentBuild() {
  if (IConst.useTestPurchases) {
    return IConst.revenueCatTestAPIKey;
  }

  if (kIsWeb) return IConst.revenueCatWebAPIKey;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return IConst.revenueCatGoogleAPIKey;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return IConst.revenueCatAppleAPIKey;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return '';
  }
}
