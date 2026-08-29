import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/meeting_controller.dart';
import 'join_screen.dart';

/// What the student sees when the class is over.
///
/// The four ways out are not the same event and should not read the same way.
/// Being removed by a teacher is a decision about this student; the session
/// closing is the end of the lesson for everyone; a dropped connection is
/// nobody's decision at all and is the one worth offering a retry for.
class EndedScreen extends StatelessWidget {
  const EndedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meeting = context.watch<MeetingController>();
    final detail = _detailFor(meeting);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: detail.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(detail.icon, size: 34, color: detail.iconColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    detail.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    detail.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff8b9cb3),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        meeting.reset();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const JoinScreen()),
                          (route) => false,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Back to join'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _EndDetail _detailFor(MeetingController meeting) {
    switch (meeting.endReason) {
      case EndReason.kicked:
        return _EndDetail(
          icon: Icons.person_remove_outlined,
          tint: const Color(0xff3a1a1e),
          iconColor: const Color(0xffff8b8b),
          title: 'You were removed from the class',
          message: meeting.error ?? 'Your teacher removed you from this meeting.',
        );
      case EndReason.sessionClosed:
        return _EndDetail(
          icon: Icons.check_circle_outline,
          tint: const Color(0xff16301f),
          iconColor: const Color(0xff35d07f),
          title: 'Class finished',
          message: meeting.error ?? 'Your teacher ended the session.',
        );
      case EndReason.connectionLost:
        return _EndDetail(
          icon: Icons.wifi_off,
          tint: const Color(0xff5a4218),
          iconColor: const Color(0xffffd48a),
          title: 'Connection lost',
          message:
              'The app could not reach the class. Check your internet and join again — '
              'if the lesson is still running, you will go straight back in.',
        );
      case EndReason.error:
        return _EndDetail(
          icon: Icons.error_outline,
          tint: const Color(0xff3a1a1e),
          iconColor: const Color(0xffff8b8b),
          title: 'Something went wrong',
          message: meeting.error ?? 'The class ended unexpectedly.',
        );
      case EndReason.left:
        return const _EndDetail(
          icon: Icons.waving_hand_outlined,
          tint: Color(0xff1b2b45),
          iconColor: Color(0xff9dc2ff),
          title: 'You left the class',
          message: 'You can rejoin any time with the same meeting ID.',
        );
    }
  }
}

class _EndDetail {
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String message;

  const _EndDetail({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.message,
  });
}
