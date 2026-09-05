import 'package:flutter/material.dart';

/// The one dark theme the app uses.
///
/// Dark and not switchable. A class is watched for an hour, often in a dim
/// room, and the stage is a white board — everything around it stays dark so
/// the board is the bright thing on screen rather than competing with the
/// chrome. Lifted out of the app shell so the sign-in and blocked screens
/// share it without importing the shell that renders them.
ThemeData lynMeetTheme() {
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
