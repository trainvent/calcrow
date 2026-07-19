import 'package:calcrow/l10n/app_localizations.dart';
import 'package:calcrow/core/data/services/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget localizedApp({
    required Locale locale,
    required String Function(AppLocalizations localizations) text,
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(body: Text(text(context.l10n))),
      ),
    );
  }

  testWidgets('keeps English copy for the English locale', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        text: (localizations) => localizations.settings,
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('translates static copy for the German locale', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('de'),
        text: (localizations) => localizations.settings,
      ),
    );

    expect(find.text('Einstellungen'), findsOneWidget);
  });

  testWidgets('translates parameterized copy without changing user data', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('de'),
        text: (localizations) =>
            localizations.selectedLocalDocument('My Worklog.xlsx'),
      ),
    );

    expect(
      find.text('Lokales Dokument My Worklog.xlsx ausgewählt.'),
      findsOneWidget,
    );
  });

  test('translates cloud sync prompts and preserves filenames', () {
    final localizations = lookupAppLocalizations(const Locale('de'));

    expect(
      localizations.chooseOrCreateTheActiveCloudSyncFile,
      'Wähle die aktive Cloud-Synchronisierungsdatei aus oder erstelle sie.',
    );
    expect(
      localizations.chooseOrCreateTheGoogleDriveFileUsedForSync,
      'Wähle die für die Synchronisierung verwendete Google-Drive-Datei aus oder erstelle sie.',
    );
    expect(
      localizations.chooseOrCreateTheWebDAVFileUsedForSync,
      'Wähle die für die Synchronisierung verwendete WebDAV-Datei aus oder erstelle sie.',
    );
    expect(
      localizations.manageGoogleDriveSyncFile('Work Log 2026.xlsx'),
      'Google-Drive-Synchronisierungsdatei verwalten: Work Log 2026.xlsx',
    );
    expect(
      localizations.manageWebDavSyncFile('Arbeitszeit.ods'),
      'WebDAV-Synchronisierungsdatei verwalten: Arbeitszeit.ods',
    );
  });

  test('reads only supported languages from the user profile', () {
    expect(
      UserSettingsData.fromMap(const {'languageCode': 'de'}).languageCode,
      'de',
    );
    expect(
      UserSettingsData.fromMap(const {'languageCode': 'EN'}).languageCode,
      'en',
    );
    expect(
      UserSettingsData.fromMap(const {'languageCode': 'fr'}).languageCode,
      isNull,
    );
  });

  test('reads diagnostics consent choices from the user profile', () {
    final settings = UserSettingsData.fromMap(const {
      'diagnosticsConsentCompleted': true,
      'usageAnalyticsEnabled': true,
      'crashReportsEnabled': false,
    });

    expect(settings.diagnosticsConsentCompleted, isTrue);
    expect(settings.usageAnalyticsEnabled, isTrue);
    expect(settings.crashReportsEnabled, isFalse);
  });
}
