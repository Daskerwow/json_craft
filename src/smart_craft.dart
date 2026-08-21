import 'enum_registry.dart' show getEnumParseByType;
import 'parsers/parsers.dart';

/// Helper function to capture exact type representations, including nullable types.
///
/// Direct `Type` literals for nullable types (e.g., `int?`) are not supported in standard
/// Dart syntax. Using generic type arguments via `_typeOf<int?>()` resolves to the correct
/// [Type] object at runtime.
Type _typeOf<T>() => T;

/// Registry mapping supported basic Dart types to their respective parsing functions.
///
/// Covers both non-nullable (fallback to default values) and nullable variants
/// (fallback to `null`).
final Map<Type, Object? Function(Object?)>
_primitiveParsers = Map.unmodifiable({
  // ── Non-nullable primitives ────────────────────────────────────────────────
  int: intOrZero,
  double: doubleOrZero,
  num: numOrZero,
  bool: boolOrFalse,
  String: stringOrEmpty,
  DateTime: dateTimeOrEpoch,
  Duration: durationOrZero,
  Uri: uriOrEmpty,
  BigInt: bigIntOrZero,
});

/// Sources of type-driven parsers, checked in order until one produces a
/// match. Kept as a list of independent lookups — rather than chaining
/// them with `??` inline inside [getParseByType] — so each source stays a
/// single, separately-reasoned-about responsibility, and a future source
/// (e.g. a `registerModel` registry) can be added here without touching
/// the resolution logic itself.
final List<Object? Function(Object?)? Function(Type type)> _typeParserSources =
    [(type) => _primitiveParsers[type], getEnumParseByType];

/// Resolves a parser function for the given [type].
///
/// Checks each entry in [_typeParserSources] in turn — built-in
/// primitives first, then any enum registered via [registerEnum] (from
/// `enum_registry.dart`) — and returns the first match. Returns `null` if
/// [type] is unknown to all sources (e.g., custom models or collections
/// — those are expected to be parsed with an explicit `Parser<T>` from
/// `parsers.dart` instead of through this registry).
///
/// Example:
/// ```dart
/// final parser = getParseByType(int);
/// final result = parser?.call("123"); // Returns 123
///
/// registerEnum(LogLevel.values, fallback: LogLevel.fatal);
/// final levelParser = getParseByType(LogLevel); // now resolves too
/// ```
Object? Function(Object?)? getParseByType(Type? type) {
  if (type == null) return null;
  for (final source in _typeParserSources) {
    final parser = source(type);
    if (parser != null) return parser;
  }
  return null;
}

/// Parses a dynamic input value [v] into a target type specified by the runtime [type].
///
/// If [type] is a recognized primitive type, the value is safely cast or converted.
/// If [type] is unknown or unsupported, the original value [v] is returned unmodified,
/// assuming a custom parser will handle it downstream.
///
/// Example:
/// ```dart
/// smartParseByType(DateTime, "2026-01-01"); // Returns DateTime instance
/// smartParseByType(String, null);           // Returns ""
/// ```
Object? smartParseByType(Type? type, Object? v) {
  final parser = getParseByType(type);
  return parser != null ? parser(v) : v;
}

/// Parses a dynamic input value [v] based on the generic type parameter [R].
///
/// Convenience wrapper over [smartParseByType] that infers the target type statically.
/// If type [R] is a known primitive, it applies the appropriate parser.
/// For unknown types, [v] is passed through unchanged.
///
/// Example:
/// ```dart
/// final count = smartParseOf<int>("42");      // Returns 42
/// final age = smartParseOf<int?>("invalid"); // Returns null
/// ```
Object? smartParseOf<R>(Object? v) => smartParseByType(_typeOf<R>(), v);
