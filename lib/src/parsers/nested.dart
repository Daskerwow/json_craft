import '../core/path.dart';
import '../core/types.dart';

/// Declares that the value this parser reads lives one level deeper in the
/// JSON, under [key].
///
/// ```dart
/// // json['meta']['stats'] as an int:
/// r.opt('meta', at('stats', intOrZero))
///
/// // Chained — json['meta']['stats']['count'] as an int:
/// r.opt('meta', at('stats', at('count', intOrZero)))
/// ```
///
/// For reading several fields out of the same nested object, prefer
/// `JsonReader.under` instead of chaining `at` on each field.
///
/// A failure from [child] is annotated with [key] so the full path
/// survives up to the nearest `JsonReader`.
ParserFn<T> at<T>(String key, ParserFn<T> child) => (Object? v) {
  final nested = v is Map ? v[key] : null;
  try {
    return child(nested);
  } on JsonPathError catch (e) {
    throw e.under(ObjectKey(key));
  } catch (e) {
    throw JsonPathError(JsonPath.root().child(ObjectKey(key)), e);
  }
};

/// Shorthand for chaining [at] across multiple levels:
/// `atPath(['meta', 'stats'], intOrZero)` is equivalent to
/// `at('meta', at('stats', intOrZero))`.
ParserFn<T> atPath<T>(List<String> keys, ParserFn<T> child) =>
    keys.reversed.fold(child, (acc, key) => at(key, acc));
