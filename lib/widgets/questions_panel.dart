import 'package:flutter/material.dart';

import '../models/question.dart';
import '../state/meeting_controller.dart';

/// Written questions from the teacher, and this student's answers.
///
/// A student sees their own answer and a count of how many people have
/// answered — never anyone else's words. That is not a decision made here:
/// the server sends answers only to a socket.io room students are not in, so
/// other people's answers never reach this device.
class QuestionsPanel extends StatelessWidget {
  const QuestionsPanel({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final questions = meeting.questions;

    if (questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, size: 36, color: Color(0xff5c6b80)),
              SizedBox(height: 12),
              Text(
                'No questions yet',
                style: TextStyle(color: Color(0xff8b9cb3), fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'When your teacher asks one, you can type your answer here.\n'
                'Only your teacher sees what you write.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff6b7a8d), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Newest first: the one still open is the one that needs an answer.
    final ordered = questions.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: ordered.length,
      itemBuilder: (context, index) => QuestionCard(
        key: ValueKey(ordered[index].id),
        meeting: meeting,
        question: ordered[index],
      ),
    );
  }
}

/// One question, with the answer box when it is still open.
class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.meeting,
    required this.question,
  });

  final MeetingController meeting;
  final Question question;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.question.myAnswer?.text ?? '');

  bool _sending = false;
  bool _editing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.meeting
        .answerQuestion(widget.question.id, _controller.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      if (error == null) _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final answered = question.answered;
    final showBox = question.isOpen && (!answered || _editing);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff17202e),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: question.closed
                ? const Color(0xff3d4a5c)
                : answered
                    ? const Color(0xff35d07f)
                    : const Color(0xffffc44d),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  question.from,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff9dc2ff),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (question.closed)
                const Text(
                  'Closed',
                  style: TextStyle(color: Color(0xff8b9cb3), fontSize: 11),
                )
              else
                Text(
                  '${question.answerCount} answered',
                  style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            question.text,
            style: const TextStyle(
              color: Color(0xffe6edf6),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          if (showBox) ...[
            TextField(
              controller: _controller,
              enabled: !_sending,
              maxLines: 4,
              minLines: 2,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type your answer',
                counterText: '',
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (answered)
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => setState(() {
                              _editing = false;
                              _controller.text = question.myAnswer?.text ?? '';
                            }),
                    child: const Text('Cancel'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(answered ? 'Update answer' : 'Send answer'),
                ),
              ],
            ),
          ] else if (answered) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff16301f),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Color(0xff35d07f)),
                      SizedBox(width: 6),
                      Text(
                        'Your answer',
                        style: TextStyle(
                          color: Color(0xff35d07f),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    question.myAnswer!.text,
                    style: const TextStyle(color: Color(0xffe6edf6), fontSize: 14),
                  ),
                ],
              ),
            ),
            if (question.isOpen) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Change my answer'),
                ),
              ),
            ],
          ] else
            const Text(
              'You did not answer this one.',
              style: TextStyle(color: Color(0xff8b9cb3), fontSize: 12.5),
            ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xffff8b8b), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
