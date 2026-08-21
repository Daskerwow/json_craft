// Total parsers/serializers for binary data (Uint8List), encoded as
// base64 strings in JSON — the conventional representation, since JSON
// has no native binary type.

import 'dart:convert';
import 'dart:typed_data';

import '../core/types.dart';

/// Parses [Uint8List] from a base64-encoded [String], or from a JSON
/// array of byte values (each entry coerced into the `0`–`255` range via
/// `& 0xff`).
///
/// Returns `null` for `null`, a malformed base64 string, or anything
/// that's neither a `String` nor a `List`.
@pragma('vm:prefer-inline')
Uint8List? bytesOrNull(Object? v) => switch (v) {
  null => null,
  final Uint8List b => b,
  final String s when s.isNotEmpty => _tryDecodeBase64(s),
  final List l => Uint8List.fromList([
    for (final e in l)
      if (e is num) e.toInt() & 0xff,
  ]),
  _ => null,
};

Uint8List? _tryDecodeBase64(String s) {
  try {
    return base64.decode(s);
  } on FormatException {
    return null;
  }
}

@pragma('vm:prefer-inline')
Uint8List bytesOrEmpty(Object? v) => bytesOrNull(v) ?? Uint8List(0);

@pragma('vm:prefer-inline')
ParserFn<Uint8List> bytesOrDefault(Uint8List fallback) =>
    (Object? v) => bytesOrNull(v) ?? fallback;

@pragma('vm:prefer-inline')
Uint8List bytesOrThrow(Object? v) =>
    bytesOrNull(v) ??
    (throw FormatException(
      'bytesOrThrow: expected a base64 string or a byte array, got '
      '${v?.runtimeType} ($v)',
    ));

/// Serializer: `Uint8List` → base64 string.
@pragma('vm:prefer-inline')
String bytesToJson(Uint8List v) => base64.encode(v);
