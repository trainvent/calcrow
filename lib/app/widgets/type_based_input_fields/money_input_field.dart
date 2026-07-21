import 'package:flutter/material.dart';

import 'decimal_input_field.dart';

class MoneyInputField extends StatelessWidget {
  const MoneyInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.readOnly = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecimalInputField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      readOnly: readOnly,
      onChanged: onChanged,
    );
  }
}
