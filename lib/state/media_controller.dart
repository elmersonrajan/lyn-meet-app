import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/mediasoup_service.dart';

/// What the student can see and hear, and whether their microphone is live.
///
/// Holds the two video renderers for the lesson — the staff camera and the
/// shared screen — plus the local microphone stream. Remote audio needs no
/// renderer on a phone: once a track is received the platform plays it, so
/// those tracks are only held here to keep them from being collected.
class MediaController extends ChangeNotifier {
  final RTCVideoRenderer cameraRenderer = RTCVideoRenderer();
  final RTCVideoRenderer screenRenderer = RTCVideoRenderer();

  MediaStream? _micStream;

  /// producerId -> track, for audio we are playing but not drawing.
  final Map<String, RemoteTrack> _audioTracks = {};

  bool _renderersReady = false;
  bool _hasCamera = false;
  bool _hasScreen = false;

  /// Whether the microphone is currently sending.
  bool _micOn = false;

  /// What to tell the student about the state of their microphone — the
  /// server sends the wording, so the app and the browser say the same thing.
  String? _micNotice;

  /// Set when the microphone could not be published at all: permission
  /// refused, or no input device. The student still hears the class.
  String? _micError;

  bool get renderersReady => _renderersReady;
  bool get hasCamera => _hasCamera;
  bool get hasScreen => _hasScreen;
  bool get micOn => _micOn;
  bool get micAvailable => _micStream != null && _micError == null;
  String? get micNotice => _micNotice;
  String? get micError => _micError;
  MediaStream? get micStream => _micStream;

  Future<void> initRenderers() async {
    if (_renderersReady) return;
    await cameraRenderer.initialize();
    await screenRenderer.initialize();
    _renderersReady = true;
    notifyListeners();
  }

  /// Opens the microphone.
  ///
  /// Echo cancellation and noise suppression are on because a classroom is a
  /// room full of phones: without them, one student unmuting near a speaker
  /// feeds the lesson back to everyone.
  Future<MediaStream?> openMicrophone() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      _micStream = stream;
      _micError = null;

      // A lesson is listened to, not held to the ear.
      await Helper.setSpeakerphoneOn(true);

      notifyListeners();
      return stream;
    } catch (err) {
      // getUserMedia is also where the permission prompt happens, so a refusal
      // and a broken input device arrive here as the same failure. The wording
      // covers both rather than guessing which one it was.
      _micError = 'Microphone unavailable — you can still hear the class';
      debugPrint('[Media] getUserMedia failed: $err');
      notifyListeners();
      return null;
    }
  }

  /// Routes an arriving track to wherever it belongs.
  void attach(RemoteTrack track) {
    switch (track.slot) {
      case TrackSlot.camera:
        cameraRenderer.srcObject = track.stream;
        _hasCamera = true;
      case TrackSlot.screen:
        screenRenderer.srcObject = track.stream;
        _hasScreen = true;
      case TrackSlot.audio:
        _audioTracks[track.producerId] = track;
    }
    notifyListeners();
  }

  /// Drops a track whose producer has gone.
  void detach(RemoteTrack track) {
    switch (track.slot) {
      case TrackSlot.camera:
        cameraRenderer.srcObject = null;
        _hasCamera = false;
      case TrackSlot.screen:
        screenRenderer.srcObject = null;
        _hasScreen = false;
      case TrackSlot.audio:
        _audioTracks.remove(track.producerId);
    }
    notifyListeners();
  }

  void setMicOn(bool value) {
    if (_micOn == value) return;
    _micOn = value;
    notifyListeners();
  }

  void setMicNotice(String? notice) {
    _micNotice = notice;
    notifyListeners();
  }

  @override
  void dispose() {
    cameraRenderer.srcObject = null;
    screenRenderer.srcObject = null;
    cameraRenderer.dispose();
    screenRenderer.dispose();
    _audioTracks.clear();
    for (final track in _micStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      try {
        track.stop();
      } catch (_) {}
    }
    _micStream?.dispose();
    _micStream = null;
    super.dispose();
  }
}
