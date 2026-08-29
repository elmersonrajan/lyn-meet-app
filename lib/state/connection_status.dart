import 'package:flutter/foundation.dart';

/// How well the class is actually reaching this student.
///
/// Ordered worst to best so states can be compared.
enum ConnectionQuality {
  /// Signalling is down. Chat, hands and the board have stopped arriving too.
  offline,

  /// The media path gave up. On a phone this is almost always TURN being
  /// unreachable rather than anything the student can fix by waiting.
  failed,

  /// ICE has dropped but has not given up. Usually a moment of bad signal.
  weak,

  /// Still being set up, or coming back.
  connecting,

  /// Everything is through.
  good,
}

extension ConnectionQualityInfo on ConnectionQuality {
  /// Short label for the banner. Deliberately plain: a student reading this
  /// mid-lesson needs to know whether to wait, move, or give up.
  String get message => switch (this) {
        ConnectionQuality.offline => 'Reconnecting to the class…',
        ConnectionQuality.failed =>
          'Cannot reach the class media — check your internet',
        ConnectionQuality.weak => 'Weak connection',
        ConnectionQuality.connecting => 'Connecting…',
        ConnectionQuality.good => '',
      };

  /// How many bars out of three to fill.
  int get bars => switch (this) {
        ConnectionQuality.offline => 0,
        ConnectionQuality.failed => 0,
        ConnectionQuality.weak => 1,
        ConnectionQuality.connecting => 2,
        ConnectionQuality.good => 3,
      };

  bool get isTrouble => this != ConnectionQuality.good;
}

/// Watches the two things that carry a lesson and reports the worse of them.
///
/// Both are already known to the app and were only being logged. Surfacing
/// them matters because the failure modes are silent: signalling can drop
/// while video keeps painting its last frame, and the media path can fail
/// while chat and the whiteboard carry on arriving perfectly. In both cases
/// the app looks fine and the class has stopped, and a student sitting there
/// waiting has no way to tell whether the problem is them.
class ConnectionStatus extends ChangeNotifier {
  /// Whether the signalling socket is up.
  bool _socketUp = false;

  /// ICE state of the transport carrying the lesson to this student.
  String _recvState = 'new';

  /// ICE state of the transport carrying their microphone out. Tracked but
  /// weighed less: a student who cannot be heard still has the lesson.
  String _sendState = 'new';

  bool get socketUp => _socketUp;
  String get recvState => _recvState;
  String get sendState => _sendState;

  /// True once the class has been fully connected at least once, so the
  /// opening moments are not reported as a fault.
  bool _everConnected = false;

  ConnectionQuality get quality {
    if (!_socketUp) return ConnectionQuality.offline;

    return switch (_recvState) {
      'failed' || 'closed' => ConnectionQuality.failed,
      'disconnected' => ConnectionQuality.weak,
      'connected' when _sendState == 'failed' => ConnectionQuality.weak,
      'connected' => ConnectionQuality.good,
      _ => _everConnected
          ? ConnectionQuality.weak
          : ConnectionQuality.connecting,
    };
  }

  /// Whether the microphone path specifically has failed, which is worth
  /// saying separately: the student can hear the class but cannot answer.
  bool get micPathFailed => _sendState == 'failed' && _recvState == 'connected';

  void setSocketUp(bool up) {
    if (_socketUp == up) return;
    _socketUp = up;
    notifyListeners();
  }

  void setTransportState(String direction, String state) {
    final next = state.trim();
    if (next.isEmpty) return;
    if (direction == 'recv') {
      if (_recvState == next) return;
      _recvState = next;
      if (next == 'connected') _everConnected = true;
    } else {
      if (_sendState == next) return;
      _sendState = next;
    }
    notifyListeners();
  }

  void reset() {
    _socketUp = false;
    _recvState = 'new';
    _sendState = 'new';
    _everConnected = false;
    notifyListeners();
  }
}
