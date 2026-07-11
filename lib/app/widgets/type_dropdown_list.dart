import 'package:flutter/material.dart';

import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:calcrow/core/sheet_type_logic/field_type.dart';

class TypeDropdownList<T> extends StatelessWidget {
  const TypeDropdownList({
    super.key,
    required this.initialValue,
    required this.labelText,
    required this.options,
    required this.labelFor,
    required this.iconFor,
    required this.onChanged,
  });

  final T initialValue;
  final String labelText;
  final List<T> options;
  final String Function(T value) labelFor;
  final IconData Function(T value) iconFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      decoration: InputDecoration(labelText: labelText),
      items: options
          .map(
            (option) => DropdownMenuItem<T>(
              value: option,
              child: _TypeDropdownItem(
                icon: iconFor(option),
                label: labelFor(option),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }

  static IconData iconForFieldType(FieldType type) {
    return switch (type) {
      FieldType.text => Icons.notes_rounded,
      FieldType.date => Icons.calendar_today_rounded,
      FieldType.time => Icons.schedule_rounded,
      FieldType.duration => Icons.timer_outlined,
      FieldType.integer => Icons.pin_rounded,
      FieldType.float => Icons.tag_rounded,
      FieldType.money => Icons.payments_outlined,
      FieldType.boolean => Icons.toggle_on_outlined,
      FieldType.email => Icons.alternate_email_rounded,
      FieldType.phone => Icons.phone_rounded,
    };
  }

  static IconData iconForTypeLabel(String rawType) {
    final type = FieldTypeGuesser.normalizeTypeLabel(rawType).toLowerCase();
    if (FieldTypeGuesser.isMoneyType(rawType) || type == 'money') {
      return Icons.payments_outlined;
    }
    if (FieldTypeGuesser.isBooleanType(rawType) || type == 'boolean') {
      return Icons.toggle_on_outlined;
    }
    if (type == 'duration' || type == 'timespan') {
      return Icons.timer_outlined;
    }
    switch (type) {
      case 'date':
        return Icons.calendar_today_rounded;
      case 'time':
        return Icons.schedule_rounded;
      case 'int':
      case 'integer':
      case 'number':
        return Icons.pin_rounded;
      case 'float':
      case 'double':
      case 'decimal':
        return Icons.tag_rounded;
      case 'email':
        return Icons.alternate_email_rounded;
      case 'phone':
        return Icons.phone_rounded;
      default:
        return Icons.notes_rounded;
    }
  }
}

class _TypeDropdownItem extends StatelessWidget {
  const _TypeDropdownItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
