import 'package:flutter/material.dart';

class TimespanWidget extends StatefulWidget {
  const TimespanWidget({
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
  State<TimespanWidget> createState() => _TimespanWidgetState();
}

class _TimespanWidgetState extends State<TimespanWidget> {
  late final TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _minutesController = TextEditingController(
      text: _minutesFromStoredValue(widget.controller.text),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _minutesController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText ?? 'Minutes (e.g. 30)',
        helperText: widget.helperText,
        suffixText: 'min',
      ),
      onChanged: _handleMinutesChanged,
      onSubmitted: _handleMinutesChanged,
    );
  }

  void _handleMinutesChanged(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      widget.controller.text = '00:00:00';
      return;
    }
    final minutes = double.tryParse(normalized);
    if (minutes == null) return;
    final totalSeconds = (minutes * 60).round();
    if (totalSeconds < 0) return;
    widget.controller.text = _formatDuration(totalSeconds);
  }

  String _minutesFromStoredValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(value)) {
      return value.replaceAll(',', '.');
    }

    final match = RegExp(r'^(\d{1,3}):(\d{2})(?::(\d{2}))?$').firstMatch(value);
    if (match == null) return '';

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    final totalMinutes = (hours * 60) + minutes + (seconds / 60);
    if (seconds == 0) return totalMinutes.round().toString();
    return totalMinutes.toStringAsFixed(2);
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
