import 'package:flutter/material.dart';

import 'package:calcrow/core/data/di/service_locator.dart';
import 'package:calcrow/core/data/services/purchases_service.dart';

import '../../app/widgets/free_mode_bottom_tile.dart';
import 'editing/selection_page.dart';
import 'settings/settings_tab.dart';
import 'sheet/sheet_preview_tab.dart';
import 'sheet/sheet_preview_store.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _tabs = const [SelectionPage(), SheetPreviewTab(), SettingsTab()];

  @override
  void initState() {
    super.initState();
    SheetPreviewStore.requestedTabIndex.addListener(_handleRequestedTabIndex);
  }

  @override
  void dispose() {
    SheetPreviewStore.requestedTabIndex.removeListener(
      _handleRequestedTabIndex,
    );
    super.dispose();
  }

  void _handleRequestedTabIndex() {
    final requestedIndex = SheetPreviewStore.requestedTabIndex.value;
    if (requestedIndex == null) return;
    if (requestedIndex < 0 || requestedIndex >= _tabs.length) {
      SheetPreviewStore.requestedTabIndex.value = null;
      return;
    }
    if (requestedIndex != _currentIndex) {
      setState(() => _currentIndex = requestedIndex);
    }
    SheetPreviewStore.requestedTabIndex.value = null;
  }

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
                    icon: _SingleRowNavIcon(selected: false),
                    selectedIcon: _SingleRowNavIcon(selected: true),
                    label: 'Row',
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

class _SingleRowNavIcon extends StatelessWidget {
  const _SingleRowNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: 24,
      height: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: selected ? 1.8 : 1.4),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Container(
            height: selected ? 2.4 : 1.8,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
