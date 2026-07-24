import 'package:flutter/material.dart';

/// A consistent pair of secondary and primary text actions.
///
/// The secondary action is rendered first as an outlined button and the
/// primary action is rendered second as a filled button. A null callback
/// disables its corresponding action.
class DualTextButton extends StatelessWidget {
  const DualTextButton({
    super.key,
    required this.secondaryLabel,
    required this.onSecondaryPressed,
    this.secondaryIcon,
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final String secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final IconData? secondaryIcon;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onSecondaryPressed,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (secondaryIcon != null) ...[
                      Icon(secondaryIcon, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(secondaryLabel),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: onPrimaryPressed,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(primaryLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
