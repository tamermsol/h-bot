import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scene.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../utils/error_handler.dart';
import '../widgets/error_message_widget.dart';
import 'add_scene_screen.dart';
import '../widgets/responsive_shell.dart';

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
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary)),
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

    if (_currentHomeId == null) return SafeArea(child: _buildNoHomeState());
    if (_scenes.isEmpty) return SafeArea(child: _buildEmptyState());

    return SafeArea(child: Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            HBotSpacing.space5, HBotSpacing.space3,
            HBotSpacing.space5, 80, // bottom padding for FAB
          ),
          itemCount: _scenes.length + 1, // +1 for header
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: HBotSpacing.space4),
                child: Text(
                  'Scenes',
                  style: const TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: HBotColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
              );
            }
            return _buildSceneCard(_scenes[index - 1]);
          },
        ),
        // Gradient FAB — bottom right
        Positioned(
          right: HBotSpacing.space5,
          bottom: HBotSpacing.space5,
          child: Container(
            decoration: BoxDecoration(
              gradient: HBotColors.primaryGradient,
              borderRadius: HBotRadius.mediumRadius,
              boxShadow: HBotShadows.medium,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: HBotRadius.mediumRadius,
                onTap: _showCreateSceneDialog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: HBotSpacing.space5, vertical: HBotSpacing.space3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: HBotSpacing.space2),
                      Text('Add Scene', style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildSceneCard(Scene scene) {
    final iconData = scene.iconCode != null
        ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.auto_awesome;
    final sceneColor = scene.colorValue != null
        ? Color(scene.colorValue!)
        : HBotColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: HBotSpacing.space3),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        borderRadius: HBotRadius.largeRadius,
        border: Border.all(color: HBotColors.borderLight, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: HBotRadius.largeRadius,
          onTap: () => _showSceneDetails(scene),
          child: Padding(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            child: Row(
              children: [
                // Scene icon — 48×48 rounded container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scene.isEnabled ? sceneColor.withOpacity(0.12) : HBotColors.neutral100,
                    borderRadius: HBotRadius.mediumRadius,
                  ),
                  child: Icon(iconData, color: scene.isEnabled ? sceneColor : HBotColors.neutral400, size: 24),
                ),
                const SizedBox(width: HBotSpacing.space4),
                // Scene info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.name,
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 16, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scene.isEnabled ? 'Enabled' : 'Disabled',
                        style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: HBotColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                // Play button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: scene.isEnabled ? HBotColors.primaryGradient : null,
                    color: scene.isEnabled ? null : HBotColors.neutral200,
                    borderRadius: HBotRadius.fullRadius,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.play_arrow, color: scene.isEnabled ? Colors.white : HBotColors.neutral400, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: scene.isEnabled ? () => _executeScene(scene) : null,
                  ),
                ),
                const SizedBox(width: HBotSpacing.space2),
                // More menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: HBotColors.neutral400, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle': _toggleScene(scene);
                      case 'edit': _showEditSceneDialog(scene);
                      case 'delete': _showDeleteSceneDialog(scene);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'toggle', child: Row(children: [
                      Icon(scene.isEnabled ? Icons.pause : Icons.play_arrow, size: 20),
                      const SizedBox(width: 12),
                      Text(scene.isEnabled ? 'Disable' : 'Enable'),
                    ])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoHomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: HBotColors.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.home_outlined, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            const Text('No Home Selected', style: TextStyle(fontFamily: 'DM Sans', fontSize: 20, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight)),
            const SizedBox(height: HBotSpacing.space2),
            const Text('Select a home from the dashboard to manage scenes', style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: HBotColors.textSecondaryLight), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: HBotColors.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_outlined, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            const Text('No Scenes Yet', style: TextStyle(fontFamily: 'DM Sans', fontSize: 20, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight)),
            const SizedBox(height: HBotSpacing.space2),
            const Text('Create your first scene to automate your smart home', style: TextStyle(fontFamily: 'DM Sans', fontSize: 14, color: HBotColors.textSecondaryLight), textAlign: TextAlign.center),
            const SizedBox(height: HBotSpacing.space6),
            Container(
              decoration: hbotPrimaryButtonDecoration(),
              child: ElevatedButton.icon(
                onPressed: _showCreateSceneDialog,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create Your First Scene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space6, vertical: HBotSpacing.space3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSceneDetails(Scene scene) {
    final iconData = scene.iconCode != null
        ? IconData(scene.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.auto_awesome;
    final sceneColor = scene.colorValue != null
        ? Color(scene.colorValue!)
        : HBotColors.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HBotSpacing.space6)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(HBotSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: HBotSpacing.space5),
                  decoration: BoxDecoration(color: HBotColors.neutral300, borderRadius: HBotRadius.fullRadius),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: sceneColor.withOpacity(0.12),
                      borderRadius: HBotRadius.mediumRadius,
                    ),
                    child: Icon(iconData, color: sceneColor, size: 28),
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(scene.name, style: const TextStyle(fontFamily: 'DM Sans', fontSize: 18, fontWeight: FontWeight.w600, color: HBotColors.textPrimaryLight)),
                        const SizedBox(height: 2),
                        Text(
                          scene.isEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: scene.isEnabled ? sceneColor : HBotColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HBotSpacing.space6),

              // Run Scene Button — gradient
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: hbotPrimaryButtonDecoration(),
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _runScene(scene); },
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Run Scene', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: HBotSpacing.space3),

              // Edit Button — outlined
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); _showEditSceneDialog(scene); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HBotColors.textPrimaryLight,
                    side: const BorderSide(color: HBotColors.borderLight),
                    shape: RoundedRectangleBorder(borderRadius: HBotRadius.mediumRadius),
                  ),
                  child: const Text('Edit Scene', style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeScene(Scene scene) => _runScene(scene);

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
    final cardColor = HBotColors.cardLight;

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
