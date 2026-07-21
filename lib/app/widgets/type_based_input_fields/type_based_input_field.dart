import 'package:flutter/material.dart';

import 'package:calcrow/core/sheet_type_logic/field_type.dart';
import 'package:calcrow/l10n/app_localizations.dart';

import 'boolean_input_field.dart';
import 'date_input_field.dart';
import 'decimal_input_field.dart';
import 'duration_input_field.dart';
import 'email_input_field.dart';
import 'integer_input_field.dart';
import 'money_input_field.dart';
import 'phone_input_field.dart';
import 'text_input_field.dart';
import 'time_input_field.dart';

class TypeBasedInputField extends StatelessWidget {
  const TypeBasedInputField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.rawType,
    this.hintText,
    this.helperText,
    this.readOnly = false,
    this.forceDuration = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.parseDate,
    this.formatDate,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String rawType;
  final String? hintText;
  final String? helperText;
  final bool readOnly;
  final bool forceDuration;
  final int minLines;
  final int maxLines;
  final DateTime? Function(String value)? parseDate;
  final String Function(DateTime value)? formatDate;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final type = forceDuration
        ? FieldType.duration
        : FieldType.fromString(rawType);
    final resolvedHint = hintText ?? defaultHintForType(context, type);
    if (readOnly) {
      return TextInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        readOnly: true,
        minLines: minLines,
        maxLines: maxLines,
      );
    }
    return switch (type) {
      FieldType.date => DateInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        parseDate: parseDate,
        formatDate: formatDate,
        onChanged: onChanged,
      ),
      FieldType.time => TimeInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: onChanged,
      ),
      FieldType.duration => DurationInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: onChanged,
      ),
      FieldType.boolean => BooleanInputField(
        controller: controller,
        labelText: labelText,
        helperText: helperText,
        trueLabel: context.l10n.trueLabel,
        falseLabel: context.l10n.falseLabel,
        onChanged: onChanged,
      ),
      FieldType.integer => IntegerInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: (_) => onChanged?.call(),
      ),
      FieldType.float => DecimalInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: (_) => onChanged?.call(),
      ),
      FieldType.money => MoneyInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: (_) => onChanged?.call(),
      ),
      FieldType.email => EmailInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: (_) => onChanged?.call(),
      ),
      FieldType.phone => PhoneInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        onChanged: (_) => onChanged?.call(),
      ),
      FieldType.text => TextInputField(
        controller: controller,
        labelText: labelText,
        hintText: resolvedHint,
        helperText: helperText,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: (_) => onChanged?.call(),
      ),
    };
  }

  static String? defaultHintForType(BuildContext context, FieldType type) {
    return switch (type) {
      FieldType.date => context.l10n.yyyyMmDd,
      FieldType.time => context.l10n.hhMmSs,
      FieldType.duration => context.l10n.minutesOrHHMMSS,
      FieldType.integer => context.l10n.exampleInteger,
      FieldType.float || FieldType.money => context.l10n.exampleDecimal,
      FieldType.boolean => context.l10n.trueOrFALSE,
      FieldType.email => context.l10n.exampleEmail,
      FieldType.phone => context.l10n.examplePhone,
      FieldType.text => null,
    };
  }
}
