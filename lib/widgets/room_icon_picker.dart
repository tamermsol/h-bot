import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/phosphor_icons.dart';

class RoomIconPicker extends StatelessWidget {
  final String? currentIconName;
  final Function(String) onIconSelected;

  const RoomIconPicker({
    super.key,
    this.currentIconName,
    required this.onIconSelected,
  });

  static final List<Map<String, dynamic>> roomIcons = [
    {'name': 'bed', 'icon': HBotIcons.bed, 'label': 'Bedroom'},
    {'name': 'single_bed', 'icon': HBotIcons.bed, 'label': 'Single Bed'},
    {'name': 'king_bed', 'icon': HBotIcons.bed, 'label': 'Master Bedroom'},
    {'name': 'weekend', 'icon': HBotIcons.couch, 'label': 'Living Room'},
    {'name': 'chair', 'icon': HBotIcons.armchair, 'label': 'Sitting Room'},
    {'name': 'event_seat', 'icon': HBotIcons.armchair, 'label': 'Lounge'},
    {'name': 'kitchen', 'icon': HBotIcons.cookingPot, 'label': 'Kitchen'},
    {'name': 'dining', 'icon': HBotIcons.forkKnife, 'label': 'Dining Room'},
    {'name': 'restaurant', 'icon': HBotIcons.forkKnife, 'label': 'Dining Area'},
    {'name': 'bathtub', 'icon': HBotIcons.bathtub, 'label': 'Bathroom'},
    {'name': 'shower', 'icon': HBotIcons.shower, 'label': 'Shower Room'},
    {'name': 'hot_tub', 'icon': HBotIcons.bathtub, 'label': 'Spa'},
    {'name': 'desk', 'icon': HBotIcons.desk, 'label': 'Office'},
    {'name': 'computer', 'icon': HBotIcons.desktop, 'label': 'Study'},
    {'name': 'work', 'icon': HBotIcons.briefcase, 'label': 'Workspace'},
    {'name': 'garage', 'icon': HBotIcons.garage, 'label': 'Garage'},
    {'name': 'directions_car', 'icon': HBotIcons.car, 'label': 'Parking'},
    {'name': 'grass', 'icon': HBotIcons.plant, 'label': 'Garden'},
    {'name': 'yard', 'icon': HBotIcons.tree, 'label': 'Backyard'},
    {'name': 'deck', 'icon': HBotIcons.park, 'label': 'Deck'},
    {'name': 'balcony', 'icon': HBotIcons.park, 'label': 'Balcony'},
    {'name': 'pool', 'icon': HBotIcons.swimmingPool, 'label': 'Pool'},
    {'name': 'fitness_center', 'icon': HBotIcons.barbell, 'label': 'Gym'},
    {'name': 'sports_esports', 'icon': HBotIcons.gameController, 'label': 'Game Room'},
    {'name': 'tv', 'icon': HBotIcons.television, 'label': 'TV Room'},
    {'name': 'movie', 'icon': HBotIcons.filmSlate, 'label': 'Cinema'},
    {'name': 'library_books', 'icon': HBotIcons.books, 'label': 'Library'},
    {'name': 'child_care', 'icon': HBotIcons.baby, 'label': 'Nursery'},
    {'name': 'toys', 'icon': HBotIcons.puzzle, 'label': 'Playroom'},
    {'name': 'checkroom', 'icon': HBotIcons.tShirt, 'label': 'Closet'},
    {'name': 'dry_cleaning', 'icon': HBotIcons.tShirt, 'label': 'Laundry'},
    {'name': 'local_laundry_service', 'icon': HBotIcons.washingMachine, 'label': 'Utility Room'},
    {'name': 'storage', 'icon': HBotIcons.package, 'label': 'Storage'},
    {'name': 'warehouse', 'icon': HBotIcons.warehouse, 'label': 'Basement'},
    {'name': 'stairs', 'icon': HBotIcons.stairs, 'label': 'Hallway'},
    {'name': 'door_sliding', 'icon': HBotIcons.doorOpen, 'label': 'Entrance'},
    {'name': 'meeting_room', 'icon': HBotIcons.usersThree, 'label': 'Conference'},
    {'name': 'room', 'icon': HBotIcons.room, 'label': 'General Room'},
  ];

  static IconData getIconData(String? iconName) {
    if (iconName == null) return HBotIcons.room;
    try {
      final iconMap = roomIcons.firstWhere(
        (icon) => icon['name'] == iconName,
        orElse: () => roomIcons.last,
      );
      return iconMap['icon'] as IconData;
    } catch (e) {
      return HBotIcons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: 400,
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: roomIcons.length,
        itemBuilder: (context, index) {
          final iconData = roomIcons[index];
          final isSelected = currentIconName == iconData['name'];

          return InkWell(
            onTap: () => onIconSelected(iconData['name'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? HBotColors.primary.withOpacity(0.2)
                    : HBotColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? HBotColors.primary
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.transparent
                            : HBotColors.borderLight),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData['icon'] as IconData,
                    color: isSelected
                        ? HBotColors.primary
                        : HBotColors.textSecondaryLight,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      iconData['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected
                            ? HBotColors.primary
                            : HBotColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
