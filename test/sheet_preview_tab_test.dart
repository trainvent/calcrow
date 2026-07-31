import 'package:calcrow/features/home/sheet/sheet_preview_store.dart';
import 'package:calcrow/features/home/sheet/sheet_preview_tab.dart';
import 'package:calcrow/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('shows the last 100 rows from a large opened sheet', (
    tester,
  ) async {
    container
        .read(sheetPreviewProvider.notifier)
        .setData(
          SheetPreviewData(
            headers: const ['Entry'],
            rows: List.generate(205, (index) => ['entry-$index']),
            fileName: 'archive.xlsx',
            rowCount: 205,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SheetPreviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('entry-0'), findsNothing);
    expect(find.text('entry-104'), findsNothing);
    expect(find.text('entry-105'), findsOneWidget);
    expect(find.text('entry-204'), findsOneWidget);
    expect(find.text('205 rows'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('sheet-preview-page-title')))
          .style,
      AppTextStyles.pageTitle,
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text(' > 106)'), findsOneWidget);
    expect(find.text(' • 1 column'), findsOneWidget);
    final visibleEntryLabels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .where((text) => text.startsWith('entry-'))
        .toList();
    expect(visibleEntryLabels.first, 'entry-105');
    expect(visibleEntryLabels.last, 'entry-204');
  });

  testWidgets('maps a picked tail row to its original sheet index', (
    tester,
  ) async {
    container
        .read(sheetPreviewProvider.notifier)
        .setData(
          SheetPreviewData(
            headers: const ['Entry'],
            rows: List.generate(205, (index) => ['entry-$index']),
            fileName: 'archive.xlsx',
            rowCount: 205,
          ),
        );
    container
        .read(sheetPreviewActionsProvider.notifier)
        .beginRowPick(
          const SheetPreviewRowPickRequest(
            selectableRowIndexes: {204},
            title: 'Pick Entry',
            subtitle: 'Choose a row',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SheetPreviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('entry-204'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(sheetPreviewPickedRowProvider), 204);
  });

  testWidgets('highlights the currently selected sheet row in green', (
    tester,
  ) async {
    container
        .read(sheetPreviewProvider.notifier)
        .setData(
          const SheetPreviewData(
            headers: ['Entry'],
            rows: [
              ['first'],
              ['selected'],
            ],
            fileName: 'current.xlsx',
            rowCount: 2,
            selectedRowIndex: 1,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SheetPreviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    final table = tester.widget<DataTable>(find.byType(DataTable));
    final selectedRow = table.rows.singleWhere(
      (row) => row.key == const ValueKey('sheet-preview-row-1'),
    );
    final rowColor = selectedRow.color?.resolve(<WidgetState>{});

    expect(rowColor, isNotNull);
    expect(rowColor!.g, greaterThan(rowColor.r));
    expect(rowColor.g, greaterThan(rowColor.b));
  });

  testWidgets('shows the active worksheet beside the file name', (
    tester,
  ) async {
    container
        .read(sheetPreviewProvider.notifier)
        .setData(
          const SheetPreviewData(
            headers: ['Entry'],
            rows: [
              ['first'],
            ],
            fileName: 'current.xlsx',
            rowCount: 1,
            sheetName: 'July 2026',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SheetPreviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('current.xlsx'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sheet-preview-active-sheet')),
      findsOneWidget,
    );
    expect(find.text('• Active sheet: July 2026'), findsOneWidget);
  });
}
