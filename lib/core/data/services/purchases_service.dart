import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

enum EntitlementTier { free, pro }

class PurchasesServiceException implements Exception {
  const PurchasesServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PurchasesService {
  PurchasesService._internal();

  static final PurchasesService instance = PurchasesService._internal();

  static const String _proEntitlementId = 'pro';

  final StreamController<EntitlementTier> _entitlementController =
      StreamController<EntitlementTier>.broadcast();

  Stream<EntitlementTier> get entitlementStream => _entitlementController.stream;

  EntitlementTier _currentTier = EntitlementTier.free;
  EntitlementTier get currentTier => _currentTier;

  bool _isInitialized = false;
  String? _appUserId;

  Future<void> init({
    required String apiKey,
    String? appUserId,
  }) async {
    if (_isInitialized || kIsWeb) return;
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration(apiKey)..appUserID = appUserId,
    );
    _appUserId = appUserId;
    _isInitialized = true;
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    final customerInfo = await Purchases.getCustomerInfo();
    _onCustomerInfoUpdated(customerInfo);
  }

  Future<void> syncAppUser(String? uid) async {
    if (!_isInitialized || kIsWeb) return;
    if (_appUserId == uid) return;
    if (uid == null) {
      await Purchases.logOut();
      _appUserId = null;
      _setTier(EntitlementTier.free);
      return;
    }
    final result = await Purchases.logIn(uid);
    _appUserId = uid;
    _onCustomerInfoUpdated(result.customerInfo);
  }

  Future<void> refreshCustomerInfo() async {
    if (!_isInitialized || kIsWeb) return;
    final customerInfo = await Purchases.getCustomerInfo();
    _onCustomerInfoUpdated(customerInfo);
  }

  Future<void> restorePurchases() async {
    if (!_isInitialized || kIsWeb) return;
    final customerInfo = await Purchases.restorePurchases();
    _onCustomerInfoUpdated(customerInfo);
  }

  Future<bool> presentPaywall() async {
    if (kIsWeb) {
      throw const PurchasesServiceException(
        'RevenueCat paywalls are not supported on web builds.',
      );
    }
    if (!_isInitialized) {
      throw const PurchasesServiceException(
        'RevenueCat is not initialized for this build.',
      );
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) {
        throw const PurchasesServiceException(
          'No current RevenueCat offering is configured. Set one in the RevenueCat dashboard first.',
        );
      }
      if (offering.availablePackages.isEmpty) {
        throw PurchasesServiceException(
          'The current RevenueCat offering "${offering.identifier}" has no packages.',
        );
      }

      await RevenueCatUI.presentPaywall(offering: offering);
      await refreshCustomerInfo();
      return true;
    } on PurchasesServiceException {
      rethrow;
    } catch (error, stackTrace) {
      log('presentPaywall error: $error\n$stackTrace');
      throw PurchasesServiceException('Could not open paywall: $error');
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final isPro = info.entitlements.all[_proEntitlementId]?.isActive == true ||
        (kDebugMode && info.activeSubscriptions.isNotEmpty);
    _setTier(isPro ? EntitlementTier.pro : EntitlementTier.free);
  }

  void _setTier(EntitlementTier nextTier) {
    if (_currentTier == nextTier) return;
    _currentTier = nextTier;
    _entitlementController.add(nextTier);
  }
}
