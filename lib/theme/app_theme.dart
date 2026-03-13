import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// H-Bot Design System
/// Derived from h-bot.tech website branding
/// Primary: #0883FD (Electric Blue) | Accent: #8CD1FB (Sky Blue)
/// Font: Inter | Light mode primary, dark mode tokens included

class HBotColors {
  HBotColors._();

  // ─── Brand Colors (from h-bot.tech) ───
  static const Color primary = Color(0xFF0883FD);
  static const Color primaryLight = Color(0xFF8CD1FB);
  static const Color primaryDark = Color(0xFF0668CA);
  static const Color primaryHover = Color(0xFF0773E0);
  static const Color primarySurface = Color(0xFFEBF5FF);
  static const Color primarySurfaceStrong = Color(0xFFD6EBFF);

  // ─── Blue Primitives (from design tokens) ───
  static const Color blue50 = Color(0xFFF0F7FF);
  static const Color blue100 = Color(0xFFD6ECFE);
  static const Color blue200 = Color(0xFF8CD1FB);
  static const Color blue300 = Color(0xFF5BBDF7);
  static const Color blue400 = Color(0xFF2FB8EC);
  static const Color blue500 = Color(0xFF0883FD);
  static const Color blue600 = Color(0xFF1070AD);
  static const Color blue700 = Color(0xFF094972);
  static const Color blue800 = Color(0xFF006080);
  static const Color blue900 = Color(0xFF0A1628);
  static const Color blue950 = Color(0xFF010510);

  // ─── Brand Gradient (left to right per design spec) ───
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
  );

  static const LinearGradient primaryGradientReversed = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFF8CD1FB), Color(0xFF0883FD)],
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF22C55E), Color(0xFF86EFAC)],
  );

  static const LinearGradient decorativeGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1070AD), Color(0xFFCBD9DE)],
  );

  // ─── Semantic Colors (updated to match design tokens) ───
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color info = Color(0xFF0883FD);
  static const Color infoLight = Color(0xFFEBF5FF);

  // ─── Neutral Palette (blue-tinted per design tokens) ───
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8F9FB);
  static const Color neutral100 = Color(0xFFF0F2F5);
  static const Color neutral200 = Color(0xFFE8ECF1);
  static const Color neutral300 = Color(0xFFD1D7E0);
  static const Color neutral400 = Color(0xFFA0AAB8);
  static const Color neutral500 = Color(0xFF7A8494);
  static const Color neutral600 = Color(0xFF5A6577);
  static const Color neutral700 = Color(0xFF3D4A5C);
  static const Color neutral800 = Color(0xFF1A202B);
  static const Color neutral900 = Color(0xFF0A1628);
  static const Color neutral950 = Color(0xFF010510);

  // ─── Decorative Neutrals ───
  static const Color silver = Color(0xFFCBD9DE);
  static const Color darkBorder = Color(0xFF181B1F);

  // ─── Semantic Surface Tokens — Light Mode ───
  static const Color surfacePrimarySubtle = Color(0xFFF0F7FF);
  static const Color surfaceDestructiveSubtle = Color(0xFFFEE2E2);
  static const Color surfaceCardHover = Color(0xFFF0F2F5);

  // ─── Semantic Border Tokens ───
  static const Color borderFocused = Color(0xFF0883FD);
  static const Color borderError = Color(0xFFEF4444);
  static const Color borderSuccess = Color(0xFF22C55E);

  // ─── Toggle Tokens ───
  static const Color toggleTrackOff = Color(0xFFD1D7E0);
  static const Color toggleThumb = Color(0xFFFFFFFF);

  // ─── Primary Disabled ───
  static const Color primaryDisabled = Color(0xFFD1D7E0);

  // ─── Device Type Colors ───
  static const Color deviceSwitch = Color(0xFF0883FD);
  static const Color deviceDimmer = Color(0xFFF59E0B);
  static const Color deviceSensor = Color(0xFF22C55E);
  static const Color deviceShutter = Color(0xFF8B5CF6);
  static const Color devicePower = Color(0xFFEF4444);

  // ─── Light Mode Surfaces ───
  static const Color backgroundLight = Color(0xFFF8F9FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE8ECF1);
  static const Color dividerLight = Color(0xFFF1F3F5);

  // ─── Light Mode Text ───
  static const Color textPrimaryLight = Color(0xFF0A1628);
  static const Color textSecondaryLight = Color(0xFF5A6577);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Dark Mode Surfaces (from h-bot.tech website / design tokens) ───
  static const Color backgroundDark = Color(0xFF010510);
  static const Color surfaceDark = Color(0xFF0F1729);
  static const Color cardDark = Color(0xFF1A202B);
  static const Color cardHoverDark = Color(0xFF222835);
  static const Color surfaceElevatedDark = Color(0xFF1E2433);
  static const Color surfaceInputDark = Color(0xFF141A26);
  static const Color borderDark = Color(0xFF181B1F);
  static const Color borderSubtleDark = Color(0xFF111520);
  static const Color dividerDark = Color(0xFF1E293B);

  // ─── Dark Mode Text ───
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFC7C9CC);
  static const Color textTertiaryDark = Color(0xFFB4B4B4);

  // ─── Icon Colors ───
  static const Color iconDefault = Color(0xFF5A6577);
  static const Color iconActive = Color(0xFF0883FD);
  static const Color iconOnPrimary = Color(0xFFFFFFFF);
  static const Color iconDisabled = Color(0xFFD1D5DB);

  // ─── State Colors ───
  static const Color deviceOnBackground = Color(0xFFEBF5FF);
  static const Color deviceOffBackground = Color(0xFFFFFFFF);
  static const Color onlineIndicator = Color(0xFF22C55E);
  static const Color offlineIndicator = Color(0xFF9CA3AF);
}

class HBotSpacing {
  HBotSpacing._();

  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 32;
  static const double space8 = 40;
  static const double space9 = 48;
  static const double space10 = 64;

  /// Standard screen horizontal padding
  static const double screenPadding = 20;
  /// iPad max content width
  static const double tabletMaxWidth = 500;

  /// Minimum touch target size (Apple HIG / WCAG)
  static const double minTouchTarget = 44;
}

class HBotRadius {
  HBotRadius._();

  static const double none = 0;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double xl = 24;
  static const double full = 9999;

  static final BorderRadius smallRadius = BorderRadius.circular(small);
  static final BorderRadius mediumRadius = BorderRadius.circular(medium);
  static final BorderRadius largeRadius = BorderRadius.circular(large);
  static final BorderRadius xlRadius = BorderRadius.circular(xl);
  static final BorderRadius fullRadius = BorderRadius.circular(full);
}

class HBotShadows {
  HBotShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x0F0A1628),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x140A1628),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1F0A1628),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x290A1628),
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x260883FD),
      blurRadius: 20,
      offset: Offset.zero,
    ),
  ];
}

class HBotDurations {
  HBotDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration skeleton = Duration(milliseconds: 1500);
}

class HBotCurves {
  HBotCurves._();

  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve sharp = Curves.easeInOutCubic;
}

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════
  // Legacy compatibility aliases (old API → new tokens)
  // These keep existing screens compiling while we migrate.
  // ═══════════════════════════════════════════════════════

  // Colors
  static const Color primaryColor = HBotColors.primary;
  static const Color secondaryColor = HBotColors.primaryLight;
  static const Color accentColor = HBotColors.primaryLight;
  static const Color errorColor = HBotColors.error;
  static const Color warningColor = HBotColors.warning;
  static const Color backgroundColor = HBotColors.backgroundLight;
  static const Color surfaceColor = HBotColors.surfaceLight;
  static const Color cardColor = HBotColors.cardLight;
  static const Color textPrimary = HBotColors.textPrimaryLight;
  static const Color textSecondary = HBotColors.textSecondaryLight;
  static const Color textHint = HBotColors.textTertiaryLight;

  // Light-mode specific
  static const Color lightBackgroundColor = HBotColors.backgroundLight;
  static const Color lightSurfaceColor = HBotColors.surfaceLight;
  static const Color lightCardColor = HBotColors.cardLight;
  static const Color lightBorderColor = HBotColors.borderLight;
  static const Color lightCardBorder = HBotColors.borderLight;
  static const Color lightDividerColor = HBotColors.dividerLight;
  static const Color lightTextPrimary = HBotColors.textPrimaryLight;
  static const Color lightTextSecondary = HBotColors.textSecondaryLight;
  static const Color lightTextHint = HBotColors.textTertiaryLight;
  static const Color lightNavBarBackground = HBotColors.surfaceLight;
  static const Color lightNavBarBorder = HBotColors.borderLight;
  static const Color lightGradientStart = HBotColors.primarySurface;
  static const Color lightGradientEnd = HBotColors.primarySurfaceStrong;

  // Spacing
  static const double paddingSmall = HBotSpacing.space2;  // 8
  static const double paddingMedium = HBotSpacing.space4;  // 16
  static const double paddingLarge = HBotSpacing.space6;   // 24

  // Radii
  static const double radiusSmall = HBotRadius.small;   // 8
  static const double radiusMedium = HBotRadius.medium;  // 12
  static const double radiusLarge = HBotRadius.large;    // 16

  // Legacy helper methods
  static Color getTextPrimary(BuildContext context) => HBotColors.textPrimaryLight;
  static Color getTextSecondary(BuildContext context) => HBotColors.textSecondaryLight;
  static Color getTextHint(BuildContext context) => HBotColors.textTertiaryLight;
  static Color getCardColor(BuildContext context) => HBotColors.cardLight;

  // Legacy text styles
  static const TextStyle priceTextStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: HBotColors.textPrimaryLight,
  );

  // Dark theme stub (not yet implemented)
  static ThemeData get darkTheme => lightTheme;

  // ═══════════════════════════════════════════════════════

  // ─── Light Theme ───
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: HBotColors.primary,
        onPrimary: HBotColors.textOnPrimary,
        primaryContainer: HBotColors.primarySurface,
        onPrimaryContainer: HBotColors.primary,
        secondary: HBotColors.primaryLight,
        onSecondary: HBotColors.textPrimaryLight,
        secondaryContainer: HBotColors.primarySurfaceStrong,
        onSecondaryContainer: HBotColors.primaryDark,
        surface: HBotColors.surfaceLight,
        onSurface: HBotColors.textPrimaryLight,
        surfaceContainerHighest: HBotColors.neutral50,
        error: HBotColors.error,
        onError: Colors.white,
        errorContainer: HBotColors.errorLight,
        outline: HBotColors.borderLight,
        outlineVariant: HBotColors.dividerLight,
      ),

      // ─── Scaffold ───
      scaffoldBackgroundColor: HBotColors.backgroundLight,

      // ─── AppBar (blends with page background per design spec) ───
      appBarTheme: const AppBarTheme(
        backgroundColor: HBotColors.backgroundLight,
        foregroundColor: HBotColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryLight,
          letterSpacing: -0.3,
          height: 1.27,
        ),
        iconTheme: IconThemeData(
          color: HBotColors.iconDefault,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ─── Bottom Navigation (64px + safe area, 1px top border) ───
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HBotColors.surfaceLight,
        selectedItemColor: HBotColors.primary,
        unselectedItemColor: HBotColors.neutral400,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ─── Cards ───
      cardTheme: CardThemeData(
        color: HBotColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.largeRadius,
          side: const BorderSide(color: HBotColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button (Primary) ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HBotColors.primary,
          foregroundColor: HBotColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(120, 52),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),

      // ─── Filled Button ───
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HBotColors.primary,
          foregroundColor: HBotColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ─── Outlined Button (Secondary) ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HBotColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: HBotColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ─── Text Button (Tertiary) ───
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HBotColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ─── Input Decoration ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HBotColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryLight,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textTertiaryLight,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: HBotColors.error,
        ),
        prefixIconColor: HBotColors.iconDefault,
        suffixIconColor: HBotColors.iconDefault,
      ),

      // ─── Floating Action Button ───
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HBotColors.primary,
        foregroundColor: HBotColors.textOnPrimary,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // ─── Switch ───
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return HBotColors.neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HBotColors.primary;
          return HBotColors.neutral200;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return HBotColors.neutral300;
        }),
      ),

      // ─── Chip ───
      chipTheme: ChipThemeData(
        backgroundColor: HBotColors.neutral50,
        selectedColor: HBotColors.primarySurface,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: HBotColors.borderLight),
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.fullRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ─── Dialog ───
      dialogTheme: DialogThemeData(
        backgroundColor: HBotColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.xlRadius,
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryLight,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryLight,
        ),
      ),

      // ─── Bottom Sheet ───
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HBotColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: HBotColors.neutral300,
        dragHandleSize: Size(36, 4),
      ),

      // ─── Snackbar ───
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HBotColors.neutral900,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.mediumRadius,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),

      // ─── Divider ───
      dividerTheme: const DividerThemeData(
        color: HBotColors.dividerLight,
        thickness: 1,
        space: 1,
      ),

      // ─── List Tile ───
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minVerticalPadding: 12,
        iconColor: HBotColors.iconDefault,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: HBotColors.textPrimaryLight,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryLight,
        ),
      ),

      // ─── Tab Bar ───
      tabBarTheme: TabBarThemeData(
        labelColor: HBotColors.primary,
        unselectedLabelColor: HBotColors.textSecondaryLight,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        indicatorColor: HBotColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ─── Progress Indicator ───
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HBotColors.primary,
        linearTrackColor: HBotColors.neutral200,
        circularTrackColor: HBotColors.neutral200,
      ),

      // ─── Text Theme ───
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.5,
          color: HBotColors.textPrimaryLight,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.29,
          letterSpacing: -0.5,
          color: HBotColors.textPrimaryLight,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.33,
          letterSpacing: -0.3,
          color: HBotColors.textPrimaryLight,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.27,
          letterSpacing: -0.3,
          color: HBotColors.textPrimaryLight,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          letterSpacing: -0.2,
          color: HBotColors.textPrimaryLight,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: -0.1,
          color: HBotColors.textPrimaryLight,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.38,
          letterSpacing: 0,
          color: HBotColors.textPrimaryLight,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.43,
          letterSpacing: 0,
          color: HBotColors.textPrimaryLight,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0,
          color: HBotColors.textPrimaryLight,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.43,
          letterSpacing: 0,
          color: HBotColors.textSecondaryLight,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.33,
          letterSpacing: 0.1,
          color: HBotColors.textTertiaryLight,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.38,
          letterSpacing: 0,
          color: HBotColors.textPrimaryLight,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.43,
          letterSpacing: 0.1,
          color: HBotColors.textSecondaryLight,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.33,
          letterSpacing: 0.2,
          color: HBotColors.textSecondaryLight,
        ),
      ),
    );
  }
}

// ─── Reusable Component Helpers ───

/// Gradient button decoration (primary gradient fill)
BoxDecoration hbotPrimaryButtonDecoration({bool enabled = true}) {
  return BoxDecoration(
    gradient: enabled ? HBotColors.primaryGradient : null,
    color: enabled ? null : HBotColors.primaryDisabled,
    borderRadius: HBotRadius.mediumRadius,
    boxShadow: enabled ? HBotShadows.medium : null,
  );
}

/// Device card decoration (active/inactive)
/// Per design spec: white bg, 1px border #E8ECF1, 16px radius
/// ON state has a 3px left blue accent border
BoxDecoration hbotDeviceCardDecoration({bool isOn = false}) {
  return BoxDecoration(
    color: HBotColors.cardLight,
    borderRadius: HBotRadius.largeRadius,
    border: Border.all(
      color: HBotColors.borderLight,
      width: 1,
    ),
  );
}

/// Settings tile decoration
BoxDecoration hbotSettingsTileDecoration() {
  return BoxDecoration(
    color: HBotColors.cardLight,
    borderRadius: HBotRadius.largeRadius,
    border: Border.all(color: HBotColors.borderLight, width: 1),
  );
}

/// Standard section header style
TextStyle hbotSectionHeader() {
  return const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: HBotColors.textTertiaryLight,
  );
}

/// Gradient text widget (h-bot.tech signature effect)
Widget hbotGradientText(
  String text, {
  double fontSize = 24,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return ShaderMask(
    shaderCallback: (bounds) => HBotColors.primaryGradient.createShader(bounds),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: Colors.white,
      ),
    ),
  );
}

/// Status indicator dot
Widget hbotStatusDot({required bool isOnline, double size = 8}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: isOnline ? HBotColors.onlineIndicator : HBotColors.offlineIndicator,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: isOnline
          ? [BoxShadow(color: HBotColors.onlineIndicator.withOpacity(0.3), blurRadius: 4)]
          : null,
    ),
  );
}

/// Icon in a colored circle (for settings, device types, etc.)
Widget hbotCircleIcon({
  required IconData icon,
  Color? backgroundColor,
  Color? iconColor,
  double size = 36,
  double iconSize = 20,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: backgroundColor ?? HBotColors.primarySurface,
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      size: iconSize,
      color: iconColor ?? HBotColors.primary,
    ),
  );
}

/// Responsive wrapper for iPad (centers content with max width)
Widget hbotResponsiveWrapper({required Widget child}) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: HBotSpacing.tabletMaxWidth),
      child: child,
    ),
  );
}
