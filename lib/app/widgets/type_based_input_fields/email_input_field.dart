import 'package:flutter/material.dart';

import 'text_input_field.dart';

class EmailInputField extends StatelessWidget {
  const EmailInputField({
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
    return TextInputField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      readOnly: readOnly,
      keyboardType: TextInputType.emailAddress,
      onChanged: onChanged,
    );
  }
}
