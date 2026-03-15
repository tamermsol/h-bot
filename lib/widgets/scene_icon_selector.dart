import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SceneIconSelector extends StatelessWidget {
  final IconData selectedIcon;
  final Function(IconData) onIconSelected;

  const SceneIconSelector({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
  });

  static const List<IconData> _availableIcons = [
    Icons.auto_awesome,
    Icons.wb_sunny,
    Icons.bedtime,
    Icons.movie,
    Icons.home,
    Icons.shield,
    Icons.celebration,
    Icons.restaurant,
    Icons.work,
    Icons.fitness_center,
    Icons.local_cafe,
    Icons.music_note,
    Icons.pets,
    Icons.spa,
    Icons.beach_access,
    Icons.nature,
    Icons.local_fire_department,
    Icons.ac_unit,
    Icons.lightbulb,
    Icons.security,
    Icons.cleaning_services,
    Icons.weekend,
    Icons.school,
    Icons.shopping_cart,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
        border: isDark ? null : Border.all(color: HBotColors.borderLight),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: HBotSpacing.space2,
          mainAxisSpacing: HBotSpacing.space2,
          childAspectRatio: 1.0,
        ),
        itemCount: _availableIcons.length,
        itemBuilder: (context, index) {
          final icon = _availableIcons[index];
          final isSelected = icon == selectedIcon;

          return GestureDetector(
            onTap: () => onIconSelected(icon),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? HBotColors.primary.withOpacity(0.2)
                    : (isDark ? HBotColors.surfaceLight : Colors.white),
                borderRadius: BorderRadius.circular(HBotRadius.small),
                border: Border.all(
                  color: isSelected
                      ? HBotColors.primary
                      : (isDark
                            ? Colors.transparent
                            : HBotColors.borderLight),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? HBotColors.primary
                    : HBotColors.textSecondaryLight,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }
}
