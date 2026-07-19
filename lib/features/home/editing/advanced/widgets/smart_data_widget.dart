import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';

class SmartDataWidget extends StatelessWidget {
  const SmartDataWidget({super.key, required this.energyLevel});

  final double energyLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.smartData, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoTag(label: context.l10n.steps, value: '7500'),
                _InfoTag(label: context.l10n.location, value: 'Bielefeld'),
                _InfoTag(
                  label: context.l10n.health,
                  value: '${(energyLevel * 100).round()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAE0D6)),
      ),
      child: Text('$label: $value'),
    );
  }
}
