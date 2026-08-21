// Parser/serializer combinators for Dart enums, matched by name.

import '../core/types.dart';
import 'primitives.dart' show stringOrNull;

/// Enum parser that returns `null` for unrecognized values.
///
/// [caseInsensitive] makes the name comparison case-insensitive.
ParserFn<T?> enumOrNull<T extends Enum>(
  List<T> values, {
  bool caseInsensitive = false,
}) {
  final byName = caseInsensitive
      ? <String, T>{for (final v in values) v.name.toLowerCase(): v}
      : values.asNameMap();

  return (Object? v) {
    if (v is T) return v;
    final key = caseInsensitive
        ? stringOrNull(v)?.toLowerCase()
        : stringOrNull(v);
    return key != null ? byName[key] : null;
  };
}

ParserFn<T> enumOrDefault<T extends Enum>(
  List<T> values,
  T fallback, {
  bool caseInsensitive = false,
}) {
  final orNull = enumOrNull(values, caseInsensitive: caseInsensitive);
  return (Object? v) => orNull(v) ?? fallback;
}

ParserFn<T> enumOrFirst<T extends Enum>(
  List<T> values, {
  bool caseInsensitive = false,
}) {
  final orNull = enumOrNull(values, caseInsensitive: caseInsensitive);
  return (Object? v) => orNull(v) ?? values.first;
}

ParserFn<T> enumOrLast<T extends Enum>(
  List<T> values, {
  bool caseInsensitive = false,
}) {
  final orNull = enumOrNull(values, caseInsensitive: caseInsensitive);
  return (Object? v) => orNull(v) ?? values.last;
}

/// Enum parser that throws [FormatException] for unrecognized values.
ParserFn<T> enumOrThrow<T extends Enum>(
  List<T> values, {
  bool caseInsensitive = false,
}) {
  final orNull = enumOrNull(values, caseInsensitive: caseInsensitive);
  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'enumOrThrow<$T>: unknown value "$v". Expected one of: ${values.map((e) => e.name).join(', ')}',
      ));
}

/// Serializer: any `Enum` → its `.name`.
@pragma('vm:prefer-inline')
String enumToJson<T extends Enum>(T v) => v.name;
