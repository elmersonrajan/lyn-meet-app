import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../state/meeting_controller.dart';
import '../theme.dart';

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
            // Meet's tile radius. Large corners are the cue that reads as
            // "a video tile" rather than "a box with video in it".
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          // hardEdge, not antiAlias, and the difference is not cosmetic.
          //
          // RTCVideoView renders through a platform texture. Anti-aliasing a
          // clip makes Flutter allocate a saveLayer to do it, and compositing
          // a texture into a saveLayer is a known way to get a black rectangle
          // on Android — Samsung devices especially. hardEdge clips to the
          // same rounded rect without the layer, so the texture composites
          // straight to the screen.
          //
          // The corners are a fraction less smooth at the pixel level. That is
          // not a trade worth arguing about against video that does not appear.
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The video comes off screen when the camera is off rather than
              // being left on its final frame. Turning a camera off pauses the
              // producer instead of closing it, so frames just stop arriving
              // and the renderer keeps what it last had — a still of the
              // teacher, indistinguishable from a hung app.
              if (meeting.cameraOff)
                _CameraOff(name: meeting.cameraPeerName)
              // Attached, resumed, and still nothing on screen. Saying so is
              // the difference between a bug somebody can report and a black
              // rectangle they assume is the lesson.
              else if (meeting.media.cameraStalled)
                const _VideoStalled()
              else
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
                right: 6,
                top: 6,
                child: Icon(
                  _size == InsetSize.large
                      ? Icons.close_fullscreen
                      : Icons.open_in_full,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),

              // The name chip in the corner, as Meet labels every tile. On a
              // stage holding one face it is less about telling people apart
              // than about confirming the right person is on screen.
              if (meeting.cameraPeerName != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  right: 6,
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (meeting.participants.any((p) =>
                                  p.id == meeting.media.cameraPeerId &&
                                  p.audioMuted)) ...[
                                const Icon(Icons.mic_off,
                                    size: 11, color: LynColors.dangerSoft),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  meeting.cameraPeerName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stands in for the video while a camera is switched off.
///
/// Says so in words. A dark tile on its own reads as a failure, and the
/// difference between "the teacher turned their camera off" and "the app has
/// broken" is the whole point of drawing anything here.
class _CameraOff extends StatelessWidget {
  const _CameraOff({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff16202c),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, size: 20, color: Color(0xff6c7f99)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              name == null ? 'Camera off' : '$name — camera off',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xff9aa0a6), fontSize: 11),
            ),
          ),
        ],
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


/// Shown when a video track is attached but no frames are reaching the screen.
class _VideoStalled extends StatelessWidget {
  const _VideoStalled();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff2d2e31),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                size: 18, color: LynColors.textSecondary),
            SizedBox(height: 6),
            Text(
              'Video is not coming through',
              textAlign: TextAlign.center,
              style: TextStyle(color: LynColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
