import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../l10n/app_localizations.dart';

enum EntitlementTier { free, pro }

enum PurchasesFailure {
  missingConfiguration,
  temporarilyUnavailable,
  unavailableBuild,
  unavailableNow,
  paywallsUnsupportedOnWeb,
  customerCenterUnsupportedOnWeb,
  couldNotOpenOptions,
}

class PurchasesServiceException implements Exception {
  const PurchasesServiceException(this.failure);

  final PurchasesFailure failure;

  String localizedMessage(AppLocalizations localizations) => switch (failure) {
    PurchasesFailure.missingConfiguration =>
      localizations.purchasesUnavailableMissingConfiguration,
    PurchasesFailure.temporarilyUnavailable =>
      localizations.purchasesTemporarilyUnavailable,
    PurchasesFailure.unavailableBuild =>
      localizations
          .purchasesAreUnavailableInThisBuildPleaseUpdateTheAppAndTryAgain,
    PurchasesFailure.unavailableNow =>
      localizations.purchasesAreUnavailableRightNowPleaseTryAgainLater,
    PurchasesFailure.paywallsUnsupportedOnWeb =>
      localizations.revenuecatPaywallsAreNotSupportedOnWebBuilds,
    PurchasesFailure.customerCenterUnsupportedOnWeb =>
      localizations.revenuecatCustomerCenterIsNotSupportedOnWebBuilds,
    PurchasesFailure.couldNotOpenOptions =>
      localizations.couldNotOpenSubscriptionOptionsPleaseTryAgainLater,
  };

  @override
  String toString() => failure.name;
}

class PurchasesService {
  PurchasesService._internal();

  static final PurchasesService instance = PurchasesService._internal();

  static const String _proEntitlementId = 'pro';
  static const String _defaultProUsersAssetPath =
      'assets/config/default_pro_users.json';

  final StreamController<EntitlementTier> _entitlementController =
      StreamController<EntitlementTier>.broadcast();

  Stream<EntitlementTier> get entitlementStream =>
      _entitlementController.stream;

  EntitlementTier _currentTier = EntitlementTier.free;
  EntitlementTier get currentTier => _currentTier;

  bool _isInitialized = false;
  PurchasesFailure? _initFailure;
  String? _appUserId;
  String? _appUserEmail;
  Set<String> _defaultProEmails = <String>{};

  Future<void> init({
    required String apiKey,
    String? appUserId,
    String? appUserEmail,
  }) async {
    if (_isInitialized) return;
    _appUserEmail = _normalizeEmail(appUserEmail);
    await _loadDefaultProEmails();
    if (_isAllowlistedProEmail(_appUserEmail)) {
      _setTier(EntitlementTier.pro);
    }
    final trimmedApiKey = apiKey.trim();
    if (kIsWeb) return;
    if (trimmedApiKey.isEmpty) {
      _initFailure = PurchasesFailure.missingConfiguration;
      return;
    }
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(
        PurchasesConfiguration(trimmedApiKey)..appUserID = appUserId,
      );
      _appUserId = appUserId;
      _isInitialized = true;
      _initFailure = null;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      final customerInfo = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdated(customerInfo);
    } catch (error, stackTrace) {
      log('Purchases init failed: $error\n$stackTrace');
      _initFailure = PurchasesFailure.temporarilyUnavailable;
      rethrow;
    }
  }

  Future<void> syncAppUser(String? uid, {String? email}) async {
    _appUserEmail = _normalizeEmail(email);
    if (!_isInitialized || kIsWeb) {
      if (_isAllowlistedProEmail(_appUserEmail)) {
        _setTier(EntitlementTier.pro);
      }
      return;
    }
    if (_appUserId == uid) return;
    if (uid == null) {
      await Purchases.logOut();
      _appUserId = null;
      _setTier(
        _isAllowlistedProEmail(_appUserEmail)
            ? EntitlementTier.pro
            : EntitlementTier.free,
      );
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
        PurchasesFailure.paywallsUnsupportedOnWeb,
      );
    }
    if (!_isInitialized) {
      throw PurchasesServiceException(
        _initFailure ?? PurchasesFailure.unavailableBuild,
      );
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) {
        throw const PurchasesServiceException(PurchasesFailure.unavailableNow);
      }
      if (offering.availablePackages.isEmpty) {
        throw const PurchasesServiceException(PurchasesFailure.unavailableNow);
      }

      await RevenueCatUI.presentPaywall(offering: offering);
      await refreshCustomerInfo();
      return true;
    } on PurchasesServiceException {
      rethrow;
    } catch (error, stackTrace) {
      log('presentPaywall error: $error\n$stackTrace');
      throw const PurchasesServiceException(
        PurchasesFailure.couldNotOpenOptions,
      );
    }
  }

  Future<void> presentCustomerCenter() async {
    if (kIsWeb) {
      throw const PurchasesServiceException(
        PurchasesFailure.customerCenterUnsupportedOnWeb,
      );
    }
    if (!_isInitialized) {
      throw PurchasesServiceException(
        _initFailure ?? PurchasesFailure.unavailableBuild,
      );
    }
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: _onCustomerInfoUpdated,
      );
      await refreshCustomerInfo();
    } catch (error, stackTrace) {
      log('presentCustomerCenter error: $error\n$stackTrace');
      throw const PurchasesServiceException(
        PurchasesFailure.couldNotOpenOptions,
      );
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    final isPro =
        info.entitlements.all[_proEntitlementId]?.isActive == true ||
        (kDebugMode && info.activeSubscriptions.isNotEmpty) ||
        _isAllowlistedProEmail(_appUserEmail);
    _setTier(isPro ? EntitlementTier.pro : EntitlementTier.free);
  }

  Future<void> _loadDefaultProEmails() async {
    try {
      final raw = await rootBundle.loadString(_defaultProUsersAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final entries = decoded['emails'];
      if (entries is! List) {
        return;
      }
      _defaultProEmails = entries
          .whereType<String>()
          .map(_normalizeEmail)
          .whereType<String>()
          .toSet();
    } catch (_) {
      // Keep default list empty if asset is unavailable or malformed.
    }
  }

  bool _isAllowlistedProEmail(String? email) {
    final normalized = _normalizeEmail(email);
    if (normalized == null) {
      return false;
    }
    return _defaultProEmails.contains(normalized);
  }

  String? _normalizeEmail(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _setTier(EntitlementTier nextTier) {
    if (_currentTier == nextTier) return;
    _currentTier = nextTier;
    _entitlementController.add(nextTier);
  }
}
