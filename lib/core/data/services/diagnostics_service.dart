import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticsService {
  DiagnosticsService._();

  static const String _usageAnalyticsPrefsKey = 'usage_analytics_enabled';
  static const String _crashReportsPrefsKey = 'crash_reports_enabled';
  static const String _consentAskedPrefsKey = 'diagnostics_consent_asked';

  static final DiagnosticsService instance = DiagnosticsService._();

  final ValueNotifier<bool> usageAnalyticsEnabledListenable =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> crashReportsEnabledListenable =
      ValueNotifier<bool>(false);

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _hasAskedForConsent = false;

  bool get usageAnalyticsEnabled => usageAnalyticsEnabledListenable.value;
  bool get crashReportsEnabled => crashReportsEnabledListenable.value;
  bool get hasAskedForConsent => _hasAskedForConsent;
  bool get needsConsentPrompt =>
      supportsUsageAnalytics && !_hasAskedForConsent;

  bool get supportsUsageAnalytics => _supportsAnalytics;
  bool get supportsCrashReports => _supportsCrashAndPerformance;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final analyticsEnabled =
        _prefs?.getBool(_usageAnalyticsPrefsKey) ?? false;
    final crashReportsEnabled =
        _prefs?.getBool(_crashReportsPrefsKey) ?? false;
    _hasAskedForConsent = _prefs?.getBool(_consentAskedPrefsKey) ?? false;

    usageAnalyticsEnabledListenable.value =
        _supportsAnalytics ? analyticsEnabled : false;
    crashReportsEnabledListenable.value =
        _supportsCrashAndPerformance ? crashReportsEnabled : false;

    if (_supportsAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        analyticsEnabled,
      );
    }
    if (_supportsCrashAndPerformance) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashReportsEnabled,
      );
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        crashReportsEnabled,
      );
      if (!crashReportsEnabled) {
        await FirebaseCrashlytics.instance.deleteUnsentReports();
      }
    }

    _initialized = true;
  }

  Future<void> setUsageAnalyticsEnabled(bool enabled) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsAnalytics) return;
    if (enabled == usageAnalyticsEnabled) return;

    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    await _prefs?.setBool(_usageAnalyticsPrefsKey, enabled);
    await _prefs?.setBool(_consentAskedPrefsKey, true);
    _hasAskedForConsent = true;
    usageAnalyticsEnabledListenable.value = enabled;
  }

  Future<void> setCrashReportsEnabled(bool enabled) async {
    if (!_initialized) {
      await init();
    }
    if (!_supportsCrashAndPerformance) return;
    if (enabled == crashReportsEnabled) return;

    if (!enabled) {
      await FirebaseCrashlytics.instance.deleteUnsentReports();
    }
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(enabled);
    await _prefs?.setBool(_crashReportsPrefsKey, enabled);
    await _prefs?.setBool(_consentAskedPrefsKey, true);
    _hasAskedForConsent = true;
    crashReportsEnabledListenable.value = enabled;
  }

  Future<void> saveConsentChoices({
    required bool usageAnalyticsEnabled,
    required bool crashReportsEnabled,
  }) async {
    if (!_initialized) {
      await init();
    }

    if (_supportsAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        usageAnalyticsEnabled,
      );
      await _prefs?.setBool(
        _usageAnalyticsPrefsKey,
        usageAnalyticsEnabled,
      );
      usageAnalyticsEnabledListenable.value = usageAnalyticsEnabled;
    }

    if (_supportsCrashAndPerformance) {
      if (!crashReportsEnabled) {
        await FirebaseCrashlytics.instance.deleteUnsentReports();
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashReportsEnabled,
      );
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        crashReportsEnabled,
      );
      await _prefs?.setBool(_crashReportsPrefsKey, crashReportsEnabled);
      crashReportsEnabledListenable.value = crashReportsEnabled;
    }

    await _prefs?.setBool(_consentAskedPrefsKey, true);
    _hasAskedForConsent = true;
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_supportsCrashAndPerformance || !crashReportsEnabled) return;
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  Future<void> log(String message) async {
    if (!_supportsCrashAndPerformance || !crashReportsEnabled) return;
    await FirebaseCrashlytics.instance.log(message);
  }

  bool get _supportsAnalytics {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  bool get _supportsCrashAndPerformance {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }
}

Future<void> installDiagnosticsErrorHandlers() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      DiagnosticsService.instance.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: details.context?.toDescription(),
        fatal: false,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      DiagnosticsService.instance.recordError(
        error,
        stack,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      ),
    );
    return true;
  };
}
