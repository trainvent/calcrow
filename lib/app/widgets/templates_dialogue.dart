import 'package:flutter/material.dart';

const simpleDocumentTemplates = <SimpleDocumentTemplate>[
  SimpleDocumentTemplate(
    name: 'Workout like Bruce Lee',
    fileName: 'bruce_lee_workout',
    description:
        'Track training sessions without turning the sheet into a fitness app.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Run km', type: 'Float'),
      SimpleTemplateColumn(header: 'Clean and Press weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Barbell Curl weight', type: 'Float'),
      SimpleTemplateColumn(
        header: 'Behind-the-neck Press weight',
        type: 'Float',
      ),
      SimpleTemplateColumn(header: 'Upright Row weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Barbell Squat weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Barbell Row weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Barbell Bench Press weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Barbell Pullover weight', type: 'Float'),
      SimpleTemplateColumn(header: 'Reps', type: 'Integer'),
      SimpleTemplateColumn(header: 'Sets', type: 'Integer'),
      SimpleTemplateColumn(header: 'Notes', type: 'text'),
    ],
  ),
  SimpleDocumentTemplate(
    name: 'Triathlon Training Tracker Plus',
    fileName: 'triathlon_training_tracker_plus',
    description: 'Track swim, bike, run, and strength work in one row.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Run km', type: 'Float'),
      SimpleTemplateColumn(header: 'Swim km', type: 'Float'),
      SimpleTemplateColumn(header: 'Bike km', type: 'Float'),
      SimpleTemplateColumn(header: 'Pull-ups', type: 'Integer'),
      SimpleTemplateColumn(header: 'Push-ups', type: 'Integer'),
      SimpleTemplateColumn(header: 'Squats', type: 'Integer'),
    ],
  ),
  SimpleDocumentTemplate(
    name: 'Customer Service',
    fileName: 'customer_service',
    description: 'Log customer visits, billable time, expenses, and outcomes.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Customer', type: 'text'),
      SimpleTemplateColumn(header: 'Workhours', type: 'Float'),
      SimpleTemplateColumn(header: 'Expenses', type: 'Float'),
      SimpleTemplateColumn(header: 'Work done', type: 'text'),
      SimpleTemplateColumn(header: 'Notes', type: 'text'),
    ],
  ),
  SimpleDocumentTemplate(
    name: 'Guestlist',
    fileName: 'guestlist',
    description: 'Names, contacts, and RSVP status for an event.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Name', type: 'text'),
      SimpleTemplateColumn(header: 'Email', type: 'email'),
      SimpleTemplateColumn(header: 'Phone', type: 'phone'),
      SimpleTemplateColumn(header: 'RSVP', type: 'boolean'),
      SimpleTemplateColumn(header: 'Notes', type: 'text'),
    ],
  ),
  SimpleDocumentTemplate(
    name: 'Workhours',
    fileName: 'workhours',
    description: 'A clean day-by-day timesheet with breaks and notes.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Start', type: 'time'),
      SimpleTemplateColumn(header: 'End', type: 'time'),
      SimpleTemplateColumn(header: 'Pause', type: 'duration'),
      SimpleTemplateColumn(header: 'Notes', type: 'text'),
    ],
  ),
  SimpleDocumentTemplate(
    name: 'Invoices',
    fileName: 'invoices',
    description: 'Basic invoice tracking with dates, clients, and totals.',
    columns: <SimpleTemplateColumn>[
      SimpleTemplateColumn(header: 'Date', type: 'date'),
      SimpleTemplateColumn(header: 'Client', type: 'text'),
      SimpleTemplateColumn(header: 'Invoice', type: 'text'),
      SimpleTemplateColumn(header: 'Amount', type: 'Float'),
      SimpleTemplateColumn(header: 'Status', type: 'text'),
    ],
  ),
];

class SimpleDocumentTemplate {
  const SimpleDocumentTemplate({
    required this.name,
    required this.fileName,
    required this.description,
    required this.columns,
  });

  final String name;
  final String fileName;
  final String description;
  final List<SimpleTemplateColumn> columns;
}

class SimpleTemplateColumn {
  const SimpleTemplateColumn({required this.header, required this.type});

  final String header;
  final String type;
}

class TemplatesDialogue extends StatelessWidget {
  const TemplatesDialogue({super.key, required this.templates});

  final List<SimpleDocumentTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Templates',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close templates',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Every template starts with Date as the first column. Pick a starting point, then rename, add, remove, and reorder the remaining fields before creating the document.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _TemplateOptionTile(template: templates[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOptionTile extends StatelessWidget {
  const _TemplateOptionTile({required this.template});

  final SimpleDocumentTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _TemplateFieldPreview(columns: template.columns),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateFieldPreview extends StatelessWidget {
  const _TemplateFieldPreview({required this.columns});

  final List<SimpleTemplateColumn> columns;

  @override
  Widget build(BuildContext context) {
    final previewColumns = columns
        .where(
          (column) =>
              column.header.trim().toLowerCase() != 'date' ||
              column.type.trim().toLowerCase() != 'date',
        )
        .toList(growable: false);
    final chipStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < previewColumns.length; index++) ...[
            Chip(
              label: Text(previewColumns[index].header),
              avatar: Icon(_iconForType(previewColumns[index].type), size: 18),
              visualDensity: VisualDensity.compact,
            ),
            if (index < previewColumns.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );

    if (previewColumns.length <= 5) return chipStrip;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.88, 1],
        ).createShader(bounds);
      },
      child: chipStrip,
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'date':
        return Icons.calendar_today_outlined;
      case 'time':
        return Icons.schedule_rounded;
      case 'duration':
        return Icons.timer_outlined;
      case 'Integer':
      case 'Float':
        return Icons.pin_outlined;
      case 'boolean':
        return Icons.toggle_on_outlined;
      case 'email':
        return Icons.alternate_email_rounded;
      case 'phone':
        return Icons.phone_outlined;
      default:
        return Icons.text_fields_rounded;
    }
  }
}
