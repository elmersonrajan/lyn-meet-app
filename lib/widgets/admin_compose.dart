import 'package:flutter/material.dart';

import '../state/meeting_controller.dart';

/// Puts a written question to the class.
///
/// Answers come back to staff only — the server sends them to a room students
/// are not in — so this is the way to ask something without the first answer
/// giving it away to everybody else.
class AskQuestionSheet extends StatefulWidget {
  const AskQuestionSheet({super.key, required this.meeting});

  final MeetingController meeting;

  static Future<void> show(BuildContext context, MeetingController meeting) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff141d29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AskQuestionSheet(meeting: meeting),
    );
  }

  @override
  State<AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<AskQuestionSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
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
    final error = await widget.meeting.askQuestion(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask the class a question',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Everyone sees the question. Only you see the answers.',
            style: TextStyle(color: Color(0xff8b9cb3), fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. In one line, what does photosynthesis produce?',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xffff8b8b), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ask the class'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sets a multiple-choice poll.
///
/// Four options, and any number of them can be right. How many are correct is
/// never sent to students while the poll runs, so marking two here does not
/// quietly tell the class to pick two — which is exactly why the server
/// withholds it.
class CreatePollSheet extends StatefulWidget {
  const CreatePollSheet({super.key, required this.meeting});

  final MeetingController meeting;

  static Future<void> show(BuildContext context, MeetingController meeting) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff141d29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreatePollSheet(meeting: meeting),
    );
  }

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _question = TextEditingController();
  final _options = List.generate(4, (_) => TextEditingController());
  final Set<int> _correct = {};

  /// The server clamps this to between 15 seconds and 10 minutes.
  Duration _duration = const Duration(minutes: 2);

  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.meeting.createPoll(
      question: _question.text,
      options: _options.map((c) => c.text).toList(),
      correct: _correct.toList(),
      duration: _duration,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New poll',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tick every correct answer. Students are not told how many.',
              style: TextStyle(color: Color(0xff8b9cb3), fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Question',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    // A tick box, not a radio, because more than one can be
                    // right and the control has to say so.
                    Checkbox(
                      value: _correct.contains(i),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _correct.add(i);
                        } else {
                          _correct.remove(i);
                        }
                      }),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _options[i],
                        maxLength: 200,
                        decoration: InputDecoration(
                          labelText: 'Option ${String.fromCharCode(65 + i)}',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Time to answer',
                  style: TextStyle(color: Color(0xff8b9cb3), fontSize: 13),
                ),
                const Spacer(),
                for (final minutes in const [1, 2, 5])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text('$minutes min'),
                      selected: _duration.inMinutes == minutes,
                      onSelected: (_) => setState(
                        () => _duration = Duration(minutes: minutes),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xffff8b8b), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start the poll'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
