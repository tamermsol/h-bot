import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// H-Bot Design System — derived from design/01-DESIGN-TOKENS.md
// Every token traces back to h-bot.tech
// ═══════════════════════════════════════════════════════════════

// ─── Color Primitives ─────────────────────────────────────────
// Never use these directly in components — use HBotColors below.
class _Blue {
  static const blue50 = Color(0xFFF0F7FF);
  static const blue100 = Color(0xFFD6ECFE);
  static const blue200 = Color(0xFF8CD1FB); // gradient endpoint
  static const blue300 = Color(0xFF5BBDF7);
  static const blue400 = Color(0xFF2FB8EC); // bright accent
  static const blue500 = Color(0xFF0883FD); // PRIMARY
  static const blue600 = Color(0xFF1070AD);
  static const blue700 = Color(0xFF094972);
  static const blue800 = Color(0xFF006080);
  static const blue900 = Color(0xFF0A1628); // deep navy
  static const blue950 = Color(0xFF010510);
}

class _Neutral {
  static const n0 = Color(0xFFFFFFFF);
  static const n50 = Color(0xFFF8F9FB);
  static const n100 = Color(0xFFF0F2F5);
  static const n200 = Color(0xFFE8ECF1);
  static const n300 = Color(0xFFD1D7E0);
  static const n400 = Color(0xFFA0AAB8);
  static const n500 = Color(0xFF7A8494);
  static const n600 = Color(0xFF5A6577);
  static const n700 = Color(0xFF3D4A5C);
  static const n800 = Color(0xFF1A202B);
  static const n900 = Color(0xFF0F1520);
  static const n950 = Color(0xFF010510);
}

// ─── Semantic Colors (Light Mode) ─────────────────────────────
class HBotColors {
  // Primary
  static const primary = _Blue.blue500;
  static const primaryLight = _Blue.blue200;
  static const primaryHover = Color(0xFF0773E0);
  static const primaryDisabled = _Neutral.n300;
  static const primarySurface = _Blue.blue50; // tinted bg

  // Surfaces
  static const backgroundLight = _Neutral.n50;
  static const surfaceLight = _Neutral.n0;
  static const cardLight = _Neutral.n0;
  static const cardHover = _Neutral.n100;
  static const elevatedLight = _Neutral.n0;
  static const inputBg = _Neutral.n0;

  // Borders
  static const borderLight = _Neutral.n200;
  static const borderSubtle = _Neutral.n100;

  // Text
  static const textPrimaryLight = _Blue.blue900;
  static const textSecondaryLight = _Neutral.n600;
  static const textTertiaryLight = _Neutral.n500;
  static const textOnPrimary = _Neutral.n0;

  // Icons
  static const iconDefault = _Neutral.n600;
  static const iconActive = _Blue.blue500;

  // Semantic
  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);

  // Toggle
  static const toggleTrackOff = _Neutral.n300;
  static const toggleThumb = _Neutral.n0;

  // Neutrals (direct access for special cases)
  static const neutral0 = _Neutral.n0;
  static const neutral50 = _Neutral.n50;
  static const neutral100 = _Neutral.n100;
  static const neutral200 = _Neutral.n200;
  static const neutral300 = _Neutral.n300;
  static const neutral400 = _Neutral.n400;
  static const neutral500 = _Neutral.n500;
  static const neutral600 = _Neutral.n600;
  static const neutral700 = _Neutral.n700;
  static const neutral800 = _Neutral.n800;
  static const neutral900 = _Neutral.n900;

  // Dark mode
  static const backgroundDark = _Neutral.n950;
  static const cardDark = _Neutral.n800;
  static const borderDark = Color(0xFF181B1F);
  static const textPrimaryDark = _Neutral.n0;
  static const textSecondaryDark = Color(0xFFC7C9CC);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [_Blue.blue500, _Blue.blue200],
  );

  static const primaryGradientReversed = LinearGradient(
    colors: [_Blue.blue200, _Blue.blue500],
  );

  // Device type colors
  static const deviceRelay = Color(0xFF3B82F6);
  static const deviceDimmer = Color(0xFFF59E0B);
  static const deviceSensor = Color(0xFF22C55E);
  static const deviceShutter = Color(0xFF8B5CF6);
}

// ─── Spacing (4px base) ───────────────────────────────────────
class HBotSpacing {
  static const space0 = 0.0;
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space7 = 32.0;
  static const space8 = 40.0;
  static const space9 = 48.0;
  static const space10 = 64.0;
  static const screenPadding = 20.0;
}

// ─── Border Radius ────────────────────────────────────────────
class HBotRadius {
  static const none = 0.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const xl = 24.0;
  static const full = 9999.0;

  static final smallRadius = BorderRadius.circular(small);
  static final mediumRadius = BorderRadius.circular(medium);
  static final largeRadius = BorderRadius.circular(large);
  static final xlRadius = BorderRadius.circular(xl);
  static final fullRadius = BorderRadius.circular(full);
}

// ─── Shadows ──────────────────────────────────────────────────
class HBotShadows {
  static const none = <BoxShadow>[];

  static const small = [
    BoxShadow(
      color: Color(0x0F0A1628), // rgba(10,22,40,0.06)
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A0A1628), // rgba(10,22,40,0.04)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const medium = [
    BoxShadow(
      color: Color(0x140A1628), // rgba(10,22,40,0.08)
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const large = [
    BoxShadow(
      color: Color(0x1F0A1628), // rgba(10,22,40,0.12)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const glow = [
    BoxShadow(
      color: Color(0x260883FD), // rgba(8,131,253,0.15)
      blurRadius: 20,
    ),
  ];
}

// ─── Motion / Animation ──────────────────────────────────────
class HBotDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const skeleton = Duration(milliseconds: 1500);
}

class HBotCurves {
  static const standard = Curves.easeInOut;
  static const decelerate = Curves.easeOut;
  static const accelerate = Curves.easeIn;
  static const sharp = Curves.easeInOutCubic;
}

// ─── Helper Widgets & Decorations ─────────────────────────────

/// Primary gradient button background
BoxDecoration hbotPrimaryButtonDecoration({bool disabled = false}) {
  return BoxDecoration(
    gradient: disabled ? null : HBotColors.primaryGradient,
    color: disabled ? HBotColors.primaryDisabled : null,
    borderRadius: HBotRadius.mediumRadius,
    boxShadow: disabled ? null : HBotShadows.medium,
  );
}

/// Gradient text effect (brand signature from website)
Widget hbotGradientText(String text, TextStyle style) {
  return ShaderMask(
    shaderCallback: (bounds) =>
        HBotColors.primaryGradient.createShader(bounds),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

/// Status indicator dot
Widget hbotStatusDot({
  required Color color,
  double size = 8,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
    ),
  );
}

/// Section header — overline style
Widget hbotSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(
      left: HBotSpacing.space5,
      right: HBotSpacing.space5,
      top: HBotSpacing.space6,
      bottom: HBotSpacing.space2,
    ),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: HBotColors.textSecondaryLight,
      ),
    ),
  );
}

// ─── Theme Data ───────────────────────────────────────────────
class AppTheme {
  // Legacy statics (for backward compatibility during migration)
  static const Color primaryColor = HBotColors.primary;
  static const Color secondaryColor = HBotColors.primaryLight;
  static const Color accentColor = HBotColors.success;
  static const Color warningColor = HBotColors.warning;
  static const Color errorColor = HBotColors.error;
  static const Color textSecondary = HBotColors.textSecondaryLight;
  static const Color textPrimary = HBotColors.textPrimaryLight;
  static const Color textHint = HBotColors.textTertiaryLight;
  static const Color cardColor = HBotColors.cardLight;
  static const Color backgroundColor = HBotColors.backgroundLight;
  static const Color surfaceColor = HBotColors.surfaceLight;
  static const Color lightBackgroundColor = HBotColors.backgroundLight;
  static const Color lightCardColor = HBotColors.cardLight;
  static const Color lightCardBorder = HBotColors.borderLight;
  static const Color lightBorderColor = HBotColors.borderLight;
  static const Color lightSurfaceColor = HBotColors.surfaceLight;
  static const Color lightTextPrimary = HBotColors.textPrimaryLight;
  static const Color lightTextSecondary = HBotColors.textSecondaryLight;
  static const Color lightGradientStart = Color(0xFFE0F2FE);
  static const Color lightGradientEnd = Color(0xFFFFFFFF);
  static const double paddingSmall = HBotSpacing.space2;
  static const double paddingMedium = HBotSpacing.space4;
  static const double paddingLarge = HBotSpacing.space6;
  static const double radiusSmall = HBotRadius.small;
  static const double radiusMedium = HBotRadius.medium;
  static const double radiusLarge = HBotRadius.large;

  static final TextStyle priceTextStyle = const TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: HBotColors.textPrimaryLight,
  );

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.cardDark
        : HBotColors.cardLight;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.textPrimaryDark
        : HBotColors.textPrimaryLight;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.textSecondaryDark
        : HBotColors.textSecondaryLight;
  }

  static Color getTextHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.textSecondaryDark
        : HBotColors.textTertiaryLight;
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'DM Sans',
      scaffoldBackgroundColor: HBotColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: HBotColors.primary,
        secondary: HBotColors.primaryLight,
        surface: HBotColors.surfaceLight,
        error: HBotColors.error,
        onPrimary: HBotColors.textOnPrimary,
        onSurface: HBotColors.textPrimaryLight,
        onError: HBotColors.textOnPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.5,
          color: HBotColors.textPrimaryLight,
        ),
        displayMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.29,
          letterSpacing: -0.5,
          color: HBotColors.textPrimaryLight,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.33,
          letterSpacing: -0.3,
          color: HBotColors.textPrimaryLight,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.27,
          letterSpacing: -0.3,
          color: HBotColors.textPrimaryLight,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.30,
          letterSpacing: -0.2,
          color: HBotColors.textPrimaryLight,
        ),
        titleLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.1,
          color: HBotColors.textPrimaryLight,
        ),
        titleMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.38,
          color: HBotColors.textPrimaryLight,
        ),
        titleSmall: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.43,
          color: HBotColors.textPrimaryLight,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.50,
          color: HBotColors.textPrimaryLight,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.43,
          color: HBotColors.textSecondaryLight,
        ),
        bodySmall: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.33,
          letterSpacing: 0.1,
          color: HBotColors.textSecondaryLight,
        ),
        labelLarge: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.38,
          color: HBotColors.textPrimaryLight,
        ),
        labelMedium: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.43,
          letterSpacing: 0.1,
          color: HBotColors.textPrimaryLight,
        ),
        labelSmall: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.33,
          letterSpacing: 0.2,
          color: HBotColors.textPrimaryLight,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HBotColors.backgroundLight,
        foregroundColor: HBotColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.27,
          letterSpacing: -0.3,
          color: HBotColors.textPrimaryLight,
        ),
        iconTheme: IconThemeData(
          color: HBotColors.iconDefault,
          size: 24,
        ),
      ),
      cardTheme: CardTheme(
        color: HBotColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.largeRadius,
          side: const BorderSide(color: HBotColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HBotColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HBotSpacing.space4,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.error, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: HBotColors.textTertiaryLight,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: HBotColors.textSecondaryLight,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: HBotColors.error,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 52),
          backgroundColor: HBotColors.primary,
          foregroundColor: HBotColors.textOnPrimary,
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: HBotSpacing.space4,
            vertical: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 52),
          foregroundColor: HBotColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          side: const BorderSide(color: HBotColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: HBotSpacing.space4,
            vertical: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: HBotColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.smallRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space3),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(HBotColors.toggleThumb),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? HBotColors.primary
              : HBotColors.toggleTrackOff;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HBotColors.surfaceLight,
        selectedItemColor: HBotColors.primary,
        unselectedItemColor: HBotColors.neutral400,
        selectedLabelStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: HBotColors.elevatedLight,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.xlRadius,
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryLight,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryLight,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HBotColors.elevatedLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(HBotRadius.xl),
            topRight: Radius.circular(HBotRadius.xl),
          ),
        ),
        dragHandleColor: HBotColors.neutral300,
        dragHandleSize: Size(36, 4),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HBotColors.neutral800,
        contentTextStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textOnPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.mediumRadius,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: HBotColors.primary,
        foregroundColor: HBotColors.textOnPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: HBotColors.borderSubtle,
        thickness: 1,
        space: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HBotColors.primary,
        linearTrackColor: HBotColors.neutral200,
        circularTrackColor: HBotColors.neutral200,
      ),
    );
  }

  // Dark theme stub for future
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.backgroundDark
        : HBotColors.backgroundLight;
  }

  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.backgroundDark
        : HBotColors.surfaceLight;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? HBotColors.borderDark
        : HBotColors.borderLight;
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'DM Sans',
      scaffoldBackgroundColor: HBotColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: HBotColors.primary,
        secondary: HBotColors.primaryLight,
        surface: HBotColors.cardDark,
        error: HBotColors.error,
        onPrimary: HBotColors.textOnPrimary,
        onSurface: HBotColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HBotColors.backgroundDark,
        foregroundColor: HBotColors.textPrimaryDark,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: HBotColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.mediumRadius,
          side: const BorderSide(color: HBotColors.borderDark, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HBotColors.backgroundDark,
        selectedItemColor: HBotColors.primary,
        unselectedItemColor: HBotColors.textSecondaryDark,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: HBotColors.cardDark,
        titleTextStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryDark,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HBotColors.cardDark,
      ),
      dividerTheme: const DividerThemeData(
        color: HBotColors.borderDark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HBotColors.primary;
          return HBotColors.textSecondaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HBotColors.primary.withOpacity(0.3);
          return HBotColors.borderDark;
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: HBotColors.cardDark,
        contentTextStyle: TextStyle(color: HBotColors.textPrimaryDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: HBotColors.backgroundDark,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.primary),
        ),
        labelStyle: const TextStyle(color: HBotColors.textSecondaryDark),
        hintStyle: const TextStyle(color: HBotColors.textSecondaryDark),
      ),
    );
  }
}

/// Extension on BuildContext for easy theme-aware color access.
/// Use these instead of HBotColors.xxxLight directly.
extension HBotThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  
  Color get hBackground => isDark ? HBotColors.backgroundDark : HBotColors.backgroundLight;
  Color get hCard => isDark ? HBotColors.cardDark : HBotColors.cardLight;
  Color get hSurface => isDark ? HBotColors.backgroundDark : HBotColors.surfaceLight;
  Color get hBorder => isDark ? HBotColors.borderDark : HBotColors.borderLight;
  Color get hTextPrimary => isDark ? HBotColors.textPrimaryDark : HBotColors.textPrimaryLight;
  Color get hTextSecondary => isDark ? HBotColors.textSecondaryDark : HBotColors.textSecondaryLight;
  Color get hTextTertiary => isDark ? HBotColors.textSecondaryDark : HBotColors.textTertiaryLight;
}
