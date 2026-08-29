import 'package:flutter/material.dart';

import '../state/audio_route.dart';

/// The speaker picker, at the top-left of the class.
///
/// Placed where Zoom puts it and behaving the same way: an icon showing where
/// the sound is going now, and a sheet to send it somewhere else. A student
/// switching to headphones halfway through a lesson should not have to leave
/// the class to do it.
class AudioRouteButton extends StatelessWidget {
  const AudioRouteButton({super.key, required this.controller});

  final AudioRouteController controller;

  IconData _iconFor(AudioRoute route) => switch (route) {
        AudioRoute.speaker => Icons.volume_up,
        AudioRoute.earpiece => Icons.hearing,
        AudioRoute.bluetooth => Icons.bluetooth_audio,
      };

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<AudioRoute>(
      context: context,
      backgroundColor: const Color(0xff141d29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Play the class through',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final route in AudioRoute.values)
              ListTile(
                leading: Icon(
                  _iconFor(route),
                  color: route == controller.route
                      ? const Color(0xff5b9bff)
                      : const Color(0xffb9c6d6),
                ),
                title: Text(
                  route.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: route == controller.route
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  route.detail,
                  style: const TextStyle(color: Color(0xff8b9cb3), fontSize: 12),
                ),
                trailing: route == controller.route
                    ? const Icon(Icons.check, color: Color(0xff5b9bff), size: 20)
                    : null,
                onTap: () => Navigator.of(context).pop(route),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen != null) await controller.select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return IconButton(
          tooltip: 'Audio: ${controller.route.label}',
          onPressed: controller.busy ? null : () => _pick(context),
          icon: Icon(
            _iconFor(controller.route),
            color: controller.route == AudioRoute.speaker
                ? Colors.white
                : const Color(0xff5b9bff),
          ),
        );
      },
    );
  }
}
