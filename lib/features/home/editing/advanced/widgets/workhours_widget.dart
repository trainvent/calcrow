import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';

class WorkhoursWidget extends StatelessWidget {
  const WorkhoursWidget({
    super.key,
    required this.startController,
    required this.endController,
    required this.breakController,
    required this.totalHours,
    required this.onChanged,
  });

  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController breakController;
  final String totalHours;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.workhours, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startController,
                    decoration: InputDecoration(labelText: context.l10n.start),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: endController,
                    decoration: InputDecoration(labelText: context.l10n.end),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: breakController,
                    decoration: InputDecoration(
                      labelText: context.l10n.pauseMin,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.total,
                      hintText: totalHours,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
