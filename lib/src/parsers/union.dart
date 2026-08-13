// Parsing support for polymorphic/discriminated JSON: an object shape
// that varies by a "tag" field (e.g. `{"type": "circle", ...}` vs.
// `{"type": "square", ...}`), decoded into a single Dart type — typically
// a `sealed class`.

import '../core/model.dart';
import '../core/types.dart';
import 'primitives.dart' show stringOrNull;

/// Builds a `Parser<T?>` that dispatches on a discriminator field.
///
/// Reads [tagField] out of the incoming JSON object, looks it up in
/// [byTag], and hands the whole object to the matching decoder. Returns
/// `null` if [v] isn't a `Map`, the tag is missing/not a `String`, or no
/// entry in [byTag] matches it — including when [caseInsensitive] is
/// `false` and the case doesn't line up.
///
/// ```dart
/// sealed class Shape implements JsonEncodable { ... }
/// final class Circle extends Shape { ... }
/// final class Square extends Shape { ... }
///
/// final shapeParser = discriminatedOrNull<Shape>(
///   tagField: 'type',
///   byTag: {
///     'circle': Circle.fromJson,
///     'square': Square.fromJson,
///   },
/// );
/// ```
ParserFn<T?> discriminatedOrNull<T>({
  required String tagField,
  required Map<String, JsonDecoder<T>> byTag,
  bool caseInsensitive = false,
}) {
  final lookup = caseInsensitive
      ? {for (final e in byTag.entries) e.key.toLowerCase(): e.value}
      : byTag;

  return (Object? v) {
    if (v is! Map) return null;
    final json = v.cast<String, Object?>();
    final rawTag = stringOrNull(json[tagField]);
    if (rawTag == null) return null;
    final tag = caseInsensitive ? rawTag.toLowerCase() : rawTag;
    return lookup[tag]?.call(json);
  };
}

/// Throwing counterpart to [discriminatedOrNull] — raises
/// [FormatException] if [v] isn't a `Map`, the tag is missing, or it
/// doesn't match any entry in [byTag].
ParserFn<T> discriminatedOrThrow<T>({
  required String tagField,
  required Map<String, JsonDecoder<T>> byTag,
  bool caseInsensitive = false,
}) {
  final orNull = discriminatedOrNull<T>(
    tagField: tagField,
    byTag: byTag,
    caseInsensitive: caseInsensitive,
  );
  return (Object? v) =>
      orNull(v) ??
      (throw FormatException(
        'discriminatedOrThrow<$T>: no match for "$tagField" in $v. '
        'Expected one of: ${byTag.keys.join(', ')}',
      ));
}

/// Serializer companion to [discriminatedOrNull]/[discriminatedOrThrow]:
/// encodes [value] via [toJson], then stamps [tagField]/[tag] onto the
/// result so the output round-trips back through the same parser.
///
/// The map returned by [toJson] is copied, not mutated, so it's safe to
/// reuse the same `toJson` implementation elsewhere.
Json discriminatedToJson<T>(
  T value, {
  required String tagField,
  required String tag,
  required Json Function(T value) toJson,
}) => {...toJson(value), tagField: tag};
