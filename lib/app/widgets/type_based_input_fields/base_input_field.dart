import 'package:flutter/material.dart';

class BaseInputField extends StatelessWidget {
  const BaseInputField({
    super.key,
    required this.labelText,
    required this.child,
    this.hintText,
    this.helperText,
  });

  final String labelText;
  final String? hintText;
  final String? helperText;
  final Widget child;

  static InputDecoration decoration({
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: decoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
      ),
      child: child,
    );
  }
}
