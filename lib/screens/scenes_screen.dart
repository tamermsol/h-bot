import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scene.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../utils/error_handler.dart';
import '../widgets/error_message_widget.dart';
import 'add_scene_screen.dart';

class ScenesScreen extends StatefulWidget {
  const ScenesScreen({super.key});

  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen>
    with AutomaticKeepAliveClientMixin {
  final SmartHomeService _service = SmartHomeService();
  final CurrentHomeService _currentHomeService = CurrentHomeService();

  List<Scene> _scenes = [];
  bool _isLoading = true;
  String? _currentHomeId;
  String? _errorMessage;
  String? _runningSceneId;

  @override
  bool get wantKeepAlive => false; // Don't keep state alive, reload each time

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload scenes when the widget becomes visible again
    _loadScenes();
  }

  Future<void> _loadScenes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Get current home ID
      _currentHomeId = await _currentHomeService.getCurrentHomeId();
      debugPrint('ScenesScreen: _loadScenes - currentHomeId = $_currentHomeId');

      if (_currentHomeId == null) {
        // No home selected, show empty state
        debugPrint('ScenesScreen: No home selected');
        setState(() {
          _scenes = [];
          _isLoading = false;
        });
        return;
      }

      // Load scenes for current home
      debugPrint('ScenesScreen: Loading scenes for home: $_currentHomeId');
      final scenes = await _service.getScenes(_currentHomeId!);
      debugPrint('ScenesScreen: Loaded ${scenes.length} scenes');

      setState(() {
        _scenes = scenes;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      // Log error for debugging (only in debug mode)
      ErrorHandler.logError(e, context: 'ScenesScreen._loadScenes');

      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  // ── Icon mapping for scene icon codes ──
  IconData _getSceneIcon(Scene scene) {
    if (scene.iconCode != null) {
      return IconData(scene.iconCode!, fontFamily: 'MaterialIcons');
    }
    return Icons.play_arrow;
  }

  Color _getSceneColor(Scene scene) {
    if (scene.colorValue != null) {
      return Color(scene.colorValue!);
    }
    return const Color(0xFFF59E0B); // Default amber
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HBotSpacing.space6),
          child: ErrorMessageWidget(error: _errorMessage, onRetry: _loadScenes),
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Appbar
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scenes',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${_scenes.length} scene${_scenes.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _currentHomeId == null
                  ? _buildNoHomeState()
                  : _scenes.isEmpty
                      ? _buildEmptyState()
                      : _buildScenesList(),
            ),
          ],
        ),
        // FAB
        Positioned(
          bottom: 88,
          right: 20,
          child: GestureDetector(
            onTap: _showCreateSceneDialog,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x610883FD), // rgba(8,131,253,0.38)
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoHomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.home_outlined, size: 28, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Home Selected',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a home from the dashboard',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sparkles icon in circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome, size: 28, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No scenes yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Automate your home with custom scenes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showCreateSceneDialog,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Create Your First Scene',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildScenesList() {
    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 112),
      itemCount: _scenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final scene = _scenes[index];
        final iconData = _getSceneIcon(scene);
        final color = _getSceneColor(scene);
        final isRunning = _runningSceneId == scene.id;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRunning ? const Color(0xFF0883FD) : const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Icon circle with gradient
              Opacity(
                opacity: scene.isEnabled ? 1.0 : 0.45,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.73)], // color + colorBB
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconData, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            scene.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!scene.isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'OFF',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Description line -- placeholder since Scene model may not have description
                    const SizedBox(height: 2),
                    Text(
                      scene.isEnabled ? 'Active' : 'Disabled',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Actions count + trigger
                    Text(
                      '${scene.isEnabled ? "Enabled" : "Disabled"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFFC9CDD6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Play button
              GestureDetector(
                onTap: scene.isEnabled && !isRunning ? () => _runScene(scene) : null,
                child: Opacity(
                  opacity: (!scene.isEnabled || isRunning) ? 0.4 : 1.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning
                          ? const Color(0xFF0883FD)
                          : color.withOpacity(0.18),
                      border: isRunning
                          ? null
                          : Border.all(color: color.withOpacity(0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: isRunning
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.play_arrow, size: 15, color: color),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // More menu button
              GestureDetector(
                onTap: () => _showSceneContextMenu(scene),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.more_vert, size: 16, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSceneContextMenu(Scene scene) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => _SceneCardMenu(
        scene: scene,
        onEnable: () {
          Navigator.pop(context);
          _toggleScene(scene);
        },
        onEdit: () {
          Navigator.pop(context);
          _showEditSceneDialog(scene);
        },
        onDelete: () {
          Navigator.pop(context);
          _showDeleteConfirmSheet(scene);
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showDeleteConfirmSheet(Scene scene) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 40, offset: Offset(0, -8))],
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Scene?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"${scene.name}" will be permanently deleted.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Delete button
              GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _service.deleteScene(scene.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Scene "${scene.name}" deleted successfully!'),
                          backgroundColor: HBotColors.primary,
                        ),
                      );
                    }
                    await _loadScenes();
                  } catch (e) {
                    ErrorHandler.logError(e, context: 'ScenesScreen._deleteScene');
                    if (mounted) {
                      ErrorSnackBar.show(context, e);
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Cancel button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSceneDetails(Scene scene) {
    // Navigate to edit mode directly when tapping a scene
    _showEditSceneDialog(scene);
  }

  Future<void> _runScene(Scene scene) async {
    try {
      setState(() => _runningSceneId = scene.id);
      await _service.runScene(scene.id);
      // Show running state for 1.8 seconds like v0
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) setState(() => _runningSceneId = null);
    } catch (e) {
      if (mounted) setState(() => _runningSceneId = null);
      ErrorHandler.logError(e, context: 'ScenesScreen._runScene');
      if (mounted) {
        ErrorSnackBar.show(context, e);
      }
    }
  }

  Future<void> _toggleScene(Scene scene) async {
    try {
      await _service.updateScene(scene.id, isEnabled: !scene.isEnabled);
      await _loadScenes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scene "${scene.name}" ${!scene.isEnabled ? "enabled" : "disabled"}',
            ),
            backgroundColor: HBotColors.primary,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ScenesScreen._toggleScene');
      if (mounted) {
        ErrorSnackBar.show(context, e);
      }
    }
  }

  Future<void> _showEditSceneDialog(Scene scene) async {
    if (_currentHomeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No home selected'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    // Navigate to AddSceneScreen in edit mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddSceneScreen(homeId: _currentHomeId!, sceneId: scene.id),
      ),
    );

    // Reload scenes if the scene was updated
    if (result == true) {
      await _loadScenes();
    }
  }

  void _showCreateSceneDialog() async {
    debugPrint('ScenesScreen: _showCreateSceneDialog called');
    debugPrint('ScenesScreen: _currentHomeId = $_currentHomeId');

    if (_currentHomeId == null) {
      debugPrint('ScenesScreen: No home selected, showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a home first'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    debugPrint(
      'ScenesScreen: Navigating to AddSceneScreen with homeId: $_currentHomeId',
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSceneScreen(homeId: _currentHomeId!),
      ),
    );

    if (result == true) {
      // Reload scenes after creation
      debugPrint('ScenesScreen: Scene created successfully, reloading scenes');
      await _loadScenes();
    }
  }
}

// ── Scene Card Menu (bottom sheet) ──
class _SceneCardMenu extends StatelessWidget {
  final Scene scene;
  final VoidCallback onEnable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _SceneCardMenu({
    required this.scene,
    required this.onEnable,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 40, offset: Offset(0, -8))],
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            // Scene name
            Text(
              scene.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),

            // Enable/Disable
            _MenuOption(
              icon: Icons.power_settings_new,
              label: scene.isEnabled ? 'Disable Scene' : 'Enable Scene',
              color: const Color(0xFF1F2937),
              iconBg: const Color(0xFFF5F7FA),
              onTap: onEnable,
              showTopBorder: false,
            ),
            // Edit
            _MenuOption(
              icon: Icons.edit,
              label: 'Edit Scene',
              color: const Color(0xFF1F2937),
              iconBg: const Color(0xFFF5F7FA),
              onTap: onEdit,
              showTopBorder: true,
            ),
            // Delete
            _MenuOption(
              icon: Icons.delete_outline,
              label: 'Delete Scene',
              color: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFFF1F2),
              onTap: onDelete,
              showTopBorder: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;
  final bool showTopBorder;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBg,
    required this.onTap,
    required this.showTopBorder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          border: showTopBorder
              ? const Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
