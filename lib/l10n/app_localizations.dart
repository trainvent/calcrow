import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

class AppLanguageController {
  AppLanguageController._();

  static final ValueNotifier<String?> languageCode = ValueNotifier<String?>(
    null,
  );

  static const supportedLanguageCodes = <String>{'en', 'de'};

  static void setLanguageCode(String? value) {
    languageCode.value = supportedLanguageCodes.contains(value) ? value : null;
  }

  static Locale? get locale {
    final value = languageCode.value;
    return value == null ? null : Locale(value);
  }
}

extension AppLocalizationBuildContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(
        Localizations.maybeLocaleOf(this) ?? const Locale('en'),
      );
}
