/// Who the server says this person is.
///
/// Every field here comes from the platform directory, never from the app.
/// The socket re-derives the role from `v_Users` on every single connection,
/// so a session minted this morning for someone demoted at lunchtime does not
/// still open a classroom this afternoon. Nothing the app stores can outrank
/// that lookup, which is why there is no way to set a role here.
class AuthUser {
  final String email;
  final String name;

  /// "teacher", "coordinator" or "student", mapped server-side from UserType:
  /// T teaches; A, Q and O are administrators and coordinators; S, M and C
  /// attend. Anything unrecognised falls through to student.
  final String role;

  const AuthUser({
    required this.email,
    required this.name,
    required this.role,
  });

  /// An administrator or academic coordinator — what this app calls admin.
  bool get isAdmin => role == 'coordinator';

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';

  /// Whether the server will accept staff-only actions from this account.
  /// Kept distinct from [isAdmin] because a teacher is staff too, and the
  /// app refuses teachers for a different reason entirely.
  bool get isStaff => isTeacher || isAdmin;

  /// What to call this mode on screen.
  String get modeLabel => switch (role) {
        'coordinator' => 'Admin',
        'teacher' => 'Teacher',
        _ => 'Student',
      };

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? 'student').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
      };
}

/// Why a sign-in attempt failed, which decides what the screen offers next.
enum AuthFailure {
  /// No session, or it has expired. Sending them to sign in again is right.
  needsSignIn,

  /// Signed in, but the account is not allowed into meetings at all. Sending
  /// them round the sign-in loop again would only fail identically.
  notAuthorised,

  /// The server could not be reached, or answered with something unusable.
  unavailable,
}

class AuthException implements Exception {
  final AuthFailure failure;
  final String message;

  const AuthException(this.failure, this.message);

  @override
  String toString() => message;
}
