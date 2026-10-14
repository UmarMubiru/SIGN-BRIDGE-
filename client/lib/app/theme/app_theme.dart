import 'package:flutter/material.dart';

class AppTheme {
  // SignBridge palette sampled from the supplied login reference image.
  static const Color primaryBackground = Color(0xFF001136);
  static const Color secondarySurface = Color(0xFF011B4E);
  static const Color raisedSurface = Color(0xFF022055);
  static const Color outline = Color(0xFF007EFF);
  static const Color mutedText = Color(0xFF9FCBFA);
  static const Color gold = Color(0xFFFF8508);
  static const Color teal = Color(0xFF00C5F5);
  static const Color ivory = Color(0xFFF4F7FF);
  static const Color subtleText = Color(0xB3F4F7FF);
  static const Color supportingCyan = Color(0xFF01C3FD);
  static const Color success = teal;
  static const Color warning = gold;
  static const Color error = Color(0xFFFF7777);

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: gold,
    onPrimary: primaryBackground,
    secondary: teal,
    onSecondary: primaryBackground,
    surface: secondarySurface,
    onSurface: ivory,
    error: error,
    onError: primaryBackground,
  );

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: primaryBackground,
      canvasColor: primaryBackground,
      dividerColor: outline,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBackground,
        foregroundColor: ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(
          color: ivory,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: ivory),
      ),
      cardTheme: CardThemeData(
        color: secondarySurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: outline, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: primaryBackground,
          disabledBackgroundColor: raisedSurface,
          disabledForegroundColor: mutedText,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ivory,
          side: const BorderSide(color: outline),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: supportingCyan,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raisedSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: mutedText),
        labelStyle: const TextStyle(color: mutedText),
        prefixIconColor: teal,
        suffixIconColor: mutedText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: secondarySurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: raisedSurface,
        contentTextStyle: const TextStyle(color: ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: raisedSurface,
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: ivory),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: gold,
        selectionColor: Color(0x66FF8508),
        selectionHandleColor: gold,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          color: ivory,
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        displayMedium: const TextStyle(
          color: ivory,
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: const TextStyle(
          color: ivory,
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          color: ivory,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: ivory,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: ivory, fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(color: ivory, fontSize: 14, height: 1.45),
        bodySmall: const TextStyle(color: mutedText, fontSize: 12, height: 1.4),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        primary: const Color(0xFFC35A00),
        secondary: const Color(0xFF007F9F),
        surface: const Color(0xFFF6F9FF),
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F5FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF0F5FF),
        foregroundColor: primaryBackground,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE0DED7)),
        ),
      ),
    );
  }
}
