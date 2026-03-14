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
import '../utils/phosphor_icons.dart';

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
  // Device counts per room
  final Map<String, int> _deviceCounts = {};

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
      // Load device counts in background
      _loadDeviceCounts();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rooms: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadDeviceCounts() async {
    for (final room in _rooms) {
      try {
        final devices = await _service.getDevicesByRoom(room.id);
        if (mounted) {
          setState(() {
            _deviceCounts[room.id] = devices.length;
          });
        }
      } catch (_) {
        // Silently ignore count errors
      }
    }
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room name'),
          backgroundColor: HBotColors.error,
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
            content: Text('Failed to create room: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  void _showCreateRoomBottomSheet() {
    _nameController.clear();
    String? selectedIconName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D7E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'New Room',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A1628),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Room name input
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Color(0xFF0A1628),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Room name',
                      hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF7A8494),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0883FD), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save button
                  InkWell(
                    onTap: _createRoom,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        alignment: Alignment.center,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editRoom(Room room) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a room name'),
          backgroundColor: HBotColors.error,
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
            content: Text('Failed to update room: $e'),
            backgroundColor: HBotColors.error,
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
            content: Text('Failed to delete room: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  void _showEditRoomBottomSheet(Room room) {
    _nameController.text = room.name;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D7E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Room',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A1628),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Color(0xFF0A1628),
                ),
                decoration: InputDecoration(
                  hintText: 'Room name',
                  hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF7A8494),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8ECF1), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0883FD), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () => _editRoom(room),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    alignment: Alignment.center,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteRoomDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Room?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A1628),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${room.name}"? This action cannot be undone and will remove all devices in this room.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF5A6577),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontFamily: 'Inter', color: Color(0xFF5A6577)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRoom(room);
              },
              style: TextButton.styleFrom(foregroundColor: HBotColors.error),
              child: const Text(
                'Delete',
                style: TextStyle(fontFamily: 'Inter'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRoomOptionsSheet(Room room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D7E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(HBotIcons.edit, color: Color(0xFF5A6577)),
                title: const Text(
                  'Rename',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF0A1628)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditRoomBottomSheet(room);
                },
              ),
              ListTile(
                leading: Icon(HBotIcons.category, color: Color(0xFF5A6577)),
                title: const Text(
                  'Change Icon',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF0A1628)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showIconPickerDialog(room);
                },
              ),
              ListTile(
                leading: Icon(HBotIcons.image, color: Color(0xFF5A6577)),
                title: const Text(
                  'Background Image',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF0A1628)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showBackgroundImageDialog(room);
                },
              ),
              ListTile(
                leading: Icon(HBotIcons.delete, color: Color(0xFFEF4444)),
                title: const Text(
                  'Delete',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFFEF4444)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteRoomDialog(room);
                },
              ),
            ],
          ),
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
          backgroundColor: HBotTheme.card(context),
          title: const Text('Room Background Image'),
          content: SingleChildScrollView(
            child: BackgroundImagePicker(
              currentImageUrl: room.backgroundImageUrl,
              userId: user.id,
              type: 'room',
              entityId: room.id,
              onImageSelected: (imageUrl) async {
                try {
                  if (imageUrl == null) {
                    await _roomsRepo.updateRoom(room.id, clearBackground: true);
                  } else {
                    await _roomsRepo.updateRoom(
                      room.id,
                      backgroundImageUrl: imageUrl,
                    );
                  }

                  await _loadRooms();

                  if (mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update background: $e'),
                        backgroundColor: HBotColors.error,
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
              backgroundColor: HBotTheme.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Change Room Icon',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A1628),
                ),
              ),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontFamily: 'Inter', color: Color(0xFF5A6577)),
                  ),
                ),
                TextButton(
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

                      await _loadRooms();

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Room icon updated successfully!'),
                            backgroundColor: HBotColors.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update icon: $e'),
                            backgroundColor: HBotColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: HBotColors.primary),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontFamily: 'Inter'),
                  ),
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
      return HBotIcons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Rooms',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1628),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(HBotIcons.add, color: Color(0xFF0883FD)),
            onPressed: _showCreateRoomBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0883FD)),
              ),
            )
          : _rooms.isEmpty
              ? _buildEmptyState()
              : _buildRoomsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F2F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                HBotIcons.home,
                size: 48,
                color: Color(0xFFD1D7E0),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No rooms yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A1628),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 260,
              child: Text(
                'Organize your devices by adding rooms.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF5A6577),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _showCreateRoomBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  child: const Text(
                    '+ Add Room',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: List.generate(_rooms.length, (index) {
            final room = _rooms[index];
            final deviceCount = _deviceCounts[room.id] ?? 0;
            final isLast = index == _rooms.length - 1;

            return Column(
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DevicesScreen(
                          home: widget.home,
                          room: room,
                          onDeviceChanged: () {},
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _showRoomOptionsSheet(room),
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Leading icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F7FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getRoomIcon(room),
                            color: const Color(0xFF0883FD),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Room info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A1628),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$deviceCount device${deviceCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF5A6577),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chevron
                        Icon(
                          HBotIcons.chevronRight,
                          size: 20,
                          color: Color(0xFFA0AAB8),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Container(
                      height: 1,
                      color: const Color(0xFFF0F2F5),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
