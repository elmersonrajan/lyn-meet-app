import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../services/meeting_link.dart';
import '../state/auth_controller.dart';
import '../state/meeting_controller.dart';
import 'room_screen.dart';

/// Which class to join.
///
/// One field. There is no name box any more and no role picker: the server
/// takes both from the signed-in account, discards a role sent by a client,
/// and can lower it further for the particular class — a teacher standing in
/// someone else's lesson joins as a student. So the app states who you are
/// rather than asking, and finds out what you are once you are in.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialMeetingId, required this.user});

  /// A meeting ID picked out of the link that opened the app.
  final String? initialMeetingId;

  final AuthUser user;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _meetingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _meetingController.text = normalizeMeetingId(widget.initialMeetingId);
  }

  @override
  void didUpdateWidget(JoinScreen old) {
    super.didUpdateWidget(old);
    // A link arriving while the app is already open — someone tapped the
    // class link without closing the app first.
    final incoming = normalizeMeetingId(widget.initialMeetingId);
    if (incoming.isNotEmpty && incoming != _meetingController.text) {
      _meetingController.text = incoming;
    }
  }

  @override
  void dispose() {
    _meetingController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final meeting = context.read<MeetingController>();
    await meeting.join(
      meetingId: _meetingController.text,
      signedInAs: widget.user.name,
    );

    if (!mounted) return;
    if (meeting.isLive) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoomScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meeting = context.watch<MeetingController>();
    final joining = meeting.phase == MeetingPhase.joining;
    final user = widget.user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 28),
                    _SignedInAs(user: user),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _meetingController,
                      enabled: !joining,
                      textInputAction: TextInputAction.go,
                      onFieldSubmitted: (_) => joining ? null : _join(),
                      // Upper-cased as it is typed. Classes are numeric now,
                      // but ad-hoc rooms are still allowed in testing and the
                      // server keys those by this exact string — lower case
                      // used to open a second, empty room of the same name.
                      inputFormatters: [UpperCaseFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Class ID',
                        hintText: 'From your timetable, or the class link',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter the class ID'
                          : null,
                    ),
                    if (meeting.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff3a1a1e),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xffff8b8b)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                meeting.error!,
                                style: const TextStyle(
                                  color: Color(0xffffb3b3),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: joining ? null : _join,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: joining
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Join the class'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user.isAdmin
                          ? 'You join muted. Your admin controls are in the class.'
                          : 'You join muted. Raise your hand when you want to speak.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff7a8ba3), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who the server says you are, and therefore what this app will let you do.
///
/// Worth stating plainly. On a shared phone the account signed in is often not
/// the person holding it, and the difference decides whether they can mute the
/// room or remove somebody from it.
class _SignedInAs extends StatelessWidget {
  const _SignedInAs({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final admin = user.isAdmin;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xff141d29),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: admin ? const Color(0xff2f6bd8) : const Color(0xff243043),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                admin ? const Color(0xff2f6bd8) : const Color(0xff2b3648),
            child: Text(
              _initials(user.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xff7a8ba3), fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: admin ? const Color(0xff1e3a63) : const Color(0xff222d3d),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.modeLabel,
              style: TextStyle(
                color: admin ? const Color(0xff9dc2ff) : const Color(0xffb9c6d6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            iconSize: 18,
            onPressed: () => context.read<AuthController>().signOut(),
            icon: const Icon(Icons.logout, color: Color(0xff7a8ba3)),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// Upper-cases the class ID as it is typed, keeping the cursor where it was.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.24).clamp(72.0, 120.0);

    return Column(
      children: [
        SizedBox(
          height: size,
          child: Image.asset(
            'assets/lyn-logo-cross.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Icon(
              Icons.cast_for_education,
              size: size * 0.6,
              color: const Color(0xff2f6bd8),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'LYN MEET',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
