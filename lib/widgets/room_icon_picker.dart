import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoomIconPicker extends StatelessWidget {
  final String? currentIconName;
  final Function(String) onIconSelected;

  const RoomIconPicker({
    super.key,
    this.currentIconName,
    required this.onIconSelected,
  });

  static final List<Map<String, dynamic>> roomIcons = [
    {'name': 'bed', 'icon': Icons.bed, 'label': 'Bedroom'},
    {'name': 'single_bed', 'icon': Icons.single_bed, 'label': 'Single Bed'},
    {'name': 'king_bed', 'icon': Icons.king_bed, 'label': 'Master Bedroom'},
    {'name': 'weekend', 'icon': Icons.weekend, 'label': 'Living Room'},
    {'name': 'chair', 'icon': Icons.chair, 'label': 'Sitting Room'},
    {'name': 'event_seat', 'icon': Icons.event_seat, 'label': 'Lounge'},
    {'name': 'kitchen', 'icon': Icons.kitchen, 'label': 'Kitchen'},
    {'name': 'dining', 'icon': Icons.dining, 'label': 'Dining Room'},
    {'name': 'restaurant', 'icon': Icons.restaurant, 'label': 'Dining Area'},
    {'name': 'bathtub', 'icon': Icons.bathtub, 'label': 'Bathroom'},
    {'name': 'shower', 'icon': Icons.shower, 'label': 'Shower Room'},
    {'name': 'hot_tub', 'icon': Icons.hot_tub, 'label': 'Spa'},
    {'name': 'desk', 'icon': Icons.desk, 'label': 'Office'},
    {'name': 'computer', 'icon': Icons.computer, 'label': 'Study'},
    {'name': 'work', 'icon': Icons.work, 'label': 'Workspace'},
    {'name': 'garage', 'icon': Icons.garage, 'label': 'Garage'},
    {
      'name': 'directions_car',
      'icon': Icons.directions_car,
      'label': 'Parking',
    },
    {'name': 'grass', 'icon': Icons.grass, 'label': 'Garden'},
    {'name': 'yard', 'icon': Icons.yard, 'label': 'Backyard'},
    {'name': 'deck', 'icon': Icons.deck, 'label': 'Deck'},
    {'name': 'balcony', 'icon': Icons.balcony, 'label': 'Balcony'},
    {'name': 'pool', 'icon': Icons.pool, 'label': 'Pool'},
    {'name': 'fitness_center', 'icon': Icons.fitness_center, 'label': 'Gym'},
    {
      'name': 'sports_esports',
      'icon': Icons.sports_esports,
      'label': 'Game Room',
    },
    {'name': 'tv', 'icon': Icons.tv, 'label': 'TV Room'},
    {'name': 'movie', 'icon': Icons.movie, 'label': 'Cinema'},
    {'name': 'library_books', 'icon': Icons.library_books, 'label': 'Library'},
    {'name': 'child_care', 'icon': Icons.child_care, 'label': 'Nursery'},
    {'name': 'toys', 'icon': Icons.toys, 'label': 'Playroom'},
    {'name': 'checkroom', 'icon': Icons.checkroom, 'label': 'Closet'},
    {'name': 'dry_cleaning', 'icon': Icons.dry_cleaning, 'label': 'Laundry'},
    {
      'name': 'local_laundry_service',
      'icon': Icons.local_laundry_service,
      'label': 'Utility Room',
    },
    {'name': 'storage', 'icon': Icons.storage, 'label': 'Storage'},
    {'name': 'warehouse', 'icon': Icons.warehouse, 'label': 'Basement'},
    {'name': 'stairs', 'icon': Icons.stairs, 'label': 'Hallway'},
    {'name': 'door_sliding', 'icon': Icons.door_sliding, 'label': 'Entrance'},
    {'name': 'meeting_room', 'icon': Icons.meeting_room, 'label': 'Conference'},
    {'name': 'room', 'icon': Icons.room, 'label': 'General Room'},
  ];

  static IconData getIconData(String? iconName) {
    if (iconName == null) return Icons.room;
    try {
      final iconMap = roomIcons.firstWhere(
        (icon) => icon['name'] == iconName,
        orElse: () => roomIcons.last,
      );
      return iconMap['icon'] as IconData;
    } catch (e) {
      return Icons.room;
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
