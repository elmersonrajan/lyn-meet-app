import 'package:flutter/material.dart';

import '../state/meeting_controller.dart';

/// What an administrator can do to a running class.
///
/// Only shown to an account the server will actually accept these from. Every
/// one is refused for a student, so offering them and letting the refusal come
/// back would be a control that exists only to produce errors.
///
/// Two things are absent on purpose. The whiteboard is teacher-only on the
/// server, and so is recording — a coordinator supervises a class, they do not
/// run it.
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.meeting});

  final MeetingController meeting;

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? done),
        backgroundColor:
            error == null ? const Color(0xff1b3a2a) : const Color(0xff4a1f24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hands = meeting.participants.where((p) => p.handRaised).length;
    final board = meeting.stageMode != 'screen';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        const _SectionLabel('The room'),
        _ActionTile(
          icon: Icons.mic_off,
          title: 'Mute everyone',
          detail: 'Students can unmute themselves again afterwards',
          onTap: () => _run(context, meeting.muteEveryone, 'Everyone muted'),
        ),
        _ActionTile(
          icon: Icons.back_hand_outlined,
          title: 'Lower all hands',
          detail: hands == 0 ? 'No hands are up' : '$hands up now',
          enabled: hands > 0,
          onTap: () => _run(context, meeting.lowerAllHands, 'Hands lowered'),
        ),

        const SizedBox(height: 8),
        const _SectionLabel('What the class is looking at'),
        Row(
          children: [
            Expanded(
              child: _StageChoice(
                icon: Icons.edit_outlined,
                label: 'Whiteboard',
                selected: board,
                onTap: () => _run(
                  context,
                  () => meeting.setStage('whiteboard'),
                  'Showing the whiteboard',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StageChoice(
                icon: Icons.screen_share_outlined,
                label: 'Shared screen',
                selected: !board,
                onTap: () => _run(
                  context,
                  () => meeting.setStage('screen'),
                  'Showing the shared screen',
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Sharing a screen itself is done from the web app. This chooses '
            'which of the two the class sees.',
            style: TextStyle(color: Color(0xff6b7a8d), fontSize: 11.5, height: 1.4),
          ),
        ),

        const SizedBox(height: 16),
        const _SectionLabel('Ending'),
        _ActionTile(
          icon: Icons.logout,
          title: 'End the class for everyone',
          detail: 'Closes the room and disconnects the whole class',
          danger: true,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('End the class?'),
                content: Text(
                  'Everyone in ${meeting.meetingId} is disconnected and the '
                  'room closes. Any recording still being prepared carries on.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffc0392b),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('End the class'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await _run(context, meeting.closeSession, 'Class ended');
          },
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xff6b7a8d),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = !enabled
        ? const Color(0xff5c6b80)
        : danger
            ? const Color(0xffff8b8b)
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xff17202e),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colour),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colour,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Color(0xff7a8ba3),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
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

class _StageChoice extends StatelessWidget {
  const _StageChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xff1e3a63) : const Color(0xff17202e),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xff2f6bd8) : const Color(0xff2a3547),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xff9dc2ff) : const Color(0xff8b9cb3),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xff8b9cb3),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
