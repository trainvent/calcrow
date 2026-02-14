import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/google_drive_auth_service.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final AuthService authService;
  static late final DbService dbService;
  static late final GoogleDriveAuthService googleDriveAuthService;

  static void setup() {
    authService = AuthService(FirebaseAuth.instance);
    dbService = DbService(FirebaseFirestore.instance);
    googleDriveAuthService = GoogleDriveAuthService();
  }
}
