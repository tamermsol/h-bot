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

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: context.hCard,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
        border: Border.all(color: context.hBorder),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
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
                    ? const Color(0x1A0883FD) // rgba(8,131,253,0.1)
                    : HBotColors.glassBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? HBotColors.primary
                      : HBotColors.glassBorder,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? HBotColors.primary
                    : HBotColors.textMuted,
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }
}
