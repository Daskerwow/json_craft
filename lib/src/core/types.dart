/// Converts an arbitrary JSON value into a typed [T].
///
/// Implementations should be total: never throw on ordinary bad input.
/// To signal "could not parse" without throwing, use `Parser<T?>` and
/// return `null`. Throwing is reserved for `xOrThrow`-style parsers, where
/// bad input represents a genuine bug rather than a case to handle
/// gracefully.
typedef ParserFn<T> = T Function(Object? value);

/// Converts a typed [T] back into a JSON-safe value: a primitive, [List],
/// [Map], or `null`.
typedef SerializerFn<T> = Object? Function(T value);

/// A standard JSON object.
typedef Json = Map<String, Object?>;

/// A JSON object as handed back by packages that use `Map<String, dynamic>`
/// instead of `Map<String, Object?>`.
typedef JsonRaw = Map<String, dynamic>;
