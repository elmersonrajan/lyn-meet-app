import 'package:flutter/material.dart';

import '../state/meeting_controller.dart';
import '../theme.dart';

/// Everything a student can do, laid out the way Meet lays it out.
///
/// The shapes are deliberate rather than decorative. A class arriving from
/// Meet already knows that a microphone in a **filled red circle** means they
/// are muted, and that the **red pill** on the end is how you leave. Keeping
/// both means nobody has to be taught the bar.
///
/// Meet's rule, which this follows: a control at rest is a dark circle, and a
/// control in its not-normal state — muted, hand up — is filled. Filled does
/// not mean "on"; it means "this is not how it usually is", which is why an
/// unmuted microphone is the plain one.
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrip(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tell your teacher how it is going',
                  style: TextStyle(
                    color: LynColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nobody else is told which you picked — only how many.',
                  style: TextStyle(color: LynColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_up, color: LynColors.success),
              title: const Text('I am following'),
              trailing: current == 'up'
                  ? const Icon(Icons.check, color: LynColors.success, size: 20)
                  : null,
              onTap: () => Navigator.of(context).pop('up'),
            ),
            ListTile(
              leading: const Icon(Icons.thumb_down, color: LynColors.dangerSoft),
              title: const Text('I am lost'),
              subtitle: const Text(
                'A quiet way to say so without interrupting',
                style: TextStyle(color: LynColors.textMuted, fontSize: 12),
              ),
              trailing: current == 'down'
                  ? const Icon(Icons.check, color: LynColors.dangerSoft, size: 20)
                  : null,
              onTap: () => Navigator.of(context).pop('down'),
            ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.close, color: LynColors.textSecondary),
                title: const Text('Take it back'),
                onTap: () => Navigator.of(context).pop(current),
              ),
            const SizedBox(height: 12),
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
        12,
        8,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      color: LynColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Muted is the filled red state, exactly as in Meet. A student
          // glancing down sees the same thing they saw last term.
          _RoundControl(
            icon: media.micOn ? Icons.mic : Icons.mic_off,
            tooltip: micBlocked
                ? 'Your microphone is locked'
                : media.micOn
                    ? 'Mute'
                    : 'Unmute',
            filled: !media.micOn,
            fillColour: LynColors.danger,
            disabled: micBlocked,
            onTap: meeting.toggleMic,
          ),

          _RoundControl(
            icon: meeting.handRaised ? Icons.back_hand : Icons.back_hand_outlined,
            tooltip: meeting.handRaised ? 'Lower your hand' : 'Raise your hand',
            filled: meeting.handRaised,
            fillColour: LynColors.warning,
            onFill: const Color(0xff202124),
            onTap: meeting.toggleHand,
          ),

          // Students only. The server refuses a thumb from staff, so an admin
          // sees the room's tally in the people list instead of a button that
          // would only ever be turned down.
          if (!meeting.isAdmin)
            _RoundControl(
              icon: meeting.myReaction == 'down'
                  ? Icons.thumb_down
                  : meeting.myReaction == 'up'
                      ? Icons.thumb_up
                      : Icons.add_reaction_outlined,
              tooltip: 'React',
              filled: meeting.myReaction != null,
              fillColour: meeting.myReaction == 'down'
                  ? LynColors.danger
                  : LynColors.success,
              onFill: meeting.myReaction == 'down'
                  ? Colors.white
                  : const Color(0xff202124),
              onTap: () => _react(context, meeting),
            ),

          _RoundControl(
            icon: Icons.people_outline,
            tooltip: 'People',
            badge: hands > 0 ? hands : null,
            onTap: onShowPeople,
          ),

          // The red pill. Meet's leave button is the one control that is not a
          // circle, and that difference is what stops it being pressed by
          // mistake — so it stays a pill here.
          _LeavePill(onTap: onLeave),
        ],
      ),
    );
  }
}

/// One of Meet's circular controls.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
    this.fillColour = LynColors.primarySolid,
    this.onFill = Colors.white,
    this.disabled = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Whether this is in its not-normal state — muted, hand up, reacting.
  final bool filled;
  final Color fillColour;
  final Color onFill;

  final bool disabled;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    // Five controls have to fit the narrowest phone, so the circle gives a
    // little on a small screen rather than the row overflowing.
    final wide = MediaQuery.sizeOf(context).width >= 360;
    final diameter = wide ? 52.0 : 46.0;

    final background = disabled
        ? const Color(0xff2a2b2e)
        : filled
            ? fillColour
            : LynColors.control;
    final foreground = disabled
        ? LynColors.textMuted
        : filled
            ? onFill
            : LynColors.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: tooltip,
        child: InkResponse(
          onTap: disabled ? null : onTap,
          radius: diameter * 0.7,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: wide ? 23 : 20),
              ),
              if (badge != null)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: LynColors.warning,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LynColors.surface, width: 1.5),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Color(0xff202124),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

/// Meet's hang-up: a wide red pill, the only non-circle in the bar.
class _LeavePill extends StatelessWidget {
  const _LeavePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 360;

    return Tooltip(
      message: 'Leave the class',
      child: Semantics(
        button: true,
        label: 'Leave the class',
        child: Material(
          color: LynColors.danger,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              width: wide ? 74 : 64,
              height: wide ? 52 : 46,
              child: Icon(
                Icons.call_end,
                color: Colors.white,
                size: wide ? 24 : 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small handle at the top of a sheet, as Meet draws it.
class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 4,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: LynColors.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
