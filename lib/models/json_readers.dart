/// Tolerant readers for values coming back from the REST API.
///
/// Postgres hands back `numeric` as a string over JSON, and a bigint as a
/// number that may not fit in an int on the JS side. Rather than sprinkling
/// casts through every model, everything goes through these.
///
/// They are deliberately forgiving: a malformed date becomes `null` and a
/// missing number becomes zero. A member with one unparseable field should
/// still render, because the alternative is a blank screen.
library;

/// Parses an ISO-8601 timestamp, or `null` if it is absent or unreadable.
DateTime? readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
  }
  return DateTime.tryParse('$value')?.toLocal();
}

int readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double readDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

bool readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

String readString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = '$value';
  return text.isEmpty ? fallback : text;
}

/// A string field, or null when the API sent null or an empty string.
///
/// Contact details and notes are stored as SQL NULL rather than '' in this
/// schema, and the UI wants to treat "no value" and "empty value" the same.
String? readNullableString(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

/// Clamps a 0-100 percentage coming off the wire.
double readPercent(Object? value) => readDouble(value).clamp(0, 100);
