import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';

enum AuthPhase {
  /// Checking a stored session on launch.
  checking,

  /// Nobody is signed in.
  signedOut,

  /// Waiting for the browser to come back with a token.
  awaitingBrowser,

  /// Redeeming the token the browser returned.
  redeeming,

  /// Signed in, with a role.
  signedIn,
}

/// Signing in, and the mode that results.
///
/// The app has no say in which mode it runs. The platform authenticates in a
/// browser, the server maps the account to a role, and the app renders whatever
/// it is told — an administrator gets the admin controls because the server
/// will accept staff actions from them, and a student does not because it
/// would refuse.
class AuthController extends ChangeNotifier {
  AuthController({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;

  AuthPhase _phase = AuthPhase.checking;
  AuthUser? _user;
  String? _error;
  AuthFailure? _failure;

  AuthPhase get phase => _phase;
  AuthUser? get user => _user;
  String? get error => _error;
  AuthFailure? get failure => _failure;
  bool get isSignedIn => _phase == AuthPhase.signedIn && _user != null;
  String? get sessionCookie => _service.cookie;

  /// True while something is in flight, so the button can be held.
  bool get busy =>
      _phase == AuthPhase.checking || _phase == AuthPhase.redeeming;

  /// Restores and re-checks a stored session at launch.
  ///
  /// The stored cookie is never taken as proof on its own. A role can be
  /// changed or an account withdrawn entirely on the platform side, so the
  /// question "who is this, and may they still join?" is put to the server
  /// every time the app starts.
  Future<void> restore() async {
    _phase = AuthPhase.checking;
    notifyListeners();

    await _service.restore();
    if (!_service.hasSession) {
      _set(AuthPhase.signedOut);
      return;
    }

    try {
      _user = await _service.fetchUser();
      _set(AuthPhase.signedIn);
    } on AuthException catch (err) {
      _user = null;
      _failure = err.failure;
      // An unreachable server is not a reason to throw away a session that may
      // be perfectly good — the student may simply be somewhere with no signal.
      _error = err.failure == AuthFailure.unavailable ? err.message : null;
      _set(AuthPhase.signedOut);
    }
  }

  /// Opens the platform sign-in in the browser as a separate app.
  ///
  /// A Custom Tab would look better and cannot work here, which is worth
  /// writing down because it is not obvious and it was tried.
  ///
  /// A Custom Tab belongs to the app that opened it, and Chrome deliberately
  /// does not hand a link back to that same app — otherwise every link would
  /// bounce in a loop. So the class address opens *in the tab*, and the web
  /// client there reads the sign-in token while its module is still loading
  /// and spends it. The app is left waiting for a token that was consumed in
  /// front of it, and every later attempt is genuinely stale: hence "this
  /// sign-in link has expired or was already used", every single time.
  ///
  /// The browser as its own app honours the verified App Link instead, and
  /// hands the address over *without loading the page*, so the token arrives
  /// here unspent. Leaving the app for a moment is the price of that.
  ///
  /// It is still never a WebView. The platform signs in with Google, and
  /// Google refuses OAuth inside an embedded WebView — on the grounds that the
  /// host app could read what is typed, which is a good reason to agree.
  Future<bool> startSignIn({String? meetingId}) async {
    _error = null;
    _failure = null;
    try {
      final uri = await _service.loginUri(meetingId: meetingId);

      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        _error = 'Could not open the browser to sign in';
        _set(AuthPhase.signedOut);
        return false;
      }
      _set(AuthPhase.awaitingBrowser);
      return true;
    } catch (err) {
      debugPrint('[Auth] could not launch sign-in: $err');
      _error = 'Could not open the browser to sign in';
      _set(AuthPhase.signedOut);
      return false;
    }
  }

  /// Redeems the one-time token the browser handed back.
  ///
  /// Single use on the server, so this is called once per sign-in and a repeat
  /// with the same token reads as a stale link rather than quietly working.
  Future<bool> completeSignIn(String token) async {
    final wasSignedIn = isSignedIn;

    _phase = AuthPhase.redeeming;
    _error = null;
    _failure = null;
    notifyListeners();

    try {
      _user = await _service.redeemToken(token);
      // Take the sign-in browser away now that it has done its job, rather
      // than leaving the class behind a tab the student has to dismiss.
      unawaited(_closeBrowser());
      _set(AuthPhase.signedIn);
      return true;
    } on AuthException catch (err) {
      // A spent token is not a reason to throw away a session that already
      // works. The same link can be opened twice — tapped again, restored from
      // history, or redeemed by the browser before the app was handed it — and
      // the second attempt is refused as already used. Signing somebody out
      // over that would be the app breaking its own sign-in.
      if (wasSignedIn && err.failure != AuthFailure.notAuthorised) {
        _set(AuthPhase.signedIn);
        return false;
      }

      _user = null;
      _failure = err.failure;
      _error = err.message;
      _set(AuthPhase.signedOut);
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _user = null;
    _error = null;
    _failure = null;
    _set(AuthPhase.signedOut);
  }

  /// Closes the in-app browser if one is open. Harmless when none is.
  Future<void> _closeBrowser() async {
    try {
      await closeInAppWebView();
    } catch (_) {
      // Nothing was open, or the platform does not support closing it.
    }
  }

  void _set(AuthPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
