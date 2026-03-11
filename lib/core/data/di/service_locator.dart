import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/google_drive_auth_service.dart';
import '../services/google_drive_sync_service.dart';
import '../services/purchases_service.dart';
import '../services/simple_cloud_document_service.dart';
import '../services/simple_local_document_service.dart';
import '../services/user_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static late final AuthService authService;
  static late final DbService dbService;
  static late final GoogleDriveAuthService googleDriveAuthService;
  static late final GoogleDriveSyncService googleDriveSyncService;
  static PurchasesService get purchasesService => PurchasesService.instance;
  static late final SimpleLocalDocumentService simpleLocalDocumentService;
  static late final SimpleCloudDocumentService simpleCloudDocumentService;
  static late final UserRepository userRepository;
  static bool _isSetup = false;

  static bool get isSetup => _isSetup;

  static void setup() {
    if (_isSetup) return;
    authService = AuthService(FirebaseAuth.instance);
    dbService = DbService(FirebaseFirestore.instance);
    googleDriveAuthService = GoogleDriveAuthService();
    googleDriveSyncService = GoogleDriveSyncService();
    userRepository = UserRepository(
      authService: authService,
      dbService: dbService,
      firestore: FirebaseFirestore.instance,
    );
    simpleLocalDocumentService = SimpleLocalDocumentService();
    simpleCloudDocumentService = SimpleCloudDocumentService(
      authService: authService,
      userRepository: userRepository,
      googleDriveAuthService: googleDriveAuthService,
      googleDriveSyncService: googleDriveSyncService,
    );
    _isSetup = true;
  }
}
