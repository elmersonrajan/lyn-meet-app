import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/state/connection_status.dart';

/// The point of this meter is that it is honest. Reporting "good" while the
/// media path is down is worse than showing nothing, because the student then
/// blames the lesson rather than their network.
void main() {
  ConnectionStatus connected() => ConnectionStatus()
    ..setSocketUp(true)
    ..setTransportState('recv', 'connected')
    ..setTransportState('send', 'connected');

  group('a healthy class', () {
    test('is good on all three bars', () {
      final status = connected();
      expect(status.quality, ConnectionQuality.good);
      expect(status.quality.bars, 3);
      expect(status.quality.isTrouble, isFalse);
    });
  });

  group('signalling', () {
    test('a socket that has not come up yet is offline, not good', () {
      expect(ConnectionStatus().quality, ConnectionQuality.offline);
    });

    test('losing the socket outranks a healthy media path', () {
      // Chat, hands and the board have all stopped even though video may keep
      // painting its last frame, so this is the more important fact.
      final status = connected()..setSocketUp(false);
      expect(status.quality, ConnectionQuality.offline);
      expect(status.quality.bars, 0);
    });
  });

  group('the media path', () {
    test('a failed receive transport is failure, not weakness', () {
      final status = connected()..setTransportState('recv', 'failed');
      expect(status.quality, ConnectionQuality.failed);
    });

    test('a dropped receive transport is weak, since it may recover', () {
      final status = connected()..setTransportState('recv', 'disconnected');
      expect(status.quality, ConnectionQuality.weak);
      expect(status.quality.bars, 1);
    });

    test('a failed microphone alone is weak, not failure', () {
      // The student can still hear the lesson, which is most of it.
      final status = connected()..setTransportState('send', 'failed');
      expect(status.quality, ConnectionQuality.weak);
      expect(status.micPathFailed, isTrue);
    });

    test('recovers when the transport comes back', () {
      final status = connected()..setTransportState('recv', 'disconnected');
      expect(status.quality, ConnectionQuality.weak);
      status.setTransportState('recv', 'connected');
      expect(status.quality, ConnectionQuality.good);
    });
  });

  group('opening moments', () {
    test('setting up reads as connecting, not as a fault', () {
      final status = ConnectionStatus()..setSocketUp(true);
      expect(status.quality, ConnectionQuality.connecting);
    });

    test('but the same state after a good connection reads as weak', () {
      // Having been connected once, falling back to "connecting" means
      // something was lost rather than never established.
      final status = connected()..setTransportState('recv', 'connecting');
      expect(status.quality, ConnectionQuality.weak);
    });
  });

  test('every trouble state has something to say, and good says nothing', () {
    for (final quality in ConnectionQuality.values) {
      if (quality == ConnectionQuality.good) {
        expect(quality.message, isEmpty);
      } else {
        expect(quality.message, isNotEmpty, reason: '$quality needs wording');
      }
    }
  });
}
