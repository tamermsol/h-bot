import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        final isDark = themeService.isDarkMode;

<<<<<<<< HEAD:.removed/appearance_settings_screen.dart
    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        children: [
          // Theme Mode Section
          Container(
            decoration: BoxDecoration(
              color: HBotColors.cardLight,
              borderRadius: HBotRadius.mediumRadius,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(HBotSpacing.space4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? HBotColors.primary.withOpacity(0.2)
                      : HBotColors.primary.withOpacity(0.1),
                  borderRadius: HBotRadius.smallRadius,
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: HBotColors.primary,
                  size: 24,
                ),
              ),
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: HBotColors.textPrimaryLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                isDark
                    ? 'Dark colors for comfortable viewing'
                    : 'Switch to dark theme for nighttime use',
                style: TextStyle(
                  color: HBotColors.textSecondaryLight,
                  fontSize: 13,
                ),
              ),
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  _themeService.setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
                activeColor: HBotColors.primary,
              ),
            ),
          ),
          const SizedBox(height: HBotSpacing.space6),
          // Info Card
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: HBotColors.primary.withOpacity(0.1),
              borderRadius: HBotRadius.mediumRadius,
              border: Border.all(
                color: HBotColors.primary.withOpacity(0.3),
========
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: HBotIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
            ),
            centerTitle: true,
            title: const Text(
              'Appearance',
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
>>>>>>>> main:lib/screens/appearance_settings_screen.dart
              ),
            ),
            child: ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + HBotSpacing.space4,
                left: HBotSpacing.space5,
                right: HBotSpacing.space5,
                bottom: HBotSpacing.space6,
              ),
              children: [
<<<<<<<< HEAD:.removed/appearance_settings_screen.dart
                Icon(
                  Icons.info_outline,
                  color: HBotColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Theme changes apply immediately across the entire app',
                    style: TextStyle(
                      color: HBotColors.textPrimaryLight,
                      fontSize: 13,
                    ),
========
                // Dark Mode toggle card
                HBotCard(
                  padding: const EdgeInsets.all(HBotSpacing.space4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: HBotColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: HBotColors.glassBorder, width: 0.5),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                          color: HBotColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: HBotSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontFamily: 'Readex Pro',
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDark
                                  ? 'Dark colors for comfortable viewing'
                                  : 'Switch to dark theme for nighttime use',
                              style: const TextStyle(
                                fontFamily: 'Readex Pro',
                                color: HBotColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isDark,
                        onChanged: (value) {
                          themeService.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                        activeColor: HBotColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HBotSpacing.space6),

                // Info card
                HBotCard(
                  padding: const EdgeInsets.all(HBotSpacing.space4),
                  backgroundColor: HBotColors.primary.withOpacity(0.08),
                  borderColor: HBotColors.primary.withOpacity(0.2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: HBotColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: HBotSpacing.space3),
                      const Expanded(
                        child: Text(
                          'Theme changes apply immediately across the entire app',
                          style: TextStyle(
                            fontFamily: 'Readex Pro',
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
>>>>>>>> main:lib/screens/appearance_settings_screen.dart
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
