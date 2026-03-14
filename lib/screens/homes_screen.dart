import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/smart_home_service.dart';
import '../models/home.dart';
import 'rooms_screen.dart';
import '../utils/phosphor_icons.dart';

class HomesScreen extends StatefulWidget {
  final VoidCallback? onHomeChanged;

  const HomesScreen({super.key, this.onHomeChanged});

  @override
  State<HomesScreen> createState() => _HomesScreenState();
}

class _HomesScreenState extends State<HomesScreen> {
  final SmartHomeService _service = SmartHomeService();
  final TextEditingController _nameController = TextEditingController();
  List<Home> _homes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadHomes() async {
    try {
      setState(() => _isLoading = true);
      final homes = await _service.getMyHomes();
      setState(() {
        _homes = homes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load homes: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createHome() async {
    debugPrint('Create home button pressed');

    if (_nameController.text.trim().isEmpty) {
      debugPrint('Home name is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a home name'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    try {
      debugPrint('Creating home: ${_nameController.text.trim()}');
      final home = await _service.createHome(_nameController.text.trim());
      debugPrint('Home created successfully: ${home.name}');

      setState(() {
        _homes.add(home);
      });
      _nameController.clear();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Home "${home.name}" created successfully!'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that homes have changed
      widget.onHomeChanged?.call();
    } catch (e) {
      debugPrint('Failed to create home: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create home: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editHome(Home home) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a home name'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    try {
      await _service.renameHome(home.id, _nameController.text.trim());

      // Update the home in the local list
      setState(() {
        final index = _homes.indexWhere((h) => h.id == home.id);
        if (index != -1) {
          _homes[index] = Home(
            id: home.id,
            name: _nameController.text.trim(),
            ownerId: home.ownerId,
            createdAt: home.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Home "${_nameController.text.trim()}" updated successfully!',
            ),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that homes have changed
      widget.onHomeChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update home: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteHome(Home home) async {
    try {
      await _service.deleteHome(home.id);

      // Remove the home from the local list
      setState(() {
        _homes.removeWhere((h) => h.id == home.id);
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Home "${home.name}" deleted successfully!'),
            backgroundColor: HBotColors.primary,
          ),
        );
      }

      // Notify parent that homes have changed
      widget.onHomeChanged?.call();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete home: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  void _showCreateHomeBottomSheet() {
    _nameController.clear();
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
                'New Home',
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
                  hintText: 'e.g., My House, Office, etc.',
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
                onTap: _createHome,
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
                      'Create',
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

  void _showEditHomeBottomSheet(Home home) {
    _nameController.text = home.name;
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
                'Edit Home',
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
                  hintText: 'Home name',
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
                onTap: () => _editHome(home),
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

  void _showDeleteHomeDialog(Home home) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Home?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A1628),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${home.name}"? This action cannot be undone and will delete all rooms and devices in this home.',
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
                _deleteHome(home);
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

  void _showHomeOptionsSheet(Home home) {
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
                leading: Icon(HBotIcons.room, color: Color(0xFF5A6577)),
                title: const Text(
                  'Manage Rooms',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF0A1628)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomsScreen(
                        home: home,
                        onRoomChanged: () {},
                      ),
                    ),
                  );
                  await _loadHomes();
                  widget.onHomeChanged?.call();
                },
              ),
              ListTile(
                leading: Icon(HBotIcons.edit, color: Color(0xFF5A6577)),
                title: const Text(
                  'Edit Home',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFF0A1628)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditHomeBottomSheet(home);
                },
              ),
              ListTile(
                leading: Icon(HBotIcons.delete, color: Color(0xFFEF4444)),
                title: const Text(
                  'Delete Home',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, color: Color(0xFFEF4444)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteHomeDialog(home);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Homes',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1628),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(HBotIcons.add, color: Color(0xFF0883FD)),
            onPressed: _showCreateHomeBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0883FD)),
              ),
            )
          : _homes.isEmpty
              ? _buildEmptyState()
              : _buildHomesList(),
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
              'No homes yet',
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
                'Create your first home to start managing your smart devices.',
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
              onTap: _showCreateHomeBottomSheet,
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
                    '+ Create Your First Home',
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

  Widget _buildHomesList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Homes list card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8ECF1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ...List.generate(_homes.length, (index) {
                  final home = _homes[index];
                  final isLast = index == _homes.length - 1;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomsScreen(
                                home: home,
                                onRoomChanged: () {},
                              ),
                            ),
                          );
                          await _loadHomes();
                          widget.onHomeChanged?.call();
                        },
                        onLongPress: () => _showHomeOptionsSheet(home),
                        child: Container(
                          height: 72,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Leading gradient icon circle
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  HBotIcons.homeFilled,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Home name
                              Expanded(
                                child: Text(
                                  home.name,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0A1628),
                                  ),
                                ),
                              ),
                              // More options
                              IconButton(
                                icon: Icon(
                                  HBotIcons.more,
                                  color: Color(0xFFA0AAB8),
                                  size: 20,
                                ),
                                onPressed: () => _showHomeOptionsSheet(home),
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
                // Add Home row
                const Padding(
                  padding: EdgeInsets.only(left: 68),
                  child: Divider(height: 1, color: Color(0xFFF0F2F5)),
                ),
                InkWell(
                  onTap: _showCreateHomeBottomSheet,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F7FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0883FD).withOpacity(0.3),
                              width: 1.5,
                              strokeAlign: BorderSide.strokeAlignInside,
                            ),
                          ),
                          child: Icon(
                            HBotIcons.add,
                            color: Color(0xFF0883FD),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Add Home',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0883FD),
                          ),
                        ),
                      ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
