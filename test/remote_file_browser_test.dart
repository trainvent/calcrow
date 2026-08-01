import 'package:calcrow/app/widgets/remote_file_browser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('folder prompt remains safe while closing after submission', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showRemoteFolderNameDialog(
                context: context,
                title: 'New folder',
                fieldLabel: 'Folder name',
                invalidNameMessage: 'Invalid folder name',
                cancelLabel: 'Cancel',
                createLabel: 'Create',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-folder-name')),
      'Reports',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, 'Reports');
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote browser shell exposes search and breadcrumb callbacks', (
    tester,
  ) async {
    final searchController = TextEditingController();
    var query = '';
    var navigatedTo = -1;
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => RemoteFileBrowserShell<String?>(
            title: 'Choose file',
            locations: const [
              RemoteBrowserLocation<String?>(id: null, name: 'Drive'),
              RemoteBrowserLocation<String?>(id: 'work', name: 'Work'),
            ],
            searchController: searchController,
            query: query,
            searchHint: 'Search this folder',
            clearSearchTooltip: 'Clear search',
            refreshTooltip: 'Refresh folder',
            onSearchChanged: (value) => query = value,
            onNavigateToLocation: (index) => navigatedTo = index,
            onRefresh: () => refreshed = true,
            body: const Text('Browser entries'),
            actions: const [Text('Action')],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('remote-file-browser-search')),
      'report',
    );
    await tester.tap(find.text('Drive'));
    await tester.tap(find.byTooltip('Refresh folder'));

    expect(query, 'report');
    expect(navigatedTo, 0);
    expect(refreshed, isTrue);
    expect(find.text('Browser entries'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    searchController.dispose();
  });
}
