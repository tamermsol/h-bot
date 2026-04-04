import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../widgets/smart_input_field.dart';
import '../widgets/device_selector.dart';
import '../widgets/scene_icon_selector.dart';
import '../services/smart_home_service.dart';
import '../services/timezone_service.dart';
import '../models/device.dart';
import '../models/scene.dart';
import '../models/scene_step.dart';
import '../models/scene_trigger.dart';
import '../repos/devices_repo.dart';
import '../l10n/app_strings.dart';

class AddSceneScreen extends StatefulWidget {
  final String homeId;
  final String? sceneId; // Optional: if provided, we're in edit mode

  const AddSceneScreen({super.key, required this.homeId, this.sceneId});

  @override
  State<AddSceneScreen> createState() => _AddSceneScreenState();
}

class _AddSceneScreenState extends State<AddSceneScreen> {
  final SmartHomeService _service = SmartHomeService();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isCreating = false;
  bool _isLoading = false;

  // Scene data
  final TextEditingController _nameController = TextEditingController();
  IconData _selectedIcon = Icons.auto_awesome;
  Color _selectedColor = HBotColors.primary;
  String _selectedTrigger = 'Manual';
  TimeOfDay? _selectedTime;

  // Location-based trigger state
  String? _selectedLocationTriggerType; // 'arrive' or 'leave'
  double? _selectedLatitude;
  double? _selectedLongitude;
  double _selectedRadius = 200; // Default 200 meters
  String? _selectedLocationAddress;
  bool _isDetectingLocation = false;

  List<Map<String, dynamic>> _selectedDevices = [];
  // Device actions: Map of device ID to action configuration
  Map<String, Map<String, dynamic>> _deviceActions = {};

  // Edit mode
  bool get _isEditMode => widget.sceneId != null;
  Scene? _existingScene;
  List<SceneStep>? _existingSteps;
  List<SceneTrigger>? _existingTriggers;

  final List<Color> _availableColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFF1976D2), // Dark Blue (replaced orange)
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFF44336), // Red
    Color(0xFF795548), // Brown
  ];

  final List<String> _triggerTypes = [
    'Manual',
    'Time Based',
    // 'Location Based', // Hidden for initial release
    'Sensor Triggered',
  ];

  String _selectedRepeat = 'Once only'; // Repeat option for time-based triggers
  List<int> _customDays = []; // Custom days selection (empty for "Once only")

  final List<String> _repeatOptions = [
    'Once only',
    'Every day',
    'Weekdays',
    'Weekend',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('AddSceneScreen: initState - homeId = ${widget.homeId}');
    debugPrint('AddSceneScreen: initState - sceneId = ${widget.sceneId}');
    debugPrint('AddSceneScreen: initState - isEditMode = $_isEditMode');

    if (_isEditMode) {
      _loadExistingScene();
    }
  }

  Future<void> _loadExistingScene() async {
    setState(() => _isLoading = true);

    try {
      // Fetch scene details
      final scene = await _service.getScene(widget.sceneId!);
      _existingScene = scene;

      // Populate scene name
      _nameController.text = scene.name;

      // Load icon and color if available
      if (scene.iconCode != null) {
        _selectedIcon = IconData(scene.iconCode!, fontFamily: 'MaterialIcons');
      }
      if (scene.colorValue != null) {
        _selectedColor = Color(scene.colorValue!);
      }

      // Fetch scene steps
      final steps = await _service.getSceneSteps(widget.sceneId!);
      _existingSteps = steps;

      // Fetch scene triggers
      final triggers = await _service.getSceneTriggers(widget.sceneId!);
      _existingTriggers = triggers;

      // Populate trigger information
      if (triggers.isNotEmpty) {
        final trigger = triggers.first; // Use first trigger
        if (trigger.kind == TriggerKind.schedule) {
          _selectedTrigger = 'Time Based';
          final configJson = trigger.configJson;

          // IMPORTANT: Stored time is in UTC, convert back to Egypt time for display
          final utcHour = configJson['hour'] as int?;
          final utcMinute = configJson['minute'] as int?;

          if (utcHour != null && utcMinute != null) {
            final timezoneService = TimezoneService();
            final egyptTime = timezoneService.utcHourMinuteToEgypt(
              utcHour,
              utcMinute,
            );
            _selectedTime = TimeOfDay(
              hour: egyptTime['hour']!,
              minute: egyptTime['minute']!,
            );

            debugPrint(
              '🕐 Loaded trigger: UTC $utcHour:$utcMinute -> Egypt ${egyptTime['hour']}:${egyptTime['minute']}',
            );
          }

          // Load repeat option from days array
          final days =
              (configJson['days'] as List?)?.cast<int>() ??
              [1, 2, 3, 4, 5, 6, 7];
          _selectedRepeat = _getRepeatOptionFromDays(days);
          if (_selectedRepeat == 'Custom') {
            _customDays = List<int>.from(days);
          }

          debugPrint('🕐 Loaded repeat: $_selectedRepeat, Days: $days');
        } else if (trigger.kind == TriggerKind.geo) {
          _selectedTrigger = 'Location Based';
          final configJson = trigger.configJson;
          _selectedLocationTriggerType = configJson['trigger_type'] as String?;
          _selectedLatitude = (configJson['latitude'] as num?)?.toDouble();
          _selectedLongitude = (configJson['longitude'] as num?)?.toDouble();
          _selectedRadius = (configJson['radius'] as num?)?.toDouble() ?? 200;
          _selectedLocationAddress = configJson['address'] as String?;
        }
      }

      // Load all devices to match device IDs with device objects
      final devices = await _service.getDevicesByHome(widget.homeId);

      // Also load shared devices using the same approach as the dashboard
      List<Device> sharedDeviceObjects = [];
      List<String> sharedDeviceIds = [];
      try {
        final devicesRepo = DevicesRepo();
        sharedDeviceObjects = await devicesRepo.listSharedDevices();
        sharedDeviceIds = sharedDeviceObjects.map((d) => d.id).toList();
      } catch (e) {
        debugPrint('⚠️ Could not load shared devices: $e');
      }

      // Clear existing selections
      _selectedDevices.clear();
      _deviceActions.clear();

      // Populate device actions from scene steps
      for (final step in steps) {
        final actionJson = step.actionJson;
        final deviceId = actionJson['device_id'] as String?;

        if (deviceId != null) {
          // First try to find device in home devices
          Device? device;
          bool isShared = false;
          try {
            device = devices.firstWhere((d) => d.id == deviceId);
          } catch (_) {
            // Not in home devices — try as a shared device
            if (sharedDeviceIds.contains(deviceId)) {
              try {
                device = sharedDeviceObjects.firstWhere((d) => d.id == deviceId);
                isShared = true;
              } catch (e) {
                debugPrint('⚠️ Could not find shared device $deviceId in loaded list');
              }
            }
          }

          if (device != null) {
            // Add to selected devices with full device object (matching DeviceSelector format)
            _selectedDevices.add({
              'id': device.id,
              'name': device.deviceName,
              'deviceName': device.deviceName,
              'type': device.deviceType.name,
              'room': isShared ? AppStrings.get('common_shared') : AppStrings.get('common_unknown'),
              'icon': _getDeviceIcon(device.deviceType.name),
              'isOnline': device.online ?? false,
              'device': device, // ✅ Include full device object
              'isShared': isShared,
            });

            // Populate device action (make a deep copy to avoid reference issues)
            _deviceActions[deviceId] = Map<String, dynamic>.from(actionJson);

            debugPrint(
              '🔧 Loaded device action for $deviceId: ${actionJson['type'] ?? actionJson['action_type']}',
            );
          } else {
            debugPrint('⚠️ Device not found: $deviceId');
          }
        }
      }

      setState(() => _isLoading = false);

      debugPrint(
        '✅ Scene loaded: ${_selectedDevices.length} devices, ${_deviceActions.length} actions',
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_load_scene_data")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('❌ Error loading scene: $e');
    }
  }

  /// Get repeat option from days array
  String _getRepeatOptionFromDays(List<int> days) {
    // Sort for comparison
    final sortedDays = List<int>.from(days)..sort();

    if (sortedDays.length == 7) {
      return AppStrings.get('repeat_every_day');
    } else if (sortedDays.length == 5 &&
        sortedDays[0] == 1 &&
        sortedDays[4] == 5) {
      return 'Monday to Friday';
    } else if (sortedDays.length == 2 &&
        sortedDays[0] == 6 &&
        sortedDays[1] == 7) {
      return AppStrings.get('repeat_weekend');
    } else if (sortedDays.length == 1) {
      return AppStrings.get('repeat_once_only');
    } else {
      return AppStrings.get('repeat_custom');
    }
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'relay':
        return Icons.power;
      case 'dimmer':
        return Icons.lightbulb_outline;
      case 'shutter':
        return Icons.window;
      case 'sensor':
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  /// Sync device actions with selected devices
  /// Removes actions for devices that are no longer selected
  void _syncDeviceActions() {
    // Get list of currently selected device IDs
    final selectedDeviceIds = _selectedDevices
        .map((deviceMap) => deviceMap['id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // Remove actions for devices that are no longer selected
    _deviceActions.removeWhere((deviceId, action) {
      final isRemoved = !selectedDeviceIds.contains(deviceId);
      if (isRemoved) {
        debugPrint('🗑️ Removed action for device: $deviceId');
      }
      return isRemoved;
    });

    debugPrint(
      '✅ Synced device actions: ${_deviceActions.length} actions for ${selectedDeviceIds.length} devices',
    );
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: HBotColors.primary))
              : Column(
                  children: [
                    // Header: back button + title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HBotSpacing.space5, HBotSpacing.space4,
                        HBotSpacing.space5, 0,
                      ),
                      child: Row(
                        children: [
                          HBotIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () {
                              if (_currentStep > 0) {
                                _previousStep();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          const SizedBox(width: HBotSpacing.space4),
                          Expanded(
                            child: Text(
                              _isEditMode ? AppStrings.get('edit_scene') : AppStrings.get('add_scene_title'),
                              style: const TextStyle(
                                fontFamily: 'Readex Pro',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: HBotSpacing.space3),

                    // Progress indicator
                    _buildProgressIndicator(),

                    // Content
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildBasicInfoStep(),
                          _buildAppearanceStep(),
                          _buildTriggerStep(),
                          _buildDevicesStep(),
                          _buildDeviceActionsStep(),
                          _buildReviewStep(),
                        ],
                      ),
                    ),

                    // Bottom navigation - STICKY at bottom
                    _buildBottomNavigation(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HBotSpacing.space5),
      child: Row(
        children: List.generate(6, (index) {
          final isDone = index < _currentStep;
          final isActive = index == _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: index < 5 ? 6 : 0,
              ),
              height: 4,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF0883FD), Color(0xFF3BC4FF)],
                      )
                    : null,
                color: isDone
                    ? HBotColors.primary
                    : isActive
                        ? null
                        : const Color(0x0FFFFFFF), // rgba(255,255,255,0.06)
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STEP 1 OF 6',
              style: TextStyle(
                fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
                color: HBotColors.textMuted, letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.get('scene_name'),
              style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.get('scene_name_hint'),
              style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
            ),
            const SizedBox(height: HBotSpacing.space4),

            SmartInputField(
              controller: _nameController,
              hint: AppStrings.get('scene_name_hint'),
              onChanged: (value) => setState(() {}),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Preview card
            if (_nameController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(HBotSpacing.space4),
                decoration: BoxDecoration(
                  color: context.hCard,
                  borderRadius: HBotRadius.mediumRadius,
                  border: Border.all(
                    color: HBotColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: HBotColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          HBotRadius.small,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: HBotColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: HBotSpacing.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 2 OF 6',
            style: TextStyle(
              fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
              color: HBotColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scene_icon'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('scene_color'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Icon selection
          Text(
            AppStrings.get('scene_icon'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: HBotSpacing.space4),
          SceneIconSelector(
            selectedIcon: _selectedIcon,
            onIconSelected: (icon) {
              setState(() {
                _selectedIcon = icon;
              });
            },
          ),

          const SizedBox(height: HBotSpacing.space6),

          // Color selection
          Text(
            AppStrings.get('scene_color'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: HBotSpacing.space4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _availableColors.length,
            itemBuilder: (context, index) {
              final color = _availableColors[index];
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              );
            },
          ),

          const SizedBox(height: HBotSpacing.space4),

          // Preview
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: context.hCard,
              borderRadius: HBotRadius.mediumRadius,
              border: Border.all(color: _selectedColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.2),
                    borderRadius: HBotRadius.smallRadius,
                  ),
                  child: Icon(_selectedIcon, color: _selectedColor, size: 24),
                ),
                const SizedBox(width: HBotSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text
                            : AppStrings.get('scene_preview'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 3 OF 6',
            style: TextStyle(
              fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
              color: HBotColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scene_triggers'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('add_trigger'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Trigger type selection
          ..._triggerTypes.map((trigger) {
            final isSelected = trigger == _selectedTrigger;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTrigger = trigger;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: HBotSpacing.space2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedColor.withOpacity(0.1)
                      : HBotColors.glassBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.5)
                        : HBotColors.glassBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedColor.withOpacity(0.2)
                            : HBotColors.glassBackground,
                        borderRadius: BorderRadius.circular(HBotRadius.small),
                      ),
                      child: Icon(
                        _getTriggerIcon(trigger),
                        color: isSelected
                            ? _selectedColor
                            : HBotColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTriggerDisplayName(trigger),
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : HBotColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getTriggerDescription(trigger),
                            style: const TextStyle(
                              fontFamily: 'Readex Pro', fontSize: 12, color: HBotColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Radio circle
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _selectedColor : HBotColors.textMuted,
                          width: 2,
                        ),
                        color: isSelected ? _selectedColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),

          // Time picker for time-based triggers
          if (_selectedTrigger == 'Time Based') ...[
            const SizedBox(height: HBotSpacing.space4),
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.get('scene_activation_time'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedTime = time;
                        });
                      }
                    },
                    child: Text(
                      _selectedTime?.format(context) ?? 'Select Time',
                      style: TextStyle(color: _selectedColor),
                    ),
                  ),
                ],
              ),
            ),

            // Repeat option
            const SizedBox(height: HBotSpacing.space4),
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.get('scene_repeat'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => _showRepeatOptions(),
                    child: Text(
                      _getRepeatDisplayName(_selectedRepeat),
                      style: TextStyle(color: _selectedColor),
                    ),
                  ),
                ],
              ),
            ),

            // Custom days selector (only show if Custom is selected)
            if (_selectedRepeat == 'Custom') ...[
              const SizedBox(height: HBotSpacing.space4),
              Container(
                padding: const EdgeInsets.all(HBotSpacing.space4),
                decoration: BoxDecoration(
                  color: context.hCard,
                  borderRadius: HBotRadius.mediumRadius,
                  border: Border.all(
                    color: _selectedColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('scene_select_days'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDayChip(AppStrings.get('day_mon'), 1),
                        _buildDayChip(AppStrings.get('day_tue'), 2),
                        _buildDayChip(AppStrings.get('day_wed'), 3),
                        _buildDayChip(AppStrings.get('day_thu'), 4),
                        _buildDayChip(AppStrings.get('day_fri'), 5),
                        _buildDayChip(AppStrings.get('day_sat'), 6),
                        _buildDayChip(AppStrings.get('day_sun'), 7),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Location configuration for location-based triggers
          if (_selectedTrigger == 'Location Based') ...[
            const SizedBox(height: HBotSpacing.space4),

            // Trigger type selection (Arrive/Leave)
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('scene_trigger_type'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: HBotSpacing.space2),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationTriggerTypeButton(
                          'arrive',
                          AppStrings.get('trigger_arrive'),
                          Icons.location_on,
                        ),
                      ),
                      const SizedBox(width: HBotSpacing.space2),
                      Expanded(
                        child: _buildLocationTriggerTypeButton(
                          'leave',
                          AppStrings.get('trigger_leave'),
                          Icons.location_off,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Location detection
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('scene_location'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: HBotSpacing.space2),

                  if (_selectedLatitude != null &&
                      _selectedLongitude != null) ...[
                    Container(
                      padding: const EdgeInsets.all(HBotSpacing.space2),
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          HBotRadius.small,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: _selectedColor,
                            size: 20,
                          ),
                          const SizedBox(width: HBotSpacing.space2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedLocationAddress != null)
                                  Text(
                                    _selectedLocationAddress!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                Text(
                                  'Lat: ${_selectedLatitude!.toStringAsFixed(6)}, '
                                  'Lng: ${_selectedLongitude!.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.hTextSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                  ],

                  ElevatedButton.icon(
                    onPressed: _isDetectingLocation
                        ? null
                        : _detectCurrentLocation,
                    icon: _isDetectingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _isDetectingLocation
                          ? AppStrings.get('scene_detecting_location')
                          : _selectedLatitude != null
                          ? AppStrings.get('scene_update_location')
                          : AppStrings.get('scene_use_current_location'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: HBotSpacing.space4),

            // Radius selection
            Container(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              decoration: BoxDecoration(
                color: context.hCard,
                borderRadius: HBotRadius.mediumRadius,
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.get('scene_radius'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_selectedRadius.toInt()} meters',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _selectedColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: HBotSpacing.space2),
                  Slider(
                    value: _selectedRadius,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    activeColor: _selectedColor,
                    label: '${_selectedRadius.toInt()}m',
                    onChanged: (value) {
                      setState(() {
                        _selectedRadius = value;
                      });
                    },
                  ),
                  Text(
                    AppStrings.get('scene_trigger_distance'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.hTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevicesStep() {
    debugPrint('AddSceneScreen: _buildDevicesStep - homeId = ${widget.homeId}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 4 OF 6',
            style: TextStyle(
              fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
              color: HBotColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scene_select_devices'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('scene_choose_devices'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
          ),
          const SizedBox(height: HBotSpacing.space6),

          DeviceSelector(
            selectedDevices: _selectedDevices,
            onDevicesChanged: (devices) {
              setState(() {
                _selectedDevices = devices;
                // Clean up device actions for removed devices
                _syncDeviceActions();
              });
            },
            accentColor: _selectedColor,
            homeId: widget.homeId,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceActionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 5 OF 6',
            style: TextStyle(
              fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
              color: HBotColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scene_configure_actions'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('scene_set_actions'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
          ),
          const SizedBox(height: HBotSpacing.space6),

          if (_selectedDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(HBotSpacing.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      size: 64,
                      color: context.hTextTertiary,
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      AppStrings.get('scene_no_devices_selected'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.hTextSecondary,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Text(
                      AppStrings.get('scene_go_back_select'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.hTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedDevices.length,
              itemBuilder: (context, index) {
                final deviceMap = _selectedDevices[index];
                final device = deviceMap['device'] as Device?;

                if (device == null) {
                  return const SizedBox.shrink();
                }

                // Initialize device action if not exists
                if (!_deviceActions.containsKey(device.id)) {
                  _deviceActions[device.id] = _getDefaultAction(device);
                }

                return _buildDeviceActionCard(device, deviceMap);
              },
            ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getDefaultAction(Device device) {
    switch (device.deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return {
          'type': 'power',
          'channels': [1], // Default to channel 1
          'state': true, // Default to ON
        };
      case DeviceType.shutter:
        return {
          'type': 'shutter',
          'position': 50, // Default to 50%
        };
      case DeviceType.sensor:
      case DeviceType.other:
        return {'type': 'none'};
    }
  }

  Widget _buildDeviceActionCard(Device device, Map<String, dynamic> deviceMap) {
    final action = _deviceActions[device.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: HBotSpacing.space4),
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: context.hCard,
        borderRadius: HBotRadius.mediumRadius,
        border: Border.all(color: _selectedColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.2),
                  borderRadius: HBotRadius.smallRadius,
                ),
                child: Icon(
                  deviceMap['icon'] as IconData? ?? Icons.device_unknown,
                  color: _selectedColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: HBotSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      deviceMap['room'] as String? ?? AppStrings.get('scene_no_room'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.hTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HBotSpacing.space4),
          const Divider(height: 1),
          const SizedBox(height: HBotSpacing.space4),

          // Action configuration based on device type
          if (device.deviceType == DeviceType.relay ||
              device.deviceType == DeviceType.dimmer)
            _buildRelayDimmerAction(device, action)
          else if (device.deviceType == DeviceType.shutter)
            _buildShutterAction(device, action)
          else
            _buildNoActionAvailable(),
        ],
      ),
    );
  }

  Widget _buildRelayDimmerAction(Device device, Map<String, dynamic> action) {
    final channels = device.effectiveChannels;
    final selectedChannels = List<int>.from(action['channels'] ?? [1]);
    final state = action['state'] as bool? ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.get('scene_action'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.hTextPrimary,
          ),
        ),
        const SizedBox(height: HBotSpacing.space2),

        // Power state toggle
        Container(
          padding: const EdgeInsets.all(HBotSpacing.space4),
          decoration: BoxDecoration(
            color: context.hCard,
            borderRadius: HBotRadius.smallRadius,
            border: Border.all(color: context.hBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Turn ${state ? "ON" : "OFF"}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              Switch(
                value: state,
                onChanged: (value) {
                  setState(() {
                    _deviceActions[device.id]!['state'] = value;
                  });
                },
                activeTrackColor: _selectedColor,
              ),
            ],
          ),
        ),

        if (channels > 1) ...[
          const SizedBox(height: HBotSpacing.space4),
          Text(
            AppStrings.get('scene_channels'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.hTextPrimary,
            ),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Wrap(
            spacing: HBotSpacing.space2,
            runSpacing: HBotSpacing.space2,
            children: [
              // All channels option
              FilterChip(
                label: Text(AppStrings.get('all_channels')),
                selected: selectedChannels.length == channels,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _deviceActions[device.id]!['channels'] = List.generate(
                        channels,
                        (i) => i + 1,
                      );
                    } else {
                      _deviceActions[device.id]!['channels'] = [1];
                    }
                  });
                },
                selectedColor: _selectedColor.withOpacity(0.2),
                checkmarkColor: _selectedColor,
                labelStyle: TextStyle(
                  color: selectedChannels.length == channels
                      ? _selectedColor
                      : context.hTextSecondary,
                ),
              ),
              // Individual channel options
              ...List.generate(channels, (i) {
                final channelNum = i + 1;
                final isSelected = selectedChannels.contains(channelNum);
                return FilterChip(
                  label: Text('${AppStrings.get("scene_channel")} $channelNum'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final currentChannels = List<int>.from(
                        _deviceActions[device.id]!['channels'],
                      );
                      if (selected) {
                        if (!currentChannels.contains(channelNum)) {
                          currentChannels.add(channelNum);
                        }
                      } else {
                        currentChannels.remove(channelNum);
                      }
                      // Ensure at least one channel is selected
                      if (currentChannels.isEmpty) {
                        currentChannels.add(1);
                      }
                      _deviceActions[device.id]!['channels'] = currentChannels;
                    });
                  },
                  selectedColor: _selectedColor.withOpacity(0.2),
                  checkmarkColor: _selectedColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? _selectedColor
                        : context.hTextSecondary,
                  ),
                );
              }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildShutterAction(Device device, Map<String, dynamic> action) {
    final position = action['position'] as int? ?? 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(HBotSpacing.space4),
          decoration: BoxDecoration(
            color: context.hCard,
            borderRadius: HBotRadius.smallRadius,
            border: Border.all(color: context.hBorder),
          ),
          child: Column(
            children: [
              // Percentage display centered
              Text(
                '$position%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _selectedColor,
                ),
              ),
              const SizedBox(height: HBotSpacing.space2),
              Slider(
                value: position.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$position%',
                activeColor: _selectedColor,
                onChanged: (value) {
                  setState(() {
                    _deviceActions[device.id]!['position'] = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: HBotSpacing.space4),

        // Quick position buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _deviceActions[device.id]!['position'] = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: position == 0
                      ? _selectedColor
                      : context.hTextSecondary,
                  side: BorderSide(
                    color: position == 0
                        ? _selectedColor
                        : context.hTextTertiary.withOpacity(0.3),
                  ),
                ),
                child: Text(AppStrings.get('add_scene_0')),
              ),
            ),
            const SizedBox(width: HBotSpacing.space2),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _deviceActions[device.id]!['position'] = 50;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: position == 50
                      ? _selectedColor
                      : context.hTextSecondary,
                  side: BorderSide(
                    color: position == 50
                        ? _selectedColor
                        : context.hTextTertiary.withOpacity(0.3),
                  ),
                ),
                child: Text(AppStrings.get('add_scene_50')),
              ),
            ),
            const SizedBox(width: HBotSpacing.space2),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _deviceActions[device.id]!['position'] = 100;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: position == 100
                      ? _selectedColor
                      : context.hTextSecondary,
                  side: BorderSide(
                    color: position == 100
                        ? _selectedColor
                        : context.hTextTertiary.withOpacity(0.3),
                  ),
                ),
                child: Text(AppStrings.get('add_scene_100')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoActionAvailable() {

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: context.hCard,
        borderRadius: HBotRadius.smallRadius,
        border: Border.all(color: context.hBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: context.hTextTertiary,
            size: 20,
          ),
          const SizedBox(width: HBotSpacing.space2),
          Expanded(
            child: Text(
              AppStrings.get('scene_no_actions'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.hTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP 6 OF 6',
            style: TextStyle(
              fontFamily: 'Readex Pro', fontSize: 10, fontWeight: FontWeight.w600,
              color: HBotColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scene_review'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('scene_review_config'),
            style: const TextStyle(fontFamily: 'Readex Pro', fontSize: 13, color: HBotColors.textMuted),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Scene preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(HBotSpacing.space6),
            decoration: BoxDecoration(
              color: context.hCard,
              borderRadius: HBotRadius.mediumRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _selectedColor.withOpacity(0.2),
                  context.hCard,
                ],
              ),
              border: Border.all(color: context.hBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          HBotRadius.small,
                        ),
                      ),
                      child: Icon(
                        _selectedIcon,
                        color: _selectedColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: HBotSpacing.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HBotSpacing.space4),
                Row(
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      size: 16,
                      color: context.hTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_selectedDevices.length} devices',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.hTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      _getTriggerIcon(_selectedTrigger),
                      size: 16,
                      color: context.hTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedTrigger == 'Time Based' && _selectedTime != null
                          ? _selectedTime!.format(context)
                          : _selectedTrigger == 'Location Based' &&
                                _selectedLocationTriggerType != null
                          ? '${_selectedLocationTriggerType == 'arrive' ? AppStrings.get('trigger_arrive') : AppStrings.get('trigger_leave')} (${_selectedRadius.toInt()}m)'
                          : _selectedTrigger,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.hTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: HBotSpacing.space4),

          // Configuration summary
          _buildSummarySection(AppStrings.get('scene_basic_info'), ['Name: ${_nameController.text}']),

          const SizedBox(height: HBotSpacing.space2),

          _buildSummarySection(AppStrings.get('scene_summary_trigger'), [
            'Type: $_selectedTrigger',
            if (_selectedTrigger == 'Time Based' && _selectedTime != null)
              'Time: ${_selectedTime!.format(context)}',
            if (_selectedTrigger == 'Location Based') ...[
              if (_selectedLocationTriggerType != null)
                '${AppStrings.get('scene_summary_trigger')}: ${_selectedLocationTriggerType == 'arrive' ? AppStrings.get('trigger_arrive') : AppStrings.get('trigger_leave')}',
              if (_selectedLatitude != null && _selectedLongitude != null)
                '${AppStrings.get('scene_location')}: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
              '${AppStrings.get('scene_radius')}: ${_selectedRadius.toInt()}m',
            ],
          ]),

          const SizedBox(height: HBotSpacing.space2),

          _buildSummarySection(AppStrings.get('scene_summary_devices'), [
            '${_selectedDevices.length} devices selected',
            ..._selectedDevices.map((device) => '• ${device['name']}'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: context.hCard,
        borderRadius: HBotRadius.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: HBotSpacing.space2),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.hTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: HBotColors.sheetBackground,
        border: const Border(
          top: BorderSide(
            color: HBotColors.glassBorder,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: HBotOutlineButton(
                  onTap: _isCreating ? null : _previousStep,
                  height: 48,
                  child: Text(
                    AppStrings.get('common_previous'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: HBotSpacing.space4),
            Expanded(
              child: HBotGradientButton(
                onTap: (_canProceed() && !_isCreating) ? _nextStep : null,
                enabled: _canProceed() && !_isCreating,
                height: 48,
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        _currentStep == 5
                            ? (_isEditMode ? AppStrings.get('scene_update') : AppStrings.get('scene_create'))
                            : AppStrings.get('common_next'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _nameController.text.isNotEmpty;
      case 1:
        return true; // Icon and color always have defaults
      case 2:
        // Validate trigger configuration
        if (_selectedTrigger == 'Time Based') {
          return _selectedTime != null;
        } else if (_selectedTrigger == 'Location Based') {
          return _selectedLocationTriggerType != null &&
              _selectedLatitude != null &&
              _selectedLongitude != null;
        }
        return true;
      case 3:
        return _selectedDevices.isNotEmpty;
      case 4:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createScene();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createScene() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('add_scene_please_enter_a_scene_name')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate time-based trigger has a time selected
    if (_selectedTrigger == 'Time Based' && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.get('scene_select_time_error'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate location-based trigger has all required fields
    if (_selectedTrigger == 'Location Based') {
      if (_selectedLocationTriggerType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('add_scene_please_select_when_to_trigger_arrive_or_leave')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('add_scene_please_detect_your_current_location')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      if (_isEditMode) {
        // UPDATE MODE: Update existing scene and its steps

        // Update scene name, icon, and color
        await _service.updateScene(
          widget.sceneId!,
          name: _nameController.text.trim(),
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.value,
        );

        // Delete all existing scene steps
        await _service.deleteSceneSteps(widget.sceneId!);

        // Create new scene steps for each device action
        int stepOrder = 0;
        for (final entry in _deviceActions.entries) {
          final deviceId = entry.key;
          final action = entry.value;

          // Build action JSON based on device type
          final actionJson = {
            'device_id': deviceId,
            'action_type': action['type'],
            ...action,
          };

          await _service.createSceneStep(
            widget.sceneId!,
            stepOrder,
            actionJson,
          );
          stepOrder++;
        }

        // Update scene triggers
        await _updateSceneTriggers(widget.sceneId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.get('scene_updated_success'),
              ),
              backgroundColor: HBotColors.primary,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // CREATE MODE: Create new scene

        // Create the scene in Supabase with icon and color
        final scene = await _service.createScene(
          widget.homeId,
          _nameController.text.trim(),
          isEnabled: true,
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.value,
        );

        // Create scene steps for each device action
        int stepOrder = 0;
        for (final entry in _deviceActions.entries) {
          final deviceId = entry.key;
          final action = entry.value;

          // Build action JSON based on device type
          final actionJson = {
            'device_id': deviceId,
            'action_type': action['type'],
            ...action,
          };

          await _service.createSceneStep(scene.id, stepOrder, actionJson);
          stepOrder++;
        }

        // Create scene trigger if not manual
        await _createSceneTrigger(scene.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.get('scene_created_success'),
              ),
              backgroundColor: HBotColors.primary,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? '${AppStrings.get('scene_update_failed')}: $e'
                  : '${AppStrings.get('scene_create_failed')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Create scene trigger based on selected trigger type
  Future<void> _createSceneTrigger(String sceneId) async {
    if (_selectedTrigger == 'Time Based' && _selectedTime != null) {
      // IMPORTANT: Convert Egypt local time to UTC before storing
      // The user selects time in Egypt timezone, but we store UTC in database
      // so the edge function can match correctly regardless of timezone

      final timezoneService = TimezoneService();

      // Get days based on repeat option
      final days = _getDaysFromRepeatOption();

      // Convert selected Egypt time to UTC hour/minute
      final utcHourMinute = await timezoneService.buildTriggerUtcHourMinute(
        _selectedTime!.hour,
        _selectedTime!.minute,
        days,
      );

      // Store UTC hour/minute in database
      final configJson = {
        'hour': utcHourMinute['hour'],
        'minute': utcHourMinute['minute'],
        'days': days,
      };

      debugPrint(
        '🕐 Creating trigger: Egypt ${_selectedTime!.hour}:${_selectedTime!.minute} -> UTC ${utcHourMinute['hour']}:${utcHourMinute['minute']}, Days: $days, Repeat: $_selectedRepeat',
      );

      await _service.createSceneTrigger(
        sceneId,
        TriggerKind.schedule,
        configJson,
        isEnabled: true,
      );
    } else if (_selectedTrigger == 'Location Based' &&
        _selectedLocationTriggerType != null &&
        _selectedLatitude != null &&
        _selectedLongitude != null) {
      // Create location-based trigger
      final configJson = {
        'trigger_type': _selectedLocationTriggerType, // 'arrive' or 'leave'
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'radius': _selectedRadius,
        if (_selectedLocationAddress != null)
          'address': _selectedLocationAddress,
      };

      await _service.createSceneTrigger(
        sceneId,
        TriggerKind.geo,
        configJson,
        isEnabled: true,
      );
    }
    // Note: Other trigger types (Sensor Triggered) can be implemented here
    // For now, Manual trigger doesn't need a database entry
  }

  /// Get days array based on selected repeat option
  List<int> _getDaysFromRepeatOption() {
    switch (_selectedRepeat) {
      case 'Once only':
        // For once only, we still need to specify a day
        // Use the next occurrence day
        final now = DateTime.now();
        return [now.weekday];
      case 'Every day':
        return [1, 2, 3, 4, 5, 6, 7]; // All days
      case 'Monday to Friday':
        return [1, 2, 3, 4, 5]; // Weekdays
      case 'Weekend':
        return [6, 7]; // Saturday, Sunday
      case 'Custom':
        return _customDays;
      default:
        return [1, 2, 3, 4, 5, 6, 7]; // Default to every day
    }
  }

  /// Show repeat options dialog
  void _showRepeatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('add_scene_repeat'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: HBotSpacing.space4),
            ..._repeatOptions.map(
              (option) => ListTile(
                title: Text(_getRepeatDisplayName(option)),
                trailing: _selectedRepeat == option
                    ? Icon(Icons.check, color: _selectedColor)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedRepeat = option;
                    // Reset custom days if switching away from custom
                    if (option != 'Custom') {
                      _customDays = [1, 2, 3, 4, 5, 6, 7];
                    }
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build day chip for custom day selection
  Widget _buildDayChip(String label, int day) {
    final isSelected = _customDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _customDays.add(day);
            _customDays.sort();
          } else {
            // Don't allow deselecting all days
            if (_customDays.length > 1) {
              _customDays.remove(day);
            }
          }
        });
      },
      selectedColor: _selectedColor.withOpacity(0.3),
      checkmarkColor: _selectedColor,
      labelStyle: TextStyle(
        color: isSelected ? _selectedColor : context.hTextSecondary,
      ),
    );
  }

  /// Update scene triggers (delete old ones and create new ones)
  Future<void> _updateSceneTriggers(String sceneId) async {
    // Get existing triggers
    final existingTriggers = await _service.getSceneTriggers(sceneId);

    // Delete all existing triggers
    for (final trigger in existingTriggers) {
      await _service.deleteSceneTrigger(trigger.id);
    }

    // Create new trigger based on current selection
    await _createSceneTrigger(sceneId);
  }

  IconData _getTriggerIcon(String trigger) {
    switch (trigger) {
      case 'Manual':
        return Icons.touch_app;
      case 'Time Based':
        return Icons.schedule;
      case 'Location Based':
        return Icons.location_on;
      case 'Sensor Triggered':
        return Icons.sensors;
      default:
        return Icons.touch_app;
    }
  }

  String _getTriggerDisplayName(String trigger) {
    switch (trigger) {
      case 'Manual':
        return AppStrings.get('trigger_manual');
      case 'Time Based':
        return AppStrings.get('trigger_time_based');
      case 'Location Based':
        return AppStrings.get('trigger_location_based');
      case 'Sensor Triggered':
        return AppStrings.get('trigger_sensor_triggered');
      default:
        return trigger;
    }
  }

  String _getRepeatDisplayName(String option) {
    switch (option) {
      case 'Once only':
        return AppStrings.get('repeat_once_only');
      case 'Every day':
        return AppStrings.get('repeat_every_day');
      case 'Weekdays':
        return AppStrings.get('repeat_weekdays');
      case 'Weekend':
        return AppStrings.get('repeat_weekend');
      case 'Custom':
        return AppStrings.get('repeat_custom');
      default:
        return option;
    }
  }

  String _getTriggerDescription(String trigger) {
    switch (trigger) {
      case 'Manual':
        return AppStrings.get('trigger_desc_manual');
      case 'Time Based':
        return AppStrings.get('trigger_desc_time');
      case 'Location Based':
        return AppStrings.get('trigger_desc_location');
      case 'Sensor Triggered':
        return AppStrings.get('trigger_desc_sensor');
      default:
        return '';
    }
  }

  /// Build location trigger type button (Arrive/Leave)
  /// Build location trigger type button (Arrive/Leave)
  Widget _buildLocationTriggerTypeButton(
    String type,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedLocationTriggerType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocationTriggerType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: HBotSpacing.space4,
          horizontal: HBotSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? _selectedColor.withOpacity(0.2)
              : context.hCard,
          borderRadius: HBotRadius.smallRadius,
          border: Border.all(
            color: isSelected
                ? _selectedColor
                : (context.hBorder),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? _selectedColor
                  : context.hTextSecondary,
              size: 32,
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? _selectedColor
                    : context.hTextSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Detect current location using geolocator
  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.get('scene_location_disabled'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.get('add_scene_location_permissions_are_denied')),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.get('scene_location_denied'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _selectedLocationAddress = 'Current Location';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location detected: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            ),
            backgroundColor: HBotColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.get("error_detect_location")}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
