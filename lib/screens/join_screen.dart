import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/meeting_link.dart';
import '../state/meeting_controller.dart';
import 'room_screen.dart';

/// The way in: a name and a class code.
///
/// There is no role picker. This build is a student app, the role is baked
/// into the join call, and offering a choice the server would refuse to
/// honour would be a lie about what the app can do.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialMeetingId});

  /// A meeting ID picked out of the link that opened the app.
  final String? initialMeetingId;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _nameController = TextEditingController();
  final _meetingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _nameKey = 'lynmeet.student.name';

  @override
  void initState() {
    super.initState();
    _meetingController.text = normalizeMeetingId(widget.initialMeetingId);
    _restoreName();
  }

  /// A student rejoins the same class from the same phone all term. Making
  /// them retype their name every time is how you end up with an attendance
  /// register full of "asdf".
  Future<void> _restoreName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_nameKey);
      if (saved != null && saved.isNotEmpty && mounted && _nameController.text.isEmpty) {
        _nameController.text = saved;
      }
    } catch (_) {
      // A missing preference is not worth interrupting a join for.
    }
  }

  @override
  void didUpdateWidget(JoinScreen old) {
    super.didUpdateWidget(old);
    // A link arriving while the app is already open — the student tapped the
    // teacher's message from WhatsApp without closing the app first.
    final incoming = normalizeMeetingId(widget.initialMeetingId);
    if (incoming.isNotEmpty && incoming != _meetingController.text) {
      _meetingController.text = incoming;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _meetingController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final meeting = context.read<MeetingController>();
    final name = _nameController.text.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, name);
    } catch (_) {}

    await meeting.join(name: name, meetingId: _meetingController.text);

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
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      enabled: !joining,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        hintText: 'The name your teacher will see',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _meetingController,
                      enabled: !joining,
                      textInputAction: TextInputAction.go,
                      onFieldSubmitted: (_) => joining ? null : _join(),
                      // Upper-cased as it is typed, because the server keys the
                      // room on this exact string. Lower case used to open a
                      // second, empty room with the same name.
                      inputFormatters: [UpperCaseFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Meeting ID',
                        hintText: 'e.g. NEET26',
                        prefixIcon: Icon(Icons.meeting_room_outlined),
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter the meeting ID from your teacher'
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
                    const SizedBox(height: 20),
                    const Text(
                      'You join muted. Raise your hand when you want to speak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff7a8ba3), fontSize: 12.5),
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

/// Upper-cases the meeting ID as it is typed, keeping the cursor where the
/// student left it.
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
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xff2f6bd8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.cast_for_education, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'LYN MEET',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Student',
          style: TextStyle(color: Color(0xff8b9cb3), fontSize: 14, letterSpacing: 3),
        ),
      ],
    );
  }
}
