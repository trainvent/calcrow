import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';

class NotesWidget extends StatelessWidget {
  const NotesWidget({
    super.key,
    required this.notesController,
    required this.onClearNote,
  });

  final TextEditingController notesController;
  final VoidCallback onClearNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.notes, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: context.l10n.focusBlockersWins,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearNote,
                icon: const Icon(Icons.clear_rounded),
                label: Text(context.l10n.clearNote),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
