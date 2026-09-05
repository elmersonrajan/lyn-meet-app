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
                    Text(
                      blocked
                          ? 'This account is not allowed into meetings. Ask your '
                              'coordinator to check your account on LYN India.'
                          : 'You sign in on LYN India. Your class and what you '
                              'can do there come from your account.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff8b9cb3),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],

                  if (auth.error != null) ...[
                    const SizedBox(height: 20),
                    _ErrorBox(message: auth.error!),
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
                            ? 'Open sign-in again'
                            : blocked
                                ? 'Sign in as someone else'
                                : 'Sign in with LYN India',
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
          'Waiting for sign-in to finish',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Finish signing in on the page that opened. This screen continues on '
          'its own when you are done.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff8b9cb3), fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff3a1a1e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xffff8b8b)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xffffb3b3), fontSize: 13),
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
