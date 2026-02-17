import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/google_drive_auth_service.dart';
import '../services/google_drive_sync_service.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final AuthService authService;
  static late final DbService dbService;
  static late final GoogleDriveAuthService googleDriveAuthService;
  static late final GoogleDriveSyncService googleDriveSyncService;
  static bool _isSetup = false;

  static bool get isSetup => _isSetup;

  static void setup() {
    if (_isSetup) return;
    authService = AuthService(FirebaseAuth.instance);
    dbService = DbService(FirebaseFirestore.instance);
    googleDriveAuthService = GoogleDriveAuthService();
    googleDriveSyncService = GoogleDriveSyncService();
    _isSetup = true;
  }
}
