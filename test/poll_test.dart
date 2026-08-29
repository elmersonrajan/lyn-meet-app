import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/poll.dart';

/// Poll payloads changed shape once already — a single `correctIndex` and a
/// single `myVote` became sets. A client that reads only one shape fails
/// silently: the vote goes through and simply never appears. These cases pin
/// both shapes down.
void main() {
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'id': 'p1',
        'question': 'Which of these are primes?',
        'options': ['2', '4', '7', '9'],
        'from': 'Teacher',
        'createdAt': 0,
        'endsAt': DateTime.now().millisecondsSinceEpoch + 60000,
        'closed': false,
        'totalVotes': 3,
        ...extra,
      };

  group('reading a vote', () {
    test('reads a set of picks', () {
      final poll = Poll.fromMap(base({'myVote': [0, 2]}));
      expect(poll.myVotes, [0, 2]);
      expect(poll.hasVoted, isTrue);
      expect(poll.isMyPick(0), isTrue);
      expect(poll.isMyPick(1), isFalse);
    });

    test('still reads the older single-answer shape', () {
      final poll = Poll.fromMap(base({'myVote': 2}));
      expect(poll.myVotes, [2]);
      expect(poll.hasVoted, isTrue);
    });

    test('no vote is not an empty vote', () {
      final poll = Poll.fromMap(base({}));
      expect(poll.myVotes, isNull);
      expect(poll.hasVoted, isFalse);
      expect(poll.isOpen, isTrue);
    });
  });

  group('the answer, once revealed', () {
    test('stays hidden while the poll runs', () {
      final poll = Poll.fromMap(base({'myVote': [0]}));
      expect(poll.correct, isNull);
      expect(poll.revealed, isFalse);
      expect(poll.gotItRight, isFalse);
    });

    test('marks an exactly-right answer correct', () {
      final poll = Poll.fromMap(base({
        'closed': true,
        'correct': [0, 2],
        'myVote': [2, 0], // tap order does not matter
        'counts': [3, 1, 3, 0],
        'correctVotes': 2,
      }));
      expect(poll.revealed, isTrue);
      expect(poll.gotItRight, isTrue);
      expect(poll.correctVotes, 2);
    });

    test('gives no credit for a partial answer', () {
      // Picking one of two right answers is not a right answer — the server
      // scores the whole set, and the app must not disagree with it.
      final poll = Poll.fromMap(base({
        'closed': true,
        'correct': [0, 2],
        'myVote': [0],
      }));
      expect(poll.gotItRight, isFalse);
    });

    test('gives no credit for a right answer plus a wrong one', () {
      final poll = Poll.fromMap(base({
        'closed': true,
        'correct': [0, 2],
        'myVote': [0, 2, 3],
      }));
      expect(poll.gotItRight, isFalse);
    });

    test('reads the older singular correctIndex', () {
      final poll = Poll.fromMap(base({
        'closed': true,
        'correctIndex': 2,
        'myVote': 2,
      }));
      expect(poll.correct, [2]);
      expect(poll.gotItRight, isTrue);
    });
  });

  group('whether it is still answerable', () {
    test('a poll already voted in is not open', () {
      expect(Poll.fromMap(base({'myVote': [1]})).isOpen, isFalse);
    });

    test('a poll past its deadline is not open, flag or no flag', () {
      final expired = Poll.fromMap(base({
        'endsAt': DateTime.now().millisecondsSinceEpoch - 1000,
      }));
      expect(expired.isOpen, isFalse);
      expect(expired.remaining, Duration.zero);
    });
  });
}
