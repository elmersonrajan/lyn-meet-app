import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/meeting_controller.dart';

/// The class feed, read-only.
///
/// There is no composer, and its absence is the design. The server refuses
/// post-message from a student (requireStaff), so a text field here could only
/// ever produce an error — a student asks a question by raising their hand and
/// speaking, and the teacher's answer comes back tagged "qa".
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    widget.meeting.markChatRead();
    _lastCount = widget.meeting.chat.length;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Follows the feed only when the student is already at the bottom.
  /// Yanking the view down while they are reading back over an earlier
  /// announcement is worse than missing the newest one by a second.
  void _followIfAtBottom() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 80) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.meeting.chat;

    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      widget.meeting.markChatRead();
      _followIfAtBottom();
    }

    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 36, color: Color(0xff5c6b80)),
              SizedBox(height: 12),
              Text(
                'Nothing posted yet',
                style: TextStyle(color: Color(0xff8b9cb3), fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Announcements from your teacher appear here.\nRaise your hand to ask a question.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xff6b7a8d), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isQa = message.isQa;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isQa ? const Color(0xff1b2f22) : const Color(0xff17202e),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isQa ? const Color(0xff35d07f) : const Color(0xff2f6bd8),
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
                  message.from,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff9dc2ff),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isQa) ...[
                const SizedBox(width: 6),
                const Text(
                  'Q&A',
                  style: TextStyle(color: Color(0xff35d07f), fontSize: 10),
                ),
              ],
              const Spacer(),
              Text(
                _time(message.sentAt),
                style: const TextStyle(color: Color(0xff6b7a8d), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            message.text,
            style: const TextStyle(color: Color(0xffe6edf6), fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  String _time(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour < 12 ? 'am' : 'pm'}';
  }
}
