import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/peer.dart';

/// A peer's media flags decide what the camera tile shows. Turning a camera
/// off pauses the producer rather than closing it, so no track goes away and
/// nothing on screen changes by itself — these flags are the only thing that
/// separates "camera off" from a frozen picture.
void main() {
  Peer peerFrom(Map<String, dynamic> extra) => Peer.fromMap({
        'id': 'p1',
        'name': 'Teacher',
        'role': 'teacher',
        ...extra,
      });

  group('reading a peer', () {
    test('a teacher arrives with their camera on', () {
      // The server sets videoOff false for a teacher who is producing video.
      expect(peerFrom({'videoOff': false}).videoOff, isFalse);
    });

    test('anyone else is assumed to have no camera', () {
      // Students never publish video, so a missing flag must not read as "on"
      // and leave the tile waiting for frames that never come.
      expect(peerFrom({}).videoOff, isTrue);
    });

    test('staff is teacher or coordinator, not student', () {
      expect(peerFrom({'role': 'teacher'}).isStaff, isTrue);
      expect(peerFrom({'role': 'coordinator'}).isStaff, isTrue);
      expect(peerFrom({'role': 'student'}).isStaff, isFalse);
    });
  });

  group('applying a media-state broadcast', () {
    test('switching a camera off does not disturb the microphone', () {
      final before = peerFrom({'videoOff': false, 'audioMuted': false});
      final after = before.copyWith(videoOff: true);
      expect(after.videoOff, isTrue);
      expect(after.audioMuted, isFalse);
    });

    test('switching a camera back on clears the flag', () {
      final off = peerFrom({'videoOff': true});
      expect(off.copyWith(videoOff: false).videoOff, isFalse);
    });

    test('muting does not disturb the camera', () {
      final before = peerFrom({'videoOff': false, 'audioMuted': false});
      final after = before.copyWith(audioMuted: true);
      expect(after.audioMuted, isTrue);
      expect(after.videoOff, isFalse);
    });

    test('an unrelated change leaves both alone', () {
      final before = peerFrom({'videoOff': false, 'audioMuted': true});
      final after = before.copyWith(handRaised: true);
      expect(after.videoOff, isFalse);
      expect(after.audioMuted, isTrue);
      expect(after.handRaised, isTrue);
    });

    test('lowering a hand clears when it went up', () {
      final up = peerFrom({'handRaised': true, 'handRaisedAt': 1000});
      final down = up.copyWith(handRaised: false);
      expect(down.handRaised, isFalse);
      expect(down.handRaisedAt, isNull);
    });
  });
}
