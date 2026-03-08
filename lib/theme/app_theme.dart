import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors (shared across themes)
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFF2196F3);
  static const Color errorColor = Color(0xFFF44336);

  // Dark theme colors
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color cardColor = Color(0xFF2C2C2C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textHint = Color(0xFF666666);

  // Light theme colors - Complete hard-defined system
  // 1. Main Background
  static const Color lightBackgroundColor = Color(0xFFFFFFFF); // Pure white
  static const Color lightSecondaryBackground = Color(
    0xFFFAFAFA,
  ); // Secondary section background

  // 2. Cards / Containers / Widgets
  static const Color lightCardColor = Color(0xFFF5F7FA); // Card background
  static const Color lightElevatedCardColor = Color(
    0xFFFFFFFF,
  ); // Elevated card
  static const Color lightCardBorder = Color(0xFFE5E7EB); // Card border
  static const Color lightDividerColor = Color(0xFFE5E7EB); // Divider lines

  // 3. Titles & Text
  static const Color lightMainTitle = Color(
    0xFF111827,
  ); // Main titles (Screen titles)
  static const Color lightSectionTitle = Color(0xFF1F2937); // Section titles
  static const Color lightTextPrimary = Color(0xFF1F2937); // Primary text
  static const Color lightTextSecondary = Color(0xFF4B5563); // Secondary text
  static const Color lightTextDisabled = Color(0xFF9CA3AF); // Disabled text

  // 4. Icons
  static const Color lightIconInactive = Color(0xFF6B7280); // Inactive icons
  static const Color lightIconDefault = Color(
    0xFF374151,
  ); // Default icon color inside cards

  // 5. Bottom Navigation Bar
  static const Color lightNavBarBackground = Color(
    0xFFFFFFFF,
  ); // Navbar background
  static const Color lightNavBarBorder = Color(0xFFE5E7EB); // Top border line
  static const Color lightNavBarInactive = Color(
    0xFF6B7280,
  ); // Inactive icon/text

  // 6. Buttons
  static const Color lightSecondaryButtonBg = Color(
    0xFFE5E7EB,
  ); // Secondary button background
  static const Color lightSecondaryButtonText = Color(
    0xFF1F2937,
  ); // Secondary button text

  // 7. Switches / Toggles
  static const Color lightSwitchInactiveTrack = Color(
    0xFFD1D5DB,
  ); // Inactive track

  // 8. Profile Header Gradient
  static const Color lightGradientStart = Color(
    0xFFE0F2FE,
  ); // Light blue gradient start
  static const Color lightGradientEnd = Color(0xFFFFFFFF); // White gradient end

  // Legacy aliases for compatibility (map to new system)
  static const Color lightSurfaceColor = lightCardColor;
  static const Color lightBorderColor = lightCardBorder;
  static const Color lightTextHint = lightIconInactive;

  // Typography
  static const String fontFamily = 'Inter';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackgroundColor,
      fontFamily: fontFamily,
      iconTheme: const IconThemeData(
        color: lightMainTitle, // Dark icons globally in Light Mode
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightCardColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackgroundColor,
        foregroundColor: lightMainTitle,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: lightMainTitle, // Dark icons in Light Mode
        ),
        titleTextStyle: TextStyle(
          color: lightMainTitle,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: const CardTheme(
        color: lightCardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: lightCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightNavBarBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightNavBarInactive,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: lightCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(
          color: lightIconInactive,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: lightMainTitle,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: lightSectionTitle,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          color: lightSectionTitle,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleSmall: TextStyle(
          color: lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        bodyLarge: TextStyle(
          color: lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.41,
        ),
        bodyMedium: TextStyle(
          color: lightTextSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.24,
        ),
        bodySmall: TextStyle(
          color: lightIconInactive,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.08,
        ),
        labelLarge: TextStyle(
          color: lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: fontFamily,
      iconTheme: const IconThemeData(
        color: textPrimary, // White icons globally in Dark Mode
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: textPrimary, // White icons in Dark Mode
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(
          color: textHint,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.41,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textHint,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
        ),
      ),
    );
  }

  // Custom text styles based on Figma design
  static const TextStyle priceTextStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.41,
  );

  static const TextStyle placeholderTextStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: textHint,
    letterSpacing: -0.41,
  );

  // Spacing constants
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Border radius constants
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Helper methods to get theme-aware colors
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardColor
        : lightCardColor;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceColor
        : lightSurfaceColor;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightTextPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondary
        : lightTextSecondary;
  }

  static Color getTextHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textHint
        : lightTextHint;
  }

  static Color getMainTitle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightMainTitle;
  }

  static Color getSectionTitle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightSectionTitle;
  }

  static Color getIconDefault(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : lightIconDefault;
  }
}
