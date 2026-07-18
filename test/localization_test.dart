import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget localizedApp({required Locale locale, required String text}) {
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: LText(text)),
    );
  }

  testWidgets('keeps English copy for the English locale', (tester) async {
    await tester.pumpWidget(
      localizedApp(locale: const Locale('en'), text: 'Settings'),
    );

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('translates static copy for the German locale', (tester) async {
    await tester.pumpWidget(
      localizedApp(locale: const Locale('de'), text: 'Settings'),
    );

    expect(find.text('Einstellungen'), findsOneWidget);
  });

  testWidgets('translates parameterized copy without changing user data', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('de'),
        text: 'Selected local document My Worklog.xlsx.',
      ),
    );

    expect(
      find.text('Lokales Dokument My Worklog.xlsx ausgewählt.'),
      findsOneWidget,
    );
  });
}
