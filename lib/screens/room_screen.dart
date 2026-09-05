import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../state/meeting_controller.dart';
import '../widgets/admin_compose.dart';
import '../widgets/admin_panel.dart';
import '../widgets/audio_route_button.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/control_bar.dart';
import '../widgets/participants_list.dart';
import '../widgets/poll_card.dart';
import '../widgets/questions_panel.dart';
import '../widgets/stage_view.dart';
import '../widgets/status_banners.dart';
import '../widgets/teacher_inset.dart';
import 'ended_screen.dart';

/// The class.
///
/// Two layouts from one tree. Upright, the stage sits above a panel that
/// slides up over it. Turned sideways — which is how a wide whiteboard is
/// actually readable on a phone — the panel moves alongside instead, so
/// opening it costs width rather than the height the board needs.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  /// Admins get a fourth tab holding the controls that only they can use.
  TabController? _tabs;
  int _tabCount = 0;

  static const _peopleTab = 0;
  static const _qaTab = 1;
  static const _pollTab = 2;
  static const _adminTab = 3;

  /// Rebuilt rather than resized when the role settles: a TabController's
  /// length is fixed at construction, and the role is only known once the
  /// server has answered the join.
  TabController _controllerFor(int count) {
    if (_tabs == null || _tabCount != count) {
      _tabs?.dispose();
      _tabs = TabController(length: count, vsync: this);
      _tabCount = count;
    }
    return _tabs!;
  }

  /// Whether the panel is open. Closed by default so the board gets the whole
  /// screen until the student asks for something else.
  bool _panelOpen = false;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Opens the panel on a given tab, or closes it if it is already showing it.
  void _openPanel(int tab) {
    setState(() {
      final tabs = _tabs;
      if (tabs == null || tab >= tabs.length) return;
      if (_panelOpen && tabs.index == tab) {
        _panelOpen = false;
        return;
      }
      _panelOpen = true;
      tabs.index = tab;
    });
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
    // The role is the server's answer to the join, so the extra tab can only
    // appear once that has come back.
    final tabs = _controllerFor(meeting.isAdmin ? 4 : 3);
    final size = MediaQuery.sizeOf(context);
    final sideBySide = size.width > size.height && size.width >= 600;

    return PopScope(
      // Back must not silently drop a student out of a lesson.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: AudioRouteButton(controller: meeting.audio),
          title: Column(
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
            Center(child: ConnectionIndicator(status: meeting.connection)),
            // A written question is easy to miss behind a closed panel, and it
            // is the one thing in the room that is waiting on this student.
            IconButton(
              tooltip: 'Questions',
              onPressed: () => _openPanel(_qaTab),
              icon: Badge(
                isLabelVisible: meeting.unansweredQuestions > 0,
                label: Text('${meeting.unansweredQuestions}'),
                backgroundColor: const Color(0xffffc44d),
                textColor: const Color(0xff2a1c00),
                child: const Icon(Icons.help_outline),
              ),
            ),
            if (meeting.isAdmin)
              IconButton(
                tooltip: 'Class controls',
                onPressed: () => _openPanel(_adminTab),
                icon: const Icon(Icons.admin_panel_settings_outlined),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: RecordingBadge(recording: meeting.recording)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Above the room's own notices: a connection that has dropped
            // explains every other thing that looks wrong, so it is read first.
            ConnectionBanner(status: meeting.connection),
            StatusBanner(meeting: meeting),
            Expanded(
              child: sideBySide
                  ? Row(
                      children: [
                        Expanded(flex: 3, child: _stage(meeting, poll)),
                        if (_panelOpen)
                          SizedBox(
                            width: (size.width * 0.36).clamp(280.0, 420.0),
                            child: _panel(meeting, poll, tabs),
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(
                          flex: _panelOpen ? 5 : 10,
                          child: _stage(meeting, poll),
                        ),
                        if (_panelOpen)
                          Expanded(flex: 6, child: _panel(meeting, poll, tabs)),
                      ],
                    ),
            ),
            ControlBar(
              meeting: meeting,
              onLeave: _confirmLeave,
              onShowPeople: () => _openPanel(_peopleTab),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stage(MeetingController meeting, Poll? poll) {
    return Stack(
      children: [
        Positioned.fill(child: StageView(meeting: meeting)),
        TeacherInset(meeting: meeting),
        // A live question is put in front of the student, over the lesson. It
        // is timed, and a student reading the board would otherwise miss the
        // window entirely.
        if (poll != null && !poll.closed && !poll.hasVoted)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: PollCard(meeting: meeting, poll: poll),
            ),
          ),
      ],
    );
  }

  Widget _panel(MeetingController meeting, Poll? poll, TabController tabs) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff0b1017),
        border: Border(top: BorderSide(color: Color(0xff1e2937))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: meeting.isAdmin,
                  tabAlignment: meeting.isAdmin ? TabAlignment.start : null,
                  controller: tabs,
                  tabs: [
                    const Tab(text: 'People'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Q&A'),
                          if (meeting.unansweredQuestions > 0) ...[
                            const SizedBox(width: 6),
                            _Dot(count: meeting.unansweredQuestions),
                          ],
                        ],
                      ),
                    ),
                    const Tab(text: 'Poll'),
                    if (meeting.isAdmin) const Tab(text: 'Controls'),
                  ],
                ),
              ),
              // Composing is offered where the thing being composed lives, so
              // the button is only on the tab it belongs to.
              if (meeting.isAdmin)
                AnimatedBuilder(
                  animation: tabs,
                  builder: (context, _) => switch (tabs.index) {
                    _qaTab => IconButton(
                        tooltip: 'Ask the class a question',
                        icon: const Icon(Icons.add_comment_outlined, size: 20),
                        onPressed: () => AskQuestionSheet.show(context, meeting),
                      ),
                    _pollTab => IconButton(
                        tooltip: 'Start a poll',
                        icon: const Icon(Icons.add_chart, size: 20),
                        onPressed: () => CreatePollSheet.show(context, meeting),
                      ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              IconButton(
                tooltip: 'Hide panel',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _panelOpen = false),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                ParticipantsList(meeting: meeting),
                QuestionsPanel(meeting: meeting),
                poll == null
                    ? const _NoPoll()
                    : SingleChildScrollView(
                        child: PollCard(meeting: meeting, poll: poll),
                      ),
                if (meeting.isAdmin) AdminPanel(meeting: meeting),
              ],
            ),
          ),
        ],
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
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
