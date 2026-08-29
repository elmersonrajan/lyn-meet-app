/// A quiz question, as a student is allowed to see it.
///
/// Mirrors pollPublic() in backend/src/socket/index.js. Two fields are absent
/// while the poll runs and appear only once it closes:
///
///   counts        how many picked each option
///   correctIndex  which one was right
///
/// That is deliberate on the server, not an oversight here -- a student who
/// could read the answer off the wire would not need to answer.
class Poll {
  final String id;
  final String question;
  final List<String> options;
  final String from;
  final int createdAt;
  final int endsAt;
  final bool closed;
  final int totalVotes;

  /// Per-option tallies, only after the poll closes.
  final List<int>? counts;

  /// The right answer, only after the poll closes.
  final int? correctIndex;

  /// This student's own choice, echoed back so a reload does not offer a
  /// second vote the server would refuse anyway.
  final int? myVote;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.from,
    required this.createdAt,
    required this.endsAt,
    required this.closed,
    required this.totalVotes,
    this.counts,
    this.correctIndex,
    this.myVote,
  });

  bool get hasVoted => myVote != null;

  DateTime get endsAtTime => DateTime.fromMillisecondsSinceEpoch(endsAt);

  /// Time left to answer. Clamped at zero: the server closes on its own timer,
  /// and a clock a few seconds out should not show a negative countdown.
  Duration get remaining {
    final ms = endsAt - DateTime.now().millisecondsSinceEpoch;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  /// Open to this student right now. Checks the clock as well as the flag,
  /// because the closing broadcast can arrive a moment after the deadline.
  bool get isOpen => !closed && remaining > Duration.zero && !hasVoted;

  bool get gotItRight => correctIndex != null && myVote == correctIndex;

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: (map['id'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      options: (map['options'] as List?)?.map((o) => o.toString()).toList() ??
          const <String>[],
      from: (map['from'] ?? '').toString(),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      endsAt: (map['endsAt'] as num?)?.toInt() ?? 0,
      closed: map['closed'] == true,
      totalVotes: (map['totalVotes'] as num?)?.toInt() ?? 0,
      counts: (map['counts'] as List?)
          ?.map((c) => (c as num?)?.toInt() ?? 0)
          .toList(),
      correctIndex: (map['correctIndex'] as num?)?.toInt(),
      myVote: (map['myVote'] as num?)?.toInt(),
    );
  }

  static List<Poll> listFrom(dynamic raw) {
    if (raw is! List) return const <Poll>[];
    return raw
        .whereType<Map>()
        .map((m) => Poll.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Applies a local vote straight away.
  ///
  /// The server acknowledges the vote but broadcasts only the running total,
  /// never "you voted" -- so without this the button would stay live until the
  /// poll closed and let the student tap an option the server would reject.
  Poll withMyVote(int index) => _copy(myVote: index, totalVotes: totalVotes);

  Poll withTotalVotes(int total) => _copy(myVote: myVote, totalVotes: total);

  Poll _copy({int? myVote, required int totalVotes}) {
    return Poll(
      id: id,
      question: question,
      options: options,
      from: from,
      createdAt: createdAt,
      endsAt: endsAt,
      closed: closed,
      totalVotes: totalVotes,
      counts: counts,
      correctIndex: correctIndex,
      myVote: myVote ?? this.myVote,
    );
  }
}
