// String parsers that validate shape/format, not just type — layered on
// top of `stringOrNull` from `primitives.dart`. Where `primitives.dart`
// answers "is this a string?", this file answers "is this string shaped
// the way I need?".

import '../core/types.dart';
import 'primitives.dart' show stringOrNull;

/// Parses a non-blank [String]: `null`, non-`String` input, and input
/// that's empty after trimming all return `null`.
///
/// Contrast with `stringOrNull`, which accepts `""` as a valid result.
ParserFn<String?> nonEmptyStringOrNull({bool trim = true}) => (Object? v) {
  final s = stringOrNull(v, trim: trim);
  return (s == null || s.isEmpty) ? null : s;
};

/// Parses a [String] whose length (after trimming, if [trim]) falls
/// within `[minLength, maxLength]` inclusive. Returns `null` otherwise.
ParserFn<String?> boundedStringOrNull(
  int minLength,
  int maxLength, {
  bool trim = true,
}) {
  assert(
    minLength <= maxLength,
    'boundedStringOrNull: minLength must be <= maxLength',
  );
  return (Object? v) {
    final s = stringOrNull(v, trim: trim);
    if (s == null) return null;
    return (s.length >= minLength && s.length <= maxLength) ? s : null;
  };
}

/// Parses a [String] that matches [pattern] anywhere in the (optionally
/// trimmed) input — use an anchored `^...$` pattern if a full match is
/// required. Returns `null` for non-matching or non-`String` input.
ParserFn<String?> matchingOrNull(RegExp pattern, {bool trim = true}) =>
    (Object? v) {
      final s = stringOrNull(v, trim: trim);
      return (s != null && pattern.hasMatch(s)) ? s : null;
    };

/// A conservative, false-negative-tolerant e-mail *shape* check — enough
/// to reject obvious garbage, not a full RFC 5322 validator. Prefer
/// server-side verification (e.g. a confirmation link) over relying on
/// this for anything security-sensitive.
final RegExp _looseEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Parses a syntactically-plausible e-mail address. See
/// [_looseEmailPattern] for the (intentionally loose) shape it checks.
final ParserFn<String?> emailOrNull = matchingOrNull(_looseEmailPattern);

/// A shape check for IPv4 addresses: four dot-separated `0`–`255` octets.
final RegExp _ipv4Pattern = RegExp(
  r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
  r'(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$',
);

/// Parses a syntactically-valid IPv4 address string.
final ParserFn<String?> ipv4OrNull = matchingOrNull(_ipv4Pattern);

/// Parses a hexadecimal-only [String] (e.g. a hash, a hex color with the
/// leading `#` already stripped), optionally requiring an exact
/// [length].
ParserFn<String?> hexStringOrNull({int? length}) {
  final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
  return (Object? v) {
    final s = stringOrNull(v, trim: true);
    if (s == null) return null;
    if (length != null && s.length != length) return null;
    return hexPattern.hasMatch(s) ? s : null;
  };
}

/// Parses a slug: lowercase letters, digits, and single hyphens between
/// them (`my-article-title`, not `-leading`, `trailing-`, or `a--b`).
final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Parses a URL/filename-safe slug string. See [_slugPattern].
final ParserFn<String?> slugOrNull = matchingOrNull(_slugPattern, trim: true);
