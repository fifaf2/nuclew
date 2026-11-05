import 'package:flutter/material.dart';

const kPaper = Color(0xFFF3F0E8);
const kInk = Color(0xFF1C1B19);
const kMuted = Color(0xFF6F6A62);
const kLine = Color(0xFFE2DCD2);
const kAccent = Color(0xFF1F6A4D);
const kBad = Color(0xFF9C3B32);
const kSurface = Color(0xFFFFFCF8);

Color taskStatusColor(String status) {
  switch (status) {
    case 'свободна':
      return const Color(0xFF3D6B8A);
    case 'в работе':
      return const Color(0xFF8A5A12);
    case 'на доработке':
      return kBad;
    case 'завершена':
      return const Color(0xFF2A6B45);
    default:
      return kMuted;
  }
}

Color presenceColor(String presence) {
  switch (presence) {
    case 'отошел':
      return const Color(0xFF8A5A12);
    case 'не беспокоить':
      return kBad;
    default:
      return const Color(0xFF2A6B45);
  }
}

ThemeData nuclewTheme() {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
    borderSide: BorderSide(color: kLine),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: kPaper,
    colorScheme: const ColorScheme.light(
      primary: kAccent,
      onPrimary: Colors.white,
      secondary: kAccent,
      surface: kSurface,
      onSurface: kInk,
      error: kBad,
      outline: kLine,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kPaper,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 1),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: kSurface,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: TextStyle(color: kMuted, fontSize: 14),
      hintStyle: TextStyle(color: kMuted, fontSize: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: kAccent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 44),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: TextStyle(color: kPaper, fontSize: 14),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kInk,
      unselectedLabelColor: kMuted,
      indicatorColor: kAccent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: kLine,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kAccent),
    popupMenuTheme: const PopupMenuThemeData(color: kSurface),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: kAccent,
      selectionColor: Color(0x331F6A4D),
    ),
  );
}
