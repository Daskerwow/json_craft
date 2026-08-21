// Small combinators that build new (de)serialization behavior out of
// existing parsers/serializers.

import '../core/types.dart';

/// Lifts a non-nullable serializer to the nullable level.
///
/// ```dart
/// 'ts'.field<M, DateTime?>(serializer: nullable(dateTimeToJson))
/// ```
@pragma('vm:prefer-inline')
SerializerFn<T?> nullable<T>(SerializerFn<T> s) =>
    (v) => v == null ? null : s(v);

/// Tries each parser in turn; returns the first non-null result.
///
/// Exceptions from individual parsers are swallowed so the next one gets a
/// chance. Returns `null` if none of them produced a value.
@pragma('vm:prefer-inline')
ParserFn<T?> oneOf<T>(List<ParserFn<T?>> parsers) {
  assert(parsers.isNotEmpty, 'oneOf: the parser list must not be empty');
  return (Object? v) {
    for (final p in parsers) {
      try {
        final r = p(v);
        if (r != null) return r;
      } catch (_) {
        // Swallowed by design — try the next parser.
      }
    }
    return null;
  };
}

/// Applies [transform] to the result of [parser], if it returned non-null.
@pragma('vm:prefer-inline')
ParserFn<R?> mappedOrNull<T, R>(
  ParserFn<T?> parser,
  R? Function(T value) transform,
) =>
    (Object? v) => switch (parser(v)) {
      final T r => transform(r),
      _ => null,
    };

/// Applies [transform] to the result of [parser]; returns [fallback] if it
/// was null.
@pragma('vm:prefer-inline')
ParserFn<R> mappedOrDefault<T, R>(
  ParserFn<T?> parser,
  R Function(T value) transform,
  R fallback,
) {
  final orNull = mappedOrNull(parser, transform);
  return (Object? v) => orNull(v) ?? fallback;
}

/// Wraps [parser] in try/catch — returns `null` on any exception.
@pragma('vm:prefer-inline')
ParserFn<T?> tryOrNull<T>(ParserFn<T> parser) => (Object? v) {
  try {
    return parser(v);
  } catch (_) {
    return null;
  }
};

/// Runs [parser]; falls back to [fallback] on error or a null result.
@pragma('vm:prefer-inline')
ParserFn<T> withFallback<T>(ParserFn<T> parser, T fallback) {
  final orNull = tryOrNull(parser);
  return (Object? v) => orNull(v) ?? fallback;
}

/// Wraps [parser], discarding its result (mapping to `null`) unless
/// [predicate] holds. Layers a validation rule onto an existing parser
/// without writing a bespoke one.
///
/// ```dart
/// final positiveInt = refine(intOrNull, (n) => n > 0);
/// ```
@pragma('vm:prefer-inline')
ParserFn<T?> refine<T>(ParserFn<T?> parser, bool Function(T value) predicate) =>
    (Object? v) => switch (parser(v)) {
      final T r when predicate(r) => r,
      _ => null,
    };

/// Runs [first]; if it returns `null`, runs [second] on the *original*
/// input instead of on [first]'s result.
///
/// Unlike [oneOf], this is a plain two-way fallback with no
/// exception-swallowing — either parser throwing propagates normally.
@pragma('vm:prefer-inline')
ParserFn<T?> orElse<T>(ParserFn<T?> first, ParserFn<T?> second) =>
    (Object? v) => first(v) ?? second(v);

/// Runs [parser], then feeds its non-null result through [next].
/// Short-circuits to `null` without calling [next] if [parser] returns
/// `null`.
///
/// Composes two parsers into a pipeline, e.g. parsing a `String` and then
/// validating its shape:
/// ```dart
/// final trimmedEmail = andThen(stringOrNull, emailOrNull);
/// ```
@pragma('vm:prefer-inline')
ParserFn<R?> andThen<T, R>(ParserFn<T?> parser, ParserFn<R?> next) =>
    (Object? v) => switch (parser(v)) {
      final T r => next(r),
      _ => null,
    };
