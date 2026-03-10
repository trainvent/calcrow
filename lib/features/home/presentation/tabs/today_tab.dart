import 'package:flutter/material.dart';

import '../../../../core/data/di/service_locator.dart';
import '../../../../core/data/services/auth_service.dart';
import 'advanced/today_page_advanced.dart';
import 'today_page.dart';

class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ServiceLocator.isSetup) {
      return const TodayPage();
    }
    return StreamBuilder<AuthSession?>(
      stream: ServiceLocator.authService.authStateChanges(),
      initialData: ServiceLocator.authService.currentSession,
      builder: (context, authSnapshot) {
        final session = authSnapshot.data;
        if (session == null) {
          return const TodayPage();
        }
        return StreamBuilder<Map<String, dynamic>?>(
          stream: ServiceLocator.dbService.watchUserSettings(session.uid),
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data;
            final advancedEnabled =
                settings?['advancedFeaturesEnabled'] == true;
            if (advancedEnabled) {
              return const TodayPageAdvanced();
            }
            return const TodayPage();
          },
        );
      },
    );
  }
}
