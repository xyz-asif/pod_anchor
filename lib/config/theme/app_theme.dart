import 'package:flutter/material.dart';

class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Font family
  static const String _fontFamily = 'Cera Pro';

  // ── Brand ──
  static const Color primaryColor = Color(0xFF7A8194); // muted slate-blue
  static const Color primaryDark = Color(0xFF656B7C); // deeper slate
  static const Color primaryLight = Color(0xFF2E3547); // muted navy highlight

  // ── Backgrounds ──
  static const Color backgroundColor = Color(0xFF1A1F2E); // deep dark navy
  static const Color surfaceColor = Color(0xFF232A3B); // elevated navy surface
  static const Color featureBackgroundColor = Color(0xFF2A3145); // feature panels
  static const Color featureIconBackgroundColor = Color(0xFF343D52); // icon bg

  // ── Chat Bubble Colors ──
  static const Color receivedBubbleColor = Color(0xFF3A4255); // steel-blue
  static const Color sentBubbleColor = Color(0xFF7E8CA2); // lighter dusty blue
  static const Color receivedBubbleTextColor = Color(0xFFDBDFE8);
  static const Color sentBubbleTextColor = Color(0xFF1A1F2E);

  // ── Text ──
  static const Color textDarkColor = Color(0xFFE8ECF2); // cream-white
  static const Color textMediumColor = Color(0xFF8B95A8); // muted blue-gray
  static const Color textLightColor = Color(0xFF5C6578); // dim slate

  // ── Accent / Chip ──
  static const Color chipBackgroundColor = Color(0xFF7A8194); // slate accent
  static const Color chipTextColor = Color(0xFFFFFFFF); // white on slate

  // ── Borders / Dividers ──
  static const Color borderColor = Color(0xFF2A3145); // subtle navy border

  // ── Status ──
  static const Color successColor = Color(0xFF4ADE80);
  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color warningColor = Color(0xFFFFB347);
  static const Color onlineColor = Color(0xFF4ADE80); // green ring like screenshot

  // ── Avatar ──
  static const Color avatarRingColor = Color(0xFF7A8194); // slate avatar ring
  static const Color avatarRingOnlineColor = Color(0xFF4ADE80); // green ring

  // ═══════════════════════════════════════════
  //  LIGHT THEME
  // ═══════════════════════════════════════════
  static final ThemeData light = ThemeData(
    useMaterial3: true,

    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: const Color(0xFF656B7C), // deeper slate for light readability
      secondary: const Color(0xFF6B7280),
      background: const Color(0xFFF8F6F4), // warm off-white
      surface: const Color(0xFFFFFFFF),
    ),

    // Scaffold Background Color
    scaffoldBackgroundColor: const Color(0xFFF8F6F4),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1F2E),
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1F2E),
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        color: Color(0xFF2A3145),
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        color: Color(0xFF6B7280),
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1F2E),
      ),
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1F2E),
      ),
      iconTheme: IconThemeData(color: Color(0xFF1A1F2E)),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF656B7C),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF656B7C),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFF656B7C), width: 1.5),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1EEED),
      contentPadding: const EdgeInsets.all(16),

      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: Color(0xFF6B7280),
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: Color(0xFF9CA3AF),
        fontSize: 13,
      ),

      prefixIconColor: const Color(0xFF6B7280),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E1DE), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E1DE), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF656B7C), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    ),

    // Radio Theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF656B7C);
        }
        return const Color(0xFF9CA3AF);
      }),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF656B7C);
        }
        return const Color(0xFF9CA3AF);
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E1DE), width: 1),
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF656B7C),
      foregroundColor: Colors.white,
      elevation: 3,
      shape: CircleBorder(),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF656B7C),
      unselectedItemColor: Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5E1DE),
      thickness: 1,
      space: 1,
    ),
  );

  // ═══════════════════════════════════════════
  //  DARK THEME (matched to screenshot)
  // ═══════════════════════════════════════════
  static final ThemeData dark = ThemeData(
    useMaterial3: true,

    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1F2E),
      primary: primaryColor,
      secondary: const Color(0xFF5C6578),
      background: backgroundColor,
      surface: surfaceColor,
      brightness: Brightness.dark,
    ),

    // Scaffold Background Color
    scaffoldBackgroundColor: backgroundColor,

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDarkColor,
      ),
      iconTheme: IconThemeData(color: textDarkColor),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textDarkColor,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textDarkColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        color: Color(0xFFCDD3DE), // soft readable
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        color: textMediumColor,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textDarkColor,
      ),
    ),

    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Outlined Button Theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: primaryColor, width: 1.5),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.all(16),

      labelStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: textMediumColor,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: _fontFamily,
        color: textLightColor,
        fontSize: 13,
      ),

      prefixIconColor: textMediumColor,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor.withOpacity(0.6), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
    ),

    // Radio Theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return textLightColor;
      }),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return textLightColor;
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderColor, width: 1),
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: backgroundColor,
      elevation: 3,
      shape: CircleBorder(),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceColor,
      selectedItemColor: textDarkColor,
      unselectedItemColor: textLightColor,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: borderColor,
      thickness: 1,
      space: 1,
    ),
  );
}