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
    required this.showBottomSeparator,
  });

  final bool isArranging;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEnterArrangeMode;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Widget compactChild;
  final List<Widget> expandedChildren;
  final bool showBottomSeparator;

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
          return _SeparatedMovingTile(
            showSeparator: showBottomSeparator,
            child: GestureDetector(
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
            ),
          );
        }

        return _SeparatedMovingTile(
          showSeparator: showBottomSeparator,
          child: GestureDetector(
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
          ),
        );
      },
    );
  }
}

class _SeparatedMovingTile extends StatelessWidget {
  const _SeparatedMovingTile({
    required this.showSeparator,
    required this.child,
  });

  final bool showSeparator;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!showSeparator) return child;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: _DashedSeparator(),
        ),
      ],
    );
  }
}

class _DashedSeparator extends StatelessWidget {
  const _DashedSeparator();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.82);
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashedSeparatorPainter(color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _DashedSeparatorPainter extends CustomPainter {
  const _DashedSeparatorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const dashWidth = 5.0;
    const dashGap = 4.0;
    final y = size.height / 2;

    for (var x = 0.0; x < size.width; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashWidth).clamp(0.0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedSeparatorPainter oldDelegate) {
    return oldDelegate.color != color;
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
