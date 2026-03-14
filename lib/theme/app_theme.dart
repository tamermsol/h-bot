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

  // ─── Neutral Palette (v0 design tokens) ───
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8F9FB);
  static const Color neutral100 = Color(0xFFF5F7FA); // v0 card/input bg
  static const Color neutral200 = Color(0xFFE5E7EB); // v0 border
  static const Color neutral300 = Color(0xFFD1D5DB); // v0 toggle OFF
  static const Color neutral400 = Color(0xFF9CA3AF); // v0 text muted
  static const Color neutral500 = Color(0xFF6B7280); // v0 text secondary
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937); // v0 text primary
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral950 = Color(0xFF030712);

  // ─── Decorative Neutrals ───
  static const Color silver = Color(0xFFCBD9DE);
  static const Color darkBorder = Color(0xFF181B1F);

  // ─── Semantic Surface Tokens — Light Mode ───
  static const Color surfacePrimarySubtle = Color(0xFFF0F7FF);
  static const Color surfaceDestructiveSubtle = Color(0xFFFEE2E2);
  static const Color surfaceCardHover = Color(0xFFEFF6FF); // v0 active bg on press

  // ─── Semantic Surface Tokens — Dark Mode ───
  static const Color surfacePrimarySubtleDark = Color(0x1F0883FD); // rgba(8,131,253,0.12)

  // ─── Semantic Border Tokens ───
  static const Color borderFocused = Color(0xFF0883FD);
  static const Color borderError = Color(0xFFEF4444);
  static const Color borderSuccess = Color(0xFF22C55E);

  // ─── Toggle Tokens (v0: ON=#0883FD, OFF=#D1D5DB) ───
  static const Color toggleTrackOff = Color(0xFFD1D5DB);
  static const Color toggleThumb = Color(0xFFFFFFFF);

  // ─── Primary Disabled ───
  static const Color primaryDisabled = Color(0xFFD1D7E0);

  // ─── Device Type Colors (v0 design tokens) ───
  static const Color deviceRelay = Color(0xFF3B82F6);     // v0 relay blue
  static const Color deviceRelayBg = Color(0xFFEFF6FF);   // v0 relay bg
  static const Color deviceDimmer = Color(0xFFF59E0B);    // v0 dimmer amber
  static const Color deviceDimmerBg = Color(0xFFFFFBEB);  // v0 dimmer bg
  static const Color deviceSensor = Color(0xFF10B981);    // v0 sensor green
  static const Color deviceSensorBg = Color(0xFFECFDF5);  // v0 sensor bg
  static const Color deviceShutter = Color(0xFF8B5CF6);   // v0 shutter purple
  static const Color deviceShutterBg = Color(0xFFF5F3FF); // v0 shutter bg
  // Legacy aliases
  static const Color deviceSwitch = deviceRelay;
  static const Color devicePower = Color(0xFF094972);

  // ─── Light Mode Surfaces (v0 tokens) ───
  static const Color backgroundLight = Color(0xFFFFFFFF); // v0: white page bg
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF5F7FA);       // v0: card/input bg
  static const Color cardLightWhite = Color(0xFFFFFFFF);   // pure white for auth etc.
  static const Color borderLight = Color(0xFFE5E7EB);     // v0: border
  static const Color borderLighter = Color(0xFFF3F4F6);   // v0: lighter border (nav, appbar)
  static const Color dividerLight = Color(0xFFF3F4F6);    // v0: lighter border

  // ─── Light Mode Text (v0 tokens) ───
  static const Color textPrimaryLight = Color(0xFF1F2937);   // v0: text primary
  static const Color textSecondaryLight = Color(0xFF6B7280); // v0: text secondary
  static const Color textTertiaryLight = Color(0xFF9CA3AF);  // v0: text muted
  static const Color textPlaceholder = Color(0xFFC9CDD6);   // v0: placeholder
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

  // ─── State Colors (v0 tokens) ───
  static const Color deviceOnBackground = Color(0xFFEFF6FF); // v0 active bg
  static const Color deviceOffBackground = Color(0xFFF5F7FA);
  static const Color onlineIndicator = Color(0xFF10B981);  // v0 online green
  static const Color offlineIndicator = Color(0xFFEF4444); // v0 offline red

  // ─── v0 Button Shadows ───
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x590883FD), // rgba(8,131,253,0.35)
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> fabShadow = [
    BoxShadow(
      color: Color(0x610883FD), // rgba(8,131,253,0.38)
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
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

class HBotTextStyles {
  HBotTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.29,
    letterSpacing: -0.5,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: -0.3,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.27,
    letterSpacing: -0.3,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.33,
    letterSpacing: -0.1,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.38,
    letterSpacing: 0,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43,
    letterSpacing: 0,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43,
    letterSpacing: 0,
    color: HBotColors.textSecondaryLight,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
    letterSpacing: 0.1,
    color: HBotColors.textTertiaryLight,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.38,
    letterSpacing: 0,
    color: HBotColors.textPrimaryLight,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43,
    letterSpacing: 0.1,
    color: HBotColors.textSecondaryLight,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33,
    letterSpacing: 0.2,
    color: HBotColors.textSecondaryLight,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 1.0,
    color: HBotColors.textTertiaryLight,
  );
}

class HBotGradients {
  HBotGradients._();

  static const LinearGradient primaryGradient = HBotColors.primaryGradient;

  static const LinearGradient reversedGradient = HBotColors.primaryGradientReversed;
}

class HBotShadows {
  HBotShadows._();

  static const List<BoxShadow> none = [];

  // Per BRAND-DNA.md: no drop shadows — use blur/border instead
  // Kept as minimal blur-only effects (no vertical offset)
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x080A1628),
      blurRadius: 2,
      offset: Offset.zero,
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 6,
      offset: Offset.zero,
    ),
  ];

  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x0F0A1628),
      blurRadius: 12,
      offset: Offset.zero,
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x140A1628),
      blurRadius: 20,
      offset: Offset.zero,
    ),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x260883FD),
      blurRadius: 20,
      offset: Offset.zero,
    ),
  ];

  // Dark mode shadows
  static const List<BoxShadow> smallDark = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> mediumDark = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> largeDark = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> glowDark = [
    BoxShadow(
      color: Color(0x400883FD),
      blurRadius: 20,
      offset: Offset.zero,
    ),
  ];

  // Bottom nav shadow per spec: 0 -2px 8px rgba(10,22,40,0.04)
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x0A0A1628),
      blurRadius: 8,
      offset: Offset(0, -2),
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

/// Theme-aware color helpers — use these in widgets instead of hardcoded light/dark values.
class HBotTheme {
  HBotTheme._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Surfaces
  static Color background(BuildContext context) =>
      isDark(context) ? HBotColors.backgroundDark : HBotColors.backgroundLight;
  static Color surface(BuildContext context) =>
      isDark(context) ? HBotColors.surfaceDark : HBotColors.surfaceLight;
  static Color card(BuildContext context) =>
      isDark(context) ? HBotColors.cardDark : HBotColors.cardLight;
  static Color cardHover(BuildContext context) =>
      isDark(context) ? HBotColors.cardHoverDark : HBotColors.surfaceCardHover;
  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? HBotColors.surfaceElevatedDark : HBotColors.surfaceLight;
  static Color surfaceInput(BuildContext context) =>
      isDark(context) ? HBotColors.surfaceInputDark : HBotColors.surfaceLight;
  static Color surfacePrimarySubtle(BuildContext context) =>
      isDark(context) ? HBotColors.surfacePrimarySubtleDark : HBotColors.surfacePrimarySubtle;

  // Borders
  static Color border(BuildContext context) =>
      isDark(context) ? HBotColors.borderDark : HBotColors.borderLight;
  static Color borderSubtle(BuildContext context) =>
      isDark(context) ? HBotColors.borderSubtleDark : HBotColors.dividerLight;
  static Color divider(BuildContext context) =>
      isDark(context) ? HBotColors.dividerDark : HBotColors.dividerLight;

  // Text
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? HBotColors.textPrimaryDark : HBotColors.textPrimaryLight;
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? HBotColors.textSecondaryDark : HBotColors.textSecondaryLight;
  static Color textTertiary(BuildContext context) =>
      isDark(context) ? HBotColors.textTertiaryDark : HBotColors.textTertiaryLight;

  // Icons
  static Color iconDefault(BuildContext context) =>
      isDark(context) ? HBotColors.textSecondaryDark : HBotColors.iconDefault;
  static Color iconActive(BuildContext context) => HBotColors.iconActive;

  // Shadows
  static List<BoxShadow> shadowSmall(BuildContext context) =>
      isDark(context) ? HBotShadows.smallDark : HBotShadows.small;
  static List<BoxShadow> shadowMedium(BuildContext context) =>
      isDark(context) ? HBotShadows.mediumDark : HBotShadows.medium;
  static List<BoxShadow> shadowGlow(BuildContext context) =>
      isDark(context) ? HBotShadows.glowDark : HBotShadows.glow;

  // Search bar bg
  static Color searchBarBg(BuildContext context) =>
      isDark(context) ? HBotColors.surfaceInputDark : HBotColors.neutral100;

  // Tab inactive bg
  static Color tabInactiveBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF141A26) : HBotColors.neutral100;
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
  static Color getTextPrimary(BuildContext context) =>
      HBotTheme.textPrimary(context);
  static Color getTextSecondary(BuildContext context) =>
      HBotTheme.textSecondary(context);
  static Color getTextHint(BuildContext context) =>
      HBotTheme.textTertiary(context);
  static Color getCardColor(BuildContext context) =>
      HBotTheme.card(context);

  // Legacy text styles
  static const TextStyle priceTextStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: HBotColors.textPrimaryLight,
  );

  /// Gradient text helper — applies primary gradient as a ShaderMask
  static Widget gradientText(String text, TextStyle style, {TextAlign? textAlign, int? maxLines}) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          HBotColors.primaryGradient.createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }

  /// H-Bot branded gradient text — convenience for the brand name
  static Widget hbotGradientText(String text, {double fontSize = 20, FontWeight fontWeight = FontWeight.w700}) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          HBotColors.primaryGradient.createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  /// Section header with gradient text — use for key branding moments
  static Widget gradientSectionHeader(String text) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          HBotColors.primaryGradient.createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════

  // ─── Text Theme factory ───
  static TextTheme _textTheme({
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color textTertiaryColor,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.5,
        color: textPrimaryColor,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.29,
        letterSpacing: -0.5,
        color: textPrimaryColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.33,
        letterSpacing: -0.3,
        color: textPrimaryColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.27,
        letterSpacing: -0.3,
        color: textPrimaryColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: textPrimaryColor,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: -0.1,
        color: textPrimaryColor,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.38,
        letterSpacing: 0,
        color: textPrimaryColor,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0,
        color: textPrimaryColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0,
        color: textPrimaryColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0,
        color: textSecondaryColor,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.1,
        color: textTertiaryColor,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.38,
        letterSpacing: 0,
        color: textPrimaryColor,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        letterSpacing: 0.1,
        color: textSecondaryColor,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.33,
        letterSpacing: 0.2,
        color: textSecondaryColor,
      ),
    );
  }

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

      // ─── AppBar (v0: white bg, 18px bold title, border-b #F3F4F6) ───
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: HBotColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: HBotColors.textPrimaryLight,
          letterSpacing: 0,
          height: 1.33,
        ),
        iconTheme: IconThemeData(
          color: HBotColors.textPrimaryLight,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // ─── Bottom Navigation (v0: 72px, white bg, border-t #F3F4F6) ───
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: HBotColors.primary,
        unselectedItemColor: HBotColors.textTertiaryLight,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ─── Cards ───
      cardTheme: CardTheme(
        color: HBotColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.largeRadius,
          side: const BorderSide(color: HBotColors.borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button ───
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

      // ─── Outlined Button ───
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

      // ─── Text Button ───
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
      dialogTheme: DialogTheme(
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
      tabBarTheme: TabBarTheme(
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
      textTheme: _textTheme(
        textPrimaryColor: HBotColors.textPrimaryLight,
        textSecondaryColor: HBotColors.textSecondaryLight,
        textTertiaryColor: HBotColors.textTertiaryLight,
      ),
    );
  }

  // ─── Dark Theme ───
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: HBotColors.primary,
        onPrimary: HBotColors.textOnPrimary,
        primaryContainer: Color(0xFF0A2A4A),
        onPrimaryContainer: HBotColors.primaryLight,
        secondary: HBotColors.primaryLight,
        onSecondary: HBotColors.textPrimaryDark,
        secondaryContainer: Color(0xFF0A2A4A),
        onSecondaryContainer: HBotColors.primaryLight,
        surface: HBotColors.cardDark,
        onSurface: HBotColors.textPrimaryDark,
        surfaceContainerHighest: HBotColors.neutral800,
        error: HBotColors.error,
        onError: Colors.white,
        errorContainer: Color(0xFF3B1111),
        outline: HBotColors.borderDark,
        outlineVariant: HBotColors.dividerDark,
      ),

      // ─── Scaffold ───
      scaffoldBackgroundColor: HBotColors.backgroundDark,

      // ─── AppBar ───
      appBarTheme: const AppBarTheme(
        backgroundColor: HBotColors.backgroundDark,
        foregroundColor: HBotColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryDark,
          letterSpacing: -0.3,
          height: 1.27,
        ),
        iconTheme: IconThemeData(
          color: HBotColors.textSecondaryDark,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      // ─── Bottom Navigation ───
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: HBotColors.cardDark,
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
      cardTheme: CardTheme(
        color: HBotColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.largeRadius,
          side: const BorderSide(color: HBotColors.borderDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button ───
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

      // ─── Outlined Button ───
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

      // ─── Text Button ───
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
        fillColor: HBotColors.surfaceInputDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HBotRadius.mediumRadius,
          borderSide: const BorderSide(color: HBotColors.borderDark, width: 1.5),
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
          color: HBotColors.textSecondaryDark,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textTertiaryDark,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: HBotColors.error,
        ),
        prefixIconColor: HBotColors.textSecondaryDark,
        suffixIconColor: HBotColors.textSecondaryDark,
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
          return HBotColors.neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HBotColors.primary;
          return HBotColors.neutral700;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return HBotColors.neutral600;
        }),
      ),

      // ─── Chip ───
      chipTheme: ChipThemeData(
        backgroundColor: HBotColors.cardDark,
        selectedColor: const Color(0xFF0A2A4A),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: HBotColors.textPrimaryDark,
        ),
        side: const BorderSide(color: HBotColors.borderDark),
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.fullRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ─── Dialog ───
      dialogTheme: DialogTheme(
        backgroundColor: HBotColors.surfaceElevatedDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: HBotRadius.xlRadius,
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HBotColors.textPrimaryDark,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryDark,
        ),
      ),

      // ─── Bottom Sheet ───
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HBotColors.surfaceElevatedDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: HBotColors.neutral600,
        dragHandleSize: Size(36, 4),
      ),

      // ─── Snackbar ───
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HBotColors.neutral800,
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
        color: HBotColors.dividerDark,
        thickness: 1,
        space: 1,
      ),

      // ─── List Tile ───
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minVerticalPadding: 12,
        iconColor: HBotColors.textSecondaryDark,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: HBotColors.textPrimaryDark,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: HBotColors.textSecondaryDark,
        ),
      ),

      // ─── Tab Bar ───
      tabBarTheme: TabBarTheme(
        labelColor: HBotColors.primary,
        unselectedLabelColor: HBotColors.textSecondaryDark,
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
        linearTrackColor: HBotColors.neutral700,
        circularTrackColor: HBotColors.neutral700,
      ),

      // ─── Text Theme ───
      textTheme: _textTheme(
        textPrimaryColor: HBotColors.textPrimaryDark,
        textSecondaryColor: HBotColors.textSecondaryDark,
        textTertiaryColor: HBotColors.textTertiaryDark,
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

/// Device card decoration (active/inactive) — theme-aware
BoxDecoration hbotDeviceCardDecoration({bool isOn = false, bool isDark = false}) {
  final cardColor = isDark ? HBotColors.cardDark : HBotColors.cardLight;
  final borderColor = isDark ? HBotColors.borderDark : HBotColors.borderLight;

  if (isOn) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: HBotRadius.largeRadius,
      border: Border(
        left: const BorderSide(color: HBotColors.primary, width: 3),
        top: BorderSide(color: borderColor, width: 1),
        right: BorderSide(color: borderColor, width: 1),
        bottom: BorderSide(color: borderColor, width: 1),
      ),
    );
  }

  return BoxDecoration(
    color: cardColor,
    borderRadius: HBotRadius.largeRadius,
    border: Border.all(
      color: borderColor,
      width: 1,
    ),
  );
}

/// Theme-aware device card decoration (uses BuildContext)
BoxDecoration hbotDeviceCardDecorationCtx(BuildContext context, {bool isOn = false}) {
  return hbotDeviceCardDecoration(
    isOn: isOn,
    isDark: HBotTheme.isDark(context),
  );
}

/// Settings tile decoration — theme-aware
BoxDecoration hbotSettingsTileDecoration({bool isDark = false}) {
  return BoxDecoration(
    color: isDark ? HBotColors.cardDark : HBotColors.cardLight,
    borderRadius: HBotRadius.largeRadius,
    border: Border.all(
      color: isDark ? HBotColors.borderDark : HBotColors.borderLight,
      width: 1,
    ),
  );
}

/// Standard section header style — theme-aware
TextStyle hbotSectionHeader({bool isDark = false}) {
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: isDark ? HBotColors.textTertiaryDark : HBotColors.textTertiaryLight,
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
