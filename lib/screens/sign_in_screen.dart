import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../state/auth_controller.dart';

/// The way in.
///
/// One button, and no fields. There is no username or password here on
/// purpose: the platform owns the account, the app never sees a credential,
/// and it does not get to decide who anybody is. Whether this person ends up
/// an administrator or a student is the server's answer, given after they
/// sign in — which is why nothing on this screen asks.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, this.pendingMeetingId});

  /// A meeting from the link that opened the app, carried through sign-in so
  /// the student lands in the right class rather than at a blank join screen.
  final String? pendingMeetingId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final blocked = auth.failure == AuthFailure.notAuthorised;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Logo(),
                  const SizedBox(height: 36),

                  if (auth.phase == AuthPhase.awaitingBrowser) ...[
                    const _Waiting(),
                  ] else ...[
                    Text(
                      blocked ? 'Access denied' : 'Sign in to join your class',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (blocked)
                      const Text(
                        'This account is not allowed into meetings. Ask your '
                        'coordinator to check your account on LYN India.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff8b9cb3),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      )
                    else
                      // Spelt out as steps because it genuinely is two moves.
                      // Signing in alone does not return anybody here — the
                      // platform only hands this app a session when a class is
                      // opened from its own pages, and a screen that implied
                      // otherwise left people watching a spinner.
                      const _Steps(),
                  ],

                  if (auth.error != null) ...[
                    const SizedBox(height: 20),
                    _ErrorBox(
                      message: auth.error!,
                      // Deliberately does not claim the link was used up. The
                      // server says "expired or already used" for any token it
                      // cannot find, and a token it still holds works again —
                      // the row is only removed on a best-effort delete. So
                      // this points at the move that produces a working link
                      // rather than explaining a rule that may not apply.
                      hint: auth.failure == AuthFailure.needsSignIn
                          ? 'Open your class again on LYN India to come back with a fresh link.'
                          : null,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Offered even when blocked, because the usual fix is to
                  // sign in as the right account — a shared phone is common.
                  FilledButton.icon(
                    onPressed: auth.busy
                        ? null
                        : () => context
                            .read<AuthController>()
                            .startSignIn(meetingId: pendingMeetingId),
                    icon: auth.busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_browser, size: 18),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        auth.phase == AuthPhase.awaitingBrowser
                            ? 'Open LYN India again'
                            : blocked
                                ? 'Sign in as someone else'
                                : 'Open LYN India to sign in',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Opens your browser. Nothing you type there is seen by this app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff6b7a8d), fontSize: 11.5),
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

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 16),
        Text(
          'Now open your class on LYN India',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Signing in is not quite enough — opening your class is what sends '
          'you back here, already signed in. This screen carries on by itself '
          'the moment it does.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff8b9cb3), fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

/// What actually has to happen, in order.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step(n: '1', text: 'Sign in on LYN India'),
        _Step(n: '2', text: 'Open your class from your timetable there'),
        _Step(
          n: '3',
          text: 'It brings you straight back here, already signed in',
          last: true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.last = false});

  final String n;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xff1e3a63),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: Color(0xff9dc2ff),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xffb9c6d6),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.hint});

  final String message;

  /// What to do about it, when there is something to do.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff3a1a1e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, size: 18, color: Color(0xffff8b8b)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: Color(0xffffb3b3), fontSize: 13),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    hint!,
                    style: const TextStyle(
                      color: Color(0xffd79a9a),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.26).clamp(80.0, 132.0);
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
        const SizedBox(height: 16),
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
