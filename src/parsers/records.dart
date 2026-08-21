// Parsers for fixed-arity JSON arrays into Dart records — the natural
// counterpart to `listOf` when the array's length and per-slot type are
// known ahead of time (e.g. a `[lat, lng]` coordinate pair) rather than a
// homogeneous, arbitrary-length collection.

import '../core/path.dart';
import '../core/types.dart';

/// Runs [read], annotating any failure with [segment] so the path
/// survives up to the nearest `JsonReader`. Mirrors the identically-named
/// helper in `collections.dart` — kept private/per-file rather than
/// shared, since neither side is meant to depend on the other's internals.
T _guarded<T>(PathSegment segment, T Function() read) {
  try {
    return read();
  } on JsonPathError catch (e) {
    throw e.under(segment);
  } catch (e) {
    throw JsonPathError(JsonPath.root().child(segment), e);
  }
}

/// Parses a 2-element JSON array into an `(A, B)` record. Returns `null`
/// unless [v] is a `List` of length exactly 2.
///
/// ```dart
/// final coordinate = pairOrNull(doubleOrZero, doubleOrZero);
/// coordinate([52.37, 4.90]); // (52.37, 4.90)
/// ```
ParserFn<(A, B)?> pairOrNull<A, B>(ParserFn<A> first, ParserFn<B> second) =>
    (Object? v) => switch (v) {
      final List l when l.length == 2 => (
        _guarded(const ArrayIndex(0), () => first(l[0])),
        _guarded(const ArrayIndex(1), () => second(l[1])),
      ),
      _ => null,
    };

/// Throwing counterpart to [pairOrNull].
ParserFn<(A, B)> pairOrThrow<A, B>(ParserFn<A> first, ParserFn<B> second) {
  final orNull = pairOrNull(first, second);
  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'pairOrThrow<$A,$B>: expected a 2-element List, got ${v?.runtimeType}',
      ));
}

/// Parses a 3-element JSON array into an `(A, B, C)` record. Returns
/// `null` unless [v] is a `List` of length exactly 3.
ParserFn<(A, B, C)?> tripleOrNull<A, B, C>(
  ParserFn<A> first,
  ParserFn<B> second,
  ParserFn<C> third,
) =>
    (Object? v) => switch (v) {
      final List l when l.length == 3 => (
        _guarded(const ArrayIndex(0), () => first(l[0])),
        _guarded(const ArrayIndex(1), () => second(l[1])),
        _guarded(const ArrayIndex(2), () => third(l[2])),
      ),
      _ => null,
    };

/// Throwing counterpart to [tripleOrNull].
ParserFn<(A, B, C)> tripleOrThrow<A, B, C>(
  ParserFn<A> first,
  ParserFn<B> second,
  ParserFn<C> third,
) {
  final orNull = tripleOrNull(first, second, third);
  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'tripleOrThrow<$A,$B,$C>: expected a 3-element List, got '
        '${v?.runtimeType}',
      ));
}

/// Serializer: `(A, B)` → a 2-element JSON array.
SerializerFn<(A, B)> pairToJson<A, B>(
  SerializerFn<A> first,
  SerializerFn<B> second,
) =>
    (record) => [first(record.$1), second(record.$2)];

/// Serializer: `(A, B, C)` → a 3-element JSON array.
SerializerFn<(A, B, C)> tripleToJson<A, B, C>(
  SerializerFn<A> first,
  SerializerFn<B> second,
  SerializerFn<C> third,
) =>
    (record) => [first(record.$1), second(record.$2), third(record.$3)];
