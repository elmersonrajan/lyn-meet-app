import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';

/// The one signalling connection to the classroom.
///
/// A direct port of frontend/src/services/socket.js, including its two
/// decisions worth keeping:
///
///   * one socket for the whole app, created lazily and reused, so a rebuild
///     never opens a second connection into the same room;
///   * every request goes through [emitAck], which turns the server's
///     `{ok: false, error}` convention into a thrown Dart exception instead of
///     a success value the caller has to remember to inspect.
class SocketService {
  io.Socket? _socket;

  /// Requests still waiting on the server. A socket that drops mid-request
  /// would otherwise leave these futures pending forever.
  final Set<Completer<Map<String, dynamic>>> _pending = {};

  io.Socket get socket => _socket ??= _create();

  bool get isConnected => _socket?.connected ?? false;

  io.Socket _create() {
    final options = io.OptionBuilder()
        .setPath(Env.socketPath)
        // Websocket only. The browser client lists polling as a fallback, but
        // a native client has no same-origin story for it, and a poll would
        // carry an Origin the server's CORS list does not know about.
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(Env.reconnectionAttempts)
        .setReconnectionDelay(Env.reconnectionDelay.inMilliseconds)
        .setReconnectionDelayMax(8000)
        .setTimeout(15000)
        .build();

    final s = io.io(Env.serverUrl, options);
    s.onConnect((_) => debugPrint('[Socket] connected ${s.id}'));
    s.onDisconnect((reason) => debugPrint('[Socket] disconnected $reason'));
    s.onConnectError((err) => debugPrint('[Socket] connect_error $err'));
    s.onError((err) => debugPrint('[Socket] error $err'));
    return s;
  }

  void connect() {
    final s = socket;
    if (!s.connected) s.connect();
  }

  /// Registers a handler, returning a function that removes it again.
  ///
  /// Returning the remover is what makes the room screen's teardown honest:
  /// it holds a list of these and calls them all in dispose(), rather than
  /// trying to re-derive the same closures it registered.
  VoidCallback on(String event, void Function(dynamic data) handler) {
    socket.on(event, handler);
    return () => socket.off(event, handler);
  }

  void off(String event) => _socket?.off(event);

  /// Fire-and-forget. Used only where the server sends no acknowledgement.
  void emit(String event, [dynamic payload]) {
    debugPrint('[Socket] emit $event');
    socket.emit(event, payload ?? <String, dynamic>{});
  }

  /// A request with a reply, as a Future.
  ///
  /// Completes with the acknowledgement map on success. Throws
  /// [SocketAckException] when the server answers `ok: false`, when the reply
  /// is malformed, or when nothing comes back inside [timeout] — the last one
  /// matters because a mediasoup handshake that silently stalls is otherwise
  /// indistinguishable from one still in flight, and the join screen would
  /// spin forever.
  Future<Map<String, dynamic>> emitAck(
    String event, [
    Map<String, dynamic> payload = const {},
    Duration timeout = const Duration(seconds: 15),
  ]) {
    final completer = Completer<Map<String, dynamic>>();
    _pending.add(completer);

    void finish(void Function() body) {
      if (completer.isCompleted) return;
      _pending.remove(completer);
      body();
    }

    debugPrint('[Socket] emit $event');
    try {
      socket.emitWithAck(
        event,
        payload,
        ack: (dynamic response) {
          finish(() {
            if (response is! Map) {
              completer.completeError(
                SocketAckException(event, 'Malformed reply from the server'),
              );
              return;
            }
            final map = Map<String, dynamic>.from(response);
            if (map['ok'] == false) {
              completer.completeError(
                SocketAckException(event, (map['error'] ?? '$event failed').toString()),
              );
              return;
            }
            completer.complete(map);
          });
        },
      );
    } catch (err) {
      finish(() => completer.completeError(SocketAckException(event, '$err')));
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(completer);
        throw SocketAckException(event, 'The server did not respond');
      },
    );
  }

  /// Mirrors a line into the server's meeting log.
  ///
  /// Best effort by design: this is how a student's connection trouble becomes
  /// visible on the server, so it must never itself be a source of failure.
  void log(String message, [Map<String, dynamic>? data]) {
    if (!Env.remoteLogging) return;
    try {
      if (!isConnected) return;
      socket.emit('client-log', {
        'message': message,
        if (data != null) ...data,
        'platform': defaultTargetPlatform.name,
        'client': 'flutter-student',
      });
    } catch (_) {
      // Logging must not break a class.
    }
  }

  /// Drops the connection and fails anything still waiting on it.
  void dispose() {
    for (final completer in _pending.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(
          SocketAckException('dispose', 'The connection was closed'),
        );
      }
    }
    _pending.clear();
    _socket?.dispose();
    _socket = null;
  }
}

/// A request the server refused, or never answered.
class SocketAckException implements Exception {
  final String event;
  final String message;

  const SocketAckException(this.event, this.message);

  @override
  String toString() => message;
}
