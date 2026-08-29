import 'dart:async';

import 'package:flutter/material.dart';

import '../models/poll.dart';
import '../state/meeting_controller.dart';

/// The current quiz question.
///
/// Three states, driven entirely by the server's view of the poll:
///
///   open      four buttons and a countdown
///   answered  the choice locked in, waiting for everyone else
///   closed    tallies, the right answer, and whether this student got it
///
/// The tallies and the correct answer genuinely are not on the device until
/// the poll closes — the server strips them from the payload — so there is
/// nothing here to peek at early.
class PollCard extends StatefulWidget {
  const PollCard({super.key, required this.meeting, required this.poll});

  final MeetingController meeting;
  final Poll poll;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  Timer? _ticker;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only to redraw the countdown; the server closes the poll on its own.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _vote(int index) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.meeting.vote(widget.poll.id, index);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final canAnswer = poll.isOpen && !_sending;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff17202e),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xff2a3547)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(poll: poll),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < poll.options.length; i++)
            _OptionTile(
              poll: poll,
              index: i,
              enabled: canAnswer,
              onTap: () => _vote(i),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xffff8b8b), fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          _Footer(poll: poll),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.poll});

  final Poll poll;

  @override
  Widget build(BuildContext context) {
    final remaining = poll.remaining;
    final closed = poll.closed || remaining == Duration.zero;
    final seconds = remaining.inSeconds;

    return Row(
      children: [
        const Icon(Icons.quiz_outlined, size: 16, color: Color(0xff9dc2ff)),
        const SizedBox(width: 6),
        Text(
          'Question from ${poll.from}',
          style: const TextStyle(color: Color(0xff9dc2ff), fontSize: 12),
        ),
        const Spacer(),
        if (!closed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: seconds <= 15 ? const Color(0xff4a1f24) : const Color(0xff1f2b3d),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: seconds <= 15 ? const Color(0xffff8b8b) : const Color(0xffb9c6d6),
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          )
        else
          const Text(
            'Closed',
            style: TextStyle(color: Color(0xff8b9cb3), fontSize: 12),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.poll,
    required this.index,
    required this.enabled,
    required this.onTap,
  });

  final Poll poll;
  final int index;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMine = poll.myVote == index;
    final isCorrect = poll.correctIndex == index;
    final revealed = poll.closed && poll.correctIndex != null;

    // Colour only says something once there is something true to say. While
    // the poll is open, a picked option is merely picked — marking it right or
    // wrong before the class has finished answering would give the game away.
    final Color border;
    final Color fill;
    if (revealed && isCorrect) {
      border = const Color(0xff35d07f);
      fill = const Color(0xff16301f);
    } else if (revealed && isMine) {
      border = const Color(0xffff8b8b);
      fill = const Color(0xff30181c);
    } else if (isMine) {
      border = const Color(0xff2f6bd8);
      fill = const Color(0xff16233a);
    } else {
      border = const Color(0xff2a3547);
      fill = const Color(0xff121a26);
    }

    final counts = poll.counts;
    final total = counts == null
        ? 0
        : counts.fold<int>(0, (sum, c) => sum + c);
    final share = counts == null || total == 0 ? 0.0 : counts[index] / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: isMine || (revealed && isCorrect) ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // The result bar, drawn behind the label rather than beside it
                // so a long option is never squeezed by its own tally.
                if (counts != null)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: share,
                      child: Container(color: const Color(0x1affffff)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        String.fromCharCode(65 + index),
                        style: const TextStyle(
                          color: Color(0xff8b9cb3),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          poll.options[index],
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      if (revealed && isCorrect)
                        const Icon(Icons.check_circle, size: 18, color: Color(0xff35d07f)),
                      if (revealed && isMine && !isCorrect)
                        const Icon(Icons.cancel, size: 18, color: Color(0xffff8b8b)),
                      if (counts != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${counts[index]}',
                          style: const TextStyle(color: Color(0xffb9c6d6), fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.poll});

  final Poll poll;

  @override
  Widget build(BuildContext context) {
    if (poll.closed && poll.correctIndex != null) {
      final right = poll.gotItRight;
      return Row(
        children: [
          Icon(
            right ? Icons.emoji_events : Icons.school_outlined,
            size: 16,
            color: right ? const Color(0xff35d07f) : const Color(0xff8b9cb3),
          ),
          const SizedBox(width: 6),
          Text(
            poll.hasVoted
                ? (right ? 'Correct' : 'Not this time')
                : 'You did not answer',
            style: TextStyle(
              color: right ? const Color(0xff35d07f) : const Color(0xff8b9cb3),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (poll.hasVoted) {
      return Row(
        children: [
          const Icon(Icons.check, size: 16, color: Color(0xff35d07f)),
          const SizedBox(width: 6),
          Text(
            'Answer sent · ${poll.totalVotes} in the class have answered',
            style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 12),
          ),
        ],
      );
    }

    return Text(
      '${poll.totalVotes} answered so far',
      style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 12),
    );
  }
}
