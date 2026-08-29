/// A media stream someone in the room is publishing.
///
/// Mirrors the entries of Room.listProducers() and the payload of the
/// new-producer broadcast, which share a shape on purpose so that the initial
/// catch-up and the live updates run through one code path.
class ProducerInfo {
  final String producerId;
  final String peerId;

  /// "audio" or "video" — the WebRTC track type.
  final String kind;

  /// What the track is *for*: "audio", "video" (camera) or "screen". The
  /// server keeps this separate from kind because a camera and a screen share
  /// are both video but belong in completely different places on screen.
  final String source;

  final String role;

  const ProducerInfo({
    required this.producerId,
    required this.peerId,
    required this.kind,
    required this.source,
    required this.role,
  });

  bool get isScreen => source == 'screen';
  bool get isAudio => kind == 'audio';
  bool get isStaff => role == 'teacher' || role == 'coordinator';

  factory ProducerInfo.fromMap(Map<String, dynamic> map) {
    return ProducerInfo(
      producerId: (map['producerId'] ?? '').toString(),
      peerId: (map['peerId'] ?? '').toString(),
      kind: (map['kind'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      role: (map['role'] ?? 'student').toString(),
    );
  }

  static List<ProducerInfo> listFrom(dynamic raw) {
    if (raw is! List) return const <ProducerInfo>[];
    return raw
        .whereType<Map>()
        .map((m) => ProducerInfo.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}
