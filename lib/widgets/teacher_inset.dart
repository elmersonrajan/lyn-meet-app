import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/meeting_controller.dart';

/// How much of the stage the teacher's tile takes.
enum InsetSize { small, large, hidden }

/// The teacher's camera, over the corner of the stage.
///
/// Tapping cycles small → large → hidden → small. A fixed size cannot be right
/// for everyone: the tile is a face to read expressions off when the teacher is
/// talking, and an obstruction when they are writing underneath it.
class TeacherInset extends StatefulWidget {
  const TeacherInset({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  State<TeacherInset> createState() => _TeacherInsetState();
}

class _TeacherInsetState extends State<TeacherInset> {
  InsetSize _size = InsetSize.small;

  void _cycle() {
    setState(() {
      _size = switch (_size) {
        InsetSize.small => InsetSize.large,
        InsetSize.large => InsetSize.hidden,
        InsetSize.hidden => InsetSize.small,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    if (!meeting.media.hasCamera) return const SizedBox.shrink();

    if (_size == InsetSize.hidden) {
      return Positioned(
        right: 12,
        bottom: 12,
        child: _RoundButton(
          icon: Icons.videocam_outlined,
          tooltip: 'Show the teacher',
          onTap: _cycle,
        ),
      );
    }

    // Sized against the shorter edge so the tile stays sensible in landscape,
    // where a fraction of the width would be enormous.
    final screen = MediaQuery.sizeOf(context);
    final short = screen.shortestSide;
    final fraction = _size == InsetSize.large ? 0.62 : 0.40;
    final insetWidth = (short * fraction).clamp(140.0, 340.0);

    return Positioned(
      right: 12,
      bottom: 12,
      child: GestureDetector(
        onTap: _cycle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
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
              // A quiet hint that the tile responds to a tap, which is not
              // otherwise discoverable.
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  _size == InsetSize.large
                      ? Icons.close_fullscreen
                      : Icons.open_in_full,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.65),
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
