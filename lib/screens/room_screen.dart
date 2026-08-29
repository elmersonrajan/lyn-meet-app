import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/meeting_controller.dart';
import '../widgets/chat_panel.dart';
import '../widgets/control_bar.dart';
import '../widgets/participants_list.dart';
import '../widgets/poll_card.dart';
import '../widgets/stage_view.dart';
import '../widgets/status_banners.dart';
import '../widgets/teacher_inset.dart';
import 'ended_screen.dart';

/// The class.
///
/// Stage on top, a drawer of tabs below. The split is fixed rather than
/// resizable: on a phone the lesson is the point, and a student fiddling with
/// panel sizes is a student not watching the board.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  /// Whether the lower panel is open. Closed by default so the board gets the
  /// whole screen until the student asks for something else.
  bool _panelOpen = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the class?'),
        content: const Text('You can rejoin with the same meeting ID.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;
    await context.read<MeetingController>().leave();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = context.watch<MeetingController>();

    // Kicked, or the teacher closed the session. Handled here rather than in
    // the controller so the navigation happens with a live BuildContext.
    if (meeting.phase == MeetingPhase.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EndedScreen()),
        );
      });
    }

    final poll = meeting.currentPoll;

    return PopScope(
      // Back must not silently drop a student out of a lesson.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                meeting.meetingId,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '${meeting.participants.length} in the class',
                style: const TextStyle(fontSize: 11.5, color: Color(0xff8b9cb3)),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: RecordingBadge(recording: meeting.recording)),
            ),
          ],
        ),
        body: Column(
          children: [
            StatusBanner(meeting: meeting),
            Expanded(
              flex: _panelOpen ? 5 : 10,
              child: Stack(
                children: [
                  Positioned.fill(child: StageView(meeting: meeting)),
                  TeacherInset(meeting: meeting),
                  // A live question is put in front of the student, over the
                  // lesson. It is timed, and a student reading the board would
                  // otherwise miss the window entirely.
                  if (poll != null && !poll.closed && !poll.hasVoted)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: PollCard(meeting: meeting, poll: poll),
                    ),
                ],
              ),
            ),
            _PanelHandle(
              open: _panelOpen,
              unread: meeting.unreadChat,
              onTap: () => setState(() => _panelOpen = !_panelOpen),
            ),
            if (_panelOpen)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabs,
                      tabs: [
                        const Tab(text: 'People'),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Feed'),
                              if (meeting.unreadChat > 0) ...[
                                const SizedBox(width: 6),
                                _Dot(count: meeting.unreadChat),
                              ],
                            ],
                          ),
                        ),
                        const Tab(text: 'Question'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          ParticipantsList(meeting: meeting),
                          ChatPanel(meeting: meeting),
                          poll == null
                              ? const _NoPoll()
                              : SingleChildScrollView(
                                  child: PollCard(meeting: meeting, poll: poll),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ControlBar(meeting: meeting, onLeave: _confirmLeave),
          ],
        ),
      ),
    );
  }
}

class _PanelHandle extends StatelessWidget {
  const _PanelHandle({
    required this.open,
    required this.unread,
    required this.onTap,
  });

  final bool open;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        color: const Color(0xff141d29),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 18,
              color: const Color(0xff8b9cb3),
            ),
            const SizedBox(width: 6),
            Text(
              open ? 'Hide panel' : 'People, feed and questions',
              style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 12.5),
            ),
            if (!open && unread > 0) ...[
              const SizedBox(width: 8),
              _Dot(count: unread),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xff2f6bd8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _NoPoll extends StatelessWidget {
  const _NoPoll();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 36, color: Color(0xff5c6b80)),
            SizedBox(height: 12),
            Text(
              'No question right now',
              style: TextStyle(color: Color(0xff8b9cb3), fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'When your teacher asks one it appears here, and over the board.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6b7a8d), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
