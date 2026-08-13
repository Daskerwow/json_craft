import 'path.dart';

/// Every failure raised anywhere in this library, however deeply nested,
/// surfaces as one of [RequiredFieldError], [TypeConversionError],
/// [UnserializableValueError], or [PathCollisionError] — always carrying
/// the model and field involved, the full path to the offending value, the
/// raw value itself, and — when triggered by another exception — that
/// exception as [cause].
///
/// Being `sealed`, this type supports exhaustive `switch` matching:
///
/// ```dart
/// String describe(SerializationError e) => switch (e) {
///   RequiredFieldError() => 'missing: ${e.path}',
///   TypeConversionError(:final expectedType) => 'wrong type, wanted $expectedType',
///   UnserializableValueError() => 'cannot serialize: ${e.path}',
///   PathCollisionError() => 'colliding paths at ${e.path}',
/// };
/// ```
///
/// ### On [path] and nested models
///
/// [path] is the full path *as seen by the `JsonReader`/`SchemaReader`
/// that actually threw this error*. For a field parsed directly by that
/// reader — including anything reached via `at(...)`/`.under(...)` — that
/// is genuinely the full path from the document root down to the
/// offending value.
///
/// A nested model parsed via `modelOf`/`modelOrNull` (i.e. `Address
/// .fromJson`) is different: it builds its own `JsonReader<Address>`
/// starting at its own root, so an error it throws initially only knows
/// about *its own* fields (e.g. `city`, not `address.city`). The outer
/// reader that called it corrects this — see [prefixPath] — by prepending
/// the path of the field it was reading (`address`) before the error
/// leaves `req`/`opt`. By the time a [SerializationError] reaches your
/// code, [path] is always the full path from the root of the *original*
/// document that was decoded, no matter how many models deep the failure
/// occurred.
sealed class SerializationError extends Error {
  SerializationError({
    required this.modelType,
    required this.jsonKey,
    required this.path,
    this.rawValue,
    this.cause,
    this.message,
  });

  /// The model type being (de)serialized, e.g. `User`.
  final Type modelType;

  /// The JSON key of the field where the error originated.
  final String jsonKey;

  /// The full path to the offending value, e.g. `users[0].address.city`.
  final JsonPath path;

  /// The raw value that caused the error, if any.
  final Object? rawValue;

  /// The underlying exception, if the error was triggered by one.
  final Object? cause;

  /// A human-readable description of the failure.
  final String? message;

  /// Returns a copy of this error with [prefix] prepended to [path].
  ///
  /// Used by `JsonReader`/`SchemaReader` to fix up an error that bubbled up
  /// from a nested model's own reader (which always starts at its own
  /// root) so the final, user-visible [path] reflects the full path from
  /// the document that was actually being decoded — not just the path
  /// relative to whichever nested model happened to throw.
  ///
  /// [modelType] and [jsonKey] are left untouched: they still correctly
  /// identify the model/field that actually failed (e.g. `Address.city`),
  /// only [path] grows a prefix.
  SerializationError prefixPath(JsonPath prefix) {
    if (prefix.isRoot) return this;
    final newPath = prefix.concat(path);
    return switch (this) {
      RequiredFieldError e => RequiredFieldError(
        modelType: e.modelType,
        jsonKey: e.jsonKey,
        path: newPath,
        rawValue: e.rawValue,
      ),
      TypeConversionError e => TypeConversionError(
        modelType: e.modelType,
        jsonKey: e.jsonKey,
        path: newPath,
        expectedType: e.expectedType,
        actualType: e.actualType,
        rawValue: e.rawValue,
        cause: e.cause,
      ),
      UnserializableValueError e => UnserializableValueError(
        modelType: e.modelType,
        fieldPath: newPath,
        // Construction requires a non-null `value`; UnserializableValueError
        // always stores its (always-non-null) constructor argument as
        // `rawValue`, so this is never actually null here.
        value: e.rawValue as Object,
      ),
      PathCollisionError e => PathCollisionError(
        modelType: e.modelType,
        jsonKey: e.jsonKey,
        path: newPath,
        existingValue: e.rawValue,
      ),
    };
  }

  @override
  String toString() {
    final buf = StringBuffer('$runtimeType: [$modelType.$jsonKey]\n');
    if (message != null) buf.writeln('  message  : $message');
    buf.writeln('  path     : $path');
    if (rawValue != null) {
      buf.writeln('  raw value: ${rawValue.runtimeType} ($rawValue)');
    }
    if (cause != null) buf.writeln('  cause    : $cause');
    return buf.toString().trimRight();
  }
}

/// A required field was missing from the JSON, or resolved to `null`.
final class RequiredFieldError extends SerializationError {
  RequiredFieldError({
    required super.modelType,
    required super.jsonKey,
    required super.path,
    super.rawValue,
  }) : super(message: 'required field is null or missing');
}

/// A value was present but could not be converted to the expected type.
final class TypeConversionError extends SerializationError {
  TypeConversionError({
    required super.modelType,
    required super.jsonKey,
    required super.path,
    required this.expectedType,
    required this.actualType,
    super.rawValue,
    super.cause,
  }) : super(message: 'expected $expectedType, got $actualType');

  /// The type the parser expected to produce.
  final Type expectedType;

  /// The runtime type of the raw value that was received.
  final Type actualType;

  @override
  String toString() =>
      '${super.toString()}\n  expected : $expectedType\n  actual   : $actualType';
}

/// A value has no known JSON representation. Thrown from the write
/// direction (`toJson()` / `serializeAny`) — the mirror image of
/// [TypeConversionError] on the read direction.
///
/// [path] is not necessarily a single field name — recursion through
/// nested `Map`s/`List`s can point past the field itself into the specific
/// key or index that held the bad value, e.g. `metadata['error']`.
///
/// Note: Dart Records (`(1, 'a')`, `({int x})`) are not, and cannot be,
/// handled generically by `serializeAny` — a Record exposes no runtime way
/// to enumerate its fields without `dart:mirrors` (unavailable on
/// Flutter/AOT). A Record value always ends up here; convert it to a `Map`
/// or a `JsonEncodable` explicitly before handing it to `serializeAny`, or
/// avoid `serializeAny` for that field and write it directly in `toJson()`.
final class UnserializableValueError extends SerializationError {
  UnserializableValueError({
    required super.modelType,
    required JsonPath fieldPath,
    required Object value,
  }) : super(
         jsonKey: fieldPath.toString(),
         path: fieldPath,
         rawValue: value,
         message:
             'value is not JSON-serializable — serialize it explicitly '
             '(e.g. call `.toJson()` on a nested model, or '
             '`.toIso8601String()` on a DateTime), or make sure it only ever '
             'holds JSON-safe values (num, String, bool, null, DateTime, '
             'Duration, Uri, BigInt, Enum, List, Set, Map, or a '
             'JsonEncodable). Dart Records are never handled automatically — '
             'see this class\'s doc comment.',
       );
}

/// Two fields written via `JsonWriter.putAt` collide: one wrote a plain
/// value where another expected to nest an object underneath it.
///
/// [path] points at the exact path segment where the collision was found
/// — e.g. for `putAt(['meta', 'stats'], 'total', v)` colliding on `meta`
/// itself, [path] is `meta`, not `meta.stats.total`. [jsonKey] still names
/// the field that was being written when the collision was discovered, so
/// you can tell *which write* triggered it even though [path] stops short
/// of that field's own key.
final class PathCollisionError extends SerializationError {
  PathCollisionError({
    required super.modelType,
    required super.jsonKey,
    required super.path,
    required Object? existingValue,
  }) : super(
         rawValue: existingValue,
         message:
             'path segment already holds a ${existingValue.runtimeType}, not '
             'a nested object — check for two fields whose paths collide',
       );
}
