import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/meeting_controller.dart';

/// What a student sees while the class is watching a clip.
///
/// The app does not play the video itself, and says so rather than showing a
/// blank stage and letting the student wonder whether the lesson has frozen.
/// It shows the title, keeps the class's own position running, and offers to
/// open it at that exact second — so somebody on a phone can follow along
/// rather than being shut out of that part of the lesson.
///
/// Playing it in-app would mean an embedded web view and YouTube's player,
/// which is a real piece of work and worth doing properly rather than badly.
class ClipStage extends StatefulWidget {
  const ClipStage({super.key, required this.meeting});

  final MeetingController meeting;

  @override
  State<ClipStage> createState() => _ClipStageState();
}

class _ClipStageState extends State<ClipStage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Only to keep the elapsed time honest; the position itself comes from the
    // server, which is what keeps the whole class on the same second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _clock(double seconds) {
    final total = seconds.round();
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.meeting.clip;
    if (clip == null) {
      return const Center(
        child: Text(
          'The clip has finished',
          style: TextStyle(color: Color(0xff8b9cb3), fontSize: 14),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: Color(0xff2a1216),
                shape: BoxShape.circle,
              ),
              child: Icon(
                clip.paused ? Icons.pause : Icons.play_arrow,
                size: 34,
                color: const Color(0xffff6b6b),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your class is watching a clip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (clip.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                clip.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff9dc2ff),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff1b2430),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                clip.paused
                    ? 'Paused at ${_clock(clip.positionNow())}'
                    : 'At ${_clock(clip.positionNow())}',
                style: const TextStyle(color: Color(0xffb9c6d6), fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => launchUrl(
                clip.watchUri,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Text('Watch from where the class is'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Opens the video at the same moment your class is at. '
              'Come back here when it finishes — the lesson carries on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff6b7a8d), fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
