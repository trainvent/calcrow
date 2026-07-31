import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';
import 'package:calcrow/core/guessers/field_type_guesser.dart';
import 'package:calcrow/core/sheet_type_logic/field_type.dart';

typedef LocalizedTemplateText = String Function(AppLocalizations);

final documentTemplates = <DocumentTemplate>[
  DocumentTemplate(
    name: (l10n) => l10n.workoutLikeBruceLee,
    fileName: 'bruce_lee_workout',
    category: TemplateCategory.sports,
    description: (l10n) =>
        l10n.trackTrainingSessionsWithoutTurningTheSheetIntoAFitnessApp,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _runKm, type: FieldType.float),
      TemplateColumn(header: _cleanAndPressWeight, type: FieldType.float),
      TemplateColumn(header: _barbellCurlWeight, type: FieldType.float),
      TemplateColumn(header: _behindTheNeckPressWeight, type: FieldType.float),
      TemplateColumn(header: _uprightRowWeight, type: FieldType.float),
      TemplateColumn(header: _barbellSquatWeight, type: FieldType.float),
      TemplateColumn(header: _barbellRowWeight, type: FieldType.float),
      TemplateColumn(header: _barbellBenchPressWeight, type: FieldType.float),
      TemplateColumn(header: _barbellPulloverWeight, type: FieldType.float),
      TemplateColumn(header: _reps, type: FieldType.integer),
      TemplateColumn(header: _sets, type: FieldType.integer),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.triathlonTrainingTrackerPlus,
    fileName: 'triathlon_training_tracker_plus',
    category: TemplateCategory.sports,
    description: (l10n) => l10n.trackSwimBikeRunAndStrengthWorkInOneRow,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _runKm, type: FieldType.float),
      TemplateColumn(header: _swimKm, type: FieldType.float),
      TemplateColumn(header: _bikeKm, type: FieldType.float),
      TemplateColumn(header: _pullUps, type: FieldType.integer),
      TemplateColumn(header: _pushUps, type: FieldType.integer),
      TemplateColumn(header: _squats, type: FieldType.integer),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.customerService,
    fileName: 'customer_service',
    category: TemplateCategory.work,
    description: (l10n) =>
        l10n.logCustomerVisitsBillableTimeExpensesAndOutcomes,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _customer, type: FieldType.text),
      TemplateColumn(header: _workhours, type: FieldType.float),
      TemplateColumn(header: _expenses, type: FieldType.money),
      TemplateColumn(header: _workDone, type: FieldType.text),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.guestlist,
    fileName: 'guestlist',
    category: TemplateCategory.other,
    description: (l10n) => l10n.namesContactsAndRSVPStatusForAnEvent,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _name, type: FieldType.text),
      TemplateColumn(header: _email, type: FieldType.email),
      TemplateColumn(header: _phone, type: FieldType.phone),
      TemplateColumn(header: _rsvp, type: FieldType.boolean),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.workhours,
    fileName: 'workhours',
    category: TemplateCategory.work,
    description: (l10n) => l10n.aCleanDayByDayTimesheetWithBreaksAndNotes,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _start, type: FieldType.time),
      TemplateColumn(header: _end, type: FieldType.time),
      TemplateColumn(header: _pause, type: FieldType.duration),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.invoices,
    fileName: 'invoices',
    category: TemplateCategory.work,
    description: (l10n) => l10n.basicInvoiceTrackingWithDatesClientsAndTotals,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _client, type: FieldType.text),
      TemplateColumn(header: _invoice, type: FieldType.text),
      TemplateColumn(header: _amount, type: FieldType.money),
      TemplateColumn(header: _status, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.dynamicWorkoutTracker,
    fileName: 'dynamic_workout_tracker',
    category: TemplateCategory.sports,
    description: (l10n) => l10n.trackFlexibleWorkoutsDistanceRepetitionsAndTime,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _exercize, type: FieldType.text),
      TemplateColumn(header: _distanceOrRepetitions, type: FieldType.text),
      TemplateColumn(header: _durationField, type: FieldType.duration),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
  DocumentTemplate(
    name: (l10n) => l10n.projectOriented,
    fileName: 'project_oriented',
    category: TemplateCategory.other,
    description: (l10n) => l10n.trackProjectGoalsSatisfactionAndProductivity,
    columns: <TemplateColumn>[
      TemplateColumn(header: _date, type: FieldType.date),
      TemplateColumn(header: _todaysGoal, type: FieldType.text),
      TemplateColumn(header: _accomplishmentOfTheDay, type: FieldType.text),
      TemplateColumn(header: _satisfactionRating, type: FieldType.integer),
      TemplateColumn(header: _productivityRating, type: FieldType.integer),
      TemplateColumn(header: _notes, type: FieldType.text),
    ],
  ),
];

enum TemplateCategory { sports, work, other }

class DocumentTemplate {
  const DocumentTemplate({
    required this.name,
    required this.fileName,
    required this.category,
    required this.description,
    required this.columns,
  });

  final LocalizedTemplateText name;
  final String fileName;
  final TemplateCategory category;
  final LocalizedTemplateText description;
  final List<TemplateColumn> columns;
}

class TemplateColumn {
  const TemplateColumn({
    required this.header,
    required this.type,
    this.currencyCode = FieldTypeGuesser.defaultCurrencyCode,
  });

  final LocalizedTemplateText header;
  final FieldType type;
  final String currencyCode;
}

String _date(AppLocalizations l10n) => l10n.date;
String _exercize(AppLocalizations l10n) => l10n.exercize;
String _distanceOrRepetitions(AppLocalizations l10n) =>
    l10n.distanceOrRepetitions;
String _durationField(AppLocalizations l10n) => l10n.durationField;
String _runKm(AppLocalizations l10n) => l10n.runKm;
String _cleanAndPressWeight(AppLocalizations l10n) => l10n.cleanAndPressWeight;
String _barbellCurlWeight(AppLocalizations l10n) => l10n.barbellCurlWeight;
String _behindTheNeckPressWeight(AppLocalizations l10n) =>
    l10n.behindTheNeckPressWeight;
String _uprightRowWeight(AppLocalizations l10n) => l10n.uprightRowWeight;
String _barbellSquatWeight(AppLocalizations l10n) => l10n.barbellSquatWeight;
String _barbellRowWeight(AppLocalizations l10n) => l10n.barbellRowWeight;
String _barbellBenchPressWeight(AppLocalizations l10n) =>
    l10n.barbellBenchPressWeight;
String _barbellPulloverWeight(AppLocalizations l10n) =>
    l10n.barbellPulloverWeight;
String _reps(AppLocalizations l10n) => l10n.reps;
String _sets(AppLocalizations l10n) => l10n.sets;
String _notes(AppLocalizations l10n) => l10n.notes;
String _swimKm(AppLocalizations l10n) => l10n.swimKm;
String _bikeKm(AppLocalizations l10n) => l10n.bikeKm;
String _pullUps(AppLocalizations l10n) => l10n.pullUps;
String _pushUps(AppLocalizations l10n) => l10n.pushUps;
String _squats(AppLocalizations l10n) => l10n.squats;
String _customer(AppLocalizations l10n) => l10n.customer;
String _workhours(AppLocalizations l10n) => l10n.workhours;
String _expenses(AppLocalizations l10n) => l10n.expenses;
String _workDone(AppLocalizations l10n) => l10n.workDone;
String _name(AppLocalizations l10n) => l10n.name;
String _email(AppLocalizations l10n) => l10n.email;
String _phone(AppLocalizations l10n) => l10n.phone;
String _rsvp(AppLocalizations l10n) => l10n.rsvpField;
String _start(AppLocalizations l10n) => l10n.start;
String _end(AppLocalizations l10n) => l10n.end;
String _pause(AppLocalizations l10n) => l10n.pauseField;
String _client(AppLocalizations l10n) => l10n.client;
String _invoice(AppLocalizations l10n) => l10n.invoice;
String _amount(AppLocalizations l10n) => l10n.amount;
String _status(AppLocalizations l10n) => l10n.status;
String _todaysGoal(AppLocalizations l10n) => l10n.todaysGoal;
String _accomplishmentOfTheDay(AppLocalizations l10n) =>
    l10n.accomplishmentOfTheDay;
String _satisfactionRating(AppLocalizations l10n) => l10n.satisfactionRating;
String _productivityRating(AppLocalizations l10n) => l10n.productivityRating;

class TemplatesDialogue extends StatefulWidget {
  const TemplatesDialogue({super.key, required this.templates});

  final List<DocumentTemplate> templates;

  @override
  State<TemplatesDialogue> createState() => _TemplatesDialogueState();
}

class _TemplatesDialogueState extends State<TemplatesDialogue> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(DocumentTemplate template, AppLocalizations l10n) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchableText = <String>[
      template.name(l10n),
      template.description(l10n),
      _categoryLabel(l10n, template.category),
      for (final column in template.columns) column.header(l10n),
    ].join(' ').toLowerCase();
    return searchableText.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final categorizedTemplates = <TemplateCategory, List<DocumentTemplate>>{
      for (final category in TemplateCategory.values)
        category: widget.templates
            .where(
              (template) =>
                  template.category == category &&
                  _matchesQuery(template, context.l10n),
            )
            .toList(growable: false),
    };
    final hasResults = categorizedTemplates.values.any(
      (templates) => templates.isNotEmpty,
    );
    final content = SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 16 : 24,
          isCompact ? 12 : 20,
          isCompact ? 16 : 24,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.templates,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.closeTemplates,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.everyTemplateStartsWithDateAsTheFirstColumn,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SearchBar(
              key: const ValueKey('template-search-bar'),
              controller: _searchController,
              hintText: context.l10n.searchTemplates,
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: hasResults
                  ? ListView(
                      key: const ValueKey('template-results-list'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        for (final category in TemplateCategory.values)
                          if (categorizedTemplates[category]!.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                              child: Text(
                                _categoryLabel(context.l10n, category),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (final template
                                in categorizedTemplates[category]!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TemplateOptionTile(template: template),
                              ),
                            const SizedBox(height: 8),
                          ],
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.noTemplatesFound,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(child: content);
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: content,
      ),
    );
  }
}

String _categoryLabel(
  AppLocalizations localizations,
  TemplateCategory category,
) {
  return switch (category) {
    TemplateCategory.sports => localizations.templateCategorySports,
    TemplateCategory.work => localizations.templateCategoryWork,
    TemplateCategory.other => localizations.templateCategoryOther,
  };
}

class _TemplateOptionTile extends StatefulWidget {
  const _TemplateOptionTile({required this.template});

  final DocumentTemplate template;

  @override
  State<_TemplateOptionTile> createState() => _TemplateOptionTileState();
}

class _TemplateOptionTileState extends State<_TemplateOptionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
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
                      template.name(context.l10n),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('select-template-${template.fileName}'),
                    tooltip: context.l10n.useTemplate,
                    onPressed: () => Navigator.of(context).pop(template),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Text(
                  template.description(context.l10n),
                  maxLines: _isExpanded ? null : 1,
                  overflow: _isExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _TemplateFieldPreview(
                  columns: template.columns,
                  expanded: _isExpanded,
                  templateId: template.fileName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateFieldPreview extends StatelessWidget {
  const _TemplateFieldPreview({
    required this.columns,
    required this.expanded,
    required this.templateId,
  });

  final List<TemplateColumn> columns;
  final bool expanded;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final previewColumns = columns
        .where((column) => column.type != FieldType.date)
        .toList(growable: false);
    final chips = [
      for (final column in previewColumns)
        Chip(
          label: Text(column.header(context.l10n)),
          avatar: Icon(_iconForType(column.type), size: 18),
          visualDensity: VisualDensity.compact,
        ),
    ];

    if (expanded) {
      return Wrap(
        key: ValueKey('expanded-template-fields-$templateId'),
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );
    }

    final chipStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            chips[index],
            if (index < chips.length - 1) const SizedBox(width: 8),
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
