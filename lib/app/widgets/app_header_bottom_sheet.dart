import 'package:flutter/material.dart';

Future<T?> showAppHeaderBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double appBarHeight = kToolbarHeight,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  final mediaQuery = MediaQuery.of(context);
  final sheetHeight =
      mediaQuery.size.height - mediaQuery.padding.top - appBarHeight;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: mediaQuery.size.width),
    builder: (sheetContext) => SizedBox(
      width: double.infinity,
      height: sheetHeight,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      ),
    ),
  );
}

class AppHeaderBottomSheet extends StatelessWidget {
  const AppHeaderBottomSheet({
    super.key,
    required this.closeTooltip,
    required this.content,
    this.title,
    this.header,
    this.footer,
    this.onClose,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 20, 20, 24),
  }) : assert((title == null) != (header == null));

  final String? title;
  final Widget? header;
  final String closeTooltip;
  final Widget content;
  final Widget? footer;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child:
                      header ?? Text(title!, style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: closeTooltip,
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: contentPadding,
              child: content,
            ),
          ),
          if (footer != null) ...[
            const Divider(height: 1),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}
