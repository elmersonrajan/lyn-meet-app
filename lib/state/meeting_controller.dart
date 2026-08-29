import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/env.dart';
import '../models/chat_message.dart';
import '../models/peer.dart';
import '../models/poll.dart';
import '../models/producer_info.dart';
import '../models/recording_state.dart';
import '../models/stroke.dart';
import '../services/mediasoup_service.dart';
import '../services/meeting_link.dart';
import '../services/socket_service.dart';
import 'media_controller.dart';
import 'whiteboard_controller.dart';

/// Where the student is in the lifecycle of a class.
enum MeetingPhase { idle, joining, live, ended }

/// Why the meeting ended, which decides what the closing screen says.
enum EndReason { left, kicked, sessionClosed, connectionLost, error }

/// The classroom, from a student's seat.
///
/// One object owns the whole session: the signalling socket, the media, the
/// board, and every list the room screen renders. It exists because the
/// server's twenty-odd broadcasts all describe the same room, and scattering
/// their handlers across widgets is how two parts of a screen end up
/// disagreeing about who is in the meeting.
///
/// The shape follows the server's own: join once, receive a complete snapshot,
/// then apply deltas. Nothing here polls, and nothing re-fetches — if a
/// broadcast is missed, the next one of its kind corrects it.
class MeetingController extends ChangeNotifier {
  MeetingController({
    SocketService? socket,
    MediaController? media,
    WhiteboardController? whiteboard,
  })  : _socket = socket ?? SocketService(),
        media = media ?? MediaController(),
        whiteboard = whiteboard ?? WhiteboardController() {
    _mediasoup = MediasoupService(_socket);
    _mediasoup.onTrack = this.media.attach;
    _mediasoup.onTrackGone = this.media.detach;
  }

  final SocketService _socket;
  final MediaController media;
  final WhiteboardController whiteboard;
  late final MediasoupService _mediasoup;

  /// Handler removers, called on the way out. Collected rather than re-derived
  /// so teardown cannot miss one and leave a dead controller listening.
  final List<VoidCallback> _subscriptions = [];

  MeetingPhase _phase = MeetingPhase.idle;
  EndReason _endReason = EndReason.left;
  String? _error;

  String _meetingId = '';
  String _displayName = '';
  Peer? _me;

  List<Peer> _participants = const [];
  final List<ChatMessage> _chat = [];
  final List<Poll> _polls = [];
  Set<String> _activeSpeakers = const {};

  /// "whiteboard" | "draw" | "screen" | "clip" — what the teacher has put on
  /// the main area. Defaults to the board, as the server does.
  String _stageMode = 'whiteboard';

  RecordingState _recording = RecordingState.idle;

  /// True while the teacher is inside their reconnect grace window. The class
  /// carries on; the banner explains why nobody is talking.
  bool _teacherAway = false;

  bool _handRaised = false;

  MeetingPhase get phase => _phase;
  EndReason get endReason => _endReason;
  String? get error => _error;
  String get meetingId => _meetingId;
  String get displayName => _displayName;
  Peer? get me => _me;
  List<Peer> get participants => _participants;
  List<ChatMessage> get chat => List.unmodifiable(_chat);
  List<Poll> get polls => List.unmodifiable(_polls);
  Set<String> get activeSpeakers => _activeSpeakers;
  String get stageMode => _stageMode;
  RecordingState get recording => _recording;
  bool get teacherAway => _teacherAway;
  bool get handRaised => _handRaised;
  bool get isLive => _phase == MeetingPhase.live;

  /// Whether a teacher or coordinator is in the room. The microphone depends
  /// on it, so the control bar needs to know.
  bool get hasStaff => _participants.any((p) => p.isStaff && !p.disconnected);

  /// The poll a student should be looking at: the newest one still open, or
  /// the newest one closed recently enough that the answer is still news.
  Poll? get currentPoll {
    if (_polls.isEmpty) return null;
    final open = _polls.where((p) => !p.closed).toList();
    if (open.isNotEmpty) return open.last;
    final last = _polls.last;
    final since = DateTime.now().millisecondsSinceEpoch - last.endsAt;
    return since < const Duration(minutes: 2).inMilliseconds ? last : null;
  }

  /// The number of unseen announcements, for the chat tab badge.
  int _lastReadChat = 0;
  int get unreadChat => (_chat.length - _lastReadChat).clamp(0, 999);
  void markChatRead() {
    _lastReadChat = _chat.length;
    notifyListeners();
  }

  /// Joins a class.
  ///
  /// The order is deliberate and each step depends on the last: signalling
  /// first, then the room snapshot, then the media the snapshot describes.
  /// The microphone comes last and is allowed to fail — a student who refuses
  /// the permission, or whose phone has no working input, should still get the
  /// lesson.
  Future<void> join({required String name, required String meetingId}) async {
    if (_phase == MeetingPhase.joining || _phase == MeetingPhase.live) return;

    _displayName = name.trim();
    _meetingId = normalizeMeetingId(meetingId);
    _error = null;
    _phase = MeetingPhase.joining;
    notifyListeners();

    try {
      if (_displayName.isEmpty || _meetingId.isEmpty) {
        throw StateError('Enter your name and the meeting ID');
      }

      await media.initRenderers();
      _socket.connect();

      final ack = await _socket.emitAck(
        'join-room',
        {
          'name': _displayName,
          'meetingId': _meetingId,
          'role': Env.role,
        },
        Env.joinTimeout,
      );

      _hydrate(ack);
      _listen();

      await _mediasoup.start(
        routerRtpCapabilities:
            Map<String, dynamic>.from(ack['routerRtpCapabilities'] as Map),
        iceServers: (ack['iceServers'] as List?) ?? const [],
        selfPeerId: _me?.id ?? '',
      );

      // Everything already being published, before any new-producer arrives.
      for (final producer in ProducerInfo.listFrom(ack['producers'])) {
        await _mediasoup.consume(producer);
      }

      await _startMicrophone();

      // A lesson is watched, not touched. Without this the screen dims mid
      // class and the student has to keep waking the phone to keep watching.
      unawaited(WakelockPlus.enable());

      _phase = MeetingPhase.live;
      _socket.log('student joined', {'meetingId': _meetingId});
      notifyListeners();
    } catch (err) {
      _error = err is SocketAckException ? err.message : err.toString();
      _phase = MeetingPhase.idle;
      await _teardown();
      notifyListeners();
    }
  }

  /// Publishes the microphone, tolerating every way it can fail.
  ///
  /// Nothing in here rethrows. A refused permission is a normal outcome for a
  /// student joining from a phone in a hurry, and it must not cost them the
  /// class — they simply cannot speak until they grant it and rejoin.
  ///
  /// The permission prompt is raised by getUserMedia itself: flutter_webrtc
  /// asks for RECORD_AUDIO on Android and the microphone on iOS as part of the
  /// call. Asking separately first would show the student two prompts for one
  /// decision.
  Future<void> _startMicrophone() async {
    try {
      final stream = await media.openMicrophone();
      if (stream == null) return;

      await _mediasoup.publishMicrophone(stream);
      // The server pauses it the instant it is created, and says so through
      // joined-muted. Reflecting that here keeps the button honest even if
      // that broadcast is slow.
      media.setMicOn(false);
    } catch (err) {
      debugPrint('[Meeting] microphone setup failed: $err');
      media.setMicNotice('Could not start your microphone — you can still listen');
    }
  }

  /// Fills every list from the join acknowledgement.
  ///
  /// The server sends the entire room state in one reply, which is why a
  /// student who joins an hour late still sees the full board, the whole chat
  /// and any poll in flight, with no extra round trips.
  void _hydrate(Map<String, dynamic> ack) {
    if (ack['peer'] is Map) {
      _me = Peer.fromMap(Map<String, dynamic>.from(ack['peer'] as Map));
    }
    _participants = Peer.listFrom(ack['participants']);
    _chat
      ..clear()
      ..addAll(ChatMessage.listFrom(ack['chat']));
    _lastReadChat = _chat.length;
    _polls
      ..clear()
      ..addAll(Poll.listFrom(ack['polls']));
    whiteboard.replaceAll(Stroke.listFrom(ack['whiteboard']));
    _stageMode = (ack['stageMode'] ?? 'whiteboard').toString();

    if (ack['recording'] is Map) {
      _recording = RecordingState.fromSnapshot(
        Map<String, dynamic>.from(ack['recording'] as Map),
      );
    }
    // A render still running from an earlier session in this same room.
    final jobs = (ack['recordingJobs'] as List?) ?? const [];
    if (!_recording.active && jobs.isNotEmpty && jobs.last is Map) {
      _recording = RecordingState.fromJob(
        Map<String, dynamic>.from(jobs.last as Map),
      );
    }

    _handRaised = _me?.handRaised ?? false;
  }

  /// Subscribes to every broadcast a student can receive.
  void _listen() {
    void sub(String event, void Function(dynamic data) handler) {
      _subscriptions.add(_socket.on(event, handler));
    }

    // --- who is in the room -------------------------------------------------
    sub('participants', (data) {
      _participants = Peer.listFrom(data);
      // The server is the authority on our own hand, and lower-all-hands can
      // put it down without addressing us directly.
      final mine = _participants.where((p) => p.id == _me?.id);
      if (mine.isNotEmpty) _handRaised = mine.first.handRaised;
      notifyListeners();
    });

    sub('peer-left', (data) {
      if (data is Map && data['id'] != null) {
        _mediasoup.removePeer(data['id'].toString());
      }
    });

    sub('peer-removed', (data) {
      if (data is Map && data['peerId'] != null) {
        _mediasoup.removePeer(data['peerId'].toString());
      }
    });

    sub('active-speakers', (data) {
      if (data is! Map) return;
      final speakers = (data['speakers'] as List?) ?? const [];
      _activeSpeakers = speakers
          .map((s) => s is Map ? (s['peerId'] ?? s['id'] ?? '').toString() : s.toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      notifyListeners();
    });

    sub('teacher-disconnected', (_) {
      _teacherAway = true;
      notifyListeners();
    });

    sub('peer-reconnected', (data) {
      if (data is Map && data['role'] == 'teacher') _teacherAway = false;
      notifyListeners();
    });

    // --- media --------------------------------------------------------------
    sub('new-producer', (data) {
      if (data is! Map) return;
      _teacherAway = false;
      unawaited(
        _mediasoup.consume(ProducerInfo.fromMap(Map<String, dynamic>.from(data))),
      );
    });

    sub('producer-closed', (data) {
      if (data is! Map || data['producerId'] == null) return;
      _mediasoup.removeProducer(data['producerId'].toString());
    });

    // --- the microphone, which the server controls ---------------------------
    sub('joined-muted', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      media.setMicLocked(
        map['locked'] == true,
        notice: map['reason']?.toString(),
      );
      media.setMicOn(false);
    });

    sub('mic-locked', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      _mediasoup.pauseMicLocally();
      media.setMicLocked(true, notice: map['reason']?.toString());
    });

    sub('force-mute', (_) {
      _mediasoup.pauseMicLocally();
      media.setMicOn(false);
      media.setMicNotice('Muted by the teacher');
    });

    // --- the lesson itself ---------------------------------------------------
    sub('stage-mode', (data) {
      if (data is! Map) return;
      _stageMode = (data['mode'] ?? 'whiteboard').toString();
      notifyListeners();
    });

    sub('whiteboard-stroke', (data) {
      if (data is! Map) return;
      whiteboard.add(Stroke.fromMap(Map<String, dynamic>.from(data)));
    });

    sub('whiteboard-clear', (_) => whiteboard.clear());

    sub('chat-message', (data) {
      if (data is! Map) return;
      _chat.add(ChatMessage.fromMap(Map<String, dynamic>.from(data)));
      notifyListeners();
    });

    // --- polls ---------------------------------------------------------------
    sub('poll-started', (data) {
      if (data is! Map) return;
      _upsertPoll(Poll.fromMap(Map<String, dynamic>.from(data)));
    });

    sub('poll-ended', (data) {
      if (data is! Map) return;
      final closed = Poll.fromMap(Map<String, dynamic>.from(data));
      // The closing broadcast carries counts and the correct answer but no
      // myVote — it is one payload sent to the whole room. Carrying our own
      // vote across is what lets the result screen say whether we were right.
      final existing = _polls.where((p) => p.id == closed.id);
      final mine = existing.isEmpty ? null : existing.first.myVote;
      _upsertPoll(mine == null ? closed : closed.withMyVote(mine));
    });

    sub('poll-vote-count', (data) {
      if (data is! Map) return;
      final id = (data['pollId'] ?? '').toString();
      final total = (data['totalVotes'] as num?)?.toInt() ?? 0;
      final index = _polls.indexWhere((p) => p.id == id);
      if (index == -1) return;
      _polls[index] = _polls[index].withTotalVotes(total);
      notifyListeners();
    });

    // --- hands ---------------------------------------------------------------
    sub('hand-changed', (data) {
      if (data is! Map) return;
      if (data['peerId']?.toString() == _me?.id) {
        _handRaised = data['raised'] == true;
        notifyListeners();
      }
    });

    sub('hands-cleared', (_) {
      _handRaised = false;
      notifyListeners();
    });

    // --- recording -----------------------------------------------------------
    sub('recording-started', (data) {
      if (data is! Map) return;
      _recording = RecordingState.fromSnapshot(Map<String, dynamic>.from(data));
      notifyListeners();
    });

    sub('recording-stopped', (data) {
      if (data is! Map) return;
      _recording = RecordingState.fromSnapshot(Map<String, dynamic>.from(data));
      notifyListeners();
    });

    sub('recording-status', (data) {
      if (data is! Map) return;
      _recording = RecordingState.fromJob(Map<String, dynamic>.from(data));
      notifyListeners();
    });

    // --- the ways a class ends ------------------------------------------------
    sub('kicked', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      _finish(EndReason.kicked, map['reason']?.toString());
    });

    sub('session-closed', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      _finish(EndReason.sessionClosed, map['reason']?.toString());
    });

    // Socket.IO retries on its own; this only ends the class once it has
    // genuinely given up, so a lift or a tunnel does not eject the student.
    _subscriptions.add(_socket.on('reconnect_failed', (_) {
      _finish(EndReason.connectionLost, 'Lost connection to the class');
    }));
  }

  void _upsertPoll(Poll poll) {
    final index = _polls.indexWhere((p) => p.id == poll.id);
    if (index == -1) {
      _polls.add(poll);
    } else {
      _polls[index] = poll;
    }
    notifyListeners();
  }

  // --- what a student can actually do ----------------------------------------

  /// Unmutes or mutes. Refuses while the server has the microphone locked,
  /// which it does whenever no teacher or coordinator is present.
  Future<void> toggleMic() async {
    if (media.micLocked || !media.micAvailable) return;
    final next = !media.micOn;
    try {
      await _mediasoup.setMicEnabled(next);
      media.setMicOn(next);
      media.setMicNotice(null);
    } catch (err) {
      media.setMicNotice(err is SocketAckException ? err.message : 'Could not change your microphone');
    }
  }

  Future<void> toggleHand() async {
    final next = !_handRaised;
    try {
      await _socket.emitAck('raise-hand', {'raised': next});
      _handRaised = next;
      notifyListeners();
    } catch (err) {
      debugPrint('[Meeting] raise-hand failed: $err');
    }
  }

  /// Answers the current poll. One vote only — the server refuses a second,
  /// so the local poll is updated immediately to take the buttons away.
  Future<String?> vote(String pollId, int optionIndex) async {
    try {
      await _socket.emitAck('vote-poll', {
        'pollId': pollId,
        'optionIndex': optionIndex,
      });
      final index = _polls.indexWhere((p) => p.id == pollId);
      if (index != -1) {
        _polls[index] = _polls[index].withMyVote(optionIndex);
        notifyListeners();
      }
      return null;
    } catch (err) {
      return err is SocketAckException ? err.message : 'Could not send your answer';
    }
  }

  /// Leaves deliberately. Tells the server first so attendance records this as
  /// a clean exit rather than a dropped connection.
  Future<void> leave() async {
    try {
      await _socket.emitAck('leave-room');
    } catch (_) {
      // Leaving must work even when the server is already unreachable.
    }
    _finish(EndReason.left, null);
  }

  void _finish(EndReason reason, String? message) {
    if (_phase == MeetingPhase.ended) return;
    _endReason = reason;
    _error = message;
    _phase = MeetingPhase.ended;
    notifyListeners();
    unawaited(_teardown());
  }

  Future<void> _teardown() async {
    for (final remove in _subscriptions) {
      remove();
    }
    _subscriptions.clear();
    await _mediasoup.dispose();
    _socket.dispose();
    unawaited(WakelockPlus.disable());
  }

  /// Clears the session so the join screen can be used again.
  void reset() {
    _phase = MeetingPhase.idle;
    _error = null;
    _participants = const [];
    _chat.clear();
    _polls.clear();
    _activeSpeakers = const {};
    _handRaised = false;
    _teacherAway = false;
    _recording = RecordingState.idle;
    _stageMode = 'whiteboard';
    whiteboard.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_teardown());
    media.dispose();
    whiteboard.dispose();
    super.dispose();
  }
}
