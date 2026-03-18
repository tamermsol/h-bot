import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/smart_home_service.dart';
import '../services/room_change_notifier.dart';
import '../repos/rooms_repo.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../widgets/background_image_picker.dart';
import '../widgets/background_container.dart';
import '../widgets/room_icon_picker.dart';
import 'devices_screen.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

class RoomsScreen extends StatefulWidget {
  final Home home;
  final VoidCallback? onRoomChanged;

  const RoomsScreen({super.key, required this.home, this.onRoomChanged});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final SmartHomeService _service = SmartHomeService();
  final RoomsRepo _roomsRepo = RoomsRepo();
  final TextEditingController _nameController = TextEditingController();
  List<Room> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      setState(() => _isLoading = true);
      final rooms = await _service.getRooms(widget.home.id);
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('rooms_failed_to_load_rooms_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('rooms_please_enter_a_room_name')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final room = await _service.createRoom(
        widget.home.id,
        _nameController.text.trim(),
      );
      setState(() {
        _rooms.add(room);
      });
      _nameController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room "${room.name}" created successfully!'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that rooms have changed
      widget.onRoomChanged?.call();

      // Notify globally that rooms have changed
      RoomChangeNotifier().notifyRoomChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('rooms_failed_to_create_room_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.hCard,
        title: Text(AppStrings.get('rooms_create_new_room')),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: AppStrings.get('rooms_room_name'),
            hintText: AppStrings.get('rooms_eg_living_room_kitchen_etc'),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.get('rooms_cancel')),
          ),
          ElevatedButton(
            onPressed: _createRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: HBotColors.primary,
            ),
            child: Text(AppStrings.get('rooms_create')),
          ),
        ],
      ),
    );
  }

  Future<void> _editRoom(Room room) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('rooms_please_enter_a_room_name_2')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final updatedRoom = await _service.updateRoom(
        room.id,
        name: _nameController.text.trim(),
      );

      // Update the room in the local list
      setState(() {
        final index = _rooms.indexWhere((r) => r.id == room.id);
        if (index != -1) {
          _rooms[index] = updatedRoom;
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room "${updatedRoom.name}" updated successfully!'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that rooms have changed
      widget.onRoomChanged?.call();

      // Notify globally that rooms have changed
      RoomChangeNotifier().notifyRoomChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('rooms_failed_to_update_room_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoom(Room room) async {
    try {
      await _service.deleteRoom(room.id);

      // Remove the room from the local list
      setState(() {
        _rooms.removeWhere((r) => r.id == room.id);
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room "${room.name}" deleted successfully!'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that rooms have changed
      widget.onRoomChanged?.call();

      // Notify globally that rooms have changed
      RoomChangeNotifier().notifyRoomChanged();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('rooms_failed_to_delete_room_e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditRoomDialog(Room room) {
    _nameController.text = room.name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Text(AppStrings.get('rooms_edit_room')),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppStrings.get('rooms_room_name_2'),
              hintText: AppStrings.get('rooms_eg_living_room_kitchen_etc_2'),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('rooms_cancel_2')),
            ),
            ElevatedButton(
              onPressed: () => _editRoom(room),
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
              ),
              child: Text(AppStrings.get('rooms_save')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteRoomDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Text(AppStrings.get('rooms_delete_room')),
          content: Text(
            'Are you sure you want to delete "${room.name}"? This action cannot be undone and will remove all devices in this room.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('rooms_cancel_3')),
            ),
            ElevatedButton(
              onPressed: () => _deleteRoom(room),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppStrings.get('rooms_delete')),
            ),
          ],
        );
      },
    );
  }

  void _showBackgroundImageDialog(Room room) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.hCard,
          title: Text(AppStrings.get('rooms_room_background_image')),
          content: SingleChildScrollView(
            child: BackgroundImagePicker(
              currentImageUrl: room.backgroundImageUrl,
              userId: user.id,
              type: 'room',
              entityId: room.id,
              onImageSelected: (imageUrl) async {
                try {
                  // If imageUrl is null, we're removing the background
                  if (imageUrl == null) {
                    await _roomsRepo.updateRoom(room.id, clearBackground: true);
                  } else {
                    await _roomsRepo.updateRoom(
                      room.id,
                      backgroundImageUrl: imageUrl,
                    );
                  }

                  // Reload rooms to get updated data
                  await _loadRooms();

                  if (mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppStrings.get('rooms_failed_to_update_background_e')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('rooms_close')),
            ),
          ],
        );
      },
    );
  }

  void _showIconPickerDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedIconName = room.iconName;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: context.hCard,
              title: Text(AppStrings.get('rooms_change_room_icon')),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: RoomIconPicker(
                    currentIconName: selectedIconName,
                    onIconSelected: (iconName) {
                      setState(() {
                        selectedIconName = iconName;
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.get('rooms_cancel_4')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedIconName == null) {
                      Navigator.pop(context);
                      return;
                    }

                    try {
                      await _roomsRepo.updateRoom(
                        room.id,
                        iconName: selectedIconName,
                      );

                      // Reload rooms to get updated data
                      await _loadRooms();

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.get('rooms_room_icon_updated_successfully')),
                            backgroundColor: HBotColors.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.get('rooms_failed_to_update_icon_e')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HBotColors.primary,
                  ),
                  child: Text(AppStrings.get('rooms_save_2')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getRoomIcon(Room room) {
    // Use custom icon if set
    if (room.iconName != null && room.iconName!.isNotEmpty) {
      return RoomIconPicker.getIconData(room.iconName);
    }

    // Otherwise, auto-detect from name
    final name = room.name.toLowerCase();
    if (name.contains('living') || name.contains('lounge')) {
      return Icons.weekend;
    } else if (name.contains('kitchen')) {
      return Icons.kitchen;
    } else if (name.contains('bedroom') || name.contains('bed')) {
      return Icons.bed;
    } else if (name.contains('bathroom') || name.contains('bath')) {
      return Icons.bathtub;
    } else if (name.contains('office') || name.contains('study')) {
      return Icons.desk;
    } else if (name.contains('garage')) {
      return Icons.garage;
    } else if (name.contains('garden') || name.contains('outdoor')) {
      return Icons.grass;
    } else {
      return Icons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? context.hBackground
          : context.hBackground,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? context.hBackground
            : context.hBackground,
        title: Text(
          widget.home.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateRoomDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
          ? _buildEmptyState()
          : _buildRoomsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.room_outlined, size: 80, color: context.hTextTertiary),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              'No Rooms Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: context.hTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              'Add rooms to organize your smart devices by location',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.hTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            ElevatedButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add),
              label: Text(AppStrings.get('rooms_add_your_first_room')),
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space6,
                  vertical: HBotSpacing.space4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        // Use EXACT same Card structure as Dashboard
        return Card(
          color: context.hCard,
          margin: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: HBotSpacing.space2,
          ),
          child: Stack(
            children: [
              // Background image if available
              if (room.backgroundImageUrl != null &&
                  room.backgroundImageUrl!.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                    child: BackgroundContainer(
                      backgroundImageUrl: room.backgroundImageUrl,
                      overlayColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors
                                .black, // Changed to black for better contrast in Light Mode
                      overlayOpacity:
                          Theme.of(context).brightness == Brightness.dark
                          ? 0.5
                          : 0.6, // Increased to 0.6 for better text visibility in Light Mode
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DevicesScreen(
                        home: widget.home,
                        room: room,
                        onDeviceChanged: () {
                          // Could refresh room data here if needed
                        },
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                child: Padding(
                  padding: const EdgeInsets.all(HBotSpacing.space4),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: HBotColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            HBotRadius.medium,
                          ),
                        ),
                        child: Icon(
                          _getRoomIcon(room),
                          color: HBotColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: HBotSpacing.space4),
                      // Room info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color:
                                    room.backgroundImageUrl != null &&
                                        room.backgroundImageUrl!.isNotEmpty
                                    ? Colors.white
                                    : context.hTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to manage devices',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    room.backgroundImageUrl != null &&
                                        room.backgroundImageUrl!.isNotEmpty
                                    ? Colors.white70
                                    : context.hTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color:
                        room.backgroundImageUrl != null &&
                            room.backgroundImageUrl!.isNotEmpty
                        ? Colors.white
                        : context.hTextTertiary,
                    size: 20,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditRoomDialog(room);
                        break;
                      case 'icon':
                        _showIconPickerDialog(room);
                        break;
                      case 'background':
                        _showBackgroundImageDialog(room);
                        break;
                      case 'delete':
                        _showDeleteRoomDialog(room);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text(AppStrings.get('rooms_edit_room_2')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'icon',
                      child: ListTile(
                        leading: Icon(Icons.category_outlined),
                        title: Text(AppStrings.get('rooms_change_icon')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'background',
                      child: ListTile(
                        leading: Icon(Icons.image_outlined),
                        title: Text(AppStrings.get('rooms_background_image')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text(
                          'Delete Room',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
