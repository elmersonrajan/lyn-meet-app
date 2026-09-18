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

  /// Opens the platform sign-in, inside the app where the platform allows it.
  ///
  /// A Custom Tab on Android, a Safari view on iOS: it sits on top of the app
  /// rather than switching to another one, it is themed, and it closes itself.
  /// Crucially it shares the browser's own cookies, so somebody already signed
  /// in to lynindia.in goes straight through without seeing a login form.
  ///
  /// It is not a WebView, and that is not a preference. The platform signs in
  /// with Google, and Google refuses OAuth inside an embedded WebView
  /// (`disallowed_useragent`) precisely because the host app could read what is
  /// typed — so a login page rendered inside this app would be turned away by
  /// Google, not by us. A Custom Tab is a real browser and is allowed.
  ///
  /// Falls back to the full browser if no Custom Tab provider is installed,
  /// which is unusual but happens on stripped-down devices.
  Future<bool> startSignIn({String? meetingId}) async {
    _error = null;
    _failure = null;
    try {
      final uri = await _service.loginUri(meetingId: meetingId);

      var launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (err) {
        debugPrint('[Auth] no in-app browser, using the full one: $err');
      }
      launched = launched ||
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
