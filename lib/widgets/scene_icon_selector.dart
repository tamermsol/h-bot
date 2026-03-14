import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';

class SceneIconSelector extends StatelessWidget {
  final IconData selectedIcon;
  final Function(IconData) onIconSelected;

  const SceneIconSelector({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
  });

  static final List<IconData> _availableIcons = [
    HBotIcons.scenes,
    HBotIcons.sun,
    HBotIcons.moon,
    HBotIcons.play,
    HBotIcons.home,
    HBotIcons.shield,
    HBotIcons.celebration,
    HBotIcons.device,
    HBotIcons.briefcase,
    HBotIcons.barbell,
    HBotIcons.coffee,
    HBotIcons.music,
    HBotIcons.pawPrint,
    HBotIcons.flower,
    HBotIcons.umbrella,
    HBotIcons.leaf,
    HBotIcons.fire,
    HBotIcons.thermometer,
    HBotIcons.lightbulb,
    HBotIcons.shield,
    HBotIcons.broom,
    HBotIcons.couch,
    HBotIcons.graduationCap,
    HBotIcons.shoppingCart,
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
