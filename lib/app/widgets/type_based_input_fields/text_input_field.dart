import 'package:flutter/material.dart';

import 'base_input_field.dart';

class TextInputField extends StatelessWidget {
  const TextInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final TextInputType keyboardType;
  final bool readOnly;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: BaseInputField.decoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
      ),
    );
  }
}
