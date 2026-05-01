import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryContainer = Color(0xFFEEEDFD);
  static const Color primaryContainerDark = Color(0xFF2D2B6B);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color secondaryContainer = Color(0xFFE0F2FE);
  static const Color canvasAmber = Color(0xFFF59E0B);
  static const Color canvasAmberContainer = Color(0xFFFEF3C7);
  static const Color personalTeal = Color(0xFF14B8A6);
  static const Color personalTealContainer = Color(0xFFCCFBF1);
  static const Color success = Color(0xFF10B981);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);

  // Light theme surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF8F7FF);
  static const Color backgroundLight = Color(0xFFF3F4F9);
  static const Color outlineLight = Color(0xFFE2E1F0);
  static const Color outlineVariantLight = Color(0xFFEEEDF8);

  // Dark theme surfaces
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceVariantDark = Color(0xFF252542);
  static const Color backgroundDark = Color(0xFF12121F);
  static const Color outlineDark = Color(0xFF3A3A5C);
  static const Color outlineVariantDark = Color(0xFF2E2E4A);

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: 36,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: Color(0xFF1E1B6E),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: Color(0xFF0C4A6E),
        tertiary: personalTeal,
        onTertiary: Colors.white,
        tertiaryContainer: personalTealContainer,
        onTertiaryContainer: Color(0xFF042F2E),
        error: errorRed,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: Color(0xFF7F1D1D),
        surface: surfaceLight,
        onSurface: Color(0xFF1C1B2E),
        surfaceContainerHighest: surfaceVariantLight,
        onSurfaceVariant: Color(0xFF6B6A8A),
        outline: outlineLight,
        outlineVariant: outlineVariantLight,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFF1C1B2E),
        onInverseSurface: Color(0xFFF3F4F9),
        inversePrimary: Color(0xFFB0ABFF),
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1C1B2E),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantLight,
        selectedColor: primaryContainer,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: outlineLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineLight),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineLight),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: errorRed),
        ),
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6B6A8A),
        ),
        hintStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF9CA3AF),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: false,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariantLight,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineLight),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF818CF8),
        onPrimary: Color(0xFF1E1B6E),
        primaryContainer: primaryContainerDark,
        onPrimaryContainer: Color(0xFFB0ABFF),
        secondary: Color(0xFF38BDF8),
        onSecondary: Color(0xFF0C4A6E),
        secondaryContainer: Color(0xFF0C4A6E),
        onSecondaryContainer: Color(0xFFBAE6FD),
        tertiary: Color(0xFF2DD4BF),
        onTertiary: Color(0xFF042F2E),
        tertiaryContainer: Color(0xFF042F2E),
        onTertiaryContainer: Color(0xFF99F6E4),
        error: Color(0xFFF87171),
        onError: Color(0xFF7F1D1D),
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Color(0xFFFECACA),
        surface: surfaceDark,
        onSurface: Color(0xFFE8E7FF),
        surfaceContainerHighest: surfaceVariantDark,
        onSurfaceVariant: Color(0xFFA5A3C8),
        outline: outlineDark,
        outlineVariant: outlineVariantDark,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFFE8E7FF),
        onInverseSurface: Color(0xFF1A1A2E),
        inversePrimary: primary,
      ),
      scaffoldBackgroundColor: backgroundDark,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8E7FF),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: primaryContainerDark,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF818CF8),
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantDark,
        selectedColor: primaryContainerDark,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: outlineDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineDark),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineDark),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF818CF8), width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFF87171)),
        ),
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFA5A3C8),
        ),
        hintStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF6B7280),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: false,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariantDark,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineDark),
        ),
      ),
    );
  }

  // Source color helpers
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
        return const Color(0xFF9CA3AF);
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
      case 'upcoming':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}
