// Declarative typing: describe a JSON shape once — as a Map whose values
// are Parsers (or nested schemas) mirroring the JSON's own structure — and
// get a typed copy of any input matching that shape back.
//
// This is the mirror image of a "schema" in the validation-library sense:
// it doesn't validate/reject, it *converts*. Every leaf parser in this
// library is total (`xOrNull`/`xOrZero`/`xOrDefault`/...), so applying a
// JsonSchema never throws unless you deliberately plug in an `xOrThrow`
// parser somewhere in it — in which case the failure is annotated with a
// full JsonPath, exactly like `at`/`listOf`/`mapOf` do.

import '../core/path.dart';
import '../core/types.dart';

/// One entry of a [JsonSchema]:
///  - a `ParserFn<Object?>` (e.g. `intOrZero`, `dateTimeOrNull`, a
///    `JsonCodec<T>.parser`, or any combinator from this library) — a
///    leaf field, run directly against the raw value at that key;
///  - a nested [JsonSchema] — recurses into the object at that key;
///  - a single-element `List<JsonSchema>` (e.g. `[itemSchema]`) — the
///    value at that key is a JSON array, each element of which is typed
///    against the one schema inside the list.
///
/// ```dart
/// final schema = <String, Object?>{
///   'assignedWork': {'pu': intOrZero, 'total': intOrZero},
///   'atProduction': {'pu': intOrZero, 'total': intOrZero},
///   'notArrived':   {'pu': intOrZero, 'total': intOrZero},
///   'startedAt': dateTimeOrNull,
///   'tags': [stringOrEmpty],
/// };
/// ```
typedef JsonSchema = Map<String, Object?>;

/// Applies [schema] to [source], producing a same-shaped `Json` whose
/// leaves have been run through the corresponding parser.
///
/// Keys present in [source] but absent from [schema] are dropped — this
/// is a projection, not a passthrough copy. A key present in [schema] but
/// missing from [source] still runs its parser against `null`, so it
/// still appears in the result (typically as the parser's own default,
/// e.g. `0` for `intOrZero`, or `null` for an `xOrNull` parser).
///
/// Non-`Map` [source] (or a non-`Map` value at a nested-schema key) is
/// treated as an empty object, mirroring `jsonObjectOrEmpty` elsewhere in
/// this library — not an error.
///
/// A malformed schema entry (anything other than a `ParserFn`, a nested
/// [JsonSchema], or a single-element `List<JsonSchema>`) throws
/// [ArgumentError] immediately — that's a bug in the schema itself, not
/// bad input data, so it isn't swallowed the way parser failures are.
Json typeJson(Object? source, JsonSchema schema) {
  final map = source is Map
      ? source.cast<String, Object?>()
      : const <String, Object?>{};
  final result = <String, Object?>{};
  for (final MapEntry(:key, value: rule) in schema.entries) {
    result[key] = _applyRule(rule, map[key], key);
  }
  return result;
}

Object? _applyRule(Object? rule, Object? raw, String key) {
  try {
    return switch (rule) {
      final JsonSchema nested => typeJson(raw, nested),
      [final JsonSchema itemSchema] => switch (raw) {
        final List l => [for (final e in l) typeJson(e, itemSchema)],
        _ => const <Object?>[],
      },
      final ParserFn<Object?> parser => parser(raw),
      _ => throw ArgumentError(
        'JsonSchema entry for "$key" must be a ParserFn, a nested '
        'JsonSchema, or a single-element List<JsonSchema>; got '
        '${rule.runtimeType}',
      ),
    };
  } on JsonPathError catch (e) {
    throw e.under(ObjectKey(key));
  } on ArgumentError {
    rethrow; // a bad schema, not bad data — surface it as-is.
  } catch (e) {
    throw JsonPathError(JsonPath.root().child(ObjectKey(key)), e);
  }
}

/// Turns a [JsonSchema] into an ordinary `ParserFn<Json>` — for plugging a
/// whole nested shape into `listOf`, `at`, `JsonFlattener.pick`'s
/// `parser:`, or anywhere else in this library that expects a
/// `ParserFn<T>` rather than a bare schema.
///
/// ```dart
/// final workBucket = schemaOf({'pu': intOrZero, 'total': intOrZero});
///
/// // e.g. a list of buckets:
/// final buckets = listOf(workBucket)(json['buckets']);
///
/// // or through a JsonReader field, if your models use one:
/// r.opt('assignedWork', workBucket) // ParserFn<Json>
/// ```
@pragma('vm:prefer-inline')
ParserFn<Json> schemaOf(JsonSchema schema) =>
    (Object? v) => typeJson(v, schema);
