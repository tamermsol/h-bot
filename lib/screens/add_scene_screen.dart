import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/smart_input_field.dart';
import '../widgets/device_selector.dart';
import '../widgets/scene_icon_selector.dart';
import '../services/smart_home_service.dart';
import '../services/timezone_service.dart';
import '../models/device.dart';
import '../models/scene.dart';
import '../models/scene_step.dart';
import '../models/scene_trigger.dart';

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
    'Location Based',
    'Sensor Triggered',
  ];

  String _selectedRepeat = 'Once only'; // Repeat option for time-based triggers
  List<int> _customDays = []; // Custom days selection (empty for "Once only")

  final List<String> _repeatOptions = [
    'Once only',
    'Every day',
    'Monday to Friday',
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

      // Clear existing selections
      _selectedDevices.clear();
      _deviceActions.clear();

      // Populate device actions from scene steps
      for (final step in steps) {
        final actionJson = step.actionJson;
        final deviceId = actionJson['device_id'] as String?;

        if (deviceId != null) {
          // Find the device
          try {
            final device = devices.firstWhere((d) => d.id == deviceId);

            // Add to selected devices with full device object (matching DeviceSelector format)
            _selectedDevices.add({
              'id': device.id,
              'name': device.name,
              'deviceName': device.name,
              'type': device.deviceType.name,
              'room': 'Unknown', // Room name would need to be fetched
              'icon': _getDeviceIcon(device.deviceType.name),
              'isOnline': device.online ?? false,
              'device': device, // ✅ Include full device object
            });

            // Populate device action (make a deep copy to avoid reference issues)
            _deviceActions[deviceId] = Map<String, dynamic>.from(actionJson);

            debugPrint(
              '🔧 Loaded device action for $deviceId: ${actionJson['type'] ?? actionJson['action_type']}',
            );
          } catch (e) {
            debugPrint('⚠️ Device not found: $deviceId - $e');
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
            content: Text('Failed to load scene data: $e'),
            backgroundColor: HBotColors.error,
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
      return 'Every day';
    } else if (sortedDays.length == 5 &&
        sortedDays[0] == 1 &&
        sortedDays[4] == 5) {
      return 'Monday to Friday';
    } else if (sortedDays.length == 2 &&
        sortedDays[0] == 6 &&
        sortedDays[1] == 7) {
      return 'Weekend';
    } else if (sortedDays.length == 1) {
      return 'Once only';
    } else {
      return 'Custom';
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
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Scene' : 'New Scene',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: HBotColors.textPrimaryLight,
          ),
        ),
        backgroundColor: HBotColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: HBotColors.textPrimaryLight),
        actions: [
          TextButton(
            onPressed: (_canProceed() && !_isCreating && _currentStep == 5)
                ? _createScene
                : null,
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: (_canProceed() && !_isCreating && _currentStep == 5)
                    ? HBotColors.primary
                    : HBotColors.neutral300,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(HBotColors.primary),
              ),
            )
          : Column(
              children: [
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
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(6, (index) {
          final isActive = index <= _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? HBotColors.primary
                    : HBotColors.borderLight,
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
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Text(
              'SCENE NAME',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HBotColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            // Text input
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HBotColors.borderLight, width: 1.5),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: HBotColors.textPrimaryLight,
                ),
                decoration: const InputDecoration(
                  hintText: 'Scene name (e.g., Movie Night)',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    color: HBotColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            const SizedBox(height: 16),

            // Preview card
            if (_nameController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HBotColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HBotColors.borderLight, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: HBotColors.surfacePrimarySubtle,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _selectedIcon,
                        color: HBotColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.textPrimaryLight,
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon section
          Text(
            'ICON',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HBotColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SceneIconSelector(
            selectedIcon: _selectedIcon,
            onIconSelected: (icon) {
              setState(() {
                _selectedIcon = icon;
              });
            },
          ),

          const SizedBox(height: 24),

          // Color section
          Text(
            'COLOR',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HBotColors.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: HBotSpacing.space4),
          Wrap(
            spacing: HBotSpacing.space2,
            runSpacing: HBotSpacing.space2,
            children: _availableColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: HBotSpacing.space4),

          // Preview
          Container(
            padding: const EdgeInsets.all(HBotSpacing.space4),
            decoration: BoxDecoration(
              color: HBotColors.cardLight,
              borderRadius: BorderRadius.circular(HBotRadius.medium),
              border: Border.all(color: _selectedColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(HBotRadius.small),
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
                            : 'Scene Preview',
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
            'Trigger',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Text(
            'How should this scene be activated?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HBotColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Trigger type selection
          ..._triggerTypes.map((trigger) {
            final isSelected = trigger == _selectedTrigger;
            return Container(
              margin: const EdgeInsets.only(bottom: HBotSpacing.space2),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.2)
                        : HBotColors.cardLight,
                    borderRadius: BorderRadius.circular(HBotRadius.small),
                  ),
                  child: Icon(
                    _getTriggerIcon(trigger),
                    color: isSelected
                        ? _selectedColor
                        : HBotColors.textSecondaryLight,
                    size: 20,
                  ),
                ),
                title: Text(
                  trigger,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isSelected
                        ? HBotColors.textPrimaryLight
                        : HBotColors.textSecondaryLight,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  _getTriggerDescription(trigger),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HBotColors.textTertiaryLight,
                  ),
                ),
                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTrigger = trigger;
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedTrigger == trigger
                            ? _selectedColor
                            : Colors.grey,
                        width: 2,
                      ),
                      color: _selectedTrigger == trigger
                          ? _selectedColor
                          : Colors.transparent,
                    ),
                    child: _selectedTrigger == trigger
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedTrigger = trigger;
                  });
                },
                tileColor: isSelected
                    ? _selectedColor.withOpacity(0.1)
                    : HBotColors.cardLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HBotRadius.medium),
                  side: BorderSide(
                    color: isSelected
                        ? _selectedColor.withOpacity(0.5)
                        : Colors.transparent,
                  ),
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
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activation Time',
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
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Repeat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => _showRepeatOptions(),
                    child: Text(
                      _selectedRepeat,
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
                  color: HBotColors.cardLight,
                  borderRadius: BorderRadius.circular(HBotRadius.medium),
                  border: Border.all(
                    color: _selectedColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Days',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDayChip('Mon', 1),
                        _buildDayChip('Tue', 2),
                        _buildDayChip('Wed', 3),
                        _buildDayChip('Thu', 4),
                        _buildDayChip('Fri', 5),
                        _buildDayChip('Sat', 6),
                        _buildDayChip('Sun', 7),
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
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trigger Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: HBotSpacing.space2),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationTriggerTypeButton(
                          'arrive',
                          'When I Arrive',
                          Icons.location_on,
                        ),
                      ),
                      const SizedBox(width: HBotSpacing.space2),
                      Expanded(
                        child: _buildLocationTriggerTypeButton(
                          'leave',
                          'When I Leave',
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
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
                border: Border.all(
                  color: _selectedColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
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
                                        color: HBotColors.textSecondaryLight,
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
                          ? 'Detecting Location...'
                          : _selectedLatitude != null
                          ? 'Update Location'
                          : 'Use Current Location',
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
                color: HBotColors.cardLight,
                borderRadius: BorderRadius.circular(HBotRadius.medium),
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
                        'Radius',
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
                    'Scene will trigger when you are within this distance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: HBotColors.textSecondaryLight,
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
            'Select Devices',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Text(
            'Choose which devices this scene will control',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HBotColors.textSecondaryLight,
            ),
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
            'Configure Device Actions',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Text(
            'Set what each device should do when this scene is activated',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HBotColors.textSecondaryLight,
            ),
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
                      color: HBotColors.textTertiaryLight,
                    ),
                    const SizedBox(height: HBotSpacing.space4),
                    Text(
                      'No devices selected',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Text(
                      'Go back and select devices first',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HBotColors.textTertiaryLight,
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
        color: HBotColors.cardLight,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
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
                  borderRadius: BorderRadius.circular(HBotRadius.small),
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
                      deviceMap['room'] as String? ?? 'No Room',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HBotColors.textTertiaryLight,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: HBotColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: HBotSpacing.space2),

        // Power state toggle
        Container(
          padding: const EdgeInsets.all(HBotSpacing.space4),
          decoration: BoxDecoration(
            color: isDark ? HBotColors.surfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(HBotRadius.small),
            border: isDark ? null : Border.all(color: HBotColors.borderLight),
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
            'Channels',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: HBotColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Wrap(
            spacing: HBotSpacing.space2,
            runSpacing: HBotSpacing.space2,
            children: [
              // All channels option
              FilterChip(
                label: const Text('All Channels'),
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
                      : HBotColors.textSecondaryLight,
                ),
              ),
              // Individual channel options
              ...List.generate(channels, (i) {
                final channelNum = i + 1;
                final isSelected = selectedChannels.contains(channelNum);
                return FilterChip(
                  label: Text('Channel $channelNum'),
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
                        : HBotColors.textSecondaryLight,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(HBotSpacing.space4),
          decoration: BoxDecoration(
            color: isDark ? HBotColors.surfaceLight : Colors.white,
            borderRadius: BorderRadius.circular(HBotRadius.small),
            border: isDark ? null : Border.all(color: HBotColors.borderLight),
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
                      : HBotColors.textSecondaryLight,
                  side: BorderSide(
                    color: position == 0
                        ? _selectedColor
                        : HBotColors.textTertiaryLight.withOpacity(0.3),
                  ),
                ),
                child: const Text('0%'),
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
                      : HBotColors.textSecondaryLight,
                  side: BorderSide(
                    color: position == 50
                        ? _selectedColor
                        : HBotColors.textTertiaryLight.withOpacity(0.3),
                  ),
                ),
                child: const Text('50%'),
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
                      : HBotColors.textSecondaryLight,
                  side: BorderSide(
                    color: position == 100
                        ? _selectedColor
                        : HBotColors.textTertiaryLight.withOpacity(0.3),
                  ),
                ),
                child: const Text('100%'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoActionAvailable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      decoration: BoxDecoration(
        color: isDark ? HBotColors.surfaceLight : Colors.white,
        borderRadius: BorderRadius.circular(HBotRadius.small),
        border: isDark ? null : Border.all(color: HBotColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: HBotColors.textTertiaryLight,
            size: 20,
          ),
          const SizedBox(width: HBotSpacing.space2),
          Expanded(
            child: Text(
              'No actions available for this device type',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HBotColors.textTertiaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HBotSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Scene',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: HBotSpacing.space2),
          Text(
            'Review your scene configuration before creating',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HBotColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: HBotSpacing.space6),

          // Scene preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(HBotSpacing.space6),
            decoration: BoxDecoration(
              color: HBotColors.cardLight,
              borderRadius: BorderRadius.circular(HBotRadius.medium),
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _selectedColor.withOpacity(0.2),
                        HBotColors.cardLight,
                      ],
                    )
                  : null,
              border: isDark
                  ? null
                  : Border.all(color: HBotColors.borderLight),
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
                      color: HBotColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_selectedDevices.length} devices',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      _getTriggerIcon(_selectedTrigger),
                      size: 16,
                      color: HBotColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedTrigger == 'Time Based' && _selectedTime != null
                          ? _selectedTime!.format(context)
                          : _selectedTrigger == 'Location Based' &&
                                _selectedLocationTriggerType != null
                          ? '${_selectedLocationTriggerType == 'arrive' ? 'Arrive' : 'Leave'} (${_selectedRadius.toInt()}m)'
                          : _selectedTrigger,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HBotColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: HBotSpacing.space4),

          // Configuration summary
          _buildSummarySection('Basic Info', ['Name: ${_nameController.text}']),

          const SizedBox(height: HBotSpacing.space2),

          _buildSummarySection('Trigger', [
            'Type: $_selectedTrigger',
            if (_selectedTrigger == 'Time Based' && _selectedTime != null)
              'Time: ${_selectedTime!.format(context)}',
            if (_selectedTrigger == 'Location Based') ...[
              if (_selectedLocationTriggerType != null)
                'When: ${_selectedLocationTriggerType == 'arrive' ? 'I Arrive' : 'I Leave'}',
              if (_selectedLatitude != null && _selectedLongitude != null)
                'Location: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
              'Radius: ${_selectedRadius.toInt()}m',
            ],
          ]),

          const SizedBox(height: HBotSpacing.space2),

          _buildSummarySection('Devices', [
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
        color: HBotColors.cardLight,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
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
                  color: HBotColors.textSecondaryLight,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        border: const Border(
          top: BorderSide(color: HBotColors.borderLight, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HBotColors.borderLight, width: 1.5),
                  ),
                  child: TextButton(
                    onPressed: _isCreating ? null : _previousStep,
                    style: TextButton.styleFrom(
                      foregroundColor: HBotColors.textPrimaryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: (_canProceed() && !_isCreating) ? _nextStep : null,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: (_canProceed() && !_isCreating)
                        ? HBotColors.primaryGradient
                        : null,
                    color: (_canProceed() && !_isCreating)
                        ? null
                        : HBotColors.neutral300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
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
                                ? (_isEditMode ? 'Update Scene' : 'Create Scene')
                                : 'Next',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
        const SnackBar(
          content: Text('Please enter a scene name'),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    // Validate time-based trigger has a time selected
    if (_selectedTrigger == 'Time Based' && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an activation time for time-based trigger',
          ),
          backgroundColor: HBotColors.error,
        ),
      );
      return;
    }

    // Validate location-based trigger has all required fields
    if (_selectedTrigger == 'Location Based') {
      if (_selectedLocationTriggerType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select when to trigger (arrive or leave)'),
            backgroundColor: HBotColors.error,
          ),
        );
        return;
      }
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please detect your current location'),
            backgroundColor: HBotColors.error,
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
                'Scene "${_nameController.text.trim()}" updated with ${_deviceActions.length} device action${_deviceActions.length != 1 ? 's' : ''}!',
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
                'Scene "${_nameController.text.trim()}" created with ${_deviceActions.length} device action${_deviceActions.length != 1 ? 's' : ''}!',
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
                  ? 'Failed to update scene: $e'
                  : 'Failed to create scene: $e',
            ),
            backgroundColor: HBotColors.error,
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
      backgroundColor: HBotColors.cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repeat', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: HBotSpacing.space4),
            ..._repeatOptions.map(
              (option) => ListTile(
                title: Text(option),
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
        color: isSelected ? _selectedColor : HBotColors.textSecondaryLight,
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

  String _getTriggerDescription(String trigger) {
    switch (trigger) {
      case 'Manual':
        return 'Activate manually when needed';
      case 'Time Based':
        return 'Activate at a specific time';
      case 'Location Based':
        return 'Activate based on your location';
      case 'Sensor Triggered':
        return 'Activate when sensors detect changes';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              : (isDark ? HBotColors.surfaceLight : Colors.white),
          borderRadius: BorderRadius.circular(HBotRadius.small),
          border: Border.all(
            color: isSelected
                ? _selectedColor
                : (isDark
                      ? Colors.grey.withOpacity(0.3)
                      : HBotColors.borderLight),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? _selectedColor
                  : HBotColors.textSecondaryLight,
              size: 32,
            ),
            const SizedBox(height: HBotSpacing.space2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? _selectedColor
                    : HBotColors.textSecondaryLight,
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
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them.',
              ),
              backgroundColor: HBotColors.error,
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
              const SnackBar(
                content: Text('Location permissions are denied'),
                backgroundColor: HBotColors.error,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied. Please enable them in settings.',
              ),
              backgroundColor: HBotColors.error,
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
            content: Text('Failed to detect location: $e'),
            backgroundColor: HBotColors.error,
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
