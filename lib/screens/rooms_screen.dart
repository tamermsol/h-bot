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
            content: Text('Failed to load rooms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room name'),
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
            backgroundColor: AppTheme.primaryColor,
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
            content: Text('Failed to create room: $e'),
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
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Create New Room'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            hintText: 'e.g., Living Room, Kitchen, etc.',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _editRoom(Room room) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room name'),
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
            backgroundColor: AppTheme.primaryColor,
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
            content: Text('Failed to update room: $e'),
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
            backgroundColor: AppTheme.primaryColor,
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
            content: Text('Failed to delete room: $e'),
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
          backgroundColor: AppTheme.getCardColor(context),
          title: const Text('Edit Room'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Room Name',
              hintText: 'e.g., Living Room, Kitchen, etc.',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _editRoom(room),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Save'),
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
          backgroundColor: AppTheme.getCardColor(context),
          title: const Text('Delete Room'),
          content: Text(
            'Are you sure you want to delete "${room.name}"? This action cannot be undone and will remove all devices in this room.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _deleteRoom(room),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
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
          backgroundColor: AppTheme.getCardColor(context),
          title: const Text('Room Background Image'),
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
                        content: Text('Failed to update background: $e'),
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
              child: const Text('Close'),
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
              backgroundColor: AppTheme.getCardColor(context),
              title: const Text('Change Room Icon'),
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
                  child: const Text('Cancel'),
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
                          const SnackBar(
                            content: Text('Room icon updated successfully!'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update icon: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Save'),
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
          ? AppTheme.backgroundColor
          : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.backgroundColor
            : AppTheme.lightBackgroundColor,
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
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.room_outlined, size: 80, color: AppTheme.textHint),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              'No Rooms Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            Text(
              'Add rooms to organize your smart devices by location',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            ElevatedButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Room'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingLarge,
                  vertical: AppTheme.paddingMedium,
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
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        // Use EXACT same Card structure as Dashboard
        return Card(
          color: AppTheme.getCardColor(context),
          margin: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: AppTheme.paddingSmall,
          ),
          child: Stack(
            children: [
              // Background image if available
              if (room.backgroundImageUrl != null &&
                  room.backgroundImageUrl!.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: Row(
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        child: Icon(
                          _getRoomIcon(room),
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppTheme.paddingMedium),
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
                                    : AppTheme.getTextPrimary(context),
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
                                    : AppTheme.getTextSecondary(context),
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
                        : AppTheme.getTextHint(context),
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
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Room'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'icon',
                      child: ListTile(
                        leading: Icon(Icons.category_outlined),
                        title: Text('Change Icon'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'background',
                      child: ListTile(
                        leading: Icon(Icons.image_outlined),
                        title: Text('Background Image'),
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
