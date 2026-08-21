import 'types.dart';

/// A type that can serialize itself to JSON.
///
/// Every hand-written model implements this by defining its own
/// `toJson()`. The interface exists so generic code — [JsonCodec],
/// `serializeAny`, collection parsers — can recognize and call it without
/// reflection.
abstract interface class JsonEncodable {
  Json toJson();
}

/// A `fromJson` factory signature: builds a [T] from a JSON object.
typedef JsonDecoder<T> = T Function(Json json);

/// Pairs a model's `fromJson` factory with its `toJson()` method into a
/// single, transferable value.
///
/// Useful anywhere a full read/write contract for [T] needs to be passed
/// around as a value — generic storage layers, HTTP clients, collection
/// parsers — without hard-coding the model type at each call site.
///
/// ```dart
/// const userCodec = JsonCodec<User>(User.fromJson);
///
/// final user = userCodec.decode(json);
/// final json = userCodec.encode(user);
/// ```
///
/// See `JsonCodecParsing` (in `model_parser.dart`) for `.parser` and
/// `.listParser` accessors that turn a codec into ordinary `Parser`s.
final class JsonCodec<T extends JsonEncodable> {
  const JsonCodec(this.decode);

  /// Builds a [T] from a JSON object.
  final JsonDecoder<T> decode;

  /// Converts a [T] back to JSON via its own `toJson()`.
  Json encode(T value) => value.toJson();
}
