import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/join_screen.dart';
import 'services/meeting_link.dart';
import 'state/meeting_controller.dart';

/// The app shell: theme, the single MeetingController, and deep links.
class LynMeetApp extends StatefulWidget {
  const LynMeetApp({super.key});

  @override
  State<LynMeetApp> createState() => _LynMeetAppState();
}

class _LynMeetAppState extends State<LynMeetApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  /// The meeting ID the app was opened with, if any.
  String? _pendingMeetingId;

  @override
  void initState() {
    super.initState();
    _wireDeepLinks();
  }

  /// A teacher shares one link with the whole class. On a phone that link has
  /// to reach the join field, or every student has to be told the code twice.
  ///
  /// Both entry points matter and they are different events: the link that
  /// launched a closed app, and a link tapped while the app is already open.
  Future<void> _wireDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      final id = readMeetingIdFromUri(initial);
      if (id.isNotEmpty && mounted) {
        setState(() => _pendingMeetingId = id);
      }
    } catch (_) {
      // No link is the normal case, not a failure.
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        final id = readMeetingIdFromUri(uri);
        if (id.isNotEmpty && mounted) {
          setState(() => _pendingMeetingId = id);
        }
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MeetingController(),
      child: Builder(
        builder: (context) {
          // The media and whiteboard controllers notify separately from the
          // meeting itself, so a stroke arriving does not rebuild the
          // participant list and a track arriving does not redraw the board.
          final meeting = context.read<MeetingController>();
          return MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: meeting.media),
              ChangeNotifierProvider.value(value: meeting.whiteboard),
            ],
            child: MaterialApp(
              title: 'LYN MEET',
              debugShowCheckedModeBanner: false,
              theme: _theme(),
              home: JoinScreen(initialMeetingId: _pendingMeetingId),
            ),
          );
        },
      ),
    );
  }

  /// Dark by default and not switchable.
  ///
  /// A class is watched for an hour, often in a dim room, and the stage is a
  /// white board. Everything around it stays dark so the board is the bright
  /// thing on the screen rather than competing with the chrome.
  ThemeData _theme() {
    const surface = Color(0xff0b1017);
    const panel = Color(0xff141d29);
    const accent = Color(0xff2f6bd8);

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: surface,
        secondary: const Color(0xff35d07f),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: panel,
        elevation: 0,
        centerTitle: false,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xff8b9cb3),
        indicatorColor: accent,
        dividerColor: Color(0xff1e2937),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: panel),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xff243043)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.6),
        ),
        labelStyle: const TextStyle(color: Color(0xff8b9cb3)),
        hintStyle: const TextStyle(color: Color(0xff5c6b80)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
