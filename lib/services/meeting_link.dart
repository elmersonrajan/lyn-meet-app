/// Reading a meeting out of a link.
///
/// A port of frontend/src/services/meetingLink.js, kept deliberately in step
/// with it: a teacher copies a link out of the browser and sends it to a class
/// on WhatsApp, and those students open it on a phone. If the two clients
/// disagree about what a link means, the link is broken for half the room.
///
/// Only the reading half is ported. Students never generate a meeting code or
/// share a link, so generateMeetingCode() and buildMeetingLink() have no
/// caller here.
library;

/// The parameter the web client's Copy Link button writes.
const String linkParam = 'lynmeet';

/// Older and alternative names still accepted, so no link ever dies.
const List<String> _queryAliases = [linkParam, 'meeting', 'meetingId', 'id'];

/// Path forms accepted in addition to the query string.
final List<RegExp> _pathPatterns = [
  RegExp(r'^/?lynmeet=(.+)$', caseSensitive: false),
  RegExp(r'^/?meeting=(.+)$', caseSensitive: false),
  RegExp(r'^/?join/(.+)$', caseSensitive: false),
  RegExp(r'^/?m/(.+)$', caseSensitive: false),
];

/// A generated code: three groups, lowercase, no ambiguous characters.
/// Recognising this shape is what lets a bare path like /kfd-8mza-qtp be
/// treated as a meeting without mistaking some other route for one.
final RegExp codePattern =
    RegExp(r'^[a-hjkmnp-z2-9]{3}-[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{3}$');

/// The part of a link that carries the meeting, as a path.
///
/// On a custom scheme the first segment is parsed as the authority, not the
/// path: `lynmeet://join/DEVTEST` gives host `join` and path `/DEVTEST`, so
/// matching the `/join/ID` form against the path alone finds nothing and the
/// link opens an empty join screen. Folding the host back on for non-http
/// schemes puts those links back in the same shape as the web ones.
String _pathOf(Uri uri) {
  final isWeb = uri.scheme.isEmpty || uri.scheme == 'http' || uri.scheme == 'https';
  if (isWeb || uri.host.isEmpty) return uri.path;
  return '/${uri.host}${uri.path}';
}

String _clean(String? raw) {
  if (raw == null) return '';
  var value = raw.trim();
  try {
    value = Uri.decodeComponent(value);
  } catch (_) {
    // A malformed escape sequence should not throw away the whole value.
  }
  value = value.split('#').first.split('?').first.trim();
  // Capped so a hostile link cannot carry a huge payload into the join field.
  return value.length > 64 ? value.substring(0, 64) : value;
}

/// Pulls a meeting ID out of a deep link, or returns "" when it carries none.
///
/// Query string wins over path, matching the web client: that is the format
/// Copy Link produces, and it needs no rewrite rule on the server.
String readMeetingIdFromUri(Uri? uri) {
  if (uri == null) return '';
  try {
    for (final key in _queryAliases) {
      final found = uri.queryParameters[key];
      if (found != null && found.isNotEmpty) {
        final id = _clean(found);
        if (id.isNotEmpty) return id;
      }
    }

    final path = _pathOf(uri);
    for (final pattern in _pathPatterns) {
      final match = pattern.firstMatch(path);
      if (match != null) {
        final id = _clean(match.group(1));
        if (id.isNotEmpty) return id;
      }
    }

    // A bare path counts only when it looks like a generated code, so "/" and
    // any future route are left alone.
    final bare = _clean(path.replaceFirst(RegExp(r'^/'), ''));
    if (codePattern.hasMatch(bare)) return bare;

    return '';
  } catch (_) {
    return '';
  }
}

/// Pulls the one-time sign-in token out of a link, or "" when there is none.
///
/// The platform spells the parameter `TockenID`. That is a typo at their end
/// and it is load-bearing — matching the corrected spelling instead would
/// authenticate nobody. `TokenID` is accepted alongside it so a fix on their
/// side does not break sign-in on the day it ships.
///
/// The token grants nothing by itself: it is an opaque pointer into a table
/// only the two servers can read, and the role is looked up from the directory
/// afterwards. So there is nothing in it to forge.
///
/// It is *meant* to be single use — the server deletes the row as it redeems
/// it — but that delete is deliberately allowed to fail rather than turn a
/// missing DELETE grant into an outage. So a token may well still be in the
/// table and still work, and nothing here should assume otherwise.
String readHandoffToken(Uri? uri) {
  if (uri == null) return '';
  for (final key in const ['TockenID', 'TokenID', 'tockenid', 'tokenid']) {
    final found = _rawQueryValue(uri, key);
    if (found != null && found.trim().isNotEmpty) return found.trim();
  }
  return '';
}

/// One query value, percent-decoded but never plus-decoded.
///
/// `Uri.queryParameters` would be the obvious way to read this and it is the
/// wrong one. In a query string it treats `+` as a space, which is correct for
/// a submitted form and wrong for a token: the server accepts
/// `[A-Za-z0-9._~+/-]`, so these are base64 and a `+` in the middle is part of
/// the value.
///
/// Turning it into a space produced exactly the failure that looked like a
/// spent link — the server trims at the first character outside that set, the
/// shortened token matches no row, and the reply is "this sign-in link has
/// expired or was already used" about a token sitting in the table.
///
/// Reading the raw query and decoding only percent escapes is right either
/// way: a platform that sends a bare `+` keeps it, and one that sends `%2B`
/// still decodes to the same character.
String? _rawQueryValue(Uri uri, String key) {
  final query = uri.query;
  if (query.isEmpty) return null;

  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    if (pair.substring(0, eq) != key) continue;

    final raw = pair.substring(eq + 1);
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      // A malformed escape should not lose the whole token — the server trims
      // anything it does not recognise anyway.
      return raw;
    }
  }
  return null;
}

/// The room key the server will actually use.
///
/// Upper-casing is not cosmetic. The backend keys rooms by this exact string
/// and upper-cases it on join-room, so "neet26" and "NEET26" were once two
/// different rooms and anyone who typed it in lower case sat alone in an empty
/// meeting. Normalising here means the join button is disabled or enabled on
/// the same value the server will use.
String normalizeMeetingId(String? raw) {
  final cleaned = _clean(raw);
  return cleaned.toUpperCase();
}
