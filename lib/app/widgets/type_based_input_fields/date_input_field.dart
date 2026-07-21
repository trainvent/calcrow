import 'package:flutter/material.dart';

import 'package:calcrow/l10n/app_localizations.dart';

import 'base_input_field.dart';

class DateInputField extends StatelessWidget {
  const DateInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.parseDate,
    this.formatDate,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final DateTime? Function(String value)? parseDate;
  final String Function(DateTime value)? formatDate;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(context),
      decoration: BaseInputField.decoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        suffixIcon: IconButton(
          tooltip: context.l10n.selectDate,
          onPressed: () => _pickDate(context),
          icon: const Icon(Icons.calendar_today_rounded),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final parsed =
        parseDate?.call(controller.text.trim()) ??
        DateTime.tryParse(controller.text.trim());
    final initial = parsed ?? DateTime.now();
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100);
    final safeInitial = initial.isBefore(firstDate)
        ? firstDate
        : initial.isAfter(lastDate)
        ? lastDate
        : initial;
    final selected = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !context.mounted) return;
    controller.text = formatDate?.call(selected) ?? _formatIsoDate(selected);
    onChanged?.call();
  }

  String _formatIsoDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
