import 'package:flutter/material.dart';

/// Meet's colours, near enough to be familiar.
///
/// The class is moving off Google Meet, and for the first few weeks every
/// student's hands already know where things are. Matching the palette, the
/// shapes and the control language means that muscle memory keeps working —
/// a red pill is still "leave", a filled red microphone still means muted —
/// and nobody has to learn a new app in the middle of a lesson.
///
/// Neutral greys rather than the navy this used to be. Meet's surfaces are
/// grey, and against grey a blue control reads as a control; against navy it
/// reads as part of the background.
class LynColors {
  const LynColors._();

  /// Meet's in-call background.
  static const surface = Color(0xff202124);

  /// One step up, for bars and sheets.
  static const surfaceHigh = Color(0xff2d2e31);

  /// A control at rest.
  static const control = Color(0xff3c4043);

  static const outline = Color(0xff5f6368);

  /// Meet blue.
  static const primary = Color(0xff8ab4f8);
  static const primarySolid = Color(0xff1a73e8);

  /// Meet red — leaving, and anything muted.
  static const danger = Color(0xffea4335);
  static const dangerSoft = Color(0xfff28b82);

  static const success = Color(0xff81c995);
  static const warning = Color(0xfffdd663);

  static const textPrimary = Color(0xffe8eaed);
  static const textSecondary = Color(0xff9aa0a6);
  static const textMuted = Color(0xff80868b);
}

/// The one dark theme the app uses.
///
/// Dark and not switchable. A class is watched for an hour, often in a dim
/// room, and the stage is a white board — everything around it stays dark so
/// the board is the bright thing on screen rather than competing with it.
/// Meet makes the same choice in a call, for the same reason.
ThemeData lynMeetTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: LynColors.surface,
    colorScheme: base.colorScheme.copyWith(
      primary: LynColors.primary,
      onPrimary: const Color(0xff202124),
      surface: LynColors.surface,
      onSurface: LynColors.textPrimary,
      secondary: LynColors.success,
      error: LynColors.danger,
      outline: LynColors.outline,
    ),
    // No font is named. Meet is set in Google Sans, which is not ours to
    // ship, and its stablemate Roboto is already the Android default — so the
    // text renders in the face Meet itself falls back to without bundling
    // anything or adding a megabyte to the download.
    appBarTheme: const AppBarTheme(
      backgroundColor: LynColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: LynColors.textPrimary),
      titleTextStyle: TextStyle(
        color: LynColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: LynColors.primary,
      unselectedLabelColor: LynColors.textSecondary,
      indicatorColor: LynColors.primary,
      dividerColor: Color(0xff3c4043),
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    // Generous corners throughout. Meet rounds almost everything, and that is
    // the single strongest cue that reads as "this is that kind of app".
    dialogTheme: DialogThemeData(
      backgroundColor: LynColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(
        color: LynColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w400,
      ),
      contentTextStyle: const TextStyle(
        color: LynColors.textSecondary,
        fontSize: 14,
        height: 1.45,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LynColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xffe8eaed),
      contentTextStyle: const TextStyle(color: Color(0xff202124), fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LynColors.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff3c4043)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LynColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: LynColors.textSecondary),
      hintStyle: const TextStyle(color: LynColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LynColors.primarySolid,
        foregroundColor: Colors.white,
        // The full pill Meet uses on its primary actions.
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LynColors.primary,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      textColor: LynColors.textPrimary,
      iconColor: LynColors.textSecondary,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: LynColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(color: LynColors.textPrimary, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xff3c4043), space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LynColors.primary,
    ),
  );
}
