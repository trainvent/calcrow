import 'package:flutter/material.dart';

import 'base_input_field.dart';

class BooleanInputField extends StatefulWidget {
  const BooleanInputField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.trueLabel,
    required this.falseLabel,
    this.helperText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String trueLabel;
  final String falseLabel;
  final String? helperText;
  final VoidCallback? onChanged;

  @override
  State<BooleanInputField> createState() => _BooleanInputFieldState();
}

class _BooleanInputFieldState extends State<BooleanInputField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant BooleanInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rawValue = widget.controller.text.trim().toUpperCase();
    final selected = rawValue == 'TRUE'
        ? const <bool>{true}
        : rawValue == 'FALSE'
        ? const <bool>{false}
        : const <bool>{};
    return BaseInputField(
      labelText: widget.labelText,
      helperText: widget.helperText,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: true,
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.trueLabel),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: const Icon(Icons.close_rounded),
              label: Text(widget.falseLabel),
            ),
          ],
          selected: selected,
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            widget.controller.text = selection.isEmpty
                ? ''
                : selection.first
                ? 'TRUE'
                : 'FALSE';
            widget.onChanged?.call();
          },
        ),
      ),
    );
  }
}
