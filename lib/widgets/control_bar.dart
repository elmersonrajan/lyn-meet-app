import 'package:flutter/material.dart';

import '../state/meeting_controller.dart';

/// Everything a student can do, in one bar.
///
/// Four controls, and that is the whole list. A student cannot draw, post,
/// share, record or mute anyone else — the server refuses all of it — so
/// offering those buttons would only be a way to produce error messages.
class ControlBar extends StatelessWidget {
  const ControlBar({
    super.key,
    required this.meeting,
    required this.onLeave,
    required this.onShowPeople,
  });

  final MeetingController meeting;
  final VoidCallback onLeave;
  final VoidCallback onShowPeople;

  /// Asks which thumb, rather than cycling through them.
  ///
  /// A single button that steps up, down and off is quick to build and awful
  /// to use: a student who is lost has to press twice and may land on "I am
  /// following" on the way. Two clear choices, and pressing the one already
  /// showing takes it back.
  Future<void> _react(BuildContext context, MeetingController meeting) async {
    final current = meeting.myReaction;
    final choice = await showModalBottomSheet<String>(
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
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tell your teacher how it is going',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nobody else is told which you picked — only how many.',
                  style: TextStyle(color: Color(0xff8b9cb3), fontSize: 12),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_up, color: Color(0xff35d07f)),
              title: const Text('I am following',
                  style: TextStyle(color: Colors.white)),
              trailing: current == 'up'
                  ? const Icon(Icons.check, color: Color(0xff35d07f), size: 20)
                  : null,
              onTap: () => Navigator.of(context).pop('up'),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_down, color: Color(0xffff8b8b)),
              title: const Text('I am lost',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'A quiet way to say so without interrupting',
                style: TextStyle(color: Color(0xff7a8ba3), fontSize: 11.5),
              ),
              trailing: current == 'down'
                  ? const Icon(Icons.check, color: Color(0xffff8b8b), size: 20)
                  : null,
              onTap: () => Navigator.of(context).pop('down'),
            ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.close, color: Color(0xff8b9cb3)),
                title: const Text('Take it back',
                    style: TextStyle(color: Color(0xffb9c6d6))),
                onTap: () => Navigator.of(context).pop(current),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await meeting.setReaction(choice);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = meeting.media;
    final micBlocked = meeting.micLocked || !media.micAvailable;
    final hands = meeting.participants.where((p) => p.handRaised).length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        10,
        8,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xff0f1720),
        border: Border(top: BorderSide(color: Color(0xff1e2937))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: media.micOn ? Icons.mic : Icons.mic_off,
            label: micBlocked
                ? 'Locked'
                : media.micOn
                    ? 'Mute'
                    : 'Unmute',
            active: media.micOn,
            disabled: micBlocked,
            onTap: meeting.toggleMic,
          ),
          _ControlButton(
            icon: meeting.handRaised ? Icons.back_hand : Icons.back_hand_outlined,
            label: meeting.handRaised ? 'Lower' : 'Raise hand',
            active: meeting.handRaised,
            activeColor: const Color(0xffffc44d),
            onTap: meeting.toggleHand,
          ),
          // Students only. The server refuses a thumb from staff, so an admin
          // sees the room's tally in the people list instead of a button that
          // would only ever be turned down.
          if (!meeting.isAdmin)
            _ControlButton(
              icon: meeting.myReaction == 'down'
                  ? Icons.thumb_down
                  : meeting.myReaction == 'up'
                      ? Icons.thumb_up
                      : Icons.thumbs_up_down_outlined,
              label: meeting.myReaction == 'down'
                  ? 'Lost'
                  : meeting.myReaction == 'up'
                      ? 'Following'
                      : 'React',
              active: meeting.myReaction != null,
              activeColor: meeting.myReaction == 'down'
                  ? const Color(0xffc0392b)
                  : const Color(0xff35d07f),
              onTap: () => _react(context, meeting),
            ),
          _ControlButton(
            icon: Icons.people_outline,
            label: 'People',
            active: false,
            badge: hands > 0 ? hands : null,
            onTap: onShowPeople,
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            active: false,
            danger: true,
            onTap: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.disabled = false,
    this.danger = false,
    this.badge,
    this.activeColor = const Color(0xff2f6bd8),
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool disabled;
  final bool danger;

  /// A count over the corner, used for raised hands.
  final int? badge;

  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? const Color(0xffc0392b)
        : disabled
            ? const Color(0xff1b2430)
            : active
                ? activeColor
                : const Color(0xff222d3d);

    final foreground = disabled ? const Color(0xff5c6b80) : Colors.white;

    // Four buttons have to fit the narrowest phone in portrait, so the circle
    // shrinks a little on a small screen rather than the row overflowing.
    final wide = MediaQuery.sizeOf(context).width >= 360;
    final diameter = wide ? 52.0 : 46.0;

    return Flexible(
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        color: background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: foreground, size: wide ? 24 : 21),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffffc44d),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xff0f1720), width: 1.5),
                          ),
                          child: Text(
                            '$badge',
                            style: const TextStyle(
                              color: Color(0xff2a1c00),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: disabled ? const Color(0xff5c6b80) : const Color(0xffb9c6d6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
