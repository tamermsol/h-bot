import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../models/scene.dart';
import '../services/smart_home_service.dart';
import '../services/current_home_service.dart';
import '../utils/error_handler.dart';
import '../widgets/error_message_widget.dart';
import 'add_scene_screen.dart';
import '../l10n/app_strings.dart';

class ScenesScreen extends StatefulWidget {
  const ScenesScreen({super.key});

  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final SmartHomeService _service = SmartHomeService();
  final CurrentHomeService _currentHomeService = CurrentHomeService();

  List<Scene> _scenes = [];
  bool _isLoading = true;
  String? _currentHomeId;
  String? _errorMessage;
  final Set<String> _executingScenes = {};

  // Predefined gradients to cycle through for scene tiles
  static const List<LinearGradient> _tileGradients = [
    HBotColors.sceneMorningGradient,
    HBotColors.sceneAwayGradient,
    HBotColors.sceneNightGradient,
    HBotColors.sceneCustomGradient,
  ];

  static const List<IconData> _tileIcons = [
    Icons.wb_sunny_rounded,
    Icons.shield_rounded,
    Icons.nightlight_round,
    Icons.power_settings_new_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadScenes();
  }

  Future<void> _loadScenes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _currentHomeId = await _currentHomeService.getCurrentHomeId();
      debugPrint('ScenesScreen: _loadScenes - currentHomeId = $_currentHomeId');

      if (_currentHomeId == null) {
        debugPrint('ScenesScreen: No home selected');
        setState(() {
          _scenes = [];
          _isLoading = false;
        });
        return;
      }

      debugPrint('ScenesScreen: Loading scenes for home: $_currentHomeId');
      final scenes = await _service.getScenes(_currentHomeId!);
      debugPrint('ScenesScreen: Loaded ${scenes.length} scenes');

      setState(() {
        _scenes = scenes;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      ErrorHandler.logError(e, context: 'ScenesScreen._loadScenes');
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  LinearGradient _getGradientForScene(Scene scene, int index) {
    if (scene.colorValue != null) {
      final color = Color(scene.colorValue!);
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withOpacity(0.7)],
      );
    }
    return _tileGradients[index % _tileGradients.length];
  }

  IconData _getIconForScene(Scene scene, int index) {
    if (scene.iconCode != null) {
      return IconData(scene.iconCode!, fontFamily: 'MaterialIcons');
    }
    return _tileIcons[index % _tileIcons.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
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

    if (_currentHomeId == null) return SafeArea(child: _buildNoHomeState());
    if (_scenes.isEmpty) return SafeArea(child: _buildEmptyState());

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header — title left, gradient "+" button right
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HBotSpacing.space5, HBotSpacing.space4,
                HBotSpacing.space5, HBotSpacing.space5,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Scenes',
                      style: TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showCreateSceneDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.5, -0.5),
                          end: Alignment(0.5, 0.5),
                          colors: [HBotColors.primary, Color(0xFF3BC4FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D0883FD),
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2-column scene grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSceneTile(_scenes[index], index),
                childCount: _scenes.length,
              ),
            ),
          ),

          // "Create New Scene" tile — full width, dashed border
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HBotSpacing.space5, 12,
                HBotSpacing.space5, HBotSpacing.space5,
              ),
              child: GestureDetector(
                onTap: _showCreateSceneDialog,
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: HBotColors.glassBorder,
                    radius: 20,
                    dashWidth: 6,
                    dashSpace: 4,
                    strokeWidth: 2,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: HBotColors.glassBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: HBotColors.textMuted, size: 22),
                            const SizedBox(width: HBotSpacing.space2),
                            Text(
                              AppStrings.get('add_scene'),
                              style: const TextStyle(
                                fontFamily: 'Readex Pro',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HBotColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneTile(Scene scene, int index) {
    final gradient = _getGradientForScene(scene, index);
    final iconData = _getIconForScene(scene, index);
    final isExecuting = _executingScenes.contains(scene.id);

    return GestureDetector(
      onTap: () => _executeScene(scene),
      onLongPress: () => _showSceneDetails(scene),
      child: AnimatedOpacity(
        duration: HBotDurations.medium,
        opacity: scene.isEnabled ? 1.0 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 140),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            children: [
              // Radial glow overlay at top-right
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Centered content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon or loading spinner
                      isExecuting
                          ? const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(iconData, color: Colors.white, size: 32),
                      const SizedBox(height: HBotSpacing.space3),
                      // Scene name
                      Text(
                        scene.name,
                        style: const TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      // Device/action count
                      Text(
                        '${_scenes.length} devices',
                        style: TextStyle(
                          fontFamily: 'Readex Pro',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          scene.isEnabled
                              ? AppStrings.get('scene_enabled')
                              : AppStrings.get('scene_disabled'),
                          style: const TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Context menu — top-right, subtle
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: HBotColors.sheetBackground,
                  onSelected: (value) {
                    switch (value) {
                      case 'toggle':
                        _toggleScene(scene);
                      case 'edit':
                        _showEditSceneDialog(scene);
                      case 'delete':
                        _showDeleteSceneDialog(scene);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(scene.isEnabled ? Icons.pause : Icons.play_arrow, size: 20),
                        const SizedBox(width: 12),
                        Text(scene.isEnabled ? AppStrings.get('disable') : AppStrings.get('enable')),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(AppStrings.get('edit')),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        Text(AppStrings.get('delete'), style: const TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: const Icon(Icons.home_outlined, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            Text(
              AppStrings.get('no_home_selected'),
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              AppStrings.get('no_home_selected_subtitle'),
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
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
        padding: const EdgeInsets.all(HBotSpacing.space7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: HBotColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: HBotColors.glassBorder, width: 1),
              ),
              child: const Icon(Icons.auto_awesome_outlined, size: 32, color: HBotColors.primary),
            ),
            const SizedBox(height: HBotSpacing.space5),
            Text(
              AppStrings.get('no_scenes_title'),
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              AppStrings.get('no_scenes_subtitle'),
              style: TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),
            HBotGradientButton(
              onTap: _showCreateSceneDialog,
              fullWidth: false,
              padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 20),
                  const SizedBox(width: 8),
                  Text(AppStrings.get('create_first_scene')),
                ],
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
      backgroundColor: HBotColors.sheetBackground,
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: HBotSpacing.space5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: HBotRadius.fullRadius,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: sceneColor.withOpacity(0.2),
                      borderRadius: HBotRadius.mediumRadius,
                    ),
                    child: Icon(iconData, color: sceneColor, size: 28),
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scene.name,
                          style: const TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scene.isEnabled
                              ? AppStrings.get('scene_enabled')
                              : AppStrings.get('scene_disabled'),
                          style: TextStyle(
                            fontFamily: 'Readex Pro',
                            fontSize: 13,
                            color: scene.isEnabled ? sceneColor : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HBotSpacing.space6),

              // Run Scene Button
              HBotGradientButton(
                onTap: () {
                  Navigator.pop(context);
                  _runScene(scene);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.get('run_scene'),
                      style: const TextStyle(fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: HBotSpacing.space3),

              // Edit Button
              HBotOutlineButton(
                onTap: () {
                  Navigator.pop(context);
                  _showEditSceneDialog(scene);
                },
                child: Text(
                  AppStrings.get('edit_scene'),
                  style: const TextStyle(fontFamily: 'Readex Pro', fontWeight: FontWeight.w500),
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
    if (_executingScenes.contains(scene.id)) return;
    setState(() => _executingScenes.add(scene.id));
    try {
      await _service.runScene(scene.id);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ScenesScreen._runScene');
      if (mounted) {
        ErrorSnackBar.show(context, e);
      }
    } finally {
      if (mounted) setState(() => _executingScenes.remove(scene.id));
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
        SnackBar(
          content: Text(AppStrings.get('no_home_for_scene')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddSceneScreen(homeId: _currentHomeId!, sceneId: scene.id),
      ),
    );

    if (result == true) {
      await _loadScenes();
    }
  }

  void _showDeleteSceneDialog(Scene scene) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HBotColors.sheetBackground,
          title: Text(
            AppStrings.get('delete_scene'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${scene.name}"? This action cannot be undone.',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.get('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _service.deleteScene(scene.id);
                  if (context.mounted) {
                    Navigator.pop(context);
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
                  if (context.mounted) {
                    Navigator.pop(context);
                    ErrorSnackBar.show(context, e);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(AppStrings.get('delete')),
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
        SnackBar(
          content: Text(AppStrings.get('select_home_for_scene')),
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
      debugPrint('ScenesScreen: Scene created successfully, reloading scenes');
      await _loadScenes();
    }
  }
}

/// Custom painter for dashed border on the "Create Scene" tile
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
        dashPath.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
