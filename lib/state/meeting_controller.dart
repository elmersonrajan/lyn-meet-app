import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config/env.dart';
import '../models/appreciation.dart';
import '../models/board.dart';
import '../models/peer.dart';
import '../models/poll.dart';
import '../models/question.dart';
import '../models/producer_info.dart';
import '../models/recording_state.dart';
import '../models/shared_media.dart';
import '../models/stroke.dart';
import '../services/mediasoup_service.dart';
import '../services/meeting_link.dart';
import '../services/socket_service.dart';
import 'audio_route.dart';
import 'connection_status.dart';
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
    _mediasoup.onTrack = _onRemoteTrack;
    _mediasoup.onTrackGone = (track) => unawaited(this.media.detach(track));
    _mediasoup.onTransportState = connection.setTransportState;
  }

  final SocketService _socket;
  final MediaController media;
  final WhiteboardController whiteboard;
  final AudioRouteController audio = AudioRouteController();
  final ConnectionStatus connection = ConnectionStatus();
  late final MediasoupService _mediasoup;

  /// Whether the loudspeaker has been claimed yet this session.
  bool _routedAudio = false;

  /// Hands the signed-in session to the socket.
  ///
  /// Nothing can be joined without it: the handshake is refused outright, and
  /// the role every screen keys off is read from the account behind this
  /// cookie rather than from anything the app asks for.
  void useSession(String? cookie) {
    _sessionCookie = cookie;
    _socket.setSessionCookie(cookie);
  }

  String? _sessionCookie;

  /// Headers for fetching a board's image or document.
  ///
  /// Those are served behind the same sign-in as everything else — a class's
  /// material is not public — and a plain Image.network carries no cookie, so
  /// without this every board with a picture on it loads as a broken image.
  Map<String, String> get assetHeaders =>
      _sessionCookie == null ? const {} : {'Cookie': _sessionCookie!};

  /// Turns a server path into a full address.
  String assetUrl(String path) =>
      path.startsWith('http') ? path : '${Env.serverUrl}$path';

  void _onRemoteTrack(RemoteTrack track) {
    unawaited(media.attach(track));
    // The first voice to arrive is what makes the routing matter. WebRTC
    // defaults to the earpiece, so without this the class plays almost
    // inaudibly from a phone lying on a desk and reads as a broken app.
    if (track.slot == TrackSlot.audio && !_routedAudio) {
      _routedAudio = true;
      unawaited(audio.applyDefault());
    }
  }

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
  final List<Question> _questions = [];
  final List<Poll> _polls = [];
  Set<String> _activeSpeakers = const {};

  /// "whiteboard" | "draw" | "screen" | "clip" — what the teacher has put on
  /// the main area. Defaults to the board, as the server does.
  String _stageMode = 'whiteboard';

  RecordingState _recording = RecordingState.idle;

  /// The platform's own name for this lesson. A room id is a ScheduleID and
  /// tells a student nothing about which class they are sitting in.
  String _className = '';

  /// The whiteboards in this class and which one is live. A student follows;
  /// only a teacher can switch.
  List<BoardTab> _boards = const [];
  String _activeBoardId = '';

  /// What the live board is drawn over, and where the class is looking at it.
  BoardImage? _boardImage;
  BoardDocument? _boardDocument;
  BoardView _boardView = BoardView.flat;

  /// A clip the teacher is playing, if any. Named apart from [media], which
  /// is the microphone and the video renderers.
  SharedMedia? _clip;

  /// The most recent piece of praise, held only long enough to celebrate it.
  Appreciation? _appreciation;

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
  List<Question> get questions => List.unmodifiable(_questions);
  List<Poll> get polls => List.unmodifiable(_polls);
  Set<String> get activeSpeakers => _activeSpeakers;
  String get stageMode => _stageMode;
  RecordingState get recording => _recording;
  String get className => _className;
  List<BoardTab> get boards => _boards;
  String get activeBoardId => _activeBoardId;
  BoardImage? get boardImage => _boardImage;
  BoardDocument? get boardDocument => _boardDocument;
  BoardView get boardView => _boardView;
  SharedMedia? get clip => _clip;
  Appreciation? get appreciation => _appreciation;

  /// How many people are showing each thumb, which is the only reason a
  /// student's reaction is worth broadcasting at all.
  int get thumbsUp => _participants.where((p) => p.isFollowing).length;
  int get thumbsDown => _participants.where((p) => p.isConfused).length;

  /// This student's own thumb, so the button can show what is already set.
  String? get myReaction {
    for (final peer in _participants) {
      if (peer.id == _me?.id) return peer.reaction;
    }
    return null;
  }
  bool get teacherAway => _teacherAway;
  bool get handRaised => _handRaised;
  bool get isLive => _phase == MeetingPhase.live;

  /// Whether a teacher or coordinator is in the room. The microphone depends
  /// on it, so the control bar needs to know.
  bool get hasStaff => _participants.any((p) => p.isStaff && !p.disconnected);

  /// The role the server granted **for this meeting**, which is not always the
  /// account's own. Enrolment can lower it — a teacher in someone else's class
  /// joins as a student — so this, not the signed-in role, decides the UI.
  String get myRole => _me?.role ?? 'student';

  /// Whether this session may use the staff-only actions. Asked of the room
  /// rather than of the account, for the reason above.
  bool get isAdmin => _me?.isStaff ?? false;

  /// Written answers, visible only to staff.
  ///
  /// The server sends these to a second socket.io room that students are not
  /// in, so for a student this map is empty because nothing ever arrives —
  /// not because anything here filters it.
  final Map<String, List<Answer>> _answers = {};
  List<Answer> answersFor(String questionId) =>
      List.unmodifiable(_answers[questionId] ?? const <Answer>[]);

  /// Whether the student may unmute at all.
  ///
  /// Derived from who is in the room, never stored. The server broadcasts
  /// `mic-locked` when the last teacher or coordinator leaves but sends
  /// nothing when one returns — there is no unlock event to wait for. Holding
  /// this as a flag meant the microphone stayed locked for the rest of the
  /// lesson once staff had dropped out even for a moment. The web client
  /// computes it the same way.
  bool get micLocked => !hasStaff;

  /// Whether the camera on the tile is switched off rather than frozen.
  ///
  /// Turning a camera off **pauses** the producer; it does not close it. No
  /// producer-closed is broadcast, the frames simply stop, and a renderer left
  /// pointing at that track holds its last frame indefinitely — which is
  /// exactly what a stuck picture of the teacher looks like. Room state is the
  /// only thing that says otherwise, so the tile is driven from videoOff
  /// rather than from whether a track happens to be attached.
  bool get cameraOff {
    final peerId = media.cameraPeerId;
    if (peerId == null) return false;
    for (final peer in _participants) {
      if (peer.id == peerId) return peer.videoOff || peer.disconnected;
    }
    // Their track is still attached but they are no longer in the room, so
    // whatever is on screen is certainly stale.
    return true;
  }

  /// The name against the camera tile, when there is one.
  String? get cameraPeerName {
    final peerId = media.cameraPeerId;
    if (peerId == null) return null;
    for (final peer in _participants) {
      if (peer.id == peerId) return peer.name;
    }
    return null;
  }

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

  /// The newest question still taking answers, which is the one a student
  /// needs to see. Older ones stay readable in the panel.
  Question? get openQuestion {
    for (final question in _questions.reversed) {
      if (question.isOpen) return question;
    }
    return null;
  }

  /// Questions the student has not answered yet, for the tab badge. A closed
  /// question is not owed an answer, so it does not count.
  int get unansweredQuestions =>
      _questions.where((q) => q.isOpen && !q.answered).length;

  /// Joins a class.
  ///
  /// The order is deliberate and each step depends on the last: signalling
  /// first, then the room snapshot, then the media the snapshot describes.
  /// The microphone comes last and is allowed to fail — a student who refuses
  /// the permission, or whose phone has no working input, should still get the
  /// lesson.
  /// Joins a class as whoever the session says you are.
  ///
  /// There is no name and no role in the payload any more, and that is the
  /// point: the server takes identity from the authenticated handshake and
  /// discards a client-supplied role outright, logging it as a probe. Sending
  /// one would not grant it — the lobby that let anyone arrive as a teacher is
  /// exactly what the change closed.
  ///
  /// The role that comes back can be *lower* than the account's own. A teacher
  /// walking into a class that is not theirs joins as a student; enrolment can
  /// demote, never promote.
  Future<void> join({required String meetingId, required String signedInAs}) async {
    if (_phase == MeetingPhase.joining || _phase == MeetingPhase.live) return;

    _displayName = signedInAs;
    _meetingId = normalizeMeetingId(meetingId);
    _error = null;
    _phase = MeetingPhase.joining;
    notifyListeners();

    try {
      if (_meetingId.isEmpty) {
        throw StateError('Enter the meeting ID');
      }

      await media.initRenderers();
      _socket.connect();

      final ack = await _socket.emitAck(
        'join-room',
        {'meetingId': _meetingId},
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
      _socket.log('joined', {'meetingId': _meetingId, 'role': myRole});
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

  /// Whether a rejoin is already under way, so two reconnects in quick
  /// succession do not both try to rebuild the media.
  bool _rejoining = false;

  /// Takes the seat in the room again after the connection came back.
  ///
  /// Everything the server held is gone with the old peer: the transports were
  /// closed with it, and every consumer on them. So this is a fresh join, not
  /// a resume — the old media is torn down first, deliberately, rather than
  /// left pointing at transports the server has forgotten.
  ///
  /// The event handlers are not re-registered. They are attached to the socket
  /// itself, which Socket.IO reconnected rather than replaced, so they are
  /// still live and doing it again would double every broadcast.
  Future<void> _rejoin() async {
    if (_rejoining) return;
    _rejoining = true;
    try {
      _socket.log('rejoining after a dropped connection', {'meetingId': _meetingId});

      await _mediasoup.dispose();
      await media.clearRemote();

      final ack = await _socket.emitAck(
        'join-room',
        {'meetingId': _meetingId},
        Env.joinTimeout,
      );

      _hydrate(ack);

      await _mediasoup.start(
        routerRtpCapabilities:
            Map<String, dynamic>.from(ack['routerRtpCapabilities'] as Map),
        iceServers: (ack['iceServers'] as List?) ?? const [],
        selfPeerId: _me?.id ?? '',
      );

      for (final producer in ProducerInfo.listFrom(ack['producers'])) {
        await _mediasoup.consume(producer);
      }

      await _startMicrophone();
      notifyListeners();
    } catch (err) {
      // The class itself may have ended while the connection was down, or the
      // seat may no longer be available. Either way this is the end of the
      // session rather than something to keep retrying silently.
      debugPrint('[Meeting] rejoin failed: $err');
      _finish(
        EndReason.connectionLost,
        err is SocketAckException ? err.message : 'Could not rejoin the class',
      );
    } finally {
      _rejoining = false;
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
    _questions
      ..clear()
      ..addAll(Question.listFrom(ack['questions']));
    _polls
      ..clear()
      ..addAll(Poll.listFrom(ack['polls']));
    _stageMode = (ack['stageMode'] ?? 'whiteboard').toString();
    _className = (ack['className'] ?? '').toString();

    // The board and everything behind it. A class is taught on an image or a
    // document as often as on a blank page now, so replaying only the ink
    // would show a student the annotations with the thing being annotated
    // missing — the one case where a half-right board is worse than none.
    _boards = BoardTab.listFrom(ack['boards']);
    _activeBoardId = (ack['activeBoardId'] ?? '').toString();
    _boardImage = BoardImage.fromMap(ack['boardImage']);
    _boardDocument = BoardDocument.fromMap(ack['boardDocument']);
    _boardView = BoardView.fromMap(ack['boardView']);
    whiteboard.replaceAll(Stroke.listFrom(ack['whiteboard']));

    _clip = SharedMedia.fromMap(ack['media']);

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

    // A fresh join broadcasts only peer-joined — there is no accompanying
    // participants snapshot — so the list has to be maintained here or the
    // room silently stops growing. That cost more than a stale list: a teacher
    // rejoining after their grace window expired arrives as a new peer, so
    // ignoring this event left the app believing no staff were present, and
    // the microphone locked for the rest of the lesson.
    sub('peer-joined', (data) {
      if (data is! Map) return;
      _upsertPeer(Peer.fromMap(Map<String, dynamic>.from(data)));
    });

    sub('peer-left', (data) {
      if (data is! Map || data['id'] == null) return;
      final id = data['id'].toString();
      _mediasoup.removePeer(id);
      _removePeer(id);
    });

    sub('peer-removed', (data) {
      if (data is! Map || data['peerId'] == null) return;
      final id = data['peerId'].toString();
      _mediasoup.removePeer(id);
      _removePeer(id);
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

    // The other way a teacher comes back: inside the grace window, into their
    // original peer rather than a new one.
    sub('peer-reconnected', (data) {
      if (data is! Map) return;
      _upsertPeer(Peer.fromMap(Map<String, dynamic>.from(data)));
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

    // A camera or microphone switched off without the producer being closed.
    // The participants broadcast that accompanies this carries the same fact,
    // but this one names the source, so the tile can change the moment the
    // teacher taps rather than after a whole-room refresh.
    sub('media-state', (data) {
      if (data is! Map) return;
      final peerId = (data['peerId'] ?? '').toString();
      final source = (data['source'] ?? '').toString();
      final paused = data['paused'] == true;
      final index = _participants.indexWhere((p) => p.id == peerId);
      if (index == -1) return;

      final next = [..._participants];
      next[index] = switch (source) {
        'video' => next[index].copyWith(videoOff: paused),
        'audio' => next[index].copyWith(audioMuted: paused),
        _ => next[index],
      };
      _participants = next;
      notifyListeners();
    });

    // --- the microphone, which the server controls ---------------------------
    sub('joined-muted', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      media.setMicNotice(map['reason']?.toString());
      media.setMicOn(false);
    });

    sub('mic-locked', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : const {};
      _mediasoup.pauseMicLocally();
      media.setMicOn(false);
      media.setMicNotice(map['reason']?.toString());
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
      final map = Map<String, dynamic>.from(data);
      // A stroke now names the board it belongs to. One arriving for a board
      // the class is not looking at is not ours to draw — the teacher can ink
      // a page nobody is on, and the strokes come back with it when they are.
      final boardId = (map['boardId'] ?? '').toString();
      if (boardId.isNotEmpty && _activeBoardId.isNotEmpty && boardId != _activeBoardId) {
        return;
      }
      whiteboard.add(Stroke.fromMap(map));
    });

    sub('whiteboard-clear', (_) => whiteboard.clear());

    // The teacher moved to another board, added one, or put something behind
    // the ink. The switch carries the whole page with it, so this replaces
    // rather than patches — which is also what makes a late join and a tab
    // switch end in exactly the same picture.
    sub('whiteboard-switched', (data) {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      _boards = BoardTab.listFrom(map['boards']);
      _activeBoardId = (map['activeBoardId'] ?? _activeBoardId).toString();
      _boardImage = BoardImage.fromMap(map['image']);
      _boardDocument = BoardDocument.fromMap(map['document']);
      _boardView = BoardView.fromMap(map['view']);
      whiteboard.replaceAll(Stroke.listFrom(map['strokes']));
      notifyListeners();
    });

    sub('whiteboard-boards', (data) {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      _boards = BoardTab.listFrom(map['boards']);
      _activeBoardId = (map['activeBoardId'] ?? _activeBoardId).toString();
      notifyListeners();
    });

    // Where the class is being asked to look. The teacher drives it and
    // everybody follows: "look at the top left" means nothing when forty
    // people are each scrolled somewhere different.
    sub('whiteboard-view', (data) {
      if (data is! Map) return;
      _boardView = BoardView.fromMap(data['view']);
      notifyListeners();
    });

    sub('whiteboard-page', (data) {
      if (data is! Map) return;
      final page = (data['page'] as num?)?.toInt();
      final document = _boardDocument;
      if (page == null || document == null) return;
      _boardDocument = BoardDocument(
        id: document.id,
        url: document.url,
        name: document.name,
        page: page,
      );
      notifyListeners();
    });

    // --- a clip on the stage ---------------------------------------------
    sub('shared-media', (data) {
      _clip = SharedMedia.fromMap(data);
      notifyListeners();
    });

    sub('shared-media-state', (data) {
      _clip = SharedMedia.fromMap(data);
      notifyListeners();
    });

    sub('shared-media-stopped', (_) {
      _clip = null;
      notifyListeners();
    });

    // --- praise, and the quiet thumbs -------------------------------------
    sub('appreciation', (data) {
      if (data is! Map) return;
      _appreciation = Appreciation.fromMap(Map<String, dynamic>.from(data));
      notifyListeners();
    });

    sub('reaction-changed', (data) {
      if (data is! Map) return;
      final peerId = (data['peerId'] ?? '').toString();
      final reaction = data['reaction']?.toString();
      final index = _participants.indexWhere((p) => p.id == peerId);
      if (index == -1) return;
      final next = [..._participants];
      next[index] = reaction == null
          ? next[index].copyWith(clearReaction: true)
          : next[index].copyWith(reaction: reaction);
      _participants = next;
      notifyListeners();
    });

    sub('reactions-cleared', (_) {
      _participants =
          _participants.map((p) => p.copyWith(clearReaction: true)).toList();
      notifyListeners();
    });

    // --- written questions ---------------------------------------------------
    sub('question-asked', (data) {
      if (data is! Map) return;
      _upsertQuestion(Question.fromMap(Map<String, dynamic>.from(data)));
    });

    // Only the count reaches students. The answers themselves go to a separate
    // socket.io room that students are not in, so nobody can copy and nobody
    // is wrong in front of the class.
    sub('question-answer-count', (data) {
      if (data is! Map) return;
      final id = (data['questionId'] ?? '').toString();
      final count = (data['answerCount'] as num?)?.toInt() ?? 0;
      final index = _questions.indexWhere((q) => q.id == id);
      if (index == -1) return;
      _questions[index] = _questions[index].withAnswerCount(count);
      notifyListeners();
    });

    // Staff only. Students are not in the room this is sent to, so for them
    // this handler simply never fires.
    sub('question-answer', (data) {
      if (data is! Map) return;
      final answer = Answer.fromMap(Map<String, dynamic>.from(data));
      final list = _answers.putIfAbsent(answer.questionId, () => <Answer>[]);
      // Answers are edited in place until the question closes, so a second one
      // from the same person replaces theirs rather than stacking up.
      final index = list.indexWhere((a) => a.peerId == answer.peerId);
      if (index == -1) {
        list.add(answer);
      } else {
        list[index] = answer;
      }
      notifyListeners();
    });

    sub('question-closed', (data) {
      if (data is! Map) return;
      final id = (data['questionId'] ?? '').toString();
      final index = _questions.indexWhere((q) => q.id == id);
      if (index == -1) return;
      _questions[index] = _questions[index].closedNow();
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
      // The closing broadcast carries counts and the correct set but no
      // myVote — it is one payload sent to the whole room. Carrying our own
      // choices across is what lets the result screen say whether we were
      // right.
      final existing = _polls.where((p) => p.id == closed.id);
      final mine = existing.isEmpty ? null : existing.first.myVotes;
      _upsertPoll(mine == null ? closed : closed.withMyVotes(mine));
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

    // --- how well any of this is arriving -------------------------------------
    // Signalling going down is invisible otherwise: video keeps painting its
    // last frame and the board keeps whatever was already drawn, so the app
    // looks fine while the class has stopped.
    connection.setSocketUp(true);

    // A dropped connection loses the seat in the room, not just the transport.
    //
    // Only a teacher gets a grace window; a student or an admin is removed the
    // instant they disconnect. Socket.IO then reconnects the transport by
    // itself and everything looks healthy — the socket is up, the bars are
    // green — while the account is in no room at all, nothing arrives, and the
    // join guard refuses to let them back in because the app still believes it
    // is live. So a reconnect has to re-join rather than merely resume.
    sub('connect', (_) {
      connection.setSocketUp(true);
      if (_phase == MeetingPhase.live) unawaited(_rejoin());
    });
    sub('disconnect', (_) => connection.setSocketUp(false));

    // Socket.IO retries on its own; this only ends the class once it has
    // genuinely given up, so a lift or a tunnel does not eject the student.
    _subscriptions.add(_socket.on('reconnect_failed', (_) {
      _finish(EndReason.connectionLost, 'Lost connection to the class');
    }));
  }

  /// Adds or replaces one person in the room.
  ///
  /// A teacher arriving by any route — a new join, or a reconnect into their
  /// old peer — clears the "teacher lost connection" banner, since the thing
  /// the banner reports is no longer true.
  void _upsertPeer(Peer peer) {
    final next = [..._participants];
    final index = next.indexWhere((p) => p.id == peer.id);
    if (index == -1) {
      next.add(peer);
    } else {
      next[index] = peer;
    }
    _participants = next;
    if (peer.isTeacher && !peer.disconnected) _teacherAway = false;
    notifyListeners();
  }

  void _removePeer(String peerId) {
    _participants = _participants.where((p) => p.id != peerId).toList();
    notifyListeners();
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

  void _upsertQuestion(Question question) {
    final index = _questions.indexWhere((q) => q.id == question.id);
    if (index == -1) {
      _questions.add(question);
    } else {
      // A re-broadcast carries no myAnswer — it goes to the whole room — so
      // the student's own answer is preserved rather than blanked.
      final mine = _questions[index].myAnswer;
      _questions[index] =
          mine == null ? question : question.withMyAnswer(mine);
    }
    notifyListeners();
  }

  // --- what a student can actually do ----------------------------------------

  /// Unmutes or mutes. Refuses while the server has the microphone locked,
  /// which it does whenever no teacher or coordinator is present.
  Future<void> toggleMic() async {
    if (micLocked || !media.micAvailable) return;
    final next = !media.micOn;
    try {
      await _mediasoup.setMicEnabled(next);
      media.setMicOn(next);
      media.setMicNotice(null);
    } catch (err) {
      media.setMicNotice(err is SocketAckException ? err.message : 'Could not change your microphone');
    }
  }

  /// Shows or takes back a thumb.
  ///
  /// Students only — the server refuses staff, on the grounds that a
  /// coordinator's view of the pace is not what this is for. Pressing the
  /// thumb already showing takes it back, which the server works out itself,
  /// so the app sends what was wanted rather than trying to predict the result.
  Future<String?> setReaction(String? reaction) async {
    if (isAdmin) return 'Only students can react';
    try {
      await _socket.emitAck('set-reaction', {'reaction': reaction});
      return null;
    } catch (err) {
      return err is SocketAckException ? err.message : 'Could not send that';
    }
  }

  /// Clears every thumb in the room. Staff only.
  Future<String?> clearReactions() => _staffAction('clear-reactions');

  /// Praises the class. Staff only.
  ///
  /// Only the id travels. The server holds its own wording and refuses an id
  /// it does not know, so a phone cannot put words in a teacher's mouth and
  /// both clients always say the same thing.
  Future<String?> appreciate(String id) =>
      _staffAction('appreciate', {'id': id});

  /// Mutes one person rather than the whole room.
  Future<String?> muteParticipant(String peerId) =>
      _staffAction('mute-participant', {'peerId': peerId});

  /// Forgets the celebration once it has been shown, so reopening the room
  /// does not replay praise from ten minutes ago.
  void clearAppreciation() {
    if (_appreciation == null) return;
    _appreciation = null;
    notifyListeners();
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

  /// Answers the current poll.
  ///
  /// A vote is a whole set, submitted once — the server refuses a second, so
  /// the local poll is updated immediately to take the buttons away. The
  /// server de-duplicates and sorts the picks; sending them in tap order is
  /// fine.
  Future<String?> vote(String pollId, List<int> optionIndexes) async {
    if (optionIndexes.isEmpty) return 'Choose at least one option';
    try {
      await _socket.emitAck('vote-poll', {
        'pollId': pollId,
        'optionIndexes': optionIndexes,
      });
      final index = _polls.indexWhere((p) => p.id == pollId);
      if (index != -1) {
        _polls[index] = _polls[index].withMyVotes(optionIndexes);
        notifyListeners();
      }
      return null;
    } catch (err) {
      return err is SocketAckException ? err.message : 'Could not send your answer';
    }
  }

  /// Answers a written question.
  ///
  /// Can be sent again to reword: the server replaces rather than appends, so
  /// staff see one answer per student and the student can fix a typo until the
  /// question closes.
  Future<String?> answerQuestion(String questionId, String text) async {
    final body = text.trim();
    if (body.isEmpty) return 'Write an answer first';
    try {
      final ack = await _socket.emitAck('answer-question', {
        'questionId': questionId,
        'text': body,
      });
      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1 && ack['answer'] is Map) {
        _questions[index] = _questions[index].withMyAnswer(
          Answer.fromMap(Map<String, dynamic>.from(ack['answer'] as Map)),
        );
        notifyListeners();
      }
      return null;
    } catch (err) {
      return err is SocketAckException ? err.message : 'Could not send your answer';
    }
  }

  // --- staff-only actions ------------------------------------------------
  //
  // Every one of these is refused by the server for a student, so the UI that
  // offers them is hidden rather than disabled — a control that only ever
  // produces an error is worse than no control. The guard here is a second
  // line, not the enforcement: that lives in requireStaff on the server.

  Future<String?> _staffAction(String event, [Map<String, dynamic> payload = const {}]) async {
    if (!isAdmin) return 'Only a teacher or coordinator can do that';
    try {
      await _socket.emitAck(event, payload);
      return null;
    } catch (err) {
      return err is SocketAckException ? err.message : 'That did not work';
    }
  }

  /// Mutes every student at once. They can unmute again themselves — this is
  /// a way to quieten a room, not a lasting restriction.
  Future<String?> muteEveryone() => _staffAction('mute-others');

  /// Removes somebody from the class. They are told why, and can rejoin unless
  /// the class itself is closed.
  Future<String?> removeParticipant(String peerId) =>
      _staffAction('remove-participant', {'peerId': peerId});

  Future<String?> lowerHand(String peerId) =>
      _staffAction('lower-hand', {'peerId': peerId});

  Future<String?> lowerAllHands() => _staffAction('lower-all-hands');

  /// Chooses what the class is looking at: the whiteboard or a shared screen.
  Future<String?> setStage(String mode) => _staffAction('set-stage', {'mode': mode});

  /// Asks the class a written question. Answers come back to staff only.
  Future<String?> askQuestion(String text) {
    final body = text.trim();
    if (body.isEmpty) return Future.value('Write the question first');
    return _staffAction('ask-question', {'text': body});
  }

  Future<String?> closeQuestion(String questionId) =>
      _staffAction('close-question', {'questionId': questionId});

  /// Puts a multiple-choice poll to the class.
  ///
  /// Four options, at least one correct. How many are correct is never sent to
  /// students while it runs, so marking two here does not tell them to pick
  /// two — which is the whole reason the server withholds it.
  Future<String?> createPoll({
    required String question,
    required List<String> options,
    required List<int> correct,
    required Duration duration,
  }) {
    if (question.trim().isEmpty) return Future.value('Write the question first');
    if (options.length != 4 || options.any((o) => o.trim().isEmpty)) {
      return Future.value('Fill in all four options');
    }
    if (correct.isEmpty) return Future.value('Mark which answers are correct');
    return _staffAction('create-poll', {
      'question': question.trim(),
      'options': options.map((o) => o.trim()).toList(),
      'correct': (correct.toList()..sort()),
      'durationMs': duration.inMilliseconds,
    });
  }

  Future<String?> endPoll(String pollId) =>
      _staffAction('end-poll', {'pollId': pollId});

  /// Ends the class for everybody. Deliberately has no undo here — the
  /// confirmation belongs in the UI, where the person can read what it means.
  Future<String?> closeSession() => _staffAction('close-session');

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
    _questions.clear();
    _polls.clear();
    _activeSpeakers = const {};
    _handRaised = false;
    _teacherAway = false;
    _recording = RecordingState.idle;
    _stageMode = 'whiteboard';
    _className = '';
    _boards = const [];
    _activeBoardId = '';
    _boardImage = null;
    _boardDocument = null;
    _boardView = BoardView.flat;
    _clip = null;
    _appreciation = null;
    whiteboard.clear();
    connection.reset();
    // Both belong to the session that has just ended. Left set, a rejoin would
    // be refused as already in progress, and the loudspeaker would not be
    // claimed again for the next class.
    _rejoining = false;
    _routedAudio = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_teardown());
    media.dispose();
    whiteboard.dispose();
    audio.dispose();
    connection.dispose();
    super.dispose();
  }
}
