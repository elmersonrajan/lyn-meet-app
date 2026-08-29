/// A quiz question, as a student is allowed to see it.
///
/// Mirrors pollPublic() in backend/src/socket/index.js.
///
/// A vote is a **set** of options, not one. How many are correct is never
/// revealed while the poll runs — that is deliberate on the server, because
/// being told "pick two" is most of the answer. So the student picks as many
/// as they think are right and submits once.
///
/// Three fields are absent until the poll closes: the per-option tallies, the
/// correct set, and how many people got it exactly right. A student who could
/// read the answer off the wire would not need to answer.
class Poll {
  final String id;
  final String question;
  final List<String> options;
  final String from;
  final int createdAt;
  final int endsAt;
  final bool closed;

  /// How many **people** have voted. Because one person can pick several
  /// options, this is not the sum of [counts].
  final int totalVotes;

  /// Per-option tallies, only after the poll closes.
  final List<int>? counts;

  /// The correct set, only after the poll closes.
  final List<int>? correct;

  /// How many people picked exactly the correct set. Partial credit is not
  /// given: the right answer plus a wrong one is a wrong answer.
  final int? correctVotes;

  /// This student's own choices, echoed back so a reload does not offer a
  /// second vote the server would refuse anyway.
  final List<int>? myVotes;

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
    this.correct,
    this.correctVotes,
    this.myVotes,
  });

  bool get hasVoted => myVotes != null && myVotes!.isNotEmpty;

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

  /// Whether the answer has been revealed.
  bool get revealed => closed && correct != null;

  /// Exactly right — the same set the teacher marked, no more and no less.
  bool get gotItRight {
    final mine = myVotes;
    final right = correct;
    if (mine == null || right == null) return false;
    if (mine.length != right.length) return false;
    final a = [...mine]..sort();
    final b = [...right]..sort();
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool isCorrectOption(int index) => correct?.contains(index) ?? false;
  bool isMyPick(int index) => myVotes?.contains(index) ?? false;

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
      correct: _indexes(map['correct'] ?? map['correctIndex']),
      correctVotes: (map['correctVotes'] as num?)?.toInt(),
      myVotes: _indexes(map['myVote'] ?? map['myVotes']),
    );
  }

  /// Reads a set of option indexes.
  ///
  /// Accepts a bare number as well as a list. Polls were single-answer before
  /// they were multi-answer, and a client that understands only one shape
  /// breaks against whichever server it does not expect — a silent failure
  /// that shows up as a student's vote simply never appearing.
  static List<int>? _indexes(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return [raw.toInt()];
    if (raw is List) {
      final out = raw
          .map((v) => v is num ? v.toInt() : int.tryParse(v.toString()))
          .whereType<int>()
          .toList();
      return out.isEmpty ? null : out;
    }
    return null;
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
  /// never "you voted" — so without this the buttons would stay live until the
  /// poll closed and let the student submit again, which the server refuses.
  Poll withMyVotes(List<int> picks) => _copy(myVotes: picks);

  Poll withTotalVotes(int total) => _copy(totalVotes: total);

  Poll _copy({List<int>? myVotes, int? totalVotes}) {
    return Poll(
      id: id,
      question: question,
      options: options,
      from: from,
      createdAt: createdAt,
      endsAt: endsAt,
      closed: closed,
      totalVotes: totalVotes ?? this.totalVotes,
      counts: counts,
      correct: correct,
      correctVotes: correctVotes,
      myVotes: myVotes ?? this.myVotes,
    );
  }
}
