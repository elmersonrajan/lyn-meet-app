import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../models/auth_user.dart';

/// Signing in, and holding the session that results.
///
/// The app never authenticates anybody itself. The platform does that in a
/// browser and hands back a one-time token; this trades that token for a
/// session cookie and then carries the cookie on every request, including the
/// socket handshake. Role is not part of what is stored — the server looks it
/// up afresh on each connection, so anything cached here would only be a
/// stale claim waiting to disagree with it.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _cookieKey = 'lynmeet.session.cookie';

  /// The session cookie, as it goes back out in a Cookie header.
  String? _cookie;
  String? get cookie => _cookie;
  bool get hasSession => _cookie != null && _cookie!.isNotEmpty;

  /// Restores a session from a previous run.
  ///
  /// Only the cookie is kept. Whether it is still good, and what it entitles
  /// the holder to, is the server's answer to give — [fetchUser] asks.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_cookieKey);
      if (stored != null && stored.isNotEmpty) _cookie = stored;
    } catch (err) {
      debugPrint('[Auth] could not restore the session: $err');
    }
  }

  Future<void> _persist(String? value) async {
    _cookie = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.isEmpty) {
        await prefs.remove(_cookieKey);
      } else {
        await prefs.setString(_cookieKey, value);
      }
    } catch (err) {
      debugPrint('[Auth] could not save the session: $err');
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (hasSession) 'Cookie': _cookie!,
      };

  /// Where to send someone to sign in.
  ///
  /// The platform bounces straight back if they already have a session there,
  /// so an already-signed-in user sees a flicker rather than a login form. The
  /// return address is the meeting link itself, which this app claims — so the
  /// token comes back to the app rather than landing in a browser tab.
  Uri loginUri({String? meetingId}) {
    final redirect = meetingId == null || meetingId.isEmpty
        ? '${Env.serverUrl}/'
        : '${Env.serverUrl}/?lynmeet=${Uri.encodeComponent(meetingId)}';
    return Uri.parse(Env.loginUrl).replace(queryParameters: {
      'redirect': redirect,
    });
  }

  /// Trades the platform's one-time token for a session.
  ///
  /// The token is spent on first use — the server deletes the row as it is
  /// redeemed — so this can be called exactly once per sign-in and a retry
  /// with the same token fails as a stale link rather than working twice.
  Future<AuthUser> redeemToken(String token) async {
    final uri = Uri.parse('${Env.serverUrl}/auth/handoff');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 20));

      final body = _decode(response.body);

      if (response.statusCode == 200 && body['ok'] == true) {
        final setCookie = response.headers['set-cookie'];
        final parsed = _cookieFrom(setCookie);
        if (parsed == null) {
          throw const AuthException(
            AuthFailure.unavailable,
            'Signed in, but the server did not return a session',
          );
        }
        await _persist(parsed);
        return AuthUser.fromMap(Map<String, dynamic>.from(body['user'] as Map));
      }

      // 403 is a real refusal — the account may not join meetings at all, and
      // signing in again would fail in exactly the same way. 401 is a stale
      // link, which another trip through sign-in does fix.
      throw AuthException(
        response.statusCode == 403
            ? AuthFailure.notAuthorised
            : AuthFailure.needsSignIn,
        (body['error'] ?? 'Sign-in failed').toString(),
      );
    } on AuthException {
      rethrow;
    } catch (err) {
      debugPrint('[Auth] hand-off failed: $err');
      throw const AuthException(
        AuthFailure.unavailable,
        'Could not reach the sign-in server',
      );
    }
  }

  /// Who the current session belongs to, asked fresh.
  ///
  /// Called on every launch rather than trusting what was stored, because the
  /// answer can change without the app being involved: a role can be altered,
  /// or an account withdrawn, entirely on the platform side.
  Future<AuthUser> fetchUser() async {
    if (!hasSession) {
      throw const AuthException(AuthFailure.needsSignIn, 'Not signed in');
    }
    final uri = Uri.parse('${Env.serverUrl}/auth/me');
    try {
      final response =
          await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = _decode(response.body);
        if (body['ok'] == true && body['user'] is Map) {
          return AuthUser.fromMap(Map<String, dynamic>.from(body['user'] as Map));
        }
      }

      if (response.statusCode == 401) {
        // The cookie is spent. Dropping it here means the next launch goes
        // straight to sign-in rather than retrying something known to fail.
        await _persist(null);
        throw const AuthException(
          AuthFailure.needsSignIn,
          'Your session has expired',
        );
      }
      if (response.statusCode == 403) {
        throw const AuthException(
          AuthFailure.notAuthorised,
          'This account is not authorised to join meetings',
        );
      }
      throw const AuthException(
        AuthFailure.unavailable,
        'Could not check your sign-in',
      );
    } on AuthException {
      rethrow;
    } catch (err) {
      debugPrint('[Auth] /auth/me failed: $err');
      throw const AuthException(
        AuthFailure.unavailable,
        'Could not reach the server',
      );
    }
  }

  /// Ends the session here. The platform session belongs to the platform and
  /// is theirs to end, so this only drops our own cookie.
  Future<void> signOut() async {
    final uri = Uri.parse('${Env.serverUrl}/auth/logout');
    try {
      await _client
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (err) {
      debugPrint('[Auth] logout call failed, dropping the cookie anyway: $err');
    }
    await _persist(null);
  }

  /// Pulls the session cookie out of a Set-Cookie header.
  ///
  /// Only the name=value pair is kept. The attributes — Path, HttpOnly,
  /// SameSite, Expires — are instructions to a browser about when to send it,
  /// and this is not a browser: sending them back in a Cookie header is
  /// malformed, and some servers reject the request outright.
  ///
  /// A header can carry several cookies, so the one that matters is found by
  /// name rather than by taking the first.
  static String? _cookieFrom(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return null;
    for (final part in setCookie.split(RegExp(r',(?=[^;]+=)'))) {
      final pair = part.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      if (pair.substring(0, eq).trim() == Env.sessionCookieName) return pair;
    }
    return null;
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  void dispose() => _client.close();
}
