import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:calcrow/core/sheet_type_logic/field_type.dart';

const documentTemplates = <DocumentTemplate>[
  DocumentTemplate(
    name: 'Workout like Bruce Lee',
    fileName: 'bruce_lee_workout',
    description:
        'Track training sessions without turning the sheet into a fitness app.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Run km', type: FieldType.float),
      TemplateColumn(header: 'Clean and Press weight', type: FieldType.float),
      TemplateColumn(header: 'Barbell Curl weight', type: FieldType.float),
      TemplateColumn(
        header: 'Behind-the-neck Press weight',
        type: FieldType.float,
      ),
      TemplateColumn(header: 'Upright Row weight', type: FieldType.float),
      TemplateColumn(header: 'Barbell Squat weight', type: FieldType.float),
      TemplateColumn(header: 'Barbell Row weight', type: FieldType.float),
      TemplateColumn(
        header: 'Barbell Bench Press weight',
        type: FieldType.float,
      ),
      TemplateColumn(header: 'Barbell Pullover weight', type: FieldType.float),
      TemplateColumn(header: 'Reps', type: FieldType.integer),
      TemplateColumn(header: 'Sets', type: FieldType.integer),
      TemplateColumn(header: 'Notes', type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: 'Triathlon Training Tracker Plus',
    fileName: 'triathlon_training_tracker_plus',
    description: 'Track swim, bike, run, and strength work in one row.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Run km', type: FieldType.float),
      TemplateColumn(header: 'Swim km', type: FieldType.float),
      TemplateColumn(header: 'Bike km', type: FieldType.float),
      TemplateColumn(header: 'Pull-ups', type: FieldType.integer),
      TemplateColumn(header: 'Push-ups', type: FieldType.integer),
      TemplateColumn(header: 'Squats', type: FieldType.integer),
    ],
  ),
  DocumentTemplate(
    name: 'Customer Service',
    fileName: 'customer_service',
    description: 'Log customer visits, billable time, expenses, and outcomes.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Customer', type: FieldType.text),
      TemplateColumn(header: 'Workhours', type: FieldType.float),
      TemplateColumn(header: 'Expenses', type: FieldType.money),
      TemplateColumn(header: 'Work done', type: FieldType.text),
      TemplateColumn(header: 'Notes', type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: 'Guestlist',
    fileName: 'guestlist',
    description: 'Names, contacts, and RSVP status for an event.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Name', type: FieldType.text),
      TemplateColumn(header: 'Email', type: FieldType.email),
      TemplateColumn(header: 'Phone', type: FieldType.phone),
      TemplateColumn(header: 'RSVP', type: FieldType.boolean),
      TemplateColumn(header: 'Notes', type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: 'Workhours',
    fileName: 'workhours',
    description: 'A clean day-by-day timesheet with breaks and notes.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Start', type: FieldType.time),
      TemplateColumn(header: 'End', type: FieldType.time),
      TemplateColumn(header: 'Pause', type: FieldType.duration),
      TemplateColumn(header: 'Notes', type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: 'Invoices',
    fileName: 'invoices',
    description: 'Basic invoice tracking with dates, clients, and totals.',
    columns: <TemplateColumn>[
      TemplateColumn(header: 'Date', type: FieldType.date),
      TemplateColumn(header: 'Client', type: FieldType.text),
      TemplateColumn(header: 'Invoice', type: FieldType.text),
      TemplateColumn(header: 'Amount', type: FieldType.money),
      TemplateColumn(header: 'Status', type: FieldType.text),
    ],
  ),
];

class DocumentTemplate {
  const DocumentTemplate({
    required this.name,
    required this.fileName,
    required this.description,
    required this.columns,
  });

  final String name;
  final String fileName;
  final String description;
  final List<TemplateColumn> columns;
}

class TemplateColumn {
  const TemplateColumn({
    required this.header,
    required this.type,
    this.currencyCode = FieldTypeGuesser.defaultCurrencyCode,
  });

  final String header;
  final FieldType type;
  final String currencyCode;
}

class TemplatesDialogue extends StatelessWidget {
  const TemplatesDialogue({super.key, required this.templates});

  final List<DocumentTemplate> templates;

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
                    child: LText(
                      'Templates',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Close templates'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LText(
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

  final DocumentTemplate template;

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
                    child: LText(
                      template.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              LText(
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

  final List<TemplateColumn> columns;

  @override
  Widget build(BuildContext context) {
    final previewColumns = columns
        .where(
          (column) =>
              column.header.trim().toLowerCase() != 'date' ||
              column.type != FieldType.date,
        )
        .toList(growable: false);
    final chipStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < previewColumns.length; index++) ...[
            Chip(
              label: LText(previewColumns[index].header),
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

  IconData _iconForType(FieldType type) {
    switch (type) {
      case FieldType.date:
        return Icons.calendar_today_outlined;
      case FieldType.time:
        return Icons.schedule_rounded;
      case FieldType.duration:
        return Icons.timer_outlined;
      case FieldType.integer:
      case FieldType.float:
        return Icons.pin_outlined;
      case FieldType.money:
        return Icons.attach_money_rounded;
      case FieldType.boolean:
        return Icons.toggle_on_outlined;
      case FieldType.email:
        return Icons.alternate_email_rounded;
      case FieldType.phone:
        return Icons.phone_outlined;
      case FieldType.text:
        return Icons.text_fields_rounded;
    }
  }
}
