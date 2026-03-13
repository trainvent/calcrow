import 'package:flutter/material.dart';

class SelectTimeWidget extends StatelessWidget {
  const SelectTimeWidget({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickTime(context),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        suffixIcon: const Icon(Icons.schedule_rounded),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final initialTime = _parseTime(controller.text.trim()) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;
    controller.text = _formatTime(picked);
  }

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) return null;

    final baseMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$')
        .firstMatch(value);
    if (baseMatch != null) {
      final hour = int.tryParse(baseMatch.group(1) ?? '');
      final minute = int.tryParse(baseMatch.group(2) ?? '');
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final amPmMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)$',
            caseSensitive: false)
        .firstMatch(value);
    if (amPmMatch != null) {
      var hour = int.tryParse(amPmMatch.group(1) ?? '');
      final minute = int.tryParse(amPmMatch.group(2) ?? '');
      final meridiem = (amPmMatch.group(3) ?? '').toUpperCase();
      if (hour == null || minute == null) return null;
      if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return null;
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}
