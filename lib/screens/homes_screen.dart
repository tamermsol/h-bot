import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/smart_home_service.dart';
import '../models/home.dart';
import 'rooms_screen.dart';
import '../widgets/responsive_shell.dart';

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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createHome() async {
    debugPrint('🏠 Create home button pressed');

    if (_nameController.text.trim().isEmpty) {
      debugPrint('❌ Home name is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a home name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      debugPrint('🔄 Creating home: ${_nameController.text.trim()}');
      final home = await _service.createHome(_nameController.text.trim());
      debugPrint('✅ Home created successfully: ${home.name}');

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
      debugPrint('❌ Failed to create home: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create home: $e'),
            backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateHomeDialog() {
    debugPrint('🔘 Show create home dialog called');
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        debugPrint('🔘 Dialog builder called');
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          title: const Text('Create New Home'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Home Name',
              hintText: 'e.g., My House, Office, etc.',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('🔘 Cancel button pressed');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                debugPrint('🔘 Create button pressed');
                _createHome();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showEditHomeDialog(Home home) {
    _nameController.text = home.name;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          title: const Text('Edit Home'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Home Name',
              hintText: 'e.g., My House, Office, etc.',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _editHome(home),
              style: ElevatedButton.styleFrom(
                backgroundColor: HBotColors.primary,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteHomeDialog(Home home) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.cardLight,
          title: const Text('Delete Home'),
          content: Text(
            'Are you sure you want to delete "${home.name}"? This action cannot be undone and will delete all rooms and devices in this home.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _deleteHome(home),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'My Homes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              debugPrint('➕ Add button in app bar pressed');
              _showCreateHomeDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _homes.isEmpty
          ? _buildEmptyState()
          : _buildHomesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 80, color: HBotColors.textTertiaryLight),
            const SizedBox(height: HBotSpacing.space6),
            Text(
              'No Homes Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: HBotColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              'Create your first home to start managing your smart devices',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: HBotColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            ElevatedButton.icon(
              onPressed: () {
                debugPrint('🏠 Create Your First Home button pressed');
                _showCreateHomeDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Home'),
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

  Widget _buildHomesList() {

    return ListView.builder(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      itemCount: _homes.length,
      itemBuilder: (context, index) {
        final home = _homes[index];
        return Card(
          color: HBotColors.cardLight,
          margin: const EdgeInsets.only(bottom: HBotSpacing.space4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: HBotRadius.mediumRadius,
            side: const BorderSide(color: HBotColors.borderLight),
          ),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: HBotColors.primary.withOpacity(0.1),
                borderRadius: HBotRadius.mediumRadius,
              ),
              child: Icon(Icons.home, color: HBotColors.primary),
            ),
            title: Text(
              home.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            subtitle: Text(
              'Created ${_formatDate(home.createdAt)}',
              style: const TextStyle(color: HBotColors.textSecondaryLight),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: HBotColors.textTertiaryLight),
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _showEditHomeDialog(home);
                    break;
                  case 'delete':
                    _showDeleteHomeDialog(home);
                    break;
                  case 'rooms':
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomsScreen(
                          home: home,
                          onRoomChanged: () {
                            // Callback is called while still on RoomsScreen
                            // We'll reload data after returning instead
                          },
                        ),
                      ),
                    );
                    // Reload homes data to get updated room names
                    await _loadHomes();
                    // Notify parent dashboard to refresh
                    widget.onHomeChanged?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rooms',
                  child: ListTile(
                    leading: Icon(Icons.room_outlined),
                    title: Text('Manage Rooms'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit Home'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      'Delete Home',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomsScreen(
                    home: home,
                    onRoomChanged: () {
                      // Callback is called while still on RoomsScreen
                      // We'll reload data after returning instead
                    },
                  ),
                ),
              );
              // Reload homes data to get updated room names
              await _loadHomes();
              // Notify parent dashboard to refresh
              widget.onHomeChanged?.call();
            },
          ),
        );
      },
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
