import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/meeting_controller.dart';
import 'board_stage.dart';
import 'clip_stage.dart';
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

    // A clip takes the stage whether or not the mode says so: the teacher
    // starting one is the instruction, and a student staring at a whiteboard
    // while the class watches a video is the worst of both.
    final clip = meeting.clip;
    if (clip != null || mode == 'clip') {
      return Container(
        color: const Color(0xff0d1520),
        child: ClipStage(meeting: meeting),
      );
    }

    return Container(
      color: const Color(0xff0d1520),
      // Both the board and a shared screen are readable only if a student can
      // magnify them: each is a wide desktop surface scaled down to a few
      // hundred pixels, and anything the teacher wrote small is lost at that
      // size. Zoom resets when the stage changes, since a magnified corner of
      // a whiteboard means nothing once a screen share replaces it.
      child: Stack(
        children: [
          Positioned.fill(
            child: ZoomableStage(
              // Reset when the class is moved somewhere else, including to
              // another board: a magnified corner of page one means nothing
              // once the teacher has turned to page two.
              resetKey: showScreen ? 'screen' : 'board:${meeting.activeBoardId}',
              child: showScreen
                  ? RTCVideoView(
                      meeting.media.screenRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    )
                  : BoardStage(meeting: meeting),
            ),
          ),
          if (!showScreen)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: BoardTabsStrip(meeting: meeting),
            ),
        ],
      ),
    );
  }
}
