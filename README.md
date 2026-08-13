# json_craft

**Total, path-aware JSON parsers and serializers for Dart.**

`json_craft` turns messy real-world JSON into typed Dart values without throwing by default. Every parser is total (`xOrNull` / `xOrDefault` / `xOrZero`…), failures are annotated with a full `JsonPath`, and the API stays small and composable.

## Why

Most JSON libraries force you to choose between:

- Strict decoding that blows up on the first bad field, or
- Manual null-checks and `as` casts everywhere.

`json_craft` gives you a third option: **total parsers** that never throw unless you explicitly ask them to (`…OrThrow`). Missing or malformed values become `null`, a default, or an empty collection — and when something _does_ go wrong, you get a precise path (`$.users[3].address.city`).

## Features

- **Primitives** — `String`, `int`, `double`, `num`, `bool`, `BigInt`, `Uri`, `Uint8List` (base64)
- **Collections** — `List`, `Set`, `Map` with element/entry parsers
- **Temporal** — smart `DateTime` (ISO-8601 + Unix s/ms), `Duration`, date-only, ISO-8601 durations
- **Enums** — by name, optional case-insensitive
- **Models** — nested objects via `JsonDecoder` / `JsonCodec`
- **Schema** — declarative `JsonSchema` that types a whole nested shape in one go
- **Flattening** — pull nested values into a flat map with explicit key control
- **Combinators** — `nullable`, `oneOf`, `andThen`, `refine`, `orElse`, `mapped…`, `tryOrNull`…
- **Discriminated unions** — tag-based parsing for sealed classes
- **Path-aware errors** — every failure carries a `JsonPath`

## Quick example

```dart
import 'package:json_craft/json_craft.dart';

final userSchema = <String, Object?>{
  'id': intOrZero,
  'name': stringOrEmpty,
  'email': emailOrNull,
  'roles': [stringOrEmpty],
  'createdAt': dateTimeOrNull,
  'settings': {
    'theme': stringOrDefault('system'),
    'notifications': boolOrFalse,
  },
};

final typed = typeJson(rawJson, userSchema);
// or turn the schema into a reusable parser:
final userParser = schemaOf(userSchema);
```
