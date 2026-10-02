import 'package:flutter/material.dart';
import 'ui/status_colors.dart';

class AppTheme {
  // =========================================================
  // COLOR PALETTE
  // =========================================================

  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);

  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF06B6D4);

  // LIGHT COLORS
  static const Color background = Color(0xFFF6F8FC);
  static const Color cardBackground = Colors.white;

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color border = Color(0xFFE5E7EB);

  // DARK COLORS
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkCardBackground = Color(0xFF1E293B);
  static const Color darkSurface = Color(0xFF111827);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  static const Color darkBorder = Color(0xFF334155);

  // =========================================================
  // LIGHT THEME
  // =========================================================

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,

      primaryContainer: const Color(0xFFE0E7FF),
      onPrimaryContainer: primaryDark,

      secondary: secondary,
      onSecondary: Colors.white,

      secondaryContainer: const Color(0xFFEDE9FE),
      onSecondaryContainer: const Color(0xFF5B21B6),

      surface: cardBackground,
      onSurface: textPrimary,

      surfaceContainerHighest: const Color(0xFFF1F3F8),
      onSurfaceVariant: textSecondary,

      outline: border,
    );

    return ThemeData(
      // =====================================================
      // GENERAL
      // =====================================================

      brightness: Brightness.light,

      useMaterial3: true,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: background,

      fontFamily: 'Inter',

      visualDensity: VisualDensity.standard,

      // =====================================================
      // APP BAR
      // =====================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,

        foregroundColor: textPrimary,

        elevation: 0,

        scrolledUnderElevation: 0,

        centerTitle: false,

        surfaceTintColor: Colors.transparent,

        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),

        iconTheme: IconThemeData(
          color: textPrimary,
          size: 24,
        ),
      ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBarTheme:
      const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,

        selectedItemColor: primary,

        unselectedItemColor: textSecondary,

        type: BottomNavigationBarType.fixed,

        elevation: 12,

        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),

        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // =====================================================
      // ELEVATED BUTTON
      // =====================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,

          foregroundColor: Colors.white,

          disabledBackgroundColor:
          primary.withOpacity(0.5),

          disabledForegroundColor:
          Colors.white.withOpacity(0.8),

          elevation: 0,

          // Aman digunakan di dalam Row
          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),

          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // =====================================================
      // TEXT BUTTON
      // =====================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,

          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // OUTLINED BUTTON
      // =====================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,

          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          side: const BorderSide(
            color: primary,
            width: 1.2,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // INPUT DECORATION
      // =====================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),

        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),

        prefixIconColor: textSecondary,

        suffixIconColor: textSecondary,

        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: border,
            width: 1,
          ),
        ),

        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: border,
            width: 1,
          ),
        ),

        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),

        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),

        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),

        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Colors.redAccent,
        ),
      ),

      // =====================================================
      // CARD
      // =====================================================

      cardTheme: CardThemeData(
        color: Colors.white,

        elevation: 0,

        margin: EdgeInsets.zero,

        shadowColor: Colors.black12,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),

          side: const BorderSide(
            color: border,
            width: 0.7,
          ),
        ),
      ),

      // =====================================================
      // ICON
      // =====================================================

      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 24,
      ),

      // =====================================================
      // DIVIDER
      // =====================================================

      dividerTheme: const DividerThemeData(
        color: border,

        thickness: 1,

        space: 1,
      ),

      // =====================================================
      // CHECKBOX
      // =====================================================

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }

            return Colors.white;
          },
        ),

        checkColor: WidgetStateProperty.all(
          Colors.white,
        ),

        side: const BorderSide(
          color: border,
          width: 1.5,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      // =====================================================
      // SWITCH
      // =====================================================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }

            return Colors.white;
          },
        ),

        trackColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }

            return const Color(0xFFD1D5DB);
          },
        ),

        trackOutlineColor:
        WidgetStateProperty.all(
          Colors.transparent,
        ),
      ),

      // =====================================================
      // PROGRESS INDICATOR
      // =====================================================

      progressIndicatorTheme:
      const ProgressIndicatorThemeData(
        color: primary,

        linearTrackColor: Color(0xFFE5E7EB),

        circularTrackColor: Color(0xFFE5E7EB),
      ),

      // =====================================================
      // SNACKBAR
      // =====================================================

      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,

        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Colors.white,
        ),

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        elevation: 4,
      ),

      // =====================================================
      // DIALOG
      // =====================================================

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,

        elevation: 8,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),

        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),

      // =====================================================
      // TEXT THEME
      // =====================================================

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.2,
        ),

        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.2,
        ),

        displaySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.25,
        ),

        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.25,
        ),

        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),

        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),

        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),

        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),

        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.35,
        ),

        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.5,
        ),

        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),

        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.4,
        ),

        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),

        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          height: 1.3,
        ),

        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.3,
        ),
      ),

      // =====================================================
      // STATUS COLORS
      // =====================================================

      extensions: const [
        StatusColors(
          submittedBg: Color(0xFFC8E6C9),
          submittedFg: Color(0xFF1B5E20),

          pendingBg: Color(0xFFFFE0B2),
          pendingFg: Color(0xFFE65100),
        ),
      ],
    );
  }

  // =========================================================
  // DARK THEME
  // =========================================================

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,

      primaryContainer: const Color(0xFF312E81),
      onPrimaryContainer: const Color(0xFFE0E7FF),

      secondary: secondary,
      onSecondary: Colors.white,

      secondaryContainer: const Color(0xFF4C1D95),
      onSecondaryContainer: const Color(0xFFEDE9FE),

      surface: darkCardBackground,
      onSurface: darkTextPrimary,

      surfaceContainerHighest: const Color(0xFF273449),
      onSurfaceVariant: darkTextSecondary,

      outline: darkBorder,
    );

    return ThemeData(
      // =====================================================
      // GENERAL
      // =====================================================

      brightness: Brightness.dark,

      useMaterial3: true,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: darkBackground,

      fontFamily: 'Inter',

      visualDensity: VisualDensity.standard,

      // =====================================================
      // APP BAR
      // =====================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,

        foregroundColor: darkTextPrimary,

        elevation: 0,

        scrolledUnderElevation: 0,

        centerTitle: false,

        surfaceTintColor: Colors.transparent,

        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),

        iconTheme: IconThemeData(
          color: darkTextPrimary,
          size: 24,
        ),
      ),

      // =====================================================
      // BOTTOM NAVIGATION
      // =====================================================

      bottomNavigationBarTheme:
      const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,

        selectedItemColor: primary,

        unselectedItemColor: darkTextSecondary,

        type: BottomNavigationBarType.fixed,

        elevation: 12,

        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),

        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // =====================================================
      // ELEVATED BUTTON
      // =====================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,

          foregroundColor: Colors.white,

          disabledBackgroundColor:
          primary.withOpacity(0.5),

          disabledForegroundColor:
          Colors.white.withOpacity(0.8),

          elevation: 0,

          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),

          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),

      // =====================================================
      // TEXT BUTTON
      // =====================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFA5B4FC),

          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // OUTLINED BUTTON
      // =====================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA5B4FC),

          minimumSize: const Size(0, 52),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          side: const BorderSide(
            color: primary,
            width: 1.2,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // INPUT DECORATION
      // =====================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: darkCardBackground,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
        ),

        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),

        prefixIconColor: darkTextSecondary,

        suffixIconColor: darkTextSecondary,

        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),

        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: darkBorder,
            width: 1,
          ),
        ),

        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),

        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),

        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          borderSide: BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),

        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Colors.redAccent,
        ),
      ),

      // =====================================================
      // CARD
      // =====================================================

      cardTheme: CardThemeData(
        color: darkCardBackground,

        elevation: 0,

        margin: EdgeInsets.zero,

        shadowColor: Colors.black54,

        surfaceTintColor: Colors.transparent,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),

          side: const BorderSide(
            color: darkBorder,
            width: 0.7,
          ),
        ),
      ),

      // =====================================================
      // ICON
      // =====================================================

      iconTheme: const IconThemeData(
        color: darkTextPrimary,
        size: 24,
      ),

      // =====================================================
      // DIVIDER
      // =====================================================

      dividerTheme: const DividerThemeData(
        color: darkBorder,

        thickness: 1,

        space: 1,
      ),

      // =====================================================
      // CHECKBOX
      // =====================================================

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }

            return darkCardBackground;
          },
        ),

        checkColor: WidgetStateProperty.all(
          Colors.white,
        ),

        side: const BorderSide(
          color: darkBorder,
          width: 1.5,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),

      // =====================================================
      // SWITCH
      // =====================================================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }

            return darkTextSecondary;
          },
        ),

        trackColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }

            return const Color(0xFF475569);
          },
        ),

        trackOutlineColor:
        WidgetStateProperty.all(
          Colors.transparent,
        ),
      ),

      // =====================================================
      // PROGRESS INDICATOR
      // =====================================================

      progressIndicatorTheme:
      const ProgressIndicatorThemeData(
        color: primary,

        linearTrackColor: Color(0xFF334155),

        circularTrackColor: Color(0xFF334155),
      ),

      // =====================================================
      // SNACKBAR
      // =====================================================

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF020617),

        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Colors.white,
        ),

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        elevation: 4,
      ),

      // =====================================================
      // DIALOG
      // =====================================================

      dialogTheme: DialogThemeData(
        backgroundColor: darkCardBackground,

        elevation: 8,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),

        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),

        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
        ),
      ),

      // =====================================================
      // TEXT THEME
      // =====================================================

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          height: 1.2,
        ),

        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          height: 1.2,
        ),

        displaySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.25,
        ),

        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          height: 1.25,
        ),

        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.3,
        ),

        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.3,
        ),

        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          height: 1.3,
        ),

        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.35,
        ),

        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.35,
        ),

        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkTextPrimary,
          height: 1.5,
        ),

        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.5,
        ),

        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.4,
        ),

        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.3,
        ),

        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkTextSecondary,
          height: 1.3,
        ),

        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
          height: 1.3,
        ),
      ),

      // =====================================================
      // STATUS COLORS
      // =====================================================

      extensions: const [
        StatusColors(
          submittedBg: Color(0xFF14532D),
          submittedFg: Color(0xFFBBF7D0),

          pendingBg: Color(0xFF7C2D12),
          pendingFg: Color(0xFFFED7AA),
        ),
      ],
    );
  }
}