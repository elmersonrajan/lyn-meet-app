import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/services/meeting_link.dart';

/// Link handling is where a class quietly goes wrong: a student who lands in
/// the wrong room sees an empty meeting and blames the app, not the link.
/// These cases mirror the ones the web client's meetingLink.js handles.
void main() {
  group('the link a teacher actually shares', () {
    // The exact form that goes out to a class. If this case ever breaks, every
    // student who taps the link lands on an empty join screen.
    const shared = 'https://meet.lynindia.in/?lynmeet=DEVTEST';

    test('opens the right meeting', () {
      expect(readMeetingIdFromUri(Uri.parse(shared)), 'DEVTEST');
    });

    test('works over http as well, since the manifest claims both', () {
      expect(
        readMeetingIdFromUri(Uri.parse('http://meet.lynindia.in/?lynmeet=DEVTEST')),
        'DEVTEST',
      );
    });

    test('the custom-scheme fallback reaches the same room', () {
      // What lynmeet:// links have to resolve to when App Link verification
      // fails on a device.
      expect(readMeetingIdFromUri(Uri.parse('lynmeet://join/DEVTEST')), 'DEVTEST');
      expect(
        readMeetingIdFromUri(Uri.parse('lynmeet://open/?lynmeet=DEVTEST')),
        'DEVTEST',
      );
    });

    test('a trailing slash or fragment does not change the room', () {
      expect(
        readMeetingIdFromUri(Uri.parse('$shared#top')),
        'DEVTEST',
      );
    });

    test('the app and the server agree on the room key', () {
      // The server upper-cases the meeting ID and keys the room on it, so a
      // lower-case link must still land in the same room rather than opening a
      // second, empty one.
      expect(
        normalizeMeetingId(
          readMeetingIdFromUri(Uri.parse('https://meet.lynindia.in/?lynmeet=devtest')),
        ),
        'DEVTEST',
      );
    });
  });

  group('readMeetingIdFromUri', () {
    test('reads the parameter Copy Link writes', () {
      expect(
        readMeetingIdFromUri(Uri.parse('https://lyn.example/?lynmeet=NEET26')),
        'NEET26',
      );
    });

    test('accepts the older parameter names so no shared link dies', () {
      for (final key in ['meeting', 'meetingId', 'id']) {
        expect(
          readMeetingIdFromUri(Uri.parse('https://lyn.example/?$key=10MATHS')),
          '10MATHS',
          reason: '$key should still be honoured',
        );
      }
    });

    test('reads the path forms', () {
      expect(readMeetingIdFromUri(Uri.parse('https://x/join/NEET26')), 'NEET26');
      expect(readMeetingIdFromUri(Uri.parse('https://x/m/NEET26')), 'NEET26');
      expect(readMeetingIdFromUri(Uri.parse('https://x/lynmeet=NEET26')), 'NEET26');
    });

    test('treats a bare path as a meeting only when it is a generated code', () {
      expect(readMeetingIdFromUri(Uri.parse('https://x/kfd-8mza-qtp')), 'kfd-8mza-qtp');
      // Not a code: a future route or an asset must not be read as a room.
      expect(readMeetingIdFromUri(Uri.parse('https://x/assets/app.js')), '');
      expect(readMeetingIdFromUri(Uri.parse('https://x/')), '');
    });

    test('prefers the query string over the path', () {
      expect(
        readMeetingIdFromUri(Uri.parse('https://x/join/OLD?lynmeet=NEW')),
        'NEW',
      );
    });

    test('survives a mangled paste', () {
      expect(readMeetingIdFromUri(Uri.parse('https://x/?lynmeet=NEET26%20')), 'NEET26');
      expect(readMeetingIdFromUri(null), '');
    });

    test('caps the length so a hostile link cannot carry a payload', () {
      final long = 'A' * 400;
      final id = readMeetingIdFromUri(Uri.parse('https://x/?lynmeet=$long'));
      expect(id.length, 64);
    });
  });

  group('normalizeMeetingId', () {
    // The bug this prevents is in the server's own comment: the room is keyed
    // by this string, so "neet26" and "NEET26" were two different rooms and
    // anyone who typed it in lower case sat alone in an empty meeting.
    test('upper-cases, because the server keys the room on this string', () {
      expect(normalizeMeetingId('neet26'), 'NEET26');
      expect(normalizeMeetingId('  10maths  '), '10MATHS');
    });

    test('is stable when applied twice', () {
      expect(normalizeMeetingId(normalizeMeetingId('neet26')), 'NEET26');
    });

    test('handles nothing at all', () {
      expect(normalizeMeetingId(null), '');
      expect(normalizeMeetingId('   '), '');
    });
  });
}
