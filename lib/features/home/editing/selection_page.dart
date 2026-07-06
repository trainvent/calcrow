import 'package:flutter/material.dart';

import 'simple/create_doc_page.dart';
import 'simple/editing_page.dart';

class SelectionPage extends StatelessWidget {
  const SelectionPage({super.key});

  Future<void> _openDocument(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const EditingPage(
          openDocumentOnStart: true,
          showBackToSelection: true,
        ),
      ),
    );
  }

  Future<void> _createDocument(BuildContext context) async {
    final draft = await Navigator.of(context).push<SimpleDocumentDraft>(
      MaterialPageRoute(builder: (context) => const CreateDocPage()),
    );
    if (!context.mounted || draft == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            EditingPage(initialDocumentDraft: draft, showBackToSelection: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Get Started',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SelectionActionCard(
          icon: Icons.folder_open_rounded,
          title: 'Choose Document',
          subtitle: 'Open an existing CSV, XLSX, or ODS sheet.',
          onTap: () => _openDocument(context),
        ),
        const SizedBox(height: 14),
        _SelectionActionCard(
          icon: Icons.add_circle_outline_rounded,
          title: 'Create Document',
          subtitle: 'Define fields first, then save the new sheet.',
          onTap: () => _createDocument(context),
        ),
      ],
    );
  }
}

class _SelectionActionCard extends StatelessWidget {
  const _SelectionActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
