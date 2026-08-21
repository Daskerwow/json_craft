/// A single step in a [JsonPath].
sealed class PathSegment {
  const PathSegment();
}

/// A key in a JSON object, e.g. the `address` in `user.address`.
final class ObjectKey extends PathSegment {
  const ObjectKey(this.name);

  final String name;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is ObjectKey && other.name == name;

  @override
  int get hashCode => Object.hash(ObjectKey, name);
}

/// An index into a JSON array, e.g. the `2` in `items[2]`.
final class ArrayIndex extends PathSegment {
  const ArrayIndex(this.index);

  final int index;

  @override
  String toString() => '[$index]';

  @override
  bool operator ==(Object other) =>
      other is ArrayIndex && other.index == index;

  @override
  int get hashCode => Object.hash(ArrayIndex, index);
}

/// A key inside a `Map` value that isn't a plain string object key,
/// rendered as `['key']`.
final class MapKey extends PathSegment {
  const MapKey(this.key);

  final Object? key;

  @override
  String toString() => "['$key']";

  @override
  bool operator ==(Object other) => other is MapKey && other.key == key;

  @override
  int get hashCode => Object.hash(MapKey, key);
}

/// An immutable, composable path to a value inside a JSON document.
///
/// Renders as dot-separated object keys with bracketed indices, e.g.
/// `addresses[0].city` or `metadata['error']`.
final class JsonPath {
  const JsonPath(this.segments);

  const JsonPath.root() : segments = const [];

  final List<PathSegment> segments;

  bool get isRoot => segments.isEmpty;

  /// Returns a new path with [segment] appended.
  JsonPath child(PathSegment segment) => JsonPath([...segments, segment]);

  /// Returns a new path with [other]'s segments appended after this one's.
  JsonPath concat(JsonPath other) => JsonPath([...segments, ...other.segments]);

  @override
  String toString() {
    if (segments.isEmpty) return r'$';
    final buf = StringBuffer();
    for (final segment in segments) {
      if (segment is ObjectKey && buf.isNotEmpty) buf.write('.');
      buf.write(segment);
    }
    return buf.toString();
  }

  // Structural equality over [segments], rather than comparing rendered
  // `toString()` output. Two paths with segments that happen to render the
  // same way (unlikely, but not impossible with adversarial `MapKey`
  // content) no longer compare equal unless their segments actually match
  // one-for-one; this also avoids building a `String` on every comparison.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JsonPath) return false;
    if (other.segments.length != segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(segments);
}

/// Thrown internally by composable parsers ([at], `listOf`, `mapOf`, ...) to
/// carry a partial [JsonPath] and the original failure up to the nearest
/// `JsonReader`, which has the model context needed to build a full
/// `SerializationError`.
///
/// This type can also surface directly to callers who use parser
/// combinators outside a `JsonReader` (e.g. calling `listOf(intOrThrow)`
/// standalone) — it is a normal [Exception] with a readable [toString].
final class JsonPathError implements Exception {
  const JsonPathError(this.path, this.cause);

  final JsonPath path;
  final Object cause;

  /// Returns a copy of this error with [segment] prepended to [path].
  JsonPathError under(PathSegment segment) =>
      JsonPathError(JsonPath([segment]).concat(path), cause);

  @override
  String toString() => 'JsonPathError: at "$path": $cause';
}
