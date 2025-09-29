import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:admin/constants.dart';

/// Centralizes the application's theming so every screen shares the same
/// typography, colors and component shapes. Keeping the definitions together
/// makes the UI look coherent and simplifies future refinements.
class AppTheme {
  const AppTheme._();

  /// Builds the dark theme used throughout the desktop/tablet experience.
  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: accentColor,
      onSecondary: Colors.black,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      background: bgColor,
      onBackground: Colors.white,
      surface: surfaceColor,
      onSurface: Colors.white,
    );

    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white);

    final elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      elevation: 0,
    );

    final inputDecorationTheme = const InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariantColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: accentColor, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFFFF6B6B), width: 1.2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      labelStyle: TextStyle(color: Colors.white70),
      floatingLabelStyle: TextStyle(color: Colors.white),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      canvasColor: surfaceColor,
      textTheme: baseTextTheme,
      fontFamily: GoogleFonts.poppins().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor.withOpacity(0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: baseTextTheme.titleLarge,
        contentTextStyle: baseTextTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceColor.withOpacity(0.96),
        elevation: 4,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.6),
        ),
        labelType: NavigationRailLabelType.all,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: elevatedButtonStyle),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: inputDecorationTheme,
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3A3C46),
        space: 24,
        thickness: 0.8,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textColor: Colors.white70,
        iconColor: Colors.white70,
        dense: true,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: baseTextTheme.labelSmall,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(12),
        thickness: const MaterialStatePropertyAll(8),
        thumbVisibility: const MaterialStatePropertyAll(true),
        thumbColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.hovered)
              ? accentColor.withOpacity(0.9)
              : accentColor.withOpacity(0.6),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
