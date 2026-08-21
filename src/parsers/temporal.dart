// Total parsers/serializers for DateTime and Duration.

import '../core/types.dart';
import 'primitives.dart' show intOrNull;

// ─── DateTime ────────────────────────────────────────────────────────────

/// Above this many units, an integer timestamp is treated as milliseconds
/// rather than seconds since the epoch (roughly the year 2286 read as
/// seconds, or 1970 + ~116 days read as milliseconds) — real-world
/// timestamps land unambiguously on the correct side.
const int _secondsVsMillisecondsThreshold = 10000000000;

/// Smart `DateTime` parser: accepts ISO-8601 strings and Unix timestamps
/// (auto-detecting seconds vs. milliseconds — see
/// [_secondsVsMillisecondsThreshold]).
@pragma('vm:prefer-inline')
DateTime? dateTimeOrNull(Object? v) => switch (v) {
  null => null,
  final DateTime dt => dt,
  final String s when s.isNotEmpty => DateTime.tryParse(s),
  final int n => _fromUnixTimestamp(n),
  final num n => _fromUnixTimestamp(n.toInt()),
  _ => null,
};

@pragma('vm:prefer-inline')
DateTime _fromUnixTimestamp(int n) {
  final ms = n > _secondsVsMillisecondsThreshold ? n : n * 1000;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

@pragma('vm:prefer-inline')
DateTime dateTimeOrEpoch(Object? v) =>
    dateTimeOrNull(v) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

@pragma('vm:prefer-inline')
DateTime dateTimeOrNow(Object? v) => dateTimeOrNull(v) ?? DateTime.now();

@pragma('vm:prefer-inline')
ParserFn<DateTime> dateTimeOrDefault(DateTime fallback) =>
    (Object? v) => dateTimeOrNull(v) ?? fallback;

@pragma('vm:prefer-inline')
DateTime dateTimeOrThrow(Object? v) =>
    dateTimeOrNull(v) ??
    (throw FormatException(
      'dateTimeOrThrow: expected a DateTime, an ISO-8601 string, or a Unix timestamp, got ${v?.runtimeType} ($v)',
    ));

/// Serializer: `DateTime` → ISO-8601 string.
@pragma('vm:prefer-inline')
String dateTimeToJson(DateTime v) => v.toIso8601String();

/// Serializer: `DateTime` → Unix seconds.
@pragma('vm:prefer-inline')
int dateTimeToUnixSeconds(DateTime v) => v.millisecondsSinceEpoch ~/ 1000;

/// Serializer: `DateTime` → Unix milliseconds.
@pragma('vm:prefer-inline')
int dateTimeToUnixMillis(DateTime v) => v.millisecondsSinceEpoch;

// ─── Duration ────────────────────────────────────────────────────────────

/// Parses [Duration] from a millisecond count (`int`/`num`), or a string
/// holding one.
@pragma('vm:prefer-inline')
Duration? durationOrNull(Object? v) => switch (v) {
  null => null,
  final int ms => Duration(milliseconds: ms),
  final num ms => Duration(milliseconds: ms.toInt()),
  final String s when s.trim().isNotEmpty => switch (intOrNull(s.trim())) {
    final int ms => Duration(milliseconds: ms),
    _ => null,
  },
  _ => null,
};

@pragma('vm:prefer-inline')
Duration durationOrZero(Object? v) => durationOrNull(v) ?? Duration.zero;

@pragma('vm:prefer-inline')
ParserFn<Duration> durationOrDefault(Duration fallback) =>
    (Object? v) => durationOrNull(v) ?? fallback;

@pragma('vm:prefer-inline')
Duration durationOrThrow(Object? v) =>
    durationOrNull(v) ??
    (throw FormatException(
      'durationOrThrow: expected a millisecond count or a parseable string, got ${v?.runtimeType} ($v)',
    ));

/// Serializer: `Duration` → milliseconds.
@pragma('vm:prefer-inline')
int durationToJson(Duration v) => v.inMilliseconds;

// ─── Date-only ───────────────────────────────────────────────────────────

/// Parses a calendar date — anything [dateTimeOrNull] accepts (an
/// ISO-8601 string, a `DateTime`, or a Unix timestamp) — and truncates it
/// to midnight UTC, discarding any time-of-day component.
///
/// Useful for fields that represent a date only (birthdays, due dates)
/// where preserving an incidental time-of-day would be misleading.
@pragma('vm:prefer-inline')
DateTime? dateOnlyOrNull(Object? v) {
  final dt = dateTimeOrNull(v)?.toUtc();
  return dt == null ? null : DateTime.utc(dt.year, dt.month, dt.day);
}

@pragma('vm:prefer-inline')
DateTime dateOnlyOrEpoch(Object? v) => dateOnlyOrNull(v) ?? DateTime.utc(1970);

@pragma('vm:prefer-inline')
ParserFn<DateTime> dateOnlyOrDefault(DateTime fallback) {
  final boundedFallback = DateTime.utc(
    fallback.year,
    fallback.month,
    fallback.day,
  );
  return (Object? v) => dateOnlyOrNull(v) ?? boundedFallback;
}

/// Serializer: `DateTime` → `yyyy-MM-dd`, discarding time-of-day.
String dateOnlyToJson(DateTime v) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  final utc = v.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-${pad2(utc.month)}-${pad2(utc.day)}';
}

// ─── ISO-8601 Duration ───────────────────────────────────────────────────

/// Matches an ISO-8601 duration, e.g. `PT1H30M`, `P3DT4H`, `P1Y2M10D`.
final RegExp _iso8601DurationPattern = RegExp(
  r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?'
  r'(?:T(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?)?$',
);

/// Weeks (`P1W`) can't combine with the other date components in the
/// standard, so they're matched separately.
final RegExp _iso8601WeekDurationPattern = RegExp(r'^P(\d+)W$');

/// Parses an ISO-8601 duration string (`P1DT2H30M`, `P2W`, ...) into a
/// [Duration]. Years and months are approximated as 365 and 30 days
/// respectively, since [Duration] has no calendar awareness — prefer
/// whole days/hours in the source data when exactness matters.
///
/// Returns `null` for anything that isn't a non-empty [String] matching
/// the expected shape, including the (technically-matching-a-prefix-only)
/// bare `"P"` with no components at all.
Duration? iso8601DurationOrNull(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final s = v.trim();

  final week = _iso8601WeekDurationPattern.firstMatch(s);
  if (week != null) {
    return Duration(days: (int.tryParse(week.group(1)!) ?? 0) * 7);
  }

  final m = _iso8601DurationPattern.firstMatch(s);
  if (m == null || s == 'P') return null;

  final years = int.tryParse(m.group(1) ?? '') ?? 0;
  final months = int.tryParse(m.group(2) ?? '') ?? 0;
  final days = int.tryParse(m.group(3) ?? '') ?? 0;
  final hours = int.tryParse(m.group(4) ?? '') ?? 0;
  final minutes = int.tryParse(m.group(5) ?? '') ?? 0;
  final seconds = double.tryParse(m.group(6) ?? '') ?? 0;

  return Duration(
    days: years * 365 + months * 30 + days,
    hours: hours,
    minutes: minutes,
    milliseconds: (seconds * 1000).round(),
  );
}

@pragma('vm:prefer-inline')
Duration iso8601DurationOrZero(Object? v) =>
    iso8601DurationOrNull(v) ?? Duration.zero;

ParserFn<Duration> iso8601DurationOrDefault(Duration fallback) =>
    (Object? v) => iso8601DurationOrNull(v) ?? fallback;

/// Serializer: `Duration` → an ISO-8601 string using only the
/// time-designator (`PT#H#M#S`) components — a plain [Duration] has no
/// calendar awareness to distinguish `Y`/`M`/`D` from `T`-side hours.
String durationToIso8601(Duration v) {
  final hours = v.inHours;
  final minutes = v.inMinutes.remainder(60);
  final wholeSeconds = v.inSeconds.remainder(60);
  final millis = v.inMilliseconds.remainder(1000);
  final seconds = wholeSeconds + millis / 1000;

  final buf = StringBuffer('PT');
  if (hours != 0) buf.write('${hours}H');
  if (minutes != 0) buf.write('${minutes}M');
  if (seconds != 0 || (hours == 0 && minutes == 0)) {
    buf.write('${seconds.toStringAsFixed(millis == 0 ? 0 : 3)}S');
  }
  return buf.toString();
}
