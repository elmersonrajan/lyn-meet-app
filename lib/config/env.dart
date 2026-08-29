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

  /// The backend origin. Plain http on purpose: the server presents a
  /// self-signed certificate that a native Dart client refuses outright, so
  /// the app talks to the API port directly rather than through the Vite
  /// proxy the browser uses. See android/app/src/main/res/xml/
  /// network_security_config.xml, which whitelists exactly this host.
  static const String serverUrl = String.fromEnvironment(
    'LYNMEET_SERVER',
    defaultValue: 'http://59.96.57.40:5000',
  );

  /// Socket.IO mount point — matches the backend's default.
  static const String socketPath = '/socket.io';

  /// The role this build joins as. A student app has no role picker: the value
  /// is baked in, and the server independently treats anything it does not
  /// recognise as a student anyway (normalizeRole in roomManager.js).
  static const String role = 'student';

  /// How long to wait for join-room before giving up and showing an error.
  static const Duration joinTimeout = Duration(seconds: 20);

  /// Socket.IO reconnection, matched to the web client so both behave alike.
  static const int reconnectionAttempts = 12;
  static const Duration reconnectionDelay = Duration(milliseconds: 800);

  /// Whether to mirror client logs up to the server's meeting log. Useful when
  /// diagnosing a student's connection from the server side.
  static const bool remoteLogging = true;
}
