/// A written question the teacher has put to the class.
///
/// Mirrors questionPublic() in backend/src/socket/index.js. The asymmetry in
/// this model is the feature: staff see every answer, a student sees only
/// their own and a count of how many people have answered. The server enforces
/// that by sending answers to a separate socket.io room students are not in,
/// so there is nothing to hide on the client — other people's answers never
/// arrive here at all.
class Question {
  final String id;
  final String text;
  final String from;
  final String role;
  final int at;

  /// Closed questions can still be read, but no longer answered.
  final bool closed;

  /// How many people have answered. Not who, and not what.
  final int answerCount;

  /// This student's own answer, if they have given one.
  final Answer? myAnswer;

  const Question({
    required this.id,
    required this.text,
    required this.from,
    required this.role,
    required this.at,
    required this.closed,
    required this.answerCount,
    this.myAnswer,
  });

  bool get answered => myAnswer != null;
  bool get isOpen => !closed;

  DateTime get askedAt => DateTime.fromMillisecondsSinceEpoch(at);

  factory Question.fromMap(Map<String, dynamic> map) {
    final mine = map['myAnswer'];
    return Question(
      id: (map['id'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      from: (map['from'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      at: (map['at'] as num?)?.toInt() ?? 0,
      closed: map['closed'] == true,
      answerCount: (map['answerCount'] as num?)?.toInt() ?? 0,
      myAnswer: mine is Map ? Answer.fromMap(Map<String, dynamic>.from(mine)) : null,
    );
  }

  static List<Question> listFrom(dynamic raw) {
    if (raw is! List) return const <Question>[];
    return raw
        .whereType<Map>()
        .map((m) => Question.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// After sending an answer.
  ///
  /// The server acknowledges with the stored answer but broadcasts only the
  /// new count to the room, so without carrying the answer across locally the
  /// student's own words would vanish from their screen the moment the next
  /// person answered.
  Question withMyAnswer(Answer answer) => _copy(myAnswer: answer);

  Question withAnswerCount(int count) => _copy(answerCount: count);

  Question closedNow() => _copy(closed: true);

  Question _copy({Answer? myAnswer, int? answerCount, bool? closed}) {
    return Question(
      id: id,
      text: text,
      from: from,
      role: role,
      at: at,
      closed: closed ?? this.closed,
      answerCount: answerCount ?? this.answerCount,
      myAnswer: myAnswer ?? this.myAnswer,
    );
  }
}

/// One person's answer. A student only ever holds their own.
class Answer {
  final String id;
  final String questionId;
  final String peerId;
  final String name;
  final String role;
  final String text;
  final int at;

  const Answer({
    required this.id,
    required this.questionId,
    required this.peerId,
    required this.name,
    required this.role,
    required this.text,
    required this.at,
  });

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: (map['id'] ?? '').toString(),
      questionId: (map['questionId'] ?? '').toString(),
      peerId: (map['peerId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      at: (map['at'] as num?)?.toInt() ?? 0,
    );
  }
}
