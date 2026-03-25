import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/internal_constants.dart';
import 'core/data/di/service_locator.dart';
import 'core/data/services/diagnostics_service.dart';
import 'core/data/services/ads_consent_service.dart';
import 'core/data/services/purchases_service.dart';

// ...

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  ServiceLocator.setup();
  await AdsConsentService.instance.init();
  await ServiceLocator.diagnosticsService.init();
  await installDiagnosticsErrorHandlers();
  await PurchasesService.instance.init(
    apiKey: _revenueCatApiKeyForCurrentBuild(),
    appUserId: ServiceLocator.authService.currentSession?.uid,
  );
  runApp(const CalcrowApp());
}

String _revenueCatApiKeyForCurrentBuild() {
  if (!kIsWeb &&
      kReleaseMode &&
      defaultTargetPlatform == TargetPlatform.android) {
    return IConst.revenueCatGoogleAPIKey;
  }

  return IConst.revenueCatTestAPIKey;
}
