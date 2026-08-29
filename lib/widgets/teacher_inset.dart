import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/meeting_controller.dart';

/// The teacher's camera, small, over the corner of the stage.
///
/// Same placement as the recording's inset and the web client's tile, so a
/// student watching live and a student watching the recording afterwards see
/// the class laid out the same way.
///
/// Tapping it hides it: on a small screen the inset can sit on top of the very
/// corner of the board the teacher is writing in.
class TeacherInset extends StatefulWidget {
  const TeacherInset({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  State<TeacherInset> createState() => _TeacherInsetState();
}

class _TeacherInsetState extends State<TeacherInset> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    if (!meeting.media.hasCamera) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final insetWidth = (width * 0.3).clamp(96.0, 168.0);

    if (_hidden) {
      return Positioned(
        right: 12,
        bottom: 12,
        child: _RoundButton(
          icon: Icons.videocam_outlined,
          tooltip: 'Show the teacher',
          onTap: () => setState(() => _hidden = false),
        ),
      );
    }

    return Positioned(
      right: 12,
      bottom: 12,
      child: GestureDetector(
        onTap: () => setState(() => _hidden = true),
        child: Container(
          width: insetWidth,
          height: insetWidth * 9 / 16,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x33ffffff)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(
                meeting.media.cameraRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              if (meeting.teacherAway)
                Container(
                  color: const Color(0xaa000000),
                  alignment: Alignment.center,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      'Reconnecting…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xcc1a2433),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
