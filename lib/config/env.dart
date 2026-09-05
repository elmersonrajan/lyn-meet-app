/// Where the app finds the classroom, and the handful of numbers that tune it.
///
/// Everything here is overridable at build time so a debug build against a
/// laptop and a release build against the school server come from one source
/// tree:
///
///   flutter run --dart-define=LYNMEET_SERVER=http://192.168.1.55:5000
library;

class Env {
  const Env._();

  /// The backend origin.
  ///
  /// The public domain, over real TLS. It fronts the same backend the browser
  /// talks to and proxies /socket.io through to it, so nothing here needs a
  /// certificate override or a cleartext exception. It is also the host the
  /// shared links point at, which is what makes App Link verification
  /// possible: the app has to be able to claim the domain it opens.
  ///
  /// Testing against a machine on the LAN or against the API port directly
  /// still works, and the cleartext exceptions for those are kept in
  /// android/app/src/main/res/xml/network_security_config.xml:
  ///
  ///   --dart-define=LYNMEET_SERVER=http://192.168.1.55:5000
  static const String serverUrl = String.fromEnvironment(
    'LYNMEET_SERVER',
    defaultValue: 'https://meet.lynindia.in',
  );

  /// The host shared links use. Kept beside the server URL because the two are
  /// the same machine, and App Links only verify when they agree.
  static const String linkHost = 'meet.lynindia.in';

  /// Socket.IO mount point — matches the backend's default.
  static const String socketPath = '/socket.io';

  /// Last resort for where signing in starts.
  ///
  /// Normally this is not used at all: the server reports its own configured
  /// login URL on an unauthenticated request, and that answer is the one to
  /// trust, since it is the value the rest of the sign-in round trip was built
  /// against. Hard-coding a guess here is how the button came to open a 404 —
  /// the address in .env.example, /sso/authorize, has never existed.
  static const String loginUrlFallback = String.fromEnvironment(
    'LYNMEET_LOGIN',
    defaultValue: 'https://lynindia.in/',
  );

  /// The session cookie the server sets, matching SESSION_COOKIE_NAME on the
  /// backend. Named here because a native client has no cookie jar and has to
  /// pick this one out of a Set-Cookie header itself.
  static const String sessionCookieName = 'lynmeet_sid';

  /// How long to wait for join-room before giving up and showing an error.
  static const Duration joinTimeout = Duration(seconds: 20);

  /// Socket.IO reconnection, matched to the web client so both behave alike.
  static const int reconnectionAttempts = 12;
  static const Duration reconnectionDelay = Duration(milliseconds: 800);

  /// Whether to mirror client logs up to the server's meeting log. Useful when
  /// diagnosing a student's connection from the server side.
  static const bool remoteLogging = true;
}
