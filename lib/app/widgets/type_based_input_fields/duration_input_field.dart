import 'package:flutter/material.dart';

import 'package:calcrow/l10n/app_localizations.dart';

import 'base_input_field.dart';

class DurationInputField extends StatefulWidget {
  const DurationInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final VoidCallback? onChanged;

  @override
  State<DurationInputField> createState() => _DurationInputFieldState();
}

class _DurationInputFieldState extends State<DurationInputField> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  bool _isWritingParentController = false;

  @override
  void initState() {
    super.initState();
    final initial = _durationPartsFromStoredValue(widget.controller.text);
    _hoursController = TextEditingController(text: initial.hours);
    _minutesController = TextEditingController(text: initial.minutes);
    widget.controller.addListener(_syncFromParentController);
  }

  @override
  void didUpdateWidget(covariant DurationInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_syncFromParentController);
    widget.controller.addListener(_syncFromParentController);
    _syncFromParentController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParentController);
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseInputField(
      labelText: widget.labelText,
      hintText: widget.hintText,
      helperText: widget.helperText,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: BaseInputField.decoration(
                labelText: context.l10n.hours,
                hintText: context.l10n.zero,
                suffixText: 'h',
              ),
              onChanged: (_) => _handleDurationChanged(),
              onSubmitted: (_) => _handleDurationChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: BaseInputField.decoration(
                labelText: context.l10n.minutes,
                hintText: context.l10n.zero,
                suffixText: 'min',
              ),
              onChanged: (_) => _handleDurationChanged(),
              onSubmitted: (_) => _handleDurationChanged(),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDurationChanged() {
    final rawHours = _hoursController.text.trim();
    final rawMinutes = _minutesController.text.trim();
    _isWritingParentController = true;
    if (rawHours.isEmpty && rawMinutes.isEmpty) {
      widget.controller.clear();
      _isWritingParentController = false;
      widget.onChanged?.call();
      return;
    }
    final hours = rawHours.isEmpty ? 0 : int.tryParse(rawHours);
    final minutes = rawMinutes.isEmpty ? 0 : int.tryParse(rawMinutes);
    if (hours == null || minutes == null || hours < 0 || minutes < 0) {
      _isWritingParentController = false;
      return;
    }
    final totalSeconds = ((hours * 60) + minutes) * 60;
    widget.controller.text = _formatDuration(totalSeconds);
    _isWritingParentController = false;
    widget.onChanged?.call();
  }

  void _syncFromParentController() {
    if (_isWritingParentController) return;
    final parts = _durationPartsFromStoredValue(widget.controller.text);
    _setControllerText(_hoursController, parts.hours);
    _setControllerText(_minutesController, parts.minutes);
  }

  _DurationParts _durationPartsFromStoredValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const _DurationParts('', '');
    if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(value)) {
      final rawMinutes = double.tryParse(value.replaceAll(',', '.'));
      if (rawMinutes == null || rawMinutes < 0) {
        return const _DurationParts('', '');
      }
      return _partsFromTotalMinutes(rawMinutes.round());
    }
    final match = RegExp(r'^(\d{1,3}):(\d{2})(?::(\d{2}))?$').firstMatch(value);
    if (match == null) return const _DurationParts('', '');
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return _partsFromTotalMinutes(
      ((hours * 60) + minutes + (seconds / 60)).round(),
    );
  }

  _DurationParts _partsFromTotalMinutes(int totalMinutes) {
    final normalized = totalMinutes < 0 ? 0 : totalMinutes;
    final hours = normalized ~/ 60;
    final minutes = normalized % 60;
    return _DurationParts(
      hours == 0 ? '' : hours.toString(),
      minutes == 0 ? '' : minutes.toString(),
    );
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

@Deprecated('Use DurationInputField instead.')
typedef TimespanWidget = DurationInputField;

class _DurationParts {
  const _DurationParts(this.hours, this.minutes);

  final String hours;
  final String minutes;
}
