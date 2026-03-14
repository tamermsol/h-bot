import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';
import '../utils/phosphor_icons.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? HBotColors.backgroundLight
          : HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Appearance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark
            ? HBotColors.backgroundLight
            : HBotColors.backgroundLight,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        children: [
          // Theme Mode Section
          Container(
            decoration: BoxDecoration(
              color: HBotColors.cardLight,
              borderRadius: BorderRadius.circular(HBotRadius.medium),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(HBotSpacing.space4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? HBotColors.primary.withOpacity(0.2)
                      : HBotColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(HBotRadius.small),
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
              borderRadius: BorderRadius.circular(HBotRadius.medium),
              border: Border.all(
                color: HBotColors.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  HBotIcons.info,
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
