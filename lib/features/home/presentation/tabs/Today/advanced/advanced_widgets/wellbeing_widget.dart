import 'package:flutter/material.dart';

class WellbeingWidget extends StatelessWidget {
  const WellbeingWidget({
    super.key,
    required this.moodLevel,
    required this.energyLevel,
    required this.onMoodChanged,
    required this.onEnergyChanged,
  });

  final double moodLevel;
  final double energyLevel;
  final ValueChanged<double> onMoodChanged;
  final ValueChanged<double> onEnergyChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wellbeing', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            _LabeledSlider(
              icon: Icons.sentiment_neutral_rounded,
              label: 'Mood',
              value: moodLevel,
              onChanged: onMoodChanged,
            ),
            _LabeledSlider(
              icon: Icons.favorite_border_rounded,
              label: 'Energy',
              value: energyLevel,
              onChanged: onEnergyChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
        SizedBox(width: 44, child: Text('${(value * 100).round()}%')),
      ],
    );
  }
}
