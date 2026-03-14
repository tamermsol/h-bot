import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/phosphor_icons.dart';
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
  final TextEditingController _descriptionController = TextEditingController();
  IconData _selectedIcon = HBotIcons.lightbulb;
  Color _selectedColor = const Color(0xFFF59E0B);
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

  // v0 scene colors
  final List<Color> _availableColors = const [
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF0883FD), // Blue
    Color(0xFF10B981), // Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF97316), // Orange
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  // v0 icon keys -> Material Icons
  final List<_SceneIconOption> _iconOptions = [
    _SceneIconOption('sun', HBotIcons.lightbulb),
    _SceneIconOption('film', HBotIcons.play),
    _SceneIconOption('shield', HBotIcons.lock),
    _SceneIconOption('moon', HBotIcons.scenes),
    _SceneIconOption('star', HBotIcons.scenes),
    _SceneIconOption('zap', HBotIcons.bolt),
    _SceneIconOption('home', HBotIcons.home),
    _SceneIconOption('coffee', HBotIcons.lightbulb),
  ];

  String _selectedIconKey = 'sun';

  // v0 trigger types (3 options)
  final List<String> _triggerTypes = ['Manual', 'Scheduled', 'Location'];

  String _selectedRepeat = 'Once only';
  List<int> _customDays = [];
  // Scheduled time as string for v0 style
  String _scheduledTimeStr = '08:00';
  List<String> _scheduledDays = [];

  final List<String> _repeatOptions = [
    'Once only',
    'Every day',
    'Monday to Friday',
    'Weekend',
    'Custom',
  ];

  static const List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<String> _stepTitles = ['Basic Info', 'Appearance', 'Trigger', 'Devices', 'Device Actions', 'Review'];

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
        // Try to find matching key
        for (final opt in _iconOptions) {
          if (opt.icon.codePoint == scene.iconCode) {
            _selectedIconKey = opt.key;
            break;
          }
        }
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
        final trigger = triggers.first;
        if (trigger.kind == TriggerKind.schedule) {
          _selectedTrigger = 'Scheduled';
          final configJson = trigger.configJson;

          final utcHour = configJson['hour'] as int?;
          final utcMinute = configJson['minute'] as int?;

          if (utcHour != null && utcMinute != null) {
            final timezoneService = TimezoneService();
            final egyptTime = timezoneService.utcHourMinuteToEgypt(utcHour, utcMinute);
            _selectedTime = TimeOfDay(hour: egyptTime['hour']!, minute: egyptTime['minute']!);
            _scheduledTimeStr = '${egyptTime['hour']!.toString().padLeft(2, '0')}:${egyptTime['minute']!.toString().padLeft(2, '0')}';
          }

          final days = (configJson['days'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];
          _selectedRepeat = _getRepeatOptionFromDays(days);
          if (_selectedRepeat == 'Custom') {
            _customDays = List<int>.from(days);
          }
          // Convert days to day name strings
          _scheduledDays = days.map((d) => _dayNames[d - 1]).toList();
        } else if (trigger.kind == TriggerKind.geo) {
          _selectedTrigger = 'Location';
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

      _selectedDevices.clear();
      _deviceActions.clear();

      for (final step in steps) {
        final actionJson = step.actionJson;
        final deviceId = actionJson['device_id'] as String?;

        if (deviceId != null) {
          try {
            final device = devices.firstWhere((d) => d.id == deviceId);
            _selectedDevices.add({
              'id': device.id,
              'name': device.name,
              'deviceName': device.name,
              'type': device.deviceType.name,
              'room': 'Unknown',
              'icon': _getDeviceIcon(device.deviceType.name),
              'isOnline': device.online ?? false,
              'device': device,
            });
            _deviceActions[deviceId] = Map<String, dynamic>.from(actionJson);
          } catch (e) {
            debugPrint('Device not found: $deviceId - $e');
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scene data: $e'), backgroundColor: HBotColors.error),
        );
      }
    }
  }

  String _getRepeatOptionFromDays(List<int> days) {
    final sortedDays = List<int>.from(days)..sort();
    if (sortedDays.length == 7) return 'Every day';
    if (sortedDays.length == 5 && sortedDays[0] == 1 && sortedDays[4] == 5) return 'Monday to Friday';
    if (sortedDays.length == 2 && sortedDays[0] == 6 && sortedDays[1] == 7) return 'Weekend';
    if (sortedDays.length == 1) return 'Once only';
    return 'Custom';
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'relay': return HBotIcons.power;
      case 'dimmer': return HBotIcons.lightbulb;
      case 'shutter': return HBotIcons.shutter;
      case 'sensor': return HBotIcons.thermometer;
      default: return HBotIcons.deviceUnknown;
    }
  }

  void _syncDeviceActions() {
    final selectedDeviceIds = _selectedDevices
        .map((deviceMap) => deviceMap['id'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet();
    _deviceActions.removeWhere((deviceId, action) => !selectedDeviceIds.contains(deviceId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0883FD)),
                ),
              )
            : Column(
                children: [
                  // Header
                  _buildHeader(),
                  // Step dots
                  _buildStepDots(),
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
                  // Footer CTA
                  _buildFooterCTA(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          // Back/Close button
          GestureDetector(
            onTap: _currentStep == 0
                ? () => Navigator.pop(context)
                : _previousStep,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                _currentStep == 0 ? HBotIcons.close : HBotIcons.back,
                size: 19,
                color: _currentStep == 0 ? const Color(0xFF4B5563) : const Color(0xFF1F2937),
              ),
            ),
          ),
          // Title
          Expanded(
            child: Column(
              children: [
                Text(
                  _isEditMode ? 'Edit Scene' : 'New Scene',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  _stepTitles[_currentStep],
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          // Spacer to balance
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildStepDots() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) {
          return Container(
            margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
            width: i == _currentStep ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == _currentStep
                  ? const Color(0xFF0883FD)
                  : i < _currentStep
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFFE5E7EB),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooterCTA() {
    final isLastStep = _currentStep == 5;
    final canProceed = _canProceed();

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: GestureDetector(
        onTap: (canProceed && !_isCreating) ? _nextStep : null,
        child: Opacity(
          opacity: (canProceed && !_isCreating) ? 1.0 : 0.4,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF0883FD), Color(0xFF8CD1FB)],
              ),
            ),
            alignment: Alignment.center,
            child: _isCreating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Text(
                    isLastStep ? (_isEditMode ? 'Update Scene' : 'Create Scene') : 'Continue',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Step 0: Basic Info ──
  Widget _buildBasicInfoStep() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scene Name
            const Text(
              'SCENE NAME *',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563), letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditMode,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF1F2937)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Movie Night',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: Color(0xFFC9CDD6)),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 20),

            // Description
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563), letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _descriptionController,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Color(0xFF1F2937)),
                decoration: const InputDecoration(
                  hintText: 'Short description (optional)',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: Color(0xFFC9CDD6)),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Appearance ──
  Widget _buildAppearanceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon grid
          const Text(
            'ICON',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563), letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: _iconOptions.map((opt) {
              final active = _selectedIconKey == opt.key;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIconKey = opt.key;
                    _selectedIcon = opt.icon;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? _selectedColor : const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                    color: active
                        ? _selectedColor.withOpacity(0.12)
                        : const Color(0xFFF5F7FA),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(opt.icon, size: 22, color: active ? _selectedColor : const Color(0xFF9CA3AF)),
                      const SizedBox(height: 6),
                      Text(
                        opt.key,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: active ? _selectedColor : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Color picker
          const Text(
            'COLOR',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563), letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((c) {
              final isSelected = c.value == _selectedColor.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(color: Colors.white, spreadRadius: 3),
                            BoxShadow(color: c, spreadRadius: 5),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Icon(HBotIcons.check, size: 16, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_selectedColor, _selectedColor.withOpacity(0.73)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_selectedIcon, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'Scene Name',
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Preview',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Trigger ──
  Widget _buildTriggerStep() {
    final triggerIcons = {
      'Manual': HBotIcons.play,
      'Scheduled': HBotIcons.accessTime,
      'Location': HBotIcons.network,
    };
    final triggerDescs = {
      'Manual': 'Run this scene manually by tapping the play button',
      'Scheduled': 'Run automatically at a set time and days',
      'Location': 'Coming soon - trigger based on location',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trigger type cards
          ...['Manual', 'Scheduled', 'Location'].map((t) {
            final active = _selectedTrigger == t;
            final disabled = t == 'Location';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: disabled ? null : () => setState(() => _selectedTrigger = t),
                child: Opacity(
                  opacity: disabled ? 0.5 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? const Color(0xFF0883FD) : const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                      color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF5F7FA),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? const Color(0xFF0883FD) : const Color(0xFFE5E7EB),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            triggerIcons[t],
                            size: 18,
                            color: active ? Colors.white : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t,
                                style: TextStyle(
                                  fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700,
                                  color: active ? const Color(0xFF0883FD) : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                triggerDescs[t] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (active)
                          Icon(HBotIcons.check, size: 16, color: Color(0xFF0883FD)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Scheduled options
          if (_selectedTrigger == 'Scheduled') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  const Text(
                    'TIME',
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563), letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedTime = time;
                          _scheduledTimeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _selectedTime != null ? _scheduledTimeStr : 'Select Time',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600,
                          color: _selectedTime != null ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Repeat (day circles)
                  const Text(
                    'REPEAT',
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563), letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dayNames.map((d) {
                      final active = _scheduledDays.contains(d);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (active) {
                              _scheduledDays.remove(d);
                            } else {
                              _scheduledDays.add(d);
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active ? const Color(0xFF0883FD) : Colors.white,
                            border: Border.all(
                              color: active ? const Color(0xFF0883FD) : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            d.substring(0, 2),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 3: Devices ──
  Widget _buildDevicesStep() {
    debugPrint('AddSceneScreen: _buildDevicesStep - homeId = ${widget.homeId}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select devices to include in this scene',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          DeviceSelector(
            selectedDevices: _selectedDevices,
            onDevicesChanged: (devices) {
              setState(() {
                _selectedDevices = devices;
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

  // ── Step 4: Device Actions ──
  Widget _buildDeviceActionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'No devices selected',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            ..._selectedDevices.map((deviceMap) {
              final device = deviceMap['device'] as Device?;
              if (device == null) return const SizedBox.shrink();

              if (!_deviceActions.containsKey(device.id)) {
                _deviceActions[device.id] = _getDefaultAction(device);
              }

              return _buildV0DeviceActionCard(device, deviceMap);
            }),
        ],
      ),
    );
  }

  Map<String, dynamic> _getDefaultAction(Device device) {
    switch (device.deviceType) {
      case DeviceType.relay:
      case DeviceType.dimmer:
        return {'type': 'power', 'channels': [1], 'state': true};
      case DeviceType.shutter:
        return {'type': 'shutter', 'position': 50};
      case DeviceType.sensor:
      case DeviceType.other:
        return {'type': 'none'};
    }
  }

  Widget _buildV0DeviceActionCard(Device device, Map<String, dynamic> deviceMap) {
    final action = _deviceActions[device.id]!;
    final deviceType = device.deviceType.name.toLowerCase();
    final color = _getDeviceTypeColor(deviceType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  deviceMap['icon'] as IconData? ?? HBotIcons.deviceUnknown,
                  size: 16, color: color,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                device.deviceName,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Channel actions with ON/OFF buttons
          if (device.deviceType == DeviceType.relay || device.deviceType == DeviceType.dimmer)
            _buildRelayDimmerActionV0(device, action),
          if (device.deviceType == DeviceType.shutter)
            _buildShutterActionV0(device, action),
        ],
      ),
    );
  }

  Color _getDeviceTypeColor(String type) {
    switch (type) {
      case 'relay': return const Color(0xFF3B82F6);
      case 'dimmer': return const Color(0xFFF59E0B);
      case 'sensor': return const Color(0xFF10B981);
      case 'shutter': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF3B82F6);
    }
  }

  Widget _buildRelayDimmerActionV0(Device device, Map<String, dynamic> action) {
    final state = action['state'] as bool? ?? true;
    final channels = device.effectiveChannels;

    return Column(
      children: [
        // For each channel
        ...List.generate(channels > 4 ? 1 : channels, (i) {
          final channelName = channels > 1 ? 'Channel ${i + 1}' : 'Channel 1';
          final isOn = state; // Simplified: all channels same state

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    channelName,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                  ),
                  Row(
                    children: [
                      _buildActionButton('ON', isOn, () {
                        setState(() => _deviceActions[device.id]!['state'] = true);
                      }),
                      const SizedBox(width: 8),
                      _buildActionButton('OFF', !isOn, () {
                        setState(() => _deviceActions[device.id]!['state'] = false);
                      }, isOff: true),
                    ],
                  ),
                ],
              ),

              // Brightness slider for dimmer when ON
              if (device.deviceType == DeviceType.dimmer && isOn) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Brightness', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF4B5563))),
                    Text(
                      '${(action['brightness'] as int?) ?? 80}%',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFF59E0B),
                    inactiveTrackColor: const Color(0xFFE5E7EB),
                    thumbColor: const Color(0xFFF59E0B),
                    overlayColor: const Color(0xFFF59E0B).withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: ((action['brightness'] as int?) ?? 80).toDouble(),
                    min: 0, max: 100,
                    onChanged: (v) {
                      setState(() => _deviceActions[device.id]!['brightness'] = v.toInt());
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(String label, bool active, VoidCallback onTap, {bool isOff = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? (isOff ? const Color(0xFFEF4444) : const Color(0xFF0883FD))
              : const Color(0xFFE5E7EB),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildShutterActionV0(Device device, Map<String, dynamic> action) {
    final position = (action['position'] as int?) ?? 50;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Position', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF4B5563))),
            Text(
              '$position%',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF8B5CF6),
            inactiveTrackColor: const Color(0xFFE5E7EB),
            thumbColor: const Color(0xFF8B5CF6),
            overlayColor: const Color(0xFF8B5CF6).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: position.toDouble(),
            min: 0, max: 100,
            onChanged: (v) {
              setState(() => _deviceActions[device.id]!['position'] = v.toInt());
            },
          ),
        ),
      ],
    );
  }

  // ── Step 5: Review ──
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scene preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_selectedColor, _selectedColor.withOpacity(0.73)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_selectedIcon, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                      ),
                      if (_descriptionController.text.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _descriptionController.text,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Summary rows
          _buildSummaryRow('Trigger', _selectedTrigger == 'Scheduled' && _scheduledTimeStr.isNotEmpty
              ? 'Scheduled at $_scheduledTimeStr'
              : _selectedTrigger),
          _buildSummaryRow('Repeat', _selectedTrigger == 'Scheduled' && _scheduledDays.isNotEmpty
              ? _scheduledDays.join(', ')
              : _selectedTrigger == 'Scheduled' ? 'Once' : '\u2014'),
          _buildSummaryRow('Devices', '${_selectedDevices.length} device${_selectedDevices.length != 1 ? 's' : ''}'),
          _buildSummaryRow('Actions', '${_deviceActions.length} action${_deviceActions.length != 1 ? 's' : ''}', isLast: true),

          const SizedBox(height: 16),

          // Actions summary
          if (_deviceActions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563), letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._deviceActions.entries.map((entry) {
                    final deviceMap = _selectedDevices.firstWhere(
                      (d) => d['id'] == entry.key,
                      orElse: () => {'name': 'Unknown'},
                    );
                    final action = entry.value;
                    final isOn = action['state'] == true;
                    final actionLabel = action['type'] == 'shutter'
                        ? 'Position ${action['position']}%'
                        : isOn ? 'ON' : 'OFF';

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFEBEDF0), width: 1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            deviceMap['name'] ?? 'Unknown',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1F2937)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: isOn ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2),
                            ),
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700,
                                color: isOn ? const Color(0xFF0883FD) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF9CA3AF))),
          Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  // ── Navigation ──
  bool _canProceed() {
    switch (_currentStep) {
      case 0: return _nameController.text.trim().isNotEmpty;
      case 1: return true;
      case 2:
        if (_selectedTrigger == 'Scheduled') return _selectedTime != null;
        if (_selectedTrigger == 'Location') {
          return _selectedLocationTriggerType != null && _selectedLatitude != null && _selectedLongitude != null;
        }
        return true;
      case 3: return _selectedDevices.isNotEmpty;
      case 4: return true;
      case 5: return true;
      default: return false;
    }
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _createScene();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _createScene() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a scene name'), backgroundColor: HBotColors.error),
      );
      return;
    }

    if (_selectedTrigger == 'Scheduled' && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activation time'), backgroundColor: HBotColors.error),
      );
      return;
    }

    if (_selectedTrigger == 'Location') {
      if (_selectedLocationTriggerType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select when to trigger (arrive or leave)'), backgroundColor: HBotColors.error),
        );
        return;
      }
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please detect your current location'), backgroundColor: HBotColors.error),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      if (_isEditMode) {
        await _service.updateScene(
          widget.sceneId!,
          name: _nameController.text.trim(),
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.value,
        );

        await _service.deleteSceneSteps(widget.sceneId!);

        int stepOrder = 0;
        for (final entry in _deviceActions.entries) {
          final deviceId = entry.key;
          final action = entry.value;
          final actionJson = {'device_id': deviceId, 'action_type': action['type'], ...action};
          await _service.createSceneStep(widget.sceneId!, stepOrder, actionJson);
          stepOrder++;
        }

        await _updateSceneTriggers(widget.sceneId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scene "${_nameController.text.trim()}" updated!'),
              backgroundColor: HBotColors.primary,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final scene = await _service.createScene(
          widget.homeId,
          _nameController.text.trim(),
          isEnabled: true,
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.value,
        );

        int stepOrder = 0;
        for (final entry in _deviceActions.entries) {
          final deviceId = entry.key;
          final action = entry.value;
          final actionJson = {'device_id': deviceId, 'action_type': action['type'], ...action};
          await _service.createSceneStep(scene.id, stepOrder, actionJson);
          stepOrder++;
        }

        await _createSceneTrigger(scene.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scene "${_nameController.text.trim()}" created!'),
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
            content: Text(_isEditMode ? 'Failed to update scene: $e' : 'Failed to create scene: $e'),
            backgroundColor: HBotColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createSceneTrigger(String sceneId) async {
    if (_selectedTrigger == 'Scheduled' && _selectedTime != null) {
      final timezoneService = TimezoneService();
      final days = _getDaysFromScheduledDays();
      final utcHourMinute = await timezoneService.buildTriggerUtcHourMinute(
        _selectedTime!.hour, _selectedTime!.minute, days,
      );

      final configJson = {
        'hour': utcHourMinute['hour'],
        'minute': utcHourMinute['minute'],
        'days': days,
      };

      await _service.createSceneTrigger(sceneId, TriggerKind.schedule, configJson, isEnabled: true);
    } else if (_selectedTrigger == 'Location' &&
        _selectedLocationTriggerType != null &&
        _selectedLatitude != null &&
        _selectedLongitude != null) {
      final configJson = {
        'trigger_type': _selectedLocationTriggerType,
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'radius': _selectedRadius,
        if (_selectedLocationAddress != null) 'address': _selectedLocationAddress,
      };
      await _service.createSceneTrigger(sceneId, TriggerKind.geo, configJson, isEnabled: true);
    }
  }

  List<int> _getDaysFromScheduledDays() {
    if (_scheduledDays.isEmpty) {
      final now = DateTime.now();
      return [now.weekday];
    }
    return _scheduledDays.map((d) {
      final idx = _dayNames.indexOf(d);
      return idx >= 0 ? idx + 1 : 1;
    }).toList();
  }

  Future<void> _updateSceneTriggers(String sceneId) async {
    final existingTriggers = await _service.getSceneTriggers(sceneId);
    for (final trigger in existingTriggers) {
      await _service.deleteSceneTrigger(trigger.id);
    }
    await _createSceneTrigger(sceneId);
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled'), backgroundColor: HBotColors.error),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions denied'), backgroundColor: HBotColors.error),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions permanently denied'), backgroundColor: HBotColors.error),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _selectedLocationAddress = 'Current Location';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to detect location: $e'), backgroundColor: HBotColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

class _SceneIconOption {
  final String key;
  final IconData icon;
  const _SceneIconOption(this.key, this.icon);
}
