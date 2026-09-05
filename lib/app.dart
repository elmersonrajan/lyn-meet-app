import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/join_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/teacher_blocked_screen.dart';
import 'services/meeting_link.dart';
import 'state/auth_controller.dart';
import 'state/meeting_controller.dart';
import 'theme.dart';

/// The app shell: theme, the controllers, deep links, and deciding which
/// screen the signed-in account is entitled to.
class LynMeetApp extends StatefulWidget {
  const LynMeetApp({super.key});

  @override
  State<LynMeetApp> createState() => _LynMeetAppState();
}

class _LynMeetAppState extends State<LynMeetApp> {
  final AppLinks _appLinks = AppLinks();
  final AuthController _auth = AuthController();
  StreamSubscription<Uri>? _linkSub;

  /// The meeting from the link that opened the app, kept across sign-in so
  /// somebody who followed a class link lands in that class rather than at a
  /// blank field.
  String? _pendingMeetingId;

  @override
  void initState() {
    super.initState();
    _wireDeepLinks();
    unawaited(_auth.restore());
  }

  /// One link does two jobs.
  ///
  /// A teacher shares `?lynmeet=<id>` with the class. The platform sends people
  /// back to that same address with `TockenID=` attached once they have signed
  /// in. Both arrive here: the meeting fills the join field, and the token is
  /// redeemed for a session.
  ///
  /// This is why claiming the domain mattered. The sign-in round trip returns
  /// to a URL the app owns, so the token comes back into the app instead of
  /// landing in a browser tab the app cannot read.
  Future<void> _wireDeepLinks() async {
    try {
      await _handleLink(await _appLinks.getInitialLink());
    } catch (_) {
      // Opened from the launcher rather than a link, which is the normal case.
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleLink(uri)),
      onError: (_) {},
    );
  }

  Future<void> _handleLink(Uri? uri) async {
    if (uri == null) return;

    final meetingId = readMeetingIdFromUri(uri);
    if (meetingId.isNotEmpty && mounted) {
      setState(() => _pendingMeetingId = meetingId);
    }

    final token = readHandoffToken(uri);
    if (token.isNotEmpty) await _auth.completeSignIn(token);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider(create: (_) => MeetingController()),
      ],
      child: MaterialApp(
        title: 'LYN MEET',
        debugShowCheckedModeBanner: false,
        theme: lynMeetTheme(),
        home: Consumer<AuthController>(
          builder: (context, auth, _) => _Gate(
            auth: auth,
            pendingMeetingId: _pendingMeetingId,
          ),
        ),
      ),
    );
  }
}

/// Chooses the screen from the account rather than from anything the app
/// decided for itself.
class _Gate extends StatelessWidget {
  const _Gate({required this.auth, required this.pendingMeetingId});

  final AuthController auth;
  final String? pendingMeetingId;

  @override
  Widget build(BuildContext context) {
    if (auth.phase == AuthPhase.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isSignedIn) {
      return SignInScreen(pendingMeetingId: pendingMeetingId);
    }

    // A teacher is turned away here rather than in the room, so they find out
    // before they have taken the class's only teacher slot.
    if (auth.user!.isTeacher) return const TeacherBlockedScreen();

    // The session travels with the socket from here on, set before the join
    // screen builds so the first connection is already authenticated.
    context.read<MeetingController>().useSession(auth.sessionCookie);

    return JoinScreen(
      initialMeetingId: pendingMeetingId,
      user: auth.user!,
    );
  }
}
