import 'package:flutter/material.dart';

import '../models/peer.dart';
import '../state/meeting_controller.dart';

/// Who is in the class.
///
/// Ordered the way the room is run, not alphabetically: staff first, then
/// raised hands in the order they went up — that ordering is the whole point
/// of the server sending handRaisedAt — then everyone else.
class ParticipantsList extends StatelessWidget {
  const ParticipantsList({super.key, required this.meeting});

  final MeetingController meeting;

  List<Peer> _ordered() {
    final peers = [...meeting.participants];
    peers.sort((a, b) {
      if (a.isStaff != b.isStaff) return a.isStaff ? -1 : 1;
      if (a.handRaised != b.handRaised) return a.handRaised ? -1 : 1;
      if (a.handRaised && b.handRaised) {
        return (a.handRaisedAt ?? 0).compareTo(b.handRaisedAt ?? 0);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return peers;
  }

  @override
  Widget build(BuildContext context) {
    final peers = _ordered();
    final hands = peers.where((p) => p.handRaised).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'In this class · ${peers.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (hands > 0)
                Text(
                  '$hands hand${hands == 1 ? '' : 's'} up',
                  style: const TextStyle(color: Color(0xffffc44d), fontSize: 12),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: peers.length,
            itemBuilder: (context, index) => _PeerRow(
              peer: peers[index],
              isMe: peers[index].id == meeting.me?.id,
              isSpeaking: meeting.activeSpeakers.contains(peers[index].id),
              meeting: meeting,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.peer,
    required this.isMe,
    required this.isSpeaking,
    required this.meeting,
  });

  final Peer peer;
  final bool isMe;
  final bool isSpeaking;
  final MeetingController meeting;

  /// Staff can act on other people; nobody can act on themselves here, and a
  /// student sees no menu at all because every item would be refused.
  bool get _canAct => meeting.isAdmin && !isMe;

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${peer.name}?'),
        content: const Text(
          'They are disconnected and told they were removed. They can rejoin '
          'unless the class is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xffc0392b)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await meeting.removeParticipant(peer.id);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = peer.isTeacher
        ? 'Teacher'
        : peer.isCoordinator
            ? 'Coordinator'
            : null;

    return ListTile(
      dense: true,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          if (isSpeaking)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xff35d07f), width: 2),
              ),
            ),
          CircleAvatar(
            radius: 16,
            backgroundColor:
                peer.isStaff ? const Color(0xff2f6bd8) : const Color(0xff2b3648),
            child: Text(
              _initials(peer.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? '${peer.name} (you)' : peer.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: peer.disconnected ? const Color(0xff7d8ca1) : Colors.white,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xff1e3a63),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Color(0xff9dc2ff), fontSize: 10),
              ),
            ),
          ],
        ],
      ),
      subtitle: peer.disconnected
          ? const Text(
              'Reconnecting…',
              style: TextStyle(color: Color(0xff7d8ca1), fontSize: 11),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (peer.handRaised)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.back_hand, size: 16, color: Color(0xffffc44d)),
            ),
          Icon(
            peer.audioMuted ? Icons.mic_off : Icons.mic,
            size: 16,
            color: peer.audioMuted
                ? const Color(0xff6b7a8d)
                : (isSpeaking ? const Color(0xff35d07f) : const Color(0xffb9c6d6)),
          ),
          if (_canAct)
            PopupMenuButton<String>(
              tooltip: 'Manage ${peer.name}',
              iconSize: 18,
              icon: const Icon(Icons.more_vert, color: Color(0xff7a8ba3)),
              onSelected: (choice) async {
                if (choice == 'lower') {
                  await meeting.lowerHand(peer.id);
                } else if (choice == 'remove') {
                  await _remove(context);
                }
              },
              itemBuilder: (context) => [
                if (peer.handRaised)
                  const PopupMenuItem(
                    value: 'lower',
                    child: Text('Lower their hand'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from the class'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// One letter from each of the first two words, so a long name still fits a
  /// 32px circle.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
