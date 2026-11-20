import 'package:flutter/material.dart';

/// Dosique theme — calm medical palette: teal/emerald primary, warm neutrals.
/// Material 3, rounded cards, full dark-mode support.
class AppTheme {
  static const seed = Color(0xFF0E9F8A);
  static const emerald = Color(0xFF10B981);
  static const warmBg = Color(0xFFFAF7F2);
  static const warmCard = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C2B29);
  static const danger = Color(0xFFD64545);
  static const warn = Color(0xFFE8930C);
  static const ok = Color(0xFF2E9E5B);

  static ThemeData light({bool senior = false}) =>
      _build(Brightness.light, senior);
  static ThemeData dark({bool senior = false}) =>
      _build(Brightness.dark, senior);

  static ThemeData _build(Brightness b, bool senior) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b)
        .copyWith(
          surface: b == Brightness.light ? warmBg : const Color(0xFF10181A),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: senior
          ? VisualDensity.comfortable
          : VisualDensity.standard,
    );
    final textScale = senior ? 1.18 : 1.0;
    final tt = base.textTheme.apply(
      fontSizeFactor: textScale,
      bodyColor: b == Brightness.light ? ink : const Color(0xFFE8F0EE),
      displayColor: b == Brightness.light ? ink : const Color(0xFFE8F0EE),
    );
    final btnMin = senior ? const Size(64, 56) : const Size(48, 48);
    return base.copyWith(
      textTheme: tt,
      cardTheme: CardThemeData(
        elevation: 0,
        color: b == Brightness.light ? warmCard : const Color(0xFF1B2426),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: b == Brightness.light
                ? const Color(0xFFEAE2D6)
                : const Color(0xFF2A3436),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: btnMin,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: TextStyle(
            fontSize: senior ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: btnMin,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: b == Brightness.light
            ? const Color(0xFFF3EFE7)
            : const Color(0xFF232D2F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: b == Brightness.light
            ? Colors.white
            : const Color(0xFF141C1E),
        indicatorColor: seed.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: senior ? 13 : 12, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tt.titleLarge?.color,
        titleTextStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
