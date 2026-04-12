import 'package:flutter/material.dart';

import '../../../core/data/di/service_locator.dart';
import '../../../core/data/services/purchases_service.dart';
import 'free_mode_bottom_tile.dart';
import 'tabs/Settings/settings_tab.dart';
import 'tabs/Sheet/sheet_preview_tab.dart';
import 'tabs/Today/today_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _tabs = const [TodayTab(), SheetPreviewTab(), SettingsTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
      bottomNavigationBar: StreamBuilder<EntitlementTier>(
        stream: ServiceLocator.purchasesService.entitlementStream,
        initialData: ServiceLocator.purchasesService.currentTier,
        builder: (context, snapshot) {
          final tier = snapshot.data ?? EntitlementTier.free;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FreeModeBottomTile(tier: tier),
              NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_on_outlined),
                    selectedIcon: Icon(Icons.grid_on),
                    label: 'Sheet',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
