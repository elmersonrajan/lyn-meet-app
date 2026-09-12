/// One person in the room, as the server describes them.
///
/// Mirrors Peer.public() in backend/src/mediasoup/roomManager.js. Every field
/// the server sends is kept even where this app does not yet show it, so a
/// participants broadcast never silently loses information.
class Peer {
  final String id;
  final String name;
  final String role;
  final bool audioMuted;
  final bool videoOff;
  final bool disconnected;
  final bool handRaised;

  /// When the hand went up, used to order the queue. Null when it is down.
  final int? handRaisedAt;

  /// "up", "down", or null.
  ///
  /// A thumbs down is a quiet "I am lost", and that is the whole point of it:
  /// a student who will not interrupt a class of forty to say so will press a
  /// button. Staff cannot set one — the server refuses.
  final String? reaction;
  final int? reactionAt;

  const Peer({
    required this.id,
    required this.name,
    required this.role,
    this.audioMuted = false,
    this.videoOff = true,
    this.disconnected = false,
    this.handRaised = false,
    this.handRaisedAt,
    this.reaction,
    this.reactionAt,
  });

  bool get isConfused => reaction == 'down';
  bool get isFollowing => reaction == 'up';

  bool get isTeacher => role == 'teacher';
  bool get isCoordinator => role == 'coordinator';

  /// Teacher or coordinator. The server calls these "staff" and gates chat,
  /// polls and the student microphone on at least one of them being present.
  bool get isStaff => isTeacher || isCoordinator;

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? 'student').toString(),
      audioMuted: map['audioMuted'] == true,
      videoOff: map['videoOff'] != false,
      disconnected: map['disconnected'] == true,
      handRaised: map['handRaised'] == true,
      handRaisedAt: (map['handRaisedAt'] as num?)?.toInt(),
      reaction: map['reaction']?.toString(),
      reactionAt: (map['reactionAt'] as num?)?.toInt(),
    );
  }

  static List<Peer> listFrom(dynamic raw) {
    if (raw is! List) return const <Peer>[];
    return raw
        .whereType<Map>()
        .map((m) => Peer.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Peer copyWith({
    bool? handRaised,
    int? handRaisedAt,
    bool? audioMuted,
    bool? videoOff,
    String? reaction,
    bool clearReaction = false,
  }) {
    return Peer(
      id: id,
      name: name,
      role: role,
      audioMuted: audioMuted ?? this.audioMuted,
      videoOff: videoOff ?? this.videoOff,
      disconnected: disconnected,
      handRaised: handRaised ?? this.handRaised,
      handRaisedAt: handRaised == false ? null : (handRaisedAt ?? this.handRaisedAt),
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      reactionAt: clearReaction ? null : reactionAt,
    );
  }
}
