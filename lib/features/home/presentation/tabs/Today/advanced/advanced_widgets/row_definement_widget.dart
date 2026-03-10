import 'package:flutter/material.dart';

class RowDefinementWidget extends StatelessWidget {
  const RowDefinementWidget({
    super.key,
    required this.dateController,
  });

  final TextEditingController dateController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Row-Definement', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Date'),
            ),
          ],
        ),
      ),
    );
  }
}
