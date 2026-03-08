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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: ErrorMessageWidget(error: _errorMessage, onRetry: _loadScenes),
        ),
      );
    }

    return _currentHomeId == null
        ? _buildNoHomeState()
        : _scenes.isEmpty
        ? _buildEmptyState()
        : Column(
            children: [
              // Add Scene Button at the top
              Padding(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _currentHomeId != null
                        ? _showCreateSceneDialog
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Scene'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              // Scenes Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingMedium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_buildScenesGrid()],
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildNoHomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 80, color: AppTheme.textHint),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              'No Home Selected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            Text(
              'Please select a home from the dashboard to view and manage scenes',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 80,
              color: AppTheme.textHint,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              'No Scenes Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            Text(
              'Create your first scene to automate your smart home',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            ElevatedButton.icon(
              onPressed: _showCreateSceneDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Scene'),
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

  Widget _buildScenesGrid() {
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Scenes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.paddingMedium),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _scenes.length,
          itemBuilder: (context, index) {
            final scene = _scenes[index];

            // Get icon and color from scene or use defaults
            final iconData = scene.iconCode != null
                ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
                : Icons.auto_awesome;
            final sceneColor = scene.colorValue != null
                ? Color(scene.colorValue!)
                : AppTheme.primaryColor;

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: AppTheme.paddingMedium),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scene.isEnabled
                        ? sceneColor.withOpacity(0.2)
                        : AppTheme.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    iconData,
                    color: scene.isEnabled ? sceneColor : AppTheme.textHint,
                  ),
                ),
                title: Text(
                  scene.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  scene.isEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    color: scene.isEnabled
                        ? sceneColor
                        : AppTheme.textSecondary,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textHint),
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle':
                        _toggleScene(scene);
                        break;
                      case 'edit':
                        _showEditSceneDialog(scene);
                        break;
                      case 'delete':
                        _showDeleteSceneDialog(scene);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        leading: Icon(
                          scene.isEnabled ? Icons.pause : Icons.play_arrow,
                        ),
                        title: Text(scene.isEnabled ? 'Disable' : 'Enable'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Scene'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text(
                          'Delete Scene',
                          style: TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                onTap: () => _showSceneDetails(scene),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showSceneDetails(Scene scene) {
    // Get icon and color from scene or use defaults
    final iconData = scene.iconCode != null
        ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.auto_awesome;
    final sceneColor = scene.colorValue != null
        ? Color(scene.colorValue!)
        : AppTheme.primaryColor;
    final cardColor = AppTheme.getCardColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sceneColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Icon(iconData, color: sceneColor, size: 28),
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          scene.isEnabled ? 'Enabled' : 'Disabled',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scene.isEnabled
                                    ? sceneColor
                                    : AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingLarge),

              // Run Scene Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _runScene(scene);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Scene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.paddingMedium,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.paddingMedium),

              // Edit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditSceneDialog(scene);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardColor,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  child: const Text('Edit Scene'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            backgroundColor: AppTheme.primaryColor,
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
          backgroundColor: Colors.red,
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
    final cardColor = AppTheme.getCardColor(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
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
                        backgroundColor: AppTheme.primaryColor,
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          backgroundColor: Colors.red,
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
