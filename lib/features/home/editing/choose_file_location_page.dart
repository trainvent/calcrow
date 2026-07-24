import 'package:flutter/material.dart';
import 'package:trainvent_general/trainvent_general.dart';

import 'package:calcrow/l10n/app_localizations.dart';

enum CreateDestination { local, cloud }

class ChooseFileLocationPage extends StatefulWidget {
  const ChooseFileLocationPage({
    super.key,
    this.showLocal = true,
    this.onSelected,
  });

  final bool showLocal;
  final Future<bool> Function(CreateDestination destination)? onSelected;

  @override
  State<ChooseFileLocationPage> createState() => _ChooseFileLocationPageState();
}

class _ChooseFileLocationPageState extends State<ChooseFileLocationPage> {
  bool _isSelecting = false;

  Future<void> _select(CreateDestination destination) async {
    if (_isSelecting) return;
    if (widget.onSelected == null) {
      Navigator.of(context).pop(destination);
      return;
    }

    setState(() => _isSelecting = true);
    try {
      final completed = await widget.onSelected!(destination);
      if (mounted && completed) Navigator.of(context).pop(destination);
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.chooseFileLocation)),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.showLocal)
                          _LocationCard(
                            icon: Icons.folder_open_rounded,
                            title: context.l10n.local,
                            subtitle:
                                context.l10n.chooseASaveLocationOnThisDevice,
                            onTap: () => _select(CreateDestination.local),
                          ),
                        if (widget.showLocal) const SizedBox(height: 12),
                        _LocationCard(
                          icon: Icons.cloud_outlined,
                          title: context.l10n.cloud,
                          subtitle:
                              context.l10n.chooseAGoogleDriveOrWebDAVFolder,
                          onTap: () => _select(CreateDestination.cloud),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSelecting)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: theme.colorScheme.surface.withValues(alpha: 0.82),
                  child: const Center(child: TriangleLoadingIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
