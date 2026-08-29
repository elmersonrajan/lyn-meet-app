import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/meeting_controller.dart';
import 'whiteboard_view.dart';
import 'zoomable_stage.dart';

/// The main area: whatever the teacher has put in front of the class.
///
/// The teacher chooses, not the student — the server broadcasts stage-mode and
/// this follows it. The one exception is a screen share that has been selected
/// but whose video has not arrived yet, which falls back to the board rather
/// than showing black.
class StageView extends StatelessWidget {
  const StageView({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final mode = meeting.stageMode;
    final showScreen = mode == 'screen' && meeting.media.hasScreen;

    if (mode == 'clip') {
      return Container(
        color: const Color(0xff0d1520),
        child: const _UnsupportedStage(
          icon: Icons.movie_outlined,
          title: 'The teacher is playing a clip',
          detail: 'Video clips play on the web app only',
        ),
      );
    }

    return Container(
      color: const Color(0xff0d1520),
      // Both the board and a shared screen are readable only if a student can
      // magnify them: each is a wide desktop surface scaled down to a few
      // hundred pixels, and anything the teacher wrote small is lost at that
      // size. Zoom resets when the stage changes, since a magnified corner of
      // a whiteboard means nothing once a screen share replaces it.
      child: ZoomableStage(
        resetKey: showScreen ? 'screen' : 'board',
        child: showScreen
            ? RTCVideoView(
                meeting.media.screenRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            : WhiteboardView(controller: meeting.whiteboard),
      ),
    );
  }
}

class _UnsupportedStage extends StatelessWidget {
  const _UnsupportedStage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xff6c7f99)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
