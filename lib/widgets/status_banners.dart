import 'package:flutter/material.dart';

import '../models/recording_state.dart';
import '../state/meeting_controller.dart';

/// The red dot that says this class is being recorded.
///
/// Deliberately not dismissible. A student is entitled to know their voice is
/// being written to a file on a server, for as long as that is true.
class RecordingBadge extends StatelessWidget {
  const RecordingBadge({super.key, required this.recording});

  final RecordingState recording;

  @override
  Widget build(BuildContext context) {
    if (!recording.active) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xcc7a1f1f),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(),
          const SizedBox(width: 7),
          Text(
            _label(recording.elapsed),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _label(Duration? elapsed) {
    if (elapsed == null) return 'REC';
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? 'REC $h:$m:$s' : 'REC $m:$s';
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xffff5a5a),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// The strip under the app bar that explains anything currently off-normal:
/// the teacher dropping out, the microphone being locked, a recording being
/// built after class.
///
/// One banner at a time, most urgent first, because a stack of them on a phone
/// eats the lesson.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  Widget build(BuildContext context) {
    final media = meeting.media;

    if (meeting.teacherAway) {
      return const _Banner(
        icon: Icons.wifi_off,
        text: 'Your teacher lost connection. The class continues.',
        color: Color(0xff5a4218),
        textColor: Color(0xffffd48a),
      );
    }

    if (media.micError != null) {
      return _Banner(
        icon: Icons.mic_off,
        text: media.micError!,
        color: const Color(0xff4a1f24),
        textColor: const Color(0xffffb3b3),
      );
    }

    if (media.micLocked && media.micNotice != null) {
      return _Banner(
        icon: Icons.lock_outline,
        text: media.micNotice!,
        color: const Color(0xff20293a),
        textColor: const Color(0xffb9c6d6),
      );
    }

    if (media.micNotice != null) {
      return _Banner(
        icon: Icons.info_outline,
        text: media.micNotice!,
        color: const Color(0xff20293a),
        textColor: const Color(0xffb9c6d6),
      );
    }

    if (meeting.recording.isRendering) {
      return const _Banner(
        icon: Icons.hourglass_bottom,
        text: 'The recording of this class is still being prepared.',
        color: Color(0xff20293a),
        textColor: Color(0xffb9c6d6),
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
