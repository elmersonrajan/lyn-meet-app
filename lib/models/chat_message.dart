/// A message on the class feed.
///
/// Students cannot post: post-message is staff-only on the server
/// (requireStaff, backend/src/socket/index.js). This model therefore only ever
/// describes something a teacher or coordinator said, and the UI renders the
/// feed read-only.
class ChatMessage {
  final String id;
  final String text;

  /// "chat" or "qa" — the teacher's Q&A answers are tagged so they can be
  /// styled apart from ordinary announcements.
  final String type;
  final String from;
  final String role;
  final int at;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.from,
    required this.role,
    required this.at,
  });

  bool get isQa => type == 'qa';

  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(at);

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      type: (map['type'] ?? 'chat').toString(),
      from: (map['from'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      at: (map['at'] as num?)?.toInt() ?? 0,
    );
  }

  static List<ChatMessage> listFrom(dynamic raw) {
    if (raw is! List) return const <ChatMessage>[];
    return raw
        .whereType<Map>()
        .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
}
