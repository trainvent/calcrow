import 'package:calcrow/app/widgets/weekday_picker_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('weekday picker keeps one row and toggles all days', (
    tester,
  ) async {
    var selected = Set<int>.from(WeekdayPickerWidget.allWeekdays);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => WeekdayPickerWidget(
              selectedWeekdays: selected,
              onChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    final toggleAll = find.byKey(const ValueKey('weekday-picker-toggle-all'));
    expect(find.byTooltip('Clear all days'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Mon')).dy,
      tester.getCenter(find.text('Sun')).dy,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'weekday-picker-divider-',
            ),
      ),
      findsNWidgets(6),
    );

    await tester.tap(toggleAll);
    await tester.pump();
    expect(selected, isEmpty);
    expect(find.byTooltip('Select all days'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weekday-picker-day-3')));
    await tester.pump();
    expect(selected, <int>{DateTime.wednesday});

    await tester.tap(toggleAll);
    await tester.pump();
    expect(selected, WeekdayPickerWidget.allWeekdays);
  });
}
