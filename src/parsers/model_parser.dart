import '../core/model.dart';
import '../core/types.dart';
import 'collections.dart' show listOf, listOrNullOf;

/// Parses a nested model from a JSON object. Returns `null` if the value
/// isn't a `Map`.
@pragma('vm:prefer-inline')
ParserFn<T?> modelOrNull<T>(JsonDecoder<T> fromJson) =>
    (Object? v) => switch (v) {
      final Map m => fromJson(m.cast<String, Object?>()),
      _ => null,
    };

/// Alias for [modelOf] — for symmetry with the other `xOrThrow` parsers.
@pragma('vm:prefer-inline')
ParserFn<T> modelOrThrow<T>(JsonDecoder<T> fromJson) => modelOf(fromJson);

/// Parses a nested model from a JSON object. Throws [FormatException] if
/// the value isn't a `Map`.
@pragma('vm:prefer-inline')
ParserFn<T> modelOf<T>(JsonDecoder<T> fromJson) {
  final orNull = modelOrNull(fromJson);

  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'modelOf<$T>: expected a Map, got ${v?.runtimeType}',
      ));
}

// ─── Raw JSON object ────────────────────────────────────────────────────

/// Parses an arbitrary JSON object as `Map<String, Object?>`.
@pragma('vm:prefer-inline')
Json? jsonObjectOrNull(Object? v) => switch (v) {
  final Map m => m.cast<String, Object?>(),
  _ => null,
};

@pragma('vm:prefer-inline')
Json jsonObjectOrEmpty(Object? v) => jsonObjectOrNull(v) ?? const {};

ParserFn<Json> jsonObjectOrDefault(Json fallback) =>
    (Object? v) => jsonObjectOrNull(v) ?? fallback;

@pragma('vm:prefer-inline')
Json jsonObjectOrThrow(Object? v) =>
    jsonObjectOrNull(v) ??
    (throw FormatException(
      'jsonObjectOrThrow: expected a Map, got ${v?.runtimeType}',
    ));

/// Parses an arbitrary JSON object as `List<Object?>`.
@pragma('vm:prefer-inline')
List<Object?>? listObjectOrNull(Object? v) => switch (v) {
  final List m => m.cast<Object?>(),
  _ => null,
};

@pragma('vm:prefer-inline')
List<Object?> listObjectOrEmpty(Object? v) =>
    listObjectOrNull(v) ?? const <Object?>[];

@pragma('vm:prefer-inline')
ParserFn<List<Object?>> listObjectOrDefault(List<Object?> fallback) =>
    (Object? v) => listObjectOrNull(v) ?? fallback;

@pragma('vm:prefer-inline')
List<Object?> listObjectOrThrow(Object? v) =>
    listObjectOrNull(v) ??
    (throw FormatException(
      'listObjectOrThrow: expected a List, got ${v?.runtimeType}',
    ));

// ─── JsonCodec parsing ──────────────────────────────────────────────────

/// Turns a [JsonCodec] into ordinary [ParserFn]s, for use with `JsonReader`,
/// [listOf], or any other combinator in this library.
extension JsonCodecParsing<T extends JsonEncodable> on JsonCodec<T> {
  /// A `Parser<T>` built from this codec's `decode`.
  ParserFn<T> get parser => modelOf(decode);

  /// A `Parser<T?>` built from this codec's `decode`.
  ParserFn<T?> get nullableParser => modelOrNull(decode);

  /// A `Parser<List<T>>` that decodes each element with this codec.
  ParserFn<List<T>> get listParser => listOf(parser);

  /// A `Parser<List<T>?>` that decodes each element with this codec, or
  /// resolves to `null` for non-`List` input.
  ParserFn<List<T>?> get nullableListParser => listOrNullOf(parser);
}
