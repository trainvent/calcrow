import 'package:flutter/material.dart';

import 'package:calcrow/l10n/app_localizations.dart';

class WeekdayPickerWidget extends StatelessWidget {
  const WeekdayPickerWidget({
    super.key,
    required this.selectedWeekdays,
    required this.onChanged,
  });

  static const Set<int> allWeekdays = <int>{
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onChanged;

  bool get _allSelected => selectedWeekdays.length == allWeekdays.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = allWeekdays.toList(growable: false);
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          IconButton.filledTonal(
            key: const ValueKey('weekday-picker-toggle-all'),
            tooltip: _allSelected
                ? context.l10n.clearAllDays
                : context.l10n.selectAllDays,
            style: IconButton.styleFrom(
              minimumSize: const Size(38, 38),
              maximumSize: const Size(38, 38),
              padding: EdgeInsets.zero,
            ),
            onPressed: () =>
                onChanged(_allSelected ? <int>{} : Set<int>.from(allWeekdays)),
            icon: Icon(
              _allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              size: 20,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Material(
              key: const ValueKey('weekday-picker-segments'),
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  for (var index = 0; index < weekdays.length; index++) ...[
                    if (index > 0)
                      SizedBox(
                        key: ValueKey('weekday-picker-divider-$index'),
                        width: 1,
                        height: double.infinity,
                        child: ColoredBox(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    Expanded(
                      child: _WeekdaySegment(
                        weekday: weekdays[index],
                        selected: selectedWeekdays.contains(weekdays[index]),
                        onPressed: () {
                          final next = Set<int>.from(selectedWeekdays);
                          if (next.contains(weekdays[index])) {
                            next.remove(weekdays[index]);
                          } else {
                            next.add(weekdays[index]);
                          }
                          onChanged(next);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdaySegment extends StatelessWidget {
  const _WeekdaySegment({
    required this.weekday,
    required this.selected,
    required this.onPressed,
  });

  final int weekday;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('weekday-picker-day-$weekday'),
        onTap: onPressed,
        child: Ink(
          color: selected ? theme.colorScheme.primaryContainer : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                _shortWeekdayLabel(context, weekday),
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _shortWeekdayLabel(BuildContext context, int weekday) {
  return switch (weekday) {
    DateTime.monday => context.l10n.mondayShort,
    DateTime.tuesday => context.l10n.tuesdayShort,
    DateTime.wednesday => context.l10n.wednesdayShort,
    DateTime.thursday => context.l10n.thursdayShort,
    DateTime.friday => context.l10n.fridayShort,
    DateTime.saturday => context.l10n.saturdayShort,
    DateTime.sunday => context.l10n.sundayShort,
    _ => '',
  };
}
