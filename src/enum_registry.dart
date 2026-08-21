// A mutable, opt-in registry that lets `getParseByType`/`smartParseByType`
// recognize enum types.
//
// ### Why this has to be explicit
//
// Every type in `_primitiveParsers` (int, String, DateTime, ...) is fixed
// at compile time, so a lookup table built once, ahead of time, is enough.
// A user-defined `enum` can't be discovered the same way: Dart has no
// `dart:mirrors` on Flutter/AOT, and a `Type` object alone carries no way
// to recover `SomeEnum.values` at runtime. The only place that list is
// available is the call site that already imports `SomeEnum` — so that
// call site has to hand it to us, once, via [registerEnum].
//
// After that one-time registration, `getParseByType(SomeEnum)` and
// `smartParseByType(SomeEnum, v)` behave exactly like they do for any
// built-in primitive — including from code that has no idea `SomeEnum`
// exists (e.g. a generic built_value plugin walking a `FullType`).

import 'core/types.dart';
import 'parsers/parsers.dart';

Type _typeOf<T>() => T;

final Map<Type, ParserFn<Object?>> _enumParsers = {};

/// Registers [T] with the shared type-driven parser registry so that
/// [getParseByType], [smartParseByType], and [smartParseOf] recognize it.
///
/// Registers both forms of [T]:
///  - `T`  — unrecognized/missing input resolves to [fallback].
///  - `T?` — unrecognized/missing input resolves to `null`.
///
/// [fallback] is required rather than silently defaulting to
/// `values.first`: unlike `0` for `int` or `""` for `String`, no enum
/// value is an obviously "correct" default. Pick the one that's right for
/// your domain — e.g. `LogLevel.fatal` so a garbled level fails loud
/// instead of quietly turning into `.verbose`.
///
/// Call this once, before the first (de)serialization that touches [T] —
/// typically from `main()` or a dedicated `registerEnums()` next to your
/// model definitions. Safe to call again for the same [T] (last
/// registration wins), which is handy for tests.
///
/// ```dart
/// void registerEnums() {
///   registerEnum(LogLevel.values, fallback: LogLevel.fatal, caseInsensitive: true);
/// }
/// ```
void registerEnum<T extends Enum>(
  List<T> values, {
  required T fallback,
  bool caseInsensitive = false,
}) {
  final orNull = enumOrNull<T>(values, caseInsensitive: caseInsensitive);
  _enumParsers[T] = (Object? v) => orNull(v) ?? fallback;
  _enumParsers[_typeOf<T?>()] = orNull;
}

/// Removes any parser registered for [T] (both nullable and non-nullable
/// forms). Mostly useful for isolating test cases.
void unregisterEnum<T extends Enum>() {
  _enumParsers.remove(T);
  _enumParsers.remove(_typeOf<T?>());
}

/// Clears every registered enum parser. Mostly useful in a test
/// `tearDown` after calls to [registerEnum].
void clearRegisteredEnums() => _enumParsers.clear();

/// Looks up the parser registered for [type] via [registerEnum], if any.
///
/// Used internally by [getParseByType] — most callers want that instead,
/// since it also covers the built-in primitives.
ParserFn<Object?>? getEnumParseByType(Type? type) {
  if (type == null) return null;
  return _enumParsers[type];
}
