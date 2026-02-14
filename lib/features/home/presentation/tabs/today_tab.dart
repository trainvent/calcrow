import 'package:flutter/material.dart';

import 'advanced/today_tab_advanced.dart';
import 'simple/today_tab_simple.dart';

enum TodayMode { simple, advanced }

/// Compatibility wrapper.
///
/// The actual implementations live in:
/// - `tabs/simple/today_tab_simple.dart`
/// - `tabs/advanced/today_tab_advanced.dart`
class TodayTab extends StatelessWidget {
  const TodayTab({
    super.key,
    this.initialMode = TodayMode.simple,
    this.allowModeSwitch = false,
  });

  final TodayMode initialMode;
  final bool allowModeSwitch;

  @override
  Widget build(BuildContext context) {
    if (initialMode == TodayMode.advanced) {
      return const TodayTabAdvanced();
    }
    return const TodayTabSimple();
  }
}
