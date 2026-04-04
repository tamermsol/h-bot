import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/background_container.dart';
import '../models/ha_entity.dart';
import '../services/ha_websocket_service.dart';
import '../services/ha_entity_state_service.dart';

/// Detail control screen for a single HA entity.
/// Shows domain-specific controls: brightness slider for lights,
/// temperature for climate, position for covers, etc.
class HaEntityControlScreen extends StatefulWidget {
  final HaEntity entity;
  final HaWebSocketService wsService;
  final HaEntityStateService stateService;

  const HaEntityControlScreen({
    super.key,
    required this.entity,
    required this.wsService,
    required this.stateService,
  });

  @override
  State<HaEntityControlScreen> createState() => _HaEntityControlScreenState();
}

class _HaEntityControlScreenState extends State<HaEntityControlScreen>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<HaEntityState> _stateSub;
  HaEntityState? _currentState;
  late final AnimationController _toggleAnim;
  bool? _prevIsOn;

  @override
  void initState() {
    super.initState();
    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _currentState = widget.stateService.getState(widget.entity.entityId);
    _prevIsOn = _isOn;
    if (_isOn) _toggleAnim.value = 1.0;
    _stateSub = widget.stateService
        .watchEntity(widget.entity.entityId)
        .listen((state) {
      if (mounted) {
        setState(() => _currentState = state);
        if (_prevIsOn != _isOn) {
          _prevIsOn = _isOn;
          if (_isOn) {
            _toggleAnim.forward();
          } else {
            _toggleAnim.reverse();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _toggleAnim.dispose();
    super.dispose();
  }

  String get _state => _currentState?.state ?? widget.entity.currentState ?? 'unknown';
  Map<String, dynamic> get _attrs =>
      _currentState?.attributes ?? widget.entity.attributes ?? {};
  bool get _isOn => _currentState?.isOn ?? widget.entity.isOn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entity.displayName),
        actions: [
          if (widget.entity.haAreaName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  widget.entity.haAreaName!,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: BackgroundContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Big state indicator
              _buildStateHeader(),
              const SizedBox(height: 32),

              // Domain-specific controls
              _buildDomainControls(),

              const SizedBox(height: 32),

              // Attributes info
              _buildAttributesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateHeader() {
    final domain = widget.entity.domainEnum;

    return AnimatedBuilder(
      animation: _toggleAnim,
      builder: (context, child) {
        final color = ColorTween(
          begin: Colors.grey,
          end: AppTheme.primaryColor,
        ).evaluate(_toggleAnim)!;

        return Column(
          children: [
            // Animated icon circle
            GestureDetector(
              onTap: domain.isControllable ? _toggle : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color, width: 3),
                ),
                child: Icon(
                  _getDomainIcon(domain, widget.entity.deviceClass),
                  size: 48,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _state.toUpperCase(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.entity.entityId,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            // Last changed timestamp
            if (_currentState != null) ...[
              const SizedBox(height: 6),
              Text(
                'Changed ${_formatTimeAgo(_currentState!.lastChanged)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDomainControls() {
    switch (widget.entity.domainEnum) {
      case HaDomain.light:
        return _buildLightControls();
      case HaDomain.climate:
        return _buildClimateControls();
      case HaDomain.cover:
        return _buildCoverControls();
      case HaDomain.fan:
        return _buildFanControls();
      case HaDomain.sensor:
      case HaDomain.binarySensor:
        return _buildSensorDisplay();
      default:
        return _buildToggleButton();
    }
  }

  Widget _buildLightControls() {
    final brightness = (_attrs['brightness'] as num?)?.toDouble() ?? 0;
    final hasBrightness =
        (_attrs['supported_color_modes'] as List?)?.any(
                (m) => m != 'onoff') ??
            false;
    final colorTemp = (_attrs['color_temp_kelvin'] as num?)?.toDouble();
    final minKelvin = (_attrs['min_color_temp_kelvin'] as num?)?.toDouble() ?? 2000;
    final maxKelvin = (_attrs['max_color_temp_kelvin'] as num?)?.toDouble() ?? 6500;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // On/off toggle
            _buildToggleButton(),
            if (hasBrightness) ...[
              const SizedBox(height: 24),
              // Brightness slider
              Row(
                children: [
                  const Icon(Icons.brightness_low, size: 20),
                  Expanded(
                    child: Slider(
                      value: brightness,
                      min: 0,
                      max: 255,
                      onChanged: (_) {},
                      onChangeEnd: (v) => _setBrightness(v.toInt()),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ),
                  const Icon(Icons.brightness_high, size: 20),
                ],
              ),
              Text('Brightness: ${(brightness / 255 * 100).round()}%'),
            ],
            if (colorTemp != null) ...[
              const SizedBox(height: 16),
              // Color temperature slider
              Row(
                children: [
                  const Icon(Icons.wb_sunny, size: 20, color: Colors.orange),
                  Expanded(
                    child: Slider(
                      value: colorTemp.clamp(minKelvin, maxKelvin),
                      min: minKelvin,
                      max: maxKelvin,
                      onChanged: (_) {},
                      onChangeEnd: (v) => _setColorTemp(v.toInt()),
                      activeColor: Colors.amber,
                    ),
                  ),
                  const Icon(Icons.wb_sunny, size: 20, color: Colors.blue),
                ],
              ),
              Text('Color temp: ${colorTemp.round()}K'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClimateControls() {
    final currentTemp =
        (_attrs['current_temperature'] as num?)?.toDouble();
    final targetTemp =
        (_attrs['temperature'] as num?)?.toDouble() ?? 20;
    final minTemp = (_attrs['min_temp'] as num?)?.toDouble() ?? 10;
    final maxTemp = (_attrs['max_temp'] as num?)?.toDouble() ?? 35;
    final hvacModes =
        (_attrs['hvac_modes'] as List?)?.cast<String>() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Current temperature
            if (currentTemp != null)
              Text(
                '${currentTemp.toStringAsFixed(1)}°',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 16),

            // Target temperature slider
            Row(
              children: [
                Text('${minTemp.round()}°'),
                Expanded(
                  child: Slider(
                    value: targetTemp.clamp(minTemp, maxTemp),
                    min: minTemp,
                    max: maxTemp,
                    divisions: ((maxTemp - minTemp) * 2).round(),
                    label: '${targetTemp.toStringAsFixed(1)}°',
                    onChanged: (_) {},
                      onChangeEnd: _setTemperature,
                    activeColor: Colors.orange,
                  ),
                ),
                Text('${maxTemp.round()}°'),
              ],
            ),
            Text('Target: ${targetTemp.toStringAsFixed(1)}°'),

            // HVAC mode chips
            if (hvacModes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: hvacModes.map((mode) {
                  final isActive = _state == mode;
                  return ChoiceChip(
                    label: Text(mode),
                    selected: isActive,
                    onSelected: (_) => _setHvacMode(mode),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoverControls() {
    final position =
        (_attrs['current_position'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Position slider
            Row(
              children: [
                const Icon(Icons.arrow_downward, size: 20),
                Expanded(
                  child: Slider(
                    value: position,
                    min: 0,
                    max: 100,
                    onChanged: (_) {},
                      onChangeEnd: (v) => _setCoverPosition(v.toInt()),
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
                const Icon(Icons.arrow_upward, size: 20),
              ],
            ),
            Text('Position: ${position.round()}%'),
            const SizedBox(height: 16),

            // Quick buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.arrow_downward, 'Close', () {
                  widget.wsService.callService(
                    domain: 'cover',
                    service: 'close_cover',
                    entityId: widget.entity.entityId,
                  );
                }),
                _actionButton(Icons.stop, 'Stop', () {
                  widget.wsService.callService(
                    domain: 'cover',
                    service: 'stop_cover',
                    entityId: widget.entity.entityId,
                  );
                }),
                _actionButton(Icons.arrow_upward, 'Open', () {
                  widget.wsService.callService(
                    domain: 'cover',
                    service: 'open_cover',
                    entityId: widget.entity.entityId,
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFanControls() {
    final percentage =
        (_attrs['percentage'] as num?)?.toDouble() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildToggleButton(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.air, size: 20),
                Expanded(
                  child: Slider(
                    value: percentage,
                    min: 0,
                    max: 100,
                    onChanged: (_) {},
                      onChangeEnd: (v) {
                      widget.wsService.callService(
                        domain: 'fan',
                        service: 'set_percentage',
                        entityId: widget.entity.entityId,
                        serviceData: {'percentage': v.round()},
                      );
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            Text('Speed: ${percentage.round()}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDisplay() {
    final unit = _attrs['unit_of_measurement'] ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '$_state$unit',
              style: const TextStyle(
                  fontSize: 48, fontWeight: FontWeight.bold),
            ),
            if (widget.entity.deviceClass != null)
              Text(
                widget.entity.deviceClass!,
                style: TextStyle(color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton() {
    if (!widget.entity.domainEnum.isControllable) return const SizedBox();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _toggle,
        icon: Icon(_isOn ? Icons.power_settings_new : Icons.power_off),
        label: Text(_isOn ? 'Turn Off' : 'Turn On'),
        style: FilledButton.styleFrom(
          backgroundColor: _isOn
              ? Colors.red.shade400
              : AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildAttributesCard() {
    final displayAttrs = Map<String, dynamic>.from(_attrs)
      ..remove('friendly_name')
      ..remove('supported_features')
      ..remove('supported_color_modes');

    if (displayAttrs.isEmpty) return const SizedBox();

    return Card(
      child: ExpansionTile(
        title: const Text('Attributes'),
        children: displayAttrs.entries.map((e) {
          return ListTile(
            dense: true,
            title: Text(e.key.replaceAll('_', ' ')),
            trailing: Text(
              '${e.value}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _actionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Domain-aware icon with device_class specializations
  IconData _getDomainIcon(HaDomain domain, String? deviceClass) {
    switch (domain) {
      case HaDomain.light:
        return Icons.lightbulb;
      case HaDomain.switchDomain:
        if (deviceClass == 'outlet') return Icons.power;
        return Icons.toggle_on;
      case HaDomain.climate:
        return Icons.thermostat;
      case HaDomain.cover:
        if (deviceClass == 'garage') return Icons.garage;
        if (deviceClass == 'door') return Icons.door_front_door;
        if (deviceClass == 'window') return Icons.window;
        if (deviceClass == 'shutter') return Icons.roller_shades;
        return Icons.blinds;
      case HaDomain.fan:
        return Icons.air;
      case HaDomain.lock:
        return _isOn ? Icons.lock_open : Icons.lock;
      case HaDomain.sensor:
        return _sensorIcon(deviceClass);
      case HaDomain.binarySensor:
        if (deviceClass == 'motion') return Icons.directions_walk;
        if (deviceClass == 'door') return Icons.door_front_door;
        if (deviceClass == 'window') return Icons.window;
        if (deviceClass == 'smoke') return Icons.local_fire_department;
        if (deviceClass == 'moisture') return Icons.water_damage;
        if (deviceClass == 'occupancy') return Icons.person;
        return Icons.sensors;
      case HaDomain.mediaPlayer:
        return Icons.speaker;
      case HaDomain.camera:
        return Icons.videocam;
      case HaDomain.scene:
        return Icons.palette;
      case HaDomain.button:
        return Icons.radio_button_checked;
      case HaDomain.number:
        return Icons.tune;
      case HaDomain.inputBoolean:
        return Icons.toggle_on_outlined;
      case HaDomain.inputNumber:
        return Icons.dialpad;
      case HaDomain.other:
        return Icons.device_hub;
    }
  }

  IconData _sensorIcon(String? deviceClass) {
    switch (deviceClass) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'power':
      case 'energy':
        return Icons.bolt;
      case 'battery':
        return Icons.battery_std;
      case 'illuminance':
        return Icons.light_mode;
      case 'pressure':
        return Icons.compress;
      case 'carbon_dioxide':
      case 'carbon_monoxide':
        return Icons.cloud;
      case 'gas':
        return Icons.propane_tank;
      default:
        return Icons.sensors;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m min${m > 1 ? 's' : ''} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h > 1 ? 's' : ''} ago';
    }
    final d = diff.inDays;
    return '$d day${d > 1 ? 's' : ''} ago';
  }

  Future<void> _toggle() async {
    try {
      if (_isOn) {
        await widget.wsService.turnOff(widget.entity.entityId);
      } else {
        await widget.wsService.turnOn(widget.entity.entityId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setBrightness(int brightness) async {
    try {
      await widget.wsService
          .setLightBrightness(widget.entity.entityId, brightness);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setColorTemp(int kelvin) async {
    try {
      await widget.wsService.turnOn(
        widget.entity.entityId,
        data: {'color_temp_kelvin': kelvin},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setTemperature(double temp) async {
    try {
      await widget.wsService
          .setClimateTemperature(widget.entity.entityId, temp);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setHvacMode(String mode) async {
    try {
      await widget.wsService.callService(
        domain: 'climate',
        service: 'set_hvac_mode',
        entityId: widget.entity.entityId,
        serviceData: {'hvac_mode': mode},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _setCoverPosition(int position) async {
    try {
      await widget.wsService
          .setCoverPosition(widget.entity.entityId, position);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
