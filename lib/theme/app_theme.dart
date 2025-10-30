import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_decor.dart';

class AppTheme {
  static ThemeData light() {
    // Fresh mint green as the primary accent
    final seed = const Color(0xFF2DD4BF); // Mint/Teal 300
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    // Base body/label with Inter for readability
    TextTheme base = GoogleFonts.interTextTheme();
    // Headings and titles with Capriola for character
    base = base.copyWith(
      headlineLarge: GoogleFonts.capriola(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.capriola(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.capriola(textStyle: base.headlineSmall),
      titleLarge: GoogleFonts.capriola(textStyle: base.titleLarge),
      titleMedium: GoogleFonts.capriola(textStyle: base.titleMedium),
      titleSmall: GoogleFonts.capriola(textStyle: base.titleSmall),
    );
    const appBarBg = Color(0xFF2DD4BF); // Fixed brand mint for both themes
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: base,
      extensions: [AppDecor.fromScheme(scheme)],
      scaffoldBackgroundColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData dark() {
    // Deeper mint for dark mode to maintain contrast and freshness
    final seed = const Color(0xFF14B8A6); // Mint/Teal 500
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    TextTheme base = GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme);
    base = base.copyWith(
      headlineLarge: GoogleFonts.capriola(textStyle: base.headlineLarge),
      headlineMedium: GoogleFonts.capriola(textStyle: base.headlineMedium),
      headlineSmall: GoogleFonts.capriola(textStyle: base.headlineSmall),
      titleLarge: GoogleFonts.capriola(textStyle: base.titleLarge),
      titleMedium: GoogleFonts.capriola(textStyle: base.titleMedium),
      titleSmall: GoogleFonts.capriola(textStyle: base.titleSmall),
    );
    const appBarBg = Color(0xFF2DD4BF); // Same fixed color as light
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: base,
      extensions: [AppDecor.fromScheme(scheme)],
      scaffoldBackgroundColor: scheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
