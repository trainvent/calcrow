import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/internal_constants.dart';
import 'core/data/di/service_locator.dart';
import 'core/data/services/purchases_service.dart';

// ...

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  ServiceLocator.setup();
  await PurchasesService.instance.init(
    apiKey: IConst.revenueCatTestAPIKey,
    appUserId: ServiceLocator.authService.currentSession?.uid,
  );
  runApp(const CalcrowApp());
}
