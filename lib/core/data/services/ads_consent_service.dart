import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../constants/internal_constants.dart';

class AdsConsentService {
  AdsConsentService._();

  static final AdsConsentService instance = AdsConsentService._();

  final ValueNotifier<bool> canRequestAdsListenable = ValueNotifier<bool>(false);
  final ValueNotifier<PrivacyOptionsRequirementStatus>
  privacyOptionsRequirementStatusListenable =
      ValueNotifier<PrivacyOptionsRequirementStatus>(
        PrivacyOptionsRequirementStatus.unknown,
      );

  bool _isRefreshing = false;
  bool _initialized = false;
  String? _lastErrorMessage;

  bool get isSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return IConst.adMobAndroidAppId.isNotEmpty;
      case TargetPlatform.iOS:
        return IConst.adMobIosAppId.isNotEmpty;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  bool get canRequestAds => canRequestAdsListenable.value;

  PrivacyOptionsRequirementStatus get privacyOptionsRequirementStatus =>
      privacyOptionsRequirementStatusListenable.value;

  bool get isPrivacyOptionsRequired =>
      privacyOptionsRequirementStatus == PrivacyOptionsRequirementStatus.required;

  String? get lastErrorMessage => _lastErrorMessage;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _refreshCachedState();
  }

  Future<void> refreshConsentInfo({bool showFormIfAvailable = true}) async {
    if (!isSupported || _isRefreshing) return;
    _isRefreshing = true;

    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          _lastErrorMessage = null;
          await _refreshCachedState();
          if (!showFormIfAvailable) {
            completer.complete();
            return;
          }

          await ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
            if (formError != null) {
              _lastErrorMessage = _formatFormError(formError);
            }
            await _refreshCachedState();
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        } catch (error) {
          _lastErrorMessage = '$error';
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
      (formError) {
        _lastErrorMessage = _formatFormError(formError);
        if (!completer.isCompleted) {
          completer.completeError(
            AdsConsentException(_lastErrorMessage!),
          );
        }
      },
    );

    try {
      await completer.future;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> showPrivacyOptionsForm() async {
    if (!isSupported) return;

    _lastErrorMessage = null;
    await ConsentForm.showPrivacyOptionsForm((formError) async {
      if (formError != null) {
        _lastErrorMessage = _formatFormError(formError);
      }
      await _refreshCachedState();
    });
  }

  Future<void> _refreshCachedState() async {
    if (!isSupported) {
      canRequestAdsListenable.value = false;
      privacyOptionsRequirementStatusListenable.value =
          PrivacyOptionsRequirementStatus.unknown;
      return;
    }

    canRequestAdsListenable.value =
        await ConsentInformation.instance.canRequestAds();
    privacyOptionsRequirementStatusListenable.value =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
  }

  String _formatFormError(FormError error) {
    return '${error.errorCode}: ${error.message}';
  }
}

class AdsConsentException implements Exception {
  AdsConsentException(this.message);

  final String message;

  @override
  String toString() => message;
}
