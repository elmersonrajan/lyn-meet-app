import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../state/auth_controller.dart';

/// Shown when a teacher signs in to the app.
///
/// Not a limitation of the app so much as a safeguard for the class. A room
/// holds exactly one teacher, and the server refuses a second — so a teacher
/// who joins from their phone takes the slot their own scheduled session needs,
/// and cannot then take it back from the laptop until the reconnect grace
/// window expires. A lesson can be lost that way, so the app does not offer it.
class TeacherBlockedScreen extends StatelessWidget {
  const TeacherBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final name = auth.user?.name ?? 'You';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xff1b2b45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_outlined,
                        size: 34, color: Color(0xff9dc2ff)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$name, teaching runs on the web app',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A class has room for one teacher, and joining from a phone '
                    'would take that place from your own session. The whiteboard '
                    'and recording are on the web app too.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff8b9cb3),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(Env.serverUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Open LYN MEET on the web'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.read<AuthController>().signOut(),
                    child: const Text('Sign in as someone else'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
