import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scene.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../utils/error_handler.dart';
import '../widgets/error_message_widget.dart';
import '../widgets/scene_card.dart';
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

    return _currentHomeId == null
        ? _buildNoHomeState()
        : _scenes.isEmpty
        ? _buildEmptyState()
        : _buildScenesList();
  }

  Widget _buildNoHomeState() {
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
                color: HBotColors.neutral100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.home_outlined,
                size: 48,
                color: HBotColors.neutral300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Home Selected',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 260),
              child: Text(
                'Please select a home from the dashboard to view and manage scenes',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HBotColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: HBotColors.neutral100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_outline,
                size: 48,
                color: HBotColors.neutral300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No scenes yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: HBotColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 260),
              child: Text(
                'Create scenes to control multiple devices with a single tap.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: HBotColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _showCreateSceneDialog,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: HBotColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  alignment: Alignment.center,
                  child: const Text(
                    '+ Create Scene',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _scenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final scene = _scenes[index];

        // Get icon from scene or use default
        final iconData = scene.iconCode != null
            ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
            : Icons.auto_awesome;

        // Convert Scene model to map for SceneCard widget
        final sceneMap = <String, dynamic>{
          'name': scene.name,
          'isActive': scene.isEnabled,
          'icon': iconData,
          'description': scene.isEnabled ? 'Enabled' : 'Disabled',
        };

        return GestureDetector(
          onLongPress: () => _showSceneContextMenu(scene),
          child: SceneCard(
            scene: sceneMap,
            onToggle: (value) => _toggleScene(scene),
            onTap: () => _showSceneDetails(scene),
            onPlay: () => _runScene(scene),
          ),
        );
      },
    );
  }

  void _showSceneContextMenu(Scene scene) {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HBotRadius.xl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HBotColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: HBotColors.iconDefault),
                title: const Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HBotColors.textPrimaryLight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditSceneDialog(scene);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: HBotColors.iconDefault),
                title: const Text(
                  'Duplicate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HBotColors.textPrimaryLight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Duplicate scene: navigate to add scene in create mode with pre-filled data
                  _showEditSceneDialog(scene);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: HBotColors.error),
                title: const Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HBotColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteSceneDialog(scene);
                },
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
      // Execute scene silently without showing notifications
      await _service.runScene(scene.id);
    } catch (e) {
      // Log error for debugging
      ErrorHandler.logError(e, context: 'ScenesScreen._runScene');

      // Show user-friendly error message
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
      // Log error for debugging
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

  void _showDeleteSceneDialog(Scene scene) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotTheme.card(context),
          title: const Text('Delete Scene'),
          content: Text(
            'Are you sure you want to delete "${scene.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteScene(scene.id);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Scene "${scene.name}" deleted successfully!',
                        ),
                        backgroundColor: HBotColors.primary,
                      ),
                    );
                  }

                  await _loadScenes();
                } catch (e) {
                  // Log error for debugging
                  ErrorHandler.logError(
                    e,
                    context: 'ScenesScreen._deleteScene',
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ErrorSnackBar.show(context, e);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: HBotColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
