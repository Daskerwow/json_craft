// Flattens a nested JSON object into a single level: you declare the
// exact key each field should have in the flat result, and the path to
// where its value lives in the (arbitrarily nested) source.
//
// Given
//   JsonFlattener()
//     ..field('assignedWorkPu', ['assignedWork', 'pu'])
//     ..field('assignedWorkTotal', ['assignedWork', 'total'])
//     ..field('atProductionPu', ['atProduction', 'pu'])
//     ..field('atProductionTotal', ['atProduction', 'total'])
// turns
//   {assignedWork: {pu: 169, total: 964}, atProduction: {pu: 137, total: 692}}
// into
//   {assignedWorkPu: 169, assignedWorkTotal: 964, atProductionPu: 137,
//    atProductionTotal: 692}

import '../core/types.dart';

/// A single flattening rule: read the value at [path] (walked through
/// nested objects from the source root) and write it under [flatKey] in
/// the result — optionally run through [parser] first.
class _FlattenRule {
  const _FlattenRule(this.flatKey, this.path, this.parser);

  final String flatKey;
  final List<String> path;
  final ParserFn<Object?>? parser;
}

/// Builds a flat `Map<String, Object?>` out of a nested one.
///
/// Unlike a generic "auto-flatten" pass, every field of the result is
/// declared explicitly: **you** name the flat key, and point it at the
/// [path] in the source that holds its value. Nothing is inferred or
/// combined automatically — this makes the result's shape fully
/// predictable and independent of the source's own key names.
///
/// ```dart
/// final flat = JsonFlattener()
///     .field('assignedWorkPu', ['assignedWork', 'pu'])
///     .field('assignedWorkTotal', ['assignedWork', 'total'])
///     .field('atProductionPu', ['atProduction', 'pu'])
///     .field('atProductionTotal', ['atProduction', 'total'])
///     .field('notArrivedPu', ['notArrived', 'pu'])
///     .field('notArrivedTotal', ['notArrived', 'total'])
///     .build(source);
/// // {assignedWorkPu: 169, assignedWorkTotal: 964,
/// //  atProductionPu: 137, atProductionTotal: 692,
/// //  notArrivedPu: 2, notArrivedTotal: 12}
/// ```
///
/// Missing intermediate objects or a missing leaf resolve to `null` (or
/// whatever [parser] does with `null`) rather than throwing — flattening
/// is best-effort by design, mirroring the `xOrDefault`-style parsers
/// elsewhere in this library.
class JsonFlattener {
  final List<_FlattenRule> _rules = [];

  /// Declares one field of the flattened result.
  ///
  /// [flatKey] is the exact key it will be written under in the output —
  /// nothing is derived from [path] automatically. [path] locates the
  /// value inside the (arbitrarily deep) source, e.g.
  /// `['assignedWork', 'pu']` for `source['assignedWork']['pu']`; a
  /// single-element path (`['topLevelKey']`) reads a top-level field.
  ///
  /// If [parser] is given, the raw value found at [path] is run through
  /// it before being written to the result — hand it any parser from
  /// `primitives.dart`/`numeric_ext.dart`/etc. to type the value at the
  /// same time as flattening it, e.g. `parser: intOrZero`. Pass a
  /// `schemaOf(...)` (see `schema.dart`) to flatten a whole nested object
  /// into one field instead of a single scalar.
  JsonFlattener field(
    String flatKey,
    List<String> path, {
    ParserFn<Object?>? parser,
  }) {
    if (path.isEmpty) {
      throw ArgumentError.value(
        path,
        'path',
        'JsonFlattener.field("$flatKey", ...): path must not be empty',
      );
    }
    _rules.add(_FlattenRule(flatKey, path, parser));
    return this;
  }

  /// Shorthand for [field] when the value lives exactly one level deep,
  /// under a single parent key — `.at('assignedWorkPu', 'assignedWork',
  /// 'pu')` is the same as `.field('assignedWorkPu', ['assignedWork',
  /// 'pu'])`.
  JsonFlattener at(
    String flatKey,
    String parentKey,
    String childKey, {
    ParserFn<Object?>? parser,
  }) => field(flatKey, [parentKey, childKey], parser: parser);

  /// Runs every declared rule against [source], producing a flat
  /// `Map<String, Object?>` with exactly the keys declared via
  /// [field]/[at] — in declaration order. Non-`Map` input (or a
  /// non-`Map` value anywhere along a declared path) simply yields `null`
  /// for that field rather than throwing.
  Json build(Object? source) {
    final result = <String, Object?>{};
    for (final rule in _rules) {
      Object? cursor = source;
      for (final key in rule.path) {
        cursor = cursor is Map ? cursor.cast<String, Object?>()[key] : null;
      }
      result[rule.flatKey] = rule.parser != null
          ? rule.parser!(cursor)
          : cursor;
    }
    return result;
  }
}

/// Flattens every nested object one level deep without declaring any
/// rules: for each top-level key of [source] that holds a JSON object,
/// every one of *its* keys is pulled up and combined into
/// `parentKeyChildKey`. Top-level keys that don't hold an object are kept
/// as-is, under their original key.
///
/// ```dart
/// flattenOneLevel({
///   'assignedWork': {'pu': 169, 'total': 964},
///   'atProduction': {'pu': 137, 'total': 692},
/// });
/// // {assignedWorkPu: 169, assignedWorkTotal: 964,
/// //  atProductionPu: 137, atProductionTotal: 692}
/// ```
///
/// This is the "just give me something flat, I don't care about exact
/// naming" escape hatch for exploratory/ad hoc use. For real field
/// definitions — where you control the exact output key and can type the
/// value — use [JsonFlattener] instead.
Json flattenOneLevel(Object? source) {
  final map = source is Map
      ? source.cast<String, Object?>()
      : const <String, Object?>{};
  final result = <String, Object?>{};
  for (final MapEntry(:key, :value) in map.entries) {
    if (value is Map) {
      final nested = value.cast<String, Object?>();
      for (final MapEntry(key: childKey, value: childValue) in nested.entries) {
        final capitalized = childKey.isEmpty
            ? childKey
            : '${childKey[0].toUpperCase()}${childKey.substring(1)}';
        result['$key$capitalized'] = childValue;
      }
    } else {
      result[key] = value;
    }
  }
  return result;
}
