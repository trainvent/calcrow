class DocumentPrefill {
  const DocumentPrefill({
    required this.name,
    required this.values,
    this.weekdays = const <int>{
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    },
  });

  final String name;
  final Map<String, String> values;

  /// Uses [DateTime.monday] through [DateTime.sunday].
  final Set<int> weekdays;

  bool isAvailableOn(DateTime date) {
    return weekdays.contains(date.weekday);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'values': values,
      'weekdays': weekdays.toList()..sort(),
    };
  }

  static DocumentPrefill? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = (raw['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final rawValues = raw['values'];
    if (rawValues is! Map) return null;
    final values = <String, String>{};
    for (final entry in rawValues.entries) {
      final header = entry.key.toString().trim();
      final value = entry.value?.toString().trim() ?? '';
      if (header.isNotEmpty && value.isNotEmpty) values[header] = value;
    }
    if (values.isEmpty) return null;

    final rawWeekdays = raw['weekdays'];
    final weekdays = rawWeekdays is List
        ? <int>{}
        : <int>{
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
          };
    if (rawWeekdays is List) {
      for (final value in rawWeekdays) {
        final weekday = value is int ? value : int.tryParse('$value');
        if (weekday != null &&
            weekday >= DateTime.monday &&
            weekday <= DateTime.sunday) {
          weekdays.add(weekday);
        }
      }
    }
    return DocumentPrefill(name: name, values: values, weekdays: weekdays);
  }
}

String localPrefillDocumentKey(String path) => 'local:${path.trim()}';

String cloudPrefillDocumentKey(String provider, String documentId) =>
    'cloud:${provider.trim()}:${documentId.trim()}';

String documentPrefillKey(String fileName) =>
    'file:${fileName.trim().toLowerCase()}';
