// lib/theme/app_theme.dart
//
// The app's visual language: a warm, minimal palette (brand maroon on
// off-white), Manrope typography, one radius scale and soft fade-through page
// transitions. Both themes are produced by the same builder so they cannot
// drift apart.
//
// Widgets should read colors from `Theme.of(context).colorScheme` where
// possible; the static constants below exist for semantic "source" colors
// (Google Calendar / Canvas / personal) and status colors.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  // ── Brand & semantic colors ────────────────────────────────────────────────
  static const Color primary = Color(0xFF6F1D1B);
  static const Color primaryContainer = Color(0xFFF7EBE9);
  static const Color primaryContainerDark = Color(0xFF3B1E1C);

  /// Google Calendar identity — calm slate blue.
  static const Color secondary = Color(0xFF3F6C8F);
  static const Color secondaryContainer = Color(0xFFE6EEF4);

  /// Canvas identity — warm amber.
  static const Color canvasAmber = Color(0xFFB7641E);
  static const Color canvasAmberContainer = Color(0xFFFBEDE0);

  /// Personal items — sage green.
  static const Color personalTeal = Color(0xFF5B8A78);
  static const Color personalTealContainer = Color(0xFFE5F0EB);

  static const Color success = Color(0xFF3F7D5A);
  static const Color successContainer = Color(0xFFE3F1E8);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningContainer = Color(0xFFFBF1DA);
  static const Color errorRed = Color(0xFFB3372F);
  static const Color errorContainer = Color(0xFFFBE6E3);

  // ── Neutrals (warm) ────────────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF5F2EF);
  static const Color backgroundLight = Color(0xFFFAF8F6);
  static const Color outlineLight = Color(0xFFE7E2DD);
  static const Color outlineVariantLight = Color(0xFFF0ECE8);
  static const Color onSurfaceLight = Color(0xFF211C19);
  static const Color onSurfaceVariantLight = Color(0xFF6E655E);
  static const Color mutedLight = Color(0xFF9B928A);

  static const Color surfaceDark = Color(0xFF1F1B19);
  static const Color surfaceVariantDark = Color(0xFF2A2522);
  static const Color backgroundDark = Color(0xFF171412);
  static const Color outlineDark = Color(0xFF3A3430);
  static const Color outlineVariantDark = Color(0xFF2F2A27);
  static const Color onSurfaceDark = Color(0xFFF1EBE6);
  static const Color onSurfaceVariantDark = Color(0xFFB5ABA3);

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextTheme _textTheme(TextTheme base, Color color) {
    TextStyle s(double size, FontWeight w, {double? height, double? spacing}) =>
        GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: color,
        );

    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: s(36, FontWeight.w700, spacing: -0.5),
      displayMedium: s(28, FontWeight.w700, spacing: -0.3),
      displaySmall: s(22, FontWeight.w700, spacing: -0.2),
      headlineLarge: s(20, FontWeight.w700),
      headlineMedium: s(18, FontWeight.w600),
      headlineSmall: s(16, FontWeight.w600),
      titleLarge: s(15, FontWeight.w600),
      titleMedium: s(14, FontWeight.w600),
      titleSmall: s(13, FontWeight.w600),
      bodyLarge: s(15, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45),
      bodySmall: s(13, FontWeight.w400, height: 1.4),
      labelLarge: s(13, FontWeight.w600),
      labelMedium: s(12, FontWeight.w500),
      labelSmall: s(11, FontWeight.w500, spacing: 0.2),
    );
  }

  // ── Theme builder (shared by light + dark) ─────────────────────────────────
  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, scheme.onSurface);
    final radius = AppRadius.control;

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? backgroundDark : backgroundLight,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeThroughPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: outline(Colors.transparent),
        enabledBorder: outline(Colors.transparent),
        focusedBorder: outline(scheme.primary, 1.5),
        errorBorder: outline(scheme.error),
        focusedErrorBorder: outline(scheme.error, 1.5),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant.withAlpha(180)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }

  static ThemeData get lightTheme => _build(const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: Color(0xFF4A1210),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: Color(0xFF1F3F57),
        tertiary: personalTeal,
        onTertiary: Colors.white,
        tertiaryContainer: personalTealContainer,
        onTertiaryContainer: Color(0xFF1D3B30),
        error: errorRed,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: Color(0xFF6B1C17),
        surface: surfaceLight,
        onSurface: onSurfaceLight,
        surfaceContainerHighest: surfaceVariantLight,
        onSurfaceVariant: onSurfaceVariantLight,
        outline: outlineLight,
        outlineVariant: outlineVariantLight,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: onSurfaceLight,
        onInverseSurface: backgroundLight,
        inversePrimary: Color(0xFFE8A9A3),
      ));

  static ThemeData get darkTheme => _build(const ColorScheme.dark(
        primary: Color(0xFFE8A9A3),
        onPrimary: Color(0xFF4A1210),
        primaryContainer: primaryContainerDark,
        onPrimaryContainer: Color(0xFFF7D9D5),
        secondary: Color(0xFF8FB8D6),
        onSecondary: Color(0xFF12293A),
        secondaryContainer: Color(0xFF1F3F57),
        onSecondaryContainer: Color(0xFFCFE3F1),
        tertiary: Color(0xFF9CC7B5),
        onTertiary: Color(0xFF12291F),
        tertiaryContainer: Color(0xFF1D3B30),
        onTertiaryContainer: Color(0xFFCFE9DD),
        error: Color(0xFFF2A29B),
        onError: Color(0xFF4A0E0A),
        errorContainer: Color(0xFF6B1C17),
        onErrorContainer: Color(0xFFFBD5D1),
        surface: surfaceDark,
        onSurface: onSurfaceDark,
        surfaceContainerHighest: surfaceVariantDark,
        onSurfaceVariant: onSurfaceVariantDark,
        outline: outlineDark,
        outlineVariant: outlineVariantDark,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: onSurfaceDark,
        onInverseSurface: surfaceDark,
        inversePrimary: primary,
      ));

  // ── Source / status helpers ────────────────────────────────────────────────
  static Color sourceColor(String source) {
    switch (source) {
      case 'google_calendar':
        return secondary;
      case 'canvas':
        return canvasAmber;
      case 'personal':
        return personalTeal;
      default:
        return primary;
    }
  }

  static Color sourceContainerColor(String source) {
    switch (source) {
      case 'google_calendar':
        return secondaryContainer;
      case 'canvas':
        return canvasAmberContainer;
      case 'personal':
        return personalTealContainer;
      default:
        return primaryContainer;
    }
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return errorRed;
      case 'medium':
        return canvasAmber;
      case 'low':
        return success;
      default:
        return mutedLight;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'submitted':
        return success;
      case 'graded':
        return primary;
      case 'overdue':
        return errorRed;
      case 'due_soon':
        return canvasAmber;
      default:
        return mutedLight;
    }
  }
}

/// Subtle fade + 2% rise. Used for every route so switching tabs feels
/// continuous instead of sliding whole screens around.
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
