import 'package:calcrow/core/constants/internal_constants.dart';
import 'package:calcrow/core/providers/app_providers.dart';
import 'package:calcrow/features/home/settings/settings_tab.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads and stores all supported theme modes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      IConst.themeModeKey: 'dark',
    });
    expect(await loadStoredThemeMode(), ThemeMode.dark);

    final container = ProviderContainer(
      overrides: [initialThemeModeProvider.overrideWithValue(ThemeMode.system)],
    );
    addTearDown(container.dispose);

    container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(preferences.getString(IConst.themeModeKey), 'light');
  });

  test('loads and stores the allow-any-date preference', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      IConst.allowAnyDateKey: true,
    });
    expect(await loadStoredAllowAnyDate(), isTrue);

    final container = ProviderContainer(
      overrides: [initialAllowAnyDateProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);

    container.read(allowAnyDateProvider.notifier).setAllowAnyDate(true);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    expect(container.read(allowAnyDateProvider), isTrue);
    expect(preferences.getBool(IConst.allowAnyDateKey), isTrue);
  });

  testWidgets('settings offers system, light, and dark appearance modes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: SettingsTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Allow editing any date'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(
      tester
          .widget<SegmentedButton<ThemeMode>>(
            find.byType(SegmentedButton<ThemeMode>).first,
          )
          .selected,
      <ThemeMode>{ThemeMode.dark},
    );

    await tester.ensureVisible(find.text('Allow editing any date'));
    await tester.tap(find.text('Allow editing any date'));
    await tester.pump();
    expect(container.read(allowAnyDateProvider), isTrue);
  });
}
