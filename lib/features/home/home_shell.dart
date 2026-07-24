import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcrow/l10n/app_localizations.dart';

import 'package:calcrow/core/providers/app_providers.dart';

import '../../app/widgets/free_mode_bottom_tile.dart';
import 'editing/selection_page.dart';
import 'settings/settings_tab.dart';
import 'sheet/sheet_preview_tab.dart';
import 'sheet/sheet_preview_store.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  final _tabs = const [SelectionPage(), SheetPreviewTab(), SettingsTab()];

  void _handleRequestedTabIndex(int? requestedIndex) {
    if (requestedIndex == null) return;
    if (requestedIndex < 0 || requestedIndex >= _tabs.length) {
      ref.read(sheetPreviewRequestedTabProvider.notifier).emit(null);
      return;
    }
    if (requestedIndex != _currentIndex) {
      setState(() => _currentIndex = requestedIndex);
    }
    ref.read(sheetPreviewRequestedTabProvider.notifier).emit(null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      sheetPreviewRequestedTabProvider,
      (previous, next) => _handleRequestedTabIndex(next),
    );
    final tier =
        ref.watch(entitlementTierProvider).asData?.value ??
        ref.read(purchasesServiceProvider).currentTier;
    final rowPickRequest = ref.watch(sheetPreviewRowPickProvider);
    final isPickingRow = rowPickRequest != null;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _tabs),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FreeModeBottomTile(tier: tier),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              if (isPickingRow && index != 1) return;
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: _PickLockedNavIcon(
                  locked: isPickingRow,
                  child: const _SingleRowNavIcon(selected: false),
                ),
                selectedIcon: _PickLockedNavIcon(
                  locked: isPickingRow,
                  child: const _SingleRowNavIcon(selected: true),
                ),
                label: context.l10n.row,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_on_outlined),
                selectedIcon: const Icon(Icons.grid_on),
                label: context.l10n.sheet,
              ),
              NavigationDestination(
                icon: _PickLockedNavIcon(
                  locked: isPickingRow,
                  child: const Icon(Icons.settings_outlined),
                ),
                selectedIcon: _PickLockedNavIcon(
                  locked: isPickingRow,
                  child: const Icon(Icons.settings),
                ),
                label: context.l10n.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickLockedNavIcon extends StatelessWidget {
  const _PickLockedNavIcon({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Opacity(
      opacity: 0.38,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
        child: child,
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
