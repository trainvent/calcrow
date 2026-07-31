import 'package:flutter/material.dart';

/// A provider-neutral location in a remote filesystem breadcrumb trail.
class RemoteBrowserLocation<T> {
  const RemoteBrowserLocation({required this.id, required this.name});

  final T id;
  final String name;
}

/// Responsive presentation shell for API-backed file browsers.
///
/// The host owns provider authentication, loading, filtering, and mutations.
/// This widget owns only the platform-adaptive browser layout, so it can be
/// reused with Google Drive, WebDAV, S3, or another hierarchical backend.
class RemoteFileBrowserShell<T> extends StatelessWidget {
  const RemoteFileBrowserShell({
    super.key,
    required this.title,
    required this.locations,
    required this.searchController,
    required this.query,
    required this.searchHint,
    required this.clearSearchTooltip,
    required this.refreshTooltip,
    required this.onSearchChanged,
    required this.onNavigateToLocation,
    required this.onRefresh,
    required this.body,
    required this.actions,
  });

  final String title;
  final List<RemoteBrowserLocation<T>> locations;
  final TextEditingController searchController;
  final String query;
  final String searchHint;
  final String clearSearchTooltip;
  final String refreshTooltip;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onNavigateToLocation;
  final VoidCallback onRefresh;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    assert(locations.isNotEmpty);
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final content = SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 24,
          isCompact ? 12 : 20,
          isCompact ? 16 : 24,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
                IconButton(
                  tooltip: refreshTooltip,
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: locations.length,
                separatorBuilder: (context, index) =>
                    const Icon(Icons.chevron_right_rounded, size: 18),
                itemBuilder: (context, index) {
                  final isCurrent = index == locations.length - 1;
                  return TextButton.icon(
                    onPressed: isCurrent
                        ? null
                        : () => onNavigateToLocation(index),
                    icon: Icon(
                      index == 0 ? Icons.cloud_outlined : Icons.folder_outlined,
                      size: 18,
                    ),
                    label: Text(locations[index].name),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SearchBar(
              key: const ValueKey('remote-file-browser-search'),
              controller: searchController,
              hintText: searchHint,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (query.isNotEmpty)
                  IconButton(
                    tooltip: clearSearchTooltip,
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: body),
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );

    if (isCompact) return Dialog.fullscreen(child: content);
    final height = (MediaQuery.sizeOf(context).height - 48)
        .clamp(420.0, 720.0)
        .toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(width: 880, height: height, child: content),
    );
  }
}
