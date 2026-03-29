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

class _HaEntityControlScreenState extends State<HaEntityControlScreen> {
  late StreamSubscription<HaEntityState> _stateSub;
  HaEntityState? _currentState;

  @override
  void initState() {
    super.initState();
    _currentState = widget.stateService.getState(widget.entity.entityId);
    _stateSub = widget.stateService
        .watchEntity(widget.entity.entityId)
        .listen((state) {
      if (mounted) setState(() => _currentState = state);
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
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
    final color = _isOn ? AppTheme.primaryColor : Colors.grey;

    return Column(
      children: [
        // Big icon with state
        GestureDetector(
          onTap: domain.isControllable ? _toggle : null,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(
              _getIcon(),
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
      ],
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

  IconData _getIcon() {
    switch (widget.entity.domainEnum) {
      case HaDomain.light:
        return Icons.lightbulb;
      case HaDomain.switchDomain:
        return Icons.toggle_on;
      case HaDomain.climate:
        return Icons.thermostat;
      case HaDomain.cover:
        return Icons.blinds;
      case HaDomain.fan:
        return Icons.air;
      case HaDomain.lock:
        return _isOn ? Icons.lock_open : Icons.lock;
      case HaDomain.sensor:
        return Icons.sensors;
      case HaDomain.binarySensor:
        return Icons.sensors;
      case HaDomain.mediaPlayer:
        return Icons.speaker;
      case HaDomain.camera:
        return Icons.videocam;
      default:
        return Icons.device_hub;
    }
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
