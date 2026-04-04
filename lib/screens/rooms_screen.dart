import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../services/smart_home_service.dart';
import '../services/room_change_notifier.dart';
import '../repos/rooms_repo.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../widgets/background_image_picker.dart';
import '../widgets/background_container.dart';
import '../widgets/room_icon_picker.dart';
import 'devices_screen.dart';
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
  String _activeFilter = 'All Rooms';

  // Room-based pill tabs
  List<String> get _roomTabs {
    final tabs = <String>['All Rooms'];
    for (final room in _rooms) {
      tabs.add(room.name);
    }
    return tabs;
  }

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
            content: Text('${AppStrings.get("success_room_created")}: ${room.name}'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      widget.onRoomChanged?.call();
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
        backgroundColor: HBotColors.sheetBackground,
        title: Text(
          AppStrings.get('rooms_create_new_room'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppStrings.get('rooms_room_name'),
            hintText: AppStrings.get('rooms_eg_living_room_kitchen_etc'),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            enabledBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: BorderSide(color: HBotColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: HBotRadius.mediumRadius,
              borderSide: const BorderSide(color: HBotColors.primary),
            ),
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
            style: ElevatedButton.styleFrom(backgroundColor: HBotColors.primary),
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
            content: Text('${AppStrings.get("success_room_updated")}: ${updatedRoom.name}'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      widget.onRoomChanged?.call();
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

      setState(() {
        _rooms.removeWhere((r) => r.id == room.id);
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("success_room_deleted")}: ${room.name}'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      widget.onRoomChanged?.call();
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
          backgroundColor: HBotColors.sheetBackground,
          title: Text(
            AppStrings.get('rooms_edit_room'),
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: AppStrings.get('rooms_room_name_2'),
              hintText: AppStrings.get('rooms_eg_living_room_kitchen_etc_2'),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              enabledBorder: OutlineInputBorder(
                borderRadius: HBotRadius.mediumRadius,
                borderSide: BorderSide(color: HBotColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: HBotRadius.mediumRadius,
                borderSide: const BorderSide(color: HBotColors.primary),
              ),
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
              style: ElevatedButton.styleFrom(backgroundColor: HBotColors.primary),
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
          backgroundColor: HBotColors.sheetBackground,
          title: Text(
            AppStrings.get('rooms_delete_room'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${room.name}"? This action cannot be undone and will remove all devices in this room.',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
          backgroundColor: HBotColors.sheetBackground,
          title: Text(
            AppStrings.get('rooms_room_background_image'),
            style: const TextStyle(color: Colors.white),
          ),
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
              backgroundColor: HBotColors.sheetBackground,
              title: Text(
                AppStrings.get('rooms_change_room_icon'),
                style: const TextStyle(color: Colors.white),
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
                  style: ElevatedButton.styleFrom(backgroundColor: HBotColors.primary),
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
    if (room.iconName != null && room.iconName!.isNotEmpty) {
      return RoomIconPicker.getIconData(room.iconName);
    }

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

  void _showDevicesBottomSheet(Room room) {
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
  }

  List<Room> get _filteredRooms {
    if (_activeFilter == 'All Rooms') return _rooms;
    return _rooms.where((r) => r.name == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: back button + "Rooms" title + add button
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HBotSpacing.space5, HBotSpacing.space4,
                  HBotSpacing.space5, 0,
                ),
                child: Row(
                  children: [
                    HBotIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: HBotSpacing.space4),
                    const Expanded(
                      child: Text(
                        'Rooms',
                        style: TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    HBotIconButton(
                      icon: Icons.add_rounded,
                      onTap: _showCreateRoomDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: HBotSpacing.space4),

              // Horizontal scrollable room pill tabs
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
                  itemCount: _roomTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final tab = _roomTabs[index];
                    final isActive = tab == _activeFilter;
                    return HBotPillTab(
                      label: tab,
                      isActive: isActive,
                      onTap: () => setState(() => _activeFilter = tab),
                    );
                  },
                ),
              ),

              const SizedBox(height: HBotSpacing.space5),

              // "Your Rooms" page title
              Padding(
                padding: const EdgeInsets.only(
                  left: HBotSpacing.space5,
                  right: HBotSpacing.space5,
                  bottom: 20,
                ),
                child: const Text(
                  'Your Rooms',
                  style: TextStyle(
                    fontFamily: 'Readex Pro',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
                        ),
                      )
                    : _rooms.isEmpty
                        ? _buildEmptyState()
                        : _buildRoomsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: Icon(
                Icons.room_outlined,
                size: 36,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              AppStrings.get('rooms_no_rooms_yet'),
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              AppStrings.get('rooms_add_rooms_desc'),
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            HBotGradientButton(
              onTap: _showCreateRoomDialog,
              fullWidth: false,
              padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 20),
                  const SizedBox(width: 8),
                  Text(AppStrings.get('rooms_add_your_first_room')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    final rooms = _filteredRooms;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(Room room) {
    final hasBackground = room.backgroundImageUrl != null &&
        room.backgroundImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _showDevicesBottomSheet(room),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: HBotColors.glassBorder,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background image if available
                  if (hasBackground)
                    Positioned.fill(
                      child: BackgroundContainer(
                        backgroundImageUrl: room.backgroundImageUrl,
                        overlayColor: Colors.black,
                        overlayOpacity: 0.6,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  // Card content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Room icon -- 40x40 with tinted background, 12px radius
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0x1A0883FD),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getRoomIcon(room),
                                color: HBotColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Room name and subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: const TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppStrings.get('rooms_tap_manage'),
                                    style: const TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontSize: 12,
                                      color: HBotColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Device count badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: HBotColors.glassBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.devices, size: 12, color: HBotColors.textMuted),
                                  SizedBox(width: 4),
                                  Text(
                                    'Devices',
                                    style: TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontSize: 12,
                                      color: HBotColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // More menu
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.white.withOpacity(0.6),
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
                                    leading: const Icon(Icons.edit_outlined),
                                    title: Text(AppStrings.get('rooms_edit_room_2')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'icon',
                                  child: ListTile(
                                    leading: const Icon(Icons.category_outlined),
                                    title: Text(AppStrings.get('rooms_change_icon')),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'background',
                                  child: ListTile(
                                    leading: const Icon(Icons.image_outlined),
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Action buttons row
                        Row(
                          children: [
                            // "View Devices" outlined button
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showDevicesBottomSheet(room),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0x14FFFFFF),
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'View Devices',
                                    style: TextStyle(
                                      fontFamily: 'Readex Pro',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // "All Off" gradient button
                            GestureDetector(
                              onTap: () {
                                // Placeholder -- could turn off all devices in room
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment(-0.7, -0.7),
                                    end: Alignment(0.7, 0.7),
                                    colors: [Color(0xFF0883FD), Color(0xFF2FB8EC)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'All Off',
                                  style: TextStyle(
                                    fontFamily: 'Readex Pro',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
