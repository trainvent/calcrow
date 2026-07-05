import 'package:flutter/material.dart';

class MovingTileWidget extends StatelessWidget {
  const MovingTileWidget({
    super.key,
    required this.isArranging,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEnterArrangeMode,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.compactChild,
    required this.expandedChildren,
  });

  final bool isArranging;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEnterArrangeMode;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Widget compactChild;
  final List<Widget> expandedChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        final arrangeControls = AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: !isArranging
              ? const SizedBox.shrink()
              : _ColumnArrangeControls(
                  canMoveUp: canMoveUp,
                  canMoveDown: canMoveDown,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                ),
        );

        if (isCompact) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onEnterArrangeMode,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isArranging) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: arrangeControls,
                    ),
                    const SizedBox(height: 6),
                  ],
                  compactChild,
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onEnterArrangeMode,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isArranging) ...[
                  arrangeControls,
                  const SizedBox(width: 10),
                ],
                ...expandedChildren,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColumnArrangeControls extends StatelessWidget {
  const _ColumnArrangeControls({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Move up',
          onPressed: canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          tooltip: 'Move down',
          onPressed: canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}
