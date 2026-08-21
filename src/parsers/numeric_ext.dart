// Numeric parsers layered on top of `primitives.dart`: range validation,
// clamping, and percentage conversion. Kept in a separate file since these
// are parser *factories* (they take bounds as arguments) rather than the
// fixed, zero-argument parsers in `primitives.dart`.

import '../core/types.dart';
import 'primitives.dart' show doubleOrNull, intOrNull, numOrNull;

// `num.clamp` returns `num`, not `int`/`double` — assigning its result
// back to a typed variable is a classic Dart footgun. These two local
// helpers keep the return type exact.
int _clampInt(int v, int min, int max) => v < min ? min : (v > max ? max : v);

double _clampDouble(double v, double min, double max) =>
    v < min ? min : (v > max ? max : v);

/// Parses an [int] and returns `null` unless it falls within `[min, max]`
/// (inclusive on both ends).
ParserFn<int?> intInRangeOrNull(int min, int max) => (Object? v) {
  final n = intOrNull(v);
  return (n != null && n >= min && n <= max) ? n : null;
};

/// Parses an [int], clamping any parseable-but-out-of-range value to the
/// nearest bound of `[min, max]`. Unparseable input falls back to
/// [fallback], itself clamped into range.
ParserFn<int> intClamped(int min, int max, {int fallback = 0}) {
  final boundedFallback = _clampInt(fallback, min, max);
  return (Object? v) {
    final n = intOrNull(v);
    return n == null ? boundedFallback : _clampInt(n, min, max);
  };
}

/// Parses a [double] and returns `null` unless it falls within
/// `[min, max]` (inclusive on both ends). `NaN` and infinities are always
/// treated as out of range.
ParserFn<double?> doubleInRangeOrNull(double min, double max) => (Object? v) {
  final n = doubleOrNull(v);
  if (n == null || n.isNaN || n.isInfinite) return null;
  return (n >= min && n <= max) ? n : null;
};

/// Parses a [double], clamping any parseable-but-out-of-range value to
/// `[min, max]`. `NaN`/infinite/unparseable input falls back to
/// [fallback], itself clamped into range.
ParserFn<double> doubleClamped(double min, double max, {double fallback = 0}) {
  final boundedFallback = _clampDouble(fallback, min, max);
  return (Object? v) {
    final n = doubleOrNull(v);
    if (n == null || n.isNaN || n.isInfinite) return boundedFallback;
    return _clampDouble(n, min, max);
  };
}

/// Parses a "percentage" value into a `0.0`–`1.0` fraction.
///
/// Accepts either an already-normalized fraction (`0.0`–`1.0`) or a
/// human-scale percentage (`0`–`100`, e.g. from a form field): any value
/// greater than `1` is assumed to be on the `0`–`100` scale and divided by
/// 100. Negative input, `NaN`/infinite input, or a result still outside
/// `0.0`–`1.0` after normalizing all return `null`.
///
/// ```dart
/// percentOrNull(50)   // 0.5  (treated as 50%)
/// percentOrNull(0.5)  // 0.5  (already a fraction)
/// percentOrNull(150)  // null (out of range)
/// ```
double? percentOrNull(Object? v) {
  final n = numOrNull(v)?.toDouble();
  if (n == null || n.isNaN || n.isInfinite || n < 0) return null;
  final fraction = n > 1 ? n / 100 : n;
  return fraction <= 1 ? fraction : null;
}

@pragma('vm:prefer-inline')
double percentOrZero(Object? v) => percentOrNull(v) ?? 0.0;
