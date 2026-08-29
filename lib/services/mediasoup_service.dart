import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
// RTCIceServer and its credential enum live in the package's handler layer,
// which the public library does not re-export — an oversight upstream rather
// than a boundary. Reaching in is the only way to hand a transport the TURN
// credentials the server issues, and without those a student on mobile data
// never gets a media path at all.
// ignore: implementation_imports
import 'package:mediasfu_mediasoup_client/src/handlers/handler_interface.dart'
    show RTCIceServer, RTCIceCredentialType;

import '../models/producer_info.dart';
import 'socket_service.dart';

/// What a track is for, once it has arrived.
enum TrackSlot {
  /// The staff camera, shown as the inset tile.
  camera,

  /// A shared screen, shown on the main stage.
  screen,

  /// Someone talking. Not rendered; the platform plays it.
  audio,
}

/// A track that has arrived, tagged with where it belongs.
class RemoteTrack {
  final String producerId;
  final String peerId;
  final TrackSlot slot;
  final MediaStream stream;
  final MediaStreamTrack track;

  /// Whether the renderer must be told which track to draw, rather than being
  /// handed the stream and left to take the first video track in it.
  ///
  /// Only true when this peer has more than one video track attached — a
  /// teacher sharing a screen while their camera is on. See the comment in
  /// MediaController.attach for why the plainer path is preferred otherwise.
  final bool selectByTrackId;

  const RemoteTrack({
    required this.producerId,
    required this.peerId,
    required this.slot,
    required this.stream,
    required this.track,
    this.selectByTrackId = false,
  });

  RemoteTrack withSelection(bool select) => RemoteTrack(
        producerId: producerId,
        peerId: peerId,
        slot: slot,
        stream: stream,
        track: track,
        selectByTrackId: select,
      );
}

/// The WebRTC half of the classroom.
///
/// Owns the mediasoup Device, the two transports, the single microphone
/// producer and every consumer. Deliberately knows nothing about widgets: it
/// reports what arrived through [onTrack] / [onTrackGone] and lets the state
/// layer decide what to draw.
///
/// The Dart port differs from mediasoup-client in JavaScript in one way that
/// shapes this whole file: `transport.produce()` and `transport.consume()`
/// return void and hand their results to callbacks registered when the
/// transport was created. So the flow here is callback-driven, and the
/// Completers below turn it back into something a caller can await.
class MediasoupService {
  MediasoupService(this._socket);

  final SocketService _socket;

  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;

  Producer? _micProducer;
  final Map<String, Consumer> _consumers = {};

  /// producerId -> what we did with it, so a producer-closed broadcast can
  /// take the right thing off the screen.
  final Map<String, RemoteTrack> _tracks = {};

  /// Producers already being consumed or in flight. get-producers and the
  /// new-producer broadcast overlap on join, and consuming the same producer
  /// twice wedges the transport.
  final Set<String> _claimed = {};

  /// Our own peer id, so we never consume what we are sending.
  String _selfPeerId = '';

  /// Fires when a remote track is ready to be shown or heard.
  void Function(RemoteTrack track)? onTrack;

  /// Fires when a producer went away and its track should be dropped.
  void Function(RemoteTrack track)? onTrackGone;

  /// Fires on every ICE state change, with "send" or "recv" and the new state.
  void Function(String direction, String state)? onTransportState;

  /// Completes once the microphone producer exists on the server.
  final Completer<void> _micReady = Completer<void>();

  bool get hasMic => _micProducer != null;
  bool get ready => _device?.loaded == true && _recvTransport != null;

  /// Brings up the device and both transports.
  ///
  /// Order matters. The receive transport is built before the send transport
  /// so that a student whose microphone permission is refused still hears the
  /// class: a failure to publish must never cost them the lesson.
  Future<void> start({
    required Map<String, dynamic> routerRtpCapabilities,
    required List<dynamic> iceServers,
    required String selfPeerId,
  }) async {
    _selfPeerId = selfPeerId;

    final device = Device();
    await device.load(
      routerRtpCapabilities: RtpCapabilities.fromMap(routerRtpCapabilities),
    );
    _device = device;

    final servers = _parseIceServers(iceServers);
    _recvTransport = await _createTransport(direction: 'recv', iceServers: servers);
    _sendTransport = await _createTransport(direction: 'send', iceServers: servers);
  }

  /// Turns the server's iceServers array into the package's own type.
  ///
  /// TURN is not optional on a phone. A student on mobile data is behind a
  /// carrier NAT that STUN cannot punch, so without these credentials the
  /// media path simply never opens — while signalling, chat and the whiteboard
  /// all keep working, which makes it look like a video bug rather than a
  /// network one.
  List<RTCIceServer> _parseIceServers(List<dynamic> raw) {
    final servers = <RTCIceServer>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final urlsRaw = entry['urls'];
      final urls = urlsRaw is List
          ? urlsRaw.map((u) => u.toString()).toList()
          : [urlsRaw.toString()];
      servers.add(RTCIceServer(
        urls: urls,
        username: (entry['username'] ?? '').toString(),
        credential: entry['credential']?.toString(),
        credentialType: RTCIceCredentialType.password,
      ));
    }
    return servers;
  }

  Future<Transport> _createTransport({
    required String direction,
    required List<RTCIceServer> iceServers,
  }) async {
    final res = await _socket.emitAck('create-transport', {'direction': direction});
    final params = Map<String, dynamic>.from(res['params'] as Map);

    final id = params['id'].toString();
    final iceParameters = IceParameters.fromMap(params['iceParameters']);
    final iceCandidates = (params['iceCandidates'] as List)
        .map((c) => IceCandidate.fromMap(c))
        .toList();
    final dtlsParameters = DtlsParameters.fromMap(params['dtlsParameters']);

    final device = _device!;
    final transport = direction == 'send'
        ? device.createSendTransport(
            id: id,
            iceParameters: iceParameters,
            iceCandidates: iceCandidates,
            dtlsParameters: dtlsParameters,
            iceServers: iceServers,
            producerCallback: _onProducer,
          )
        : device.createRecvTransport(
            id: id,
            iceParameters: iceParameters,
            iceCandidates: iceCandidates,
            dtlsParameters: dtlsParameters,
            iceServers: iceServers,
            consumerCallback: _onConsumer,
          );

    // DTLS handshake. The transport hands us its parameters and two callbacks;
    // the server must be told before media can flow, and it must be told only
    // once, which the package guarantees by firing this a single time.
    transport.on('connect', (Map data) async {
      try {
        await _socket.emitAck('connect-transport', {
          'transportId': id,
          'dtlsParameters': (data['dtlsParameters'] as DtlsParameters).toMap(),
        });
        data['callback']();
      } catch (err) {
        debugPrint('[Mediasoup] connect-transport failed: $err');
        data['errback'](err);
      }
    });

    if (direction == 'send') {
      // Fires once per produce(). The id the server allocates is what the
      // package uses to build its local Producer, so the callback must be
      // handed the raw id and nothing else.
      transport.on('produce', (Map data) async {
        try {
          final res = await _socket.emitAck('produce', {
            'transportId': id,
            'kind': data['kind'],
            'rtpParameters': (data['rtpParameters'] as RtpParameters).toMap(),
            // The server routes on this, not on kind: it is what separates a
            // camera from a screen share, and what the recorder keys on.
            'source': (data['appData'] as Map?)?['source'] ?? data['kind'],
          });
          data['callback'](res['id']);
        } catch (err) {
          debugPrint('[Mediasoup] produce failed: $err');
          data['errback'](err);
        }
      });
    }

    transport.on('connectionstatechange', (Map data) {
      final state = (data['connectionState'] ?? data['state'] ?? '').toString();
      debugPrint('[Mediasoup] $direction transport $state');
      _socket.log('transport $direction $state');
      // The only honest measure of whether the lesson is arriving. Reported
      // rather than merely logged: ICE can fail while chat and the whiteboard
      // keep working perfectly, so nothing else on screen changes and the
      // student is left watching a still picture with no idea why.
      onTransportState?.call(direction, state);
      if (state == 'failed') {
        // On a phone this is almost always TURN being unreachable.
        _socket.log('ICE FAILED on $direction — check TURN reachability');
      }
    });

    return transport;
  }

  void _onProducer(Producer producer) {
    _micProducer = producer;
    if (!_micReady.isCompleted) _micReady.complete();
  }

  /// Publishes the microphone.
  ///
  /// The track arrives live, and the server immediately pauses it: a student
  /// always joins muted, and unmuting is a deliberate act. That pause is the
  /// server's job, not this one's — see the produce handler in
  /// backend/src/socket/index.js — so nothing here tries to pre-mute the
  /// track and risk fighting it.
  Future<void> publishMicrophone(MediaStream stream) async {
    final transport = _sendTransport;
    if (transport == null) throw StateError('Send transport is not ready');

    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) throw StateError('No microphone track to publish');

    transport.produce(
      track: tracks.first,
      stream: stream,
      source: 'audio',
      appData: {'source': 'audio'},
      // Keep the track alive across pauses. The default stops it outright,
      // which on Android drops the microphone route and makes the next unmute
      // come back silent.
      stopTracks: false,
      disableTrackOnPause: true,
      zeroRtpOnPause: true,
    );

    await _micReady.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw StateError('The microphone did not start'),
    );
  }

  /// Mutes or unmutes, on the server as well as locally.
  ///
  /// Both halves are needed and neither is sufficient. The local pause stops
  /// the packets; the server call is what updates the participant list for
  /// everyone else, and what the teacher's Mute All acts on. Pausing rather
  /// than closing keeps the producer id stable, so the teacher's view of this
  /// student does not flicker in and out on every unmute.
  Future<void> setMicEnabled(bool enabled) async {
    final producer = _micProducer;
    if (producer == null) throw StateError('The microphone is not published');

    if (enabled) {
      producer.resume();
      await _socket.emitAck('resume-producer', {'source': 'audio'});
    } else {
      producer.pause();
      await _socket.emitAck('pause-producer', {'source': 'audio'});
    }
  }

  /// Pauses the local producer without telling the server.
  ///
  /// Used when the server has already muted us — force-mute or mic-locked —
  /// where echoing a pause-producer back would be a pointless round trip.
  void pauseMicLocally() {
    _micProducer?.pause();
  }

  /// Subscribes to a remote producer, unless it is one we should ignore.
  ///
  /// Two are skipped, matching the web client exactly:
  ///
  ///   * our own, which the server includes in the list;
  ///   * any student camera or screen, which the classroom does not show —
  ///     thirty phone cameras would bury the lesson and the bandwidth.
  Future<void> consume(ProducerInfo producer) async {
    final transport = _recvTransport;
    final device = _device;
    if (transport == null || device == null) return;

    if (producer.peerId == _selfPeerId) return;
    if (!producer.isAudio && !producer.isStaff) return;
    if (_claimed.contains(producer.producerId)) return;
    _claimed.add(producer.producerId);

    try {
      final res = await _socket.emitAck('consume', {
        'producerId': producer.producerId,
        'transportId': transport.id,
        'rtpCapabilities': device.rtpCapabilities.toMap(),
      });
      final params = Map<String, dynamic>.from(res['params'] as Map);

      transport.consume(
        id: params['id'].toString(),
        producerId: params['producerId'].toString(),
        peerId: producer.peerId,
        kind: RTCRtpMediaTypeExtension.fromString(params['kind'].toString()),
        rtpParameters: RtpParameters.fromMap(params['rtpParameters']),
        appData: {
          'source': producer.source,
          'role': producer.role,
          'peerId': producer.peerId,
        },
        accept: () {},
      );
    } catch (err) {
      // Let it be retried if the producer is announced again.
      _claimed.remove(producer.producerId);
      debugPrint('[Mediasoup] consume failed for ${producer.producerId}: $err');
    }
  }

  Future<void> _onConsumer(Consumer consumer, dynamic accept) async {
    try {
      final appData = consumer.appData;
      final source = (appData['source'] ?? '').toString();
      final peerId = (appData['peerId'] ?? '').toString();

      final slot = source == 'screen'
          ? TrackSlot.screen
          : consumer.track.kind == 'audio'
              ? TrackSlot.audio
              : TrackSlot.camera;

      // The stream is passed through as the package built it, and the track is
      // carried alongside so the renderer can be told which one to draw.
      //
      // Both are needed. The package resolves a consumer's stream by RTCP
      // cname, and mediasoup gives every producer from one peer the same
      // cname, so a teacher's camera and screen share arrive in one
      // MediaStream holding two video tracks. Handing that stream to a
      // renderer draws whichever track comes first — the camera — which is
      // why a teacher's screen share was invisible while a coordinator's, who
      // has no camera to collide with, worked.
      //
      // Rebuilding a stream per consumer looks like the fix and is not: the
      // native renderer looks a stream up by id and owner, and one made with
      // createLocalMediaStream is owned locally, so it finds nothing and draws
      // black. Selecting by track id is the supported way through.
      final remote = RemoteTrack(
        producerId: consumer.producerId,
        peerId: peerId,
        slot: slot,
        stream: consumer.stream,
        track: consumer.track,
      );

      // Drop whatever this peer had in the same slot before.
      //
      // A teacher who reconnects publishes a fresh camera, and the server does
      // not always announce the dead one as closed — a producer lost to a
      // disconnect has no replacement to point at. Without this the old track
      // stays attached and the teacher comes back to the meeting while their
      // tile stays frozen on a track that will never carry another frame. The
      // web client carries the same guard for the same reason.
      for (final stale in _tracks.entries
          .where((e) =>
              e.value.peerId == peerId &&
              e.value.slot == slot &&
              e.key != consumer.producerId)
          .map((e) => e.key)
          .toList()) {
        removeProducer(stale);
      }

      _consumers[consumer.id] = consumer;
      _tracks[consumer.producerId] = remote;
      _publishVideoFor(peerId, only: remote);

      // The server creates every consumer paused so that no media is in
      // flight before the client is ready for it. Nothing arrives until this.
      _socket
          .emitAck('resume-consumer', {'consumerId': consumer.id})
          .then((_) => consumer.resume())
          .catchError((Object err) {
        debugPrint('[Mediasoup] resume-consumer failed: $err');
      });
    } catch (err) {
      debugPrint('[Mediasoup] consumer setup failed: $err');
    }
  }

  /// Hands this peer's video to the renderers, deciding how to address it.
  ///
  /// Two ways to point a renderer at a track, and they are not equally safe.
  ///
  /// Handing over the whole stream makes the native side render the first
  /// video track in it, which is right whenever there is only one — and that
  /// is the ordinary case, a teacher with a camera and nothing else.
  ///
  /// Naming the track is only needed when a peer has two, because mediasoup
  /// gives all of one peer's producers the same RTCP cname and they therefore
  /// share a stream. But naming it makes the native side look the track up in
  /// the peer connection identified by the stream's owner tag, and if that
  /// lookup comes back empty the renderer is left with nothing and draws
  /// black — where handing over the stream would simply have fallen through to
  /// the first track. That is what turned the teacher's camera black.
  ///
  /// So the plain path is used until there is genuinely something to
  /// disambiguate, and both of the peer's tracks are re-pointed at the moment
  /// a second one shows up.
  void _publishVideoFor(String peerId, {RemoteTrack? only}) {
    final video = _tracks.values
        .where((t) => t.peerId == peerId && t.slot != TrackSlot.audio)
        .toList();

    if (only != null && only.slot == TrackSlot.audio) {
      onTrack?.call(only);
      return;
    }

    final select = video.length > 1;
    for (final track in video) {
      // On a first arrival only the new track needs attaching; once a second
      // shows up the other has to be re-pointed as well, since it was attached
      // by stream and would now draw whichever track came first.
      if (only != null && !select && track.producerId != only.producerId) {
        continue;
      }
      onTrack?.call(track.withSelection(select));
    }
  }

  /// Drops a producer that has gone away.
  void removeProducer(String producerId) {
    _claimed.remove(producerId);
    final track = _tracks.remove(producerId);

    String? consumerId;
    for (final entry in _consumers.entries) {
      if (entry.value.producerId == producerId) {
        consumerId = entry.key;
        break;
      }
    }
    if (consumerId != null) {
      try {
        _consumers.remove(consumerId)?.close();
      } catch (_) {}
    }

    // The stream belongs to the package's peer connection, not to us, and
    // other consumers from the same peer may still be using it — so it is
    // detached, never disposed.
    if (track == null) return;
    onTrackGone?.call(track);

    // With one of the peer's two video tracks gone there is nothing left to
    // disambiguate, so whatever remains goes back to the plain path rather
    // than staying on the fragile one for the rest of the lesson.
    if (track.slot != TrackSlot.audio) _publishVideoFor(track.peerId);
  }

  /// Everything this peer had, gone. Called when someone leaves the room.
  void removePeer(String peerId) {
    for (final producerId in _tracks.entries
        .where((e) => e.value.peerId == peerId)
        .map((e) => e.key)
        .toList()) {
      removeProducer(producerId);
    }
  }

  Future<void> dispose() async {
    for (final consumer in _consumers.values) {
      try {
        consumer.close();
      } catch (_) {}
    }
    _consumers.clear();
    _tracks.clear();
    _claimed.clear();

    try {
      _micProducer?.close();
    } catch (_) {}
    _micProducer = null;

    await _sendTransport?.close();
    await _recvTransport?.close();
    _sendTransport = null;
    _recvTransport = null;
    _device = null;
  }
}
