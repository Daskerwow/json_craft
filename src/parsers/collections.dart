// Total parsers for List, Set, and Map — built from a per-element/per-entry
// Parser<T>.
//
// All three come in three flavors:
//   xOf        — empty collection on a non-matching input.
//   xOrNullOf  — null on a non-matching input.
//   xOrThrowOf — FormatException on a non-matching input.
//
// Element/entry failures are annotated with their index or key via
// JsonPathError so a failure deep inside a large payload is easy to locate.

import '../core/path.dart';
import '../core/types.dart';
import 'primitives.dart' show stringOrThrow;

/// Runs [read], annotating any failure with [segment] so the path survives
/// up to the nearest `JsonReader`.
T _guarded<T>(PathSegment segment, T Function() read) {
  try {
    return read();
  } on JsonPathError catch (e) {
    throw e.under(segment);
  } catch (e) {
    throw JsonPathError(JsonPath.root().child(segment), e);
  }
}

// ─── List ────────────────────────────────────────────────────────────────

/// Parses `List<T>?` from a JSON array. Returns `null` for non-`List` input.
ParserFn<List<T>?> listOrNullOf<T>(ParserFn<T> item) =>
    (Object? v) => switch (v) {
      final List l => List<T>.unmodifiable([
        for (final (i, e) in l.indexed) _guarded(ArrayIndex(i), () => item(e)),
      ]),
      _ => null,
    };

/// Parses `List<T>` from a JSON array. Throws [FormatException] for
/// non-`List` input.
ParserFn<List<T>> listOrThrowOf<T>(ParserFn<T> item) {
  final orNull = listOrNullOf(item);

  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'listOrThrowOf<$T>: expected a List, got ${v?.runtimeType}',
      ));
}

/// Parses `List<T>` from a JSON array. Returns `[]` for non-`List` input.
ParserFn<List<T>> listOf<T>(ParserFn<T> item) {
  final orNull = listOrNullOf(item);
  return (Object? v) => orNull(v) ?? <T>[];
}

// ─── Set ─────────────────────────────────────────────────────────────────

/// Parses `Set<T>?` from a JSON array. Returns `null` for non-`List` input.
ParserFn<Set<T>?> setOrNullOf<T>(ParserFn<T> item) =>
    (Object? v) => switch (v) {
      final List l => Set<T>.unmodifiable([
        for (final (i, e) in l.indexed) _guarded(ArrayIndex(i), () => item(e)),
      ]),
      _ => null,
    };

/// Parses `Set<T>` from a JSON array. Throws [FormatException] for
/// non-`List` input.
ParserFn<Set<T>> setOrThrowOf<T>(ParserFn<T> item) {
  final orNull = setOrNullOf(item);

  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'setOrThrowOf<$T>: expected a List, got ${v?.runtimeType}',
      ));
}

/// Parses `Set<T>` from a JSON array. Returns `{}` for non-`List` input.
ParserFn<Set<T>> setOf<T>(ParserFn<T> item) {
  final orNull = setOrNullOf(item);

  return (Object? v) => orNull(v) ?? <T>{};
}

// ─── Map ─────────────────────────────────────────────────────────────────

/// Parses `Map<K, V>?` from a JSON object. Returns `null` for non-`Map`
/// input.
ParserFn<Map<K, V>?> mapOrNullOf<K, V>(
  ParserFn<K> keyParser,
  ParserFn<V> valueParser,
) =>
    (Object? v) => switch (v) {
      final Map m => Map<K, V>.unmodifiable({
        for (final MapEntry(:key, :value) in m.entries)
          _guarded(MapKey(key), () => keyParser(key)): _guarded(
            MapKey(key),
            () => valueParser(value),
          ),
      }),
      _ => null,
    };

/// Parses `Map<K, V>` from a JSON object. Throws [FormatException] for
/// non-`Map` input.
ParserFn<Map<K, V>> mapOrThrowOf<K, V>(
  ParserFn<K> keyParser,
  ParserFn<V> valueParser,
) {
  final orNull = mapOrNullOf(keyParser, valueParser);

  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'mapOrThrowOf<$K,$V>: expected a Map, got ${v?.runtimeType}',
      ));
}

/// Parses `Map<K, V>` from a JSON object. Returns `{}` for non-`Map` input.
ParserFn<Map<K, V>> mapOf<K, V>(
  ParserFn<K> keyParser,
  ParserFn<V> valueParser,
) {
  final orNull = mapOrNullOf(keyParser, valueParser);

  return (Object? v) => orNull(v) ?? <K, V>{};
}

// ─── Map<String, V> convenience ─────────────────────────────────────────
//
// The overwhelming majority of real-world JSON maps have string keys —
// these skip specifying a key parser for that common case.

/// Parses `Map<String, V>` from a JSON object. Returns `{}` for non-`Map`
/// input.
ParserFn<Map<String, V>> stringKeyedMapOf<V>(ParserFn<V> valueParser) =>
    mapOf(stringOrThrow, valueParser);

/// Parses `Map<String, V>?` from a JSON object. Returns `null` for
/// non-`Map` input.
ParserFn<Map<String, V>?> stringKeyedMapOrNullOf<V>(ParserFn<V> valueParser) =>
    mapOrNullOf(stringOrThrow, valueParser);
