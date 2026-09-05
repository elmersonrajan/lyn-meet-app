import 'package:flutter_test/flutter_test.dart';
import 'package:lynmeet/models/auth_user.dart';
import 'package:lynmeet/services/meeting_link.dart';

/// Sign-in decides what the app lets someone do, so the two places it can go
/// quietly wrong are worth pinning down: reading the token out of the link the
/// platform sends back, and reading the role the server returns.
void main() {
  group('the token the platform sends back', () {
    // The platform spells it TockenID. Matching the corrected spelling would
    // authenticate nobody, which is a failure with no error attached to it.
    test('reads the platform spelling', () {
      final uri = Uri.parse(
        'https://meet.lynindia.in/?lynmeet=10214&TockenID=ya29.a0AfB_abcdef',
      );
      expect(readHandoffToken(uri), 'ya29.a0AfB_abcdef');
    });

    test('also reads the corrected spelling, for the day they fix it', () {
      final uri = Uri.parse('https://meet.lynindia.in/?TokenID=ya29.xyz');
      expect(readHandoffToken(uri), 'ya29.xyz');
    });

    test('a class link carries no token', () {
      final uri = Uri.parse('https://meet.lynindia.in/?lynmeet=DEVTEST');
      expect(readHandoffToken(uri), '');
      expect(readMeetingIdFromUri(uri), 'DEVTEST');
    });

    test('one link can carry both, and both are read', () {
      final uri = Uri.parse(
        'https://meet.lynindia.in/?lynmeet=10214&TockenID=ya29.token',
      );
      expect(readMeetingIdFromUri(uri), '10214');
      expect(readHandoffToken(uri), 'ya29.token');
    });

    test('an empty parameter is not a token', () {
      expect(readHandoffToken(Uri.parse('https://x/?TockenID=')), '');
      expect(readHandoffToken(Uri.parse('https://x/?TockenID=%20')), '');
      expect(readHandoffToken(null), '');
    });
  });

  group('the role the server returns', () {
    AuthUser as(String role) =>
        AuthUser.fromMap({'email': 'a@b.c', 'name': 'A B', 'role': role});

    test('an administrator gets admin, and is staff', () {
      expect(as('coordinator').isAdmin, isTrue);
      expect(as('coordinator').isStaff, isTrue);
      expect(as('coordinator').modeLabel, 'Admin');
    });

    test('a teacher is staff but is not an admin', () {
      // Both matter and they are not the same test: the app refuses teachers
      // for a reason that has nothing to do with what they are allowed to do.
      expect(as('teacher').isTeacher, isTrue);
      expect(as('teacher').isStaff, isTrue);
      expect(as('teacher').isAdmin, isFalse);
    });

    test('a student is neither', () {
      expect(as('student').isStudent, isTrue);
      expect(as('student').isStaff, isFalse);
      expect(as('student').isAdmin, isFalse);
    });

    test('an unknown role reads as a student, never as staff', () {
      // The server maps unknown UserTypes down to student rather than up. A
      // client that guessed the other way would show controls to someone every
      // one of whose actions the server then refuses.
      final unknown = AuthUser.fromMap({'email': 'a@b.c', 'name': 'A'});
      expect(unknown.role, 'student');
      expect(unknown.isStaff, isFalse);
    });
  });
}
