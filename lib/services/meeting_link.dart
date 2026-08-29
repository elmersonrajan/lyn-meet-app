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
