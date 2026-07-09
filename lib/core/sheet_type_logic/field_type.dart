enum FieldType {
  text('text'),
  date('date'),
  time('time'),
  duration('duration'),
  integer('integer'),
  float('float'),
  money('money'),
  boolean('boolean'),
  email('email'),
  phone('phone');

  const FieldType(this.value);

  final String value;

  static const List<FieldType> createOptions = <FieldType>[
    text,
    date,
    time,
    duration,
    integer,
    float,
    money,
    boolean,
    email,
    phone,
  ];

  static FieldType fromString(String rawType) {
    final normalizedType = rawType.trim().toLowerCase();
    if (normalizedType.startsWith('money:') ||
        normalizedType.startsWith('currency:')) {
      return money;
    }
    switch (normalizedType) {
      case 'date':
        return date;
      case 'time':
        return time;
      case 'duration':
      case 'timespan':
        return duration;
      case 'integer':
      case 'int':
      case 'number':
        return integer;
      case 'float':
      case 'double':
      case 'decimal':
        return float;
      case 'money':
      case 'currency':
        return money;
      case 'boolean':
      case 'bool':
        return boolean;
      case 'email':
        return email;
      case 'phone':
        return phone;
      case 'text':
      case 'string':
      default:
        return text;
    }
  }
}
