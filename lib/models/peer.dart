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

  const Peer({
    required this.id,
    required this.name,
    required this.role,
    this.audioMuted = false,
    this.videoOff = true,
    this.disconnected = false,
    this.handRaised = false,
    this.handRaisedAt,
  });

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
    );
  }

  static List<Peer> listFrom(dynamic raw) {
    if (raw is! List) return const <Peer>[];
    return raw
        .whereType<Map>()
        .map((m) => Peer.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Peer copyWith({bool? handRaised, int? handRaisedAt, bool? audioMuted}) {
    return Peer(
      id: id,
      name: name,
      role: role,
      audioMuted: audioMuted ?? this.audioMuted,
      videoOff: videoOff,
      disconnected: disconnected,
      handRaised: handRaised ?? this.handRaised,
      handRaisedAt: handRaised == false ? null : (handRaisedAt ?? this.handRaisedAt),
    );
  }
}
