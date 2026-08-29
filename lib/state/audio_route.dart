import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Where the lesson comes out of.
enum AudioRoute {
  /// The loudspeaker. The default, because a class is listened to with the
  /// phone on a desk, not held to the ear.
  speaker,

  /// The earpiece, or a wired headset when one is plugged in — the phone
  /// routes to the headset automatically once the speakerphone is off.
  earpiece,

  /// A paired bluetooth headset, when one is connected.
  bluetooth,
}

extension AudioRouteLabel on AudioRoute {
  String get label => switch (this) {
        AudioRoute.speaker => 'Speaker',
        AudioRoute.earpiece => 'Earpiece',
        AudioRoute.bluetooth => 'Bluetooth',
      };

  String get detail => switch (this) {
        AudioRoute.speaker => 'Out loud, phone on the desk',
        AudioRoute.earpiece => 'Quiet, or through wired headphones',
        AudioRoute.bluetooth => 'A paired wireless headset',
      };
}

/// Chooses the speaker the class plays through.
///
/// The platform owns the actual routing and can override any of this — a
/// headset being unplugged moves the audio on its own, and nothing here is
/// told. So this holds an *intent* rather than a reading of the hardware: what
/// the student last asked for, reapplied when they ask again.
class AudioRouteController extends ChangeNotifier {
  AudioRoute _route = AudioRoute.speaker;
  bool _busy = false;

  AudioRoute get route => _route;
  bool get busy => _busy;

  /// Puts the class on the loudspeaker.
  ///
  /// Called once the first remote audio arrives. WebRTC defaults a voice call
  /// to the earpiece, which for a lesson means a student holding the phone to
  /// their head for an hour or, more likely, assuming the app is broken
  /// because nothing seems to be playing.
  Future<void> applyDefault() => select(AudioRoute.speaker);

  Future<void> select(AudioRoute route) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      switch (route) {
        case AudioRoute.speaker:
          await Helper.setSpeakerphoneOn(true);
        case AudioRoute.earpiece:
          await Helper.setSpeakerphoneOn(false);
        case AudioRoute.bluetooth:
          // Falls back to the loudspeaker by itself when nothing is paired,
          // which is the right failure: audible beats silent.
          await Helper.setSpeakerphoneOnButPreferBluetooth();
      }
      _route = route;
    } catch (err) {
      debugPrint('[Audio] could not switch to ${route.label}: $err');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
