import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';

/// Screen for calibrating shutter open/close durations
class ShutterCalibrationScreen extends StatefulWidget {
  final Device device;

  const ShutterCalibrationScreen({super.key, required this.device});

  @override
  State<ShutterCalibrationScreen> createState() =>
      _ShutterCalibrationScreenState();
}

class _ShutterCalibrationScreenState extends State<ShutterCalibrationScreen> {
  final MqttDeviceManager _mqttManager = MqttDeviceManager();

  // Calibration state
  CalibrationMode _mode = CalibrationMode.none;
  bool _isCalibrating = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  // Calibration results
  int? _openDuration;
  int? _closeDuration;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCloseCalibration() {
    setState(() {
      _mode = CalibrationMode.close;
      _isCalibrating = true;
      _elapsedSeconds = 0;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    // Send close command to shutter
    _sendShutterCommand('close');
  }

  void _startOpenCalibration() {
    setState(() {
      _mode = CalibrationMode.open;
      _isCalibrating = true;
      _elapsedSeconds = 0;
    });

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });

    // Send open command to shutter
    _sendShutterCommand('open');
  }

  Future<void> _stopCalibration() async {
    _timer?.cancel();

    // Send stop command to shutter
    await _sendShutterCommand('stop');

    // Save the duration and send the appropriate SetClose/SetOpen command
    if (_mode == CalibrationMode.close) {
      setState(() {
        _closeDuration = _elapsedSeconds;
        _isCalibrating = false;
      });

      // Send ShutterSetClose1 to mark current position as 0% (closed)
      try {
        final topicBase = widget.device.tasmotaTopicBase;
        if (topicBase != null && topicBase.isNotEmpty) {
          debugPrint('📤 Sending ShutterSetClose1 (marking 0% position)');
          await _sendCustomCommand(topicBase, 'ShutterSetClose1', '');
        }
      } catch (e) {
        debugPrint('❌ Error sending ShutterSetClose1: $e');
      }
    } else if (_mode == CalibrationMode.open) {
      setState(() {
        _openDuration = _elapsedSeconds;
        _isCalibrating = false;
      });

      // Send ShutterSetOpen1 to mark current position as 100% (open)
      try {
        final topicBase = widget.device.tasmotaTopicBase;
        if (topicBase != null && topicBase.isNotEmpty) {
          debugPrint('📤 Sending ShutterSetOpen1 (marking 100% position)');
          await _sendCustomCommand(topicBase, 'ShutterSetOpen1', '');
        }
      } catch (e) {
        debugPrint('❌ Error sending ShutterSetOpen1: $e');
      }
    }
  }

  Future<void> _sendShutterCommand(String action) async {
    try {
      final topicBase = widget.device.tasmotaTopicBase;
      if (topicBase == null || topicBase.isEmpty) {
        throw Exception('Device has no MQTT topic configured');
      }

      switch (action) {
        case 'open':
          await _mqttManager.openShutter(widget.device.id, 1);
          break;
        case 'close':
          await _mqttManager.closeShutter(widget.device.id, 1);
          break;
        case 'stop':
          await _mqttManager.stopShutter(widget.device.id, 1);
          break;
        default:
          return;
      }

      debugPrint('📤 Sent calibration command: $action');
    } catch (e) {
      debugPrint('❌ Error sending shutter command: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send command: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyCalibration() async {
    if (_openDuration == null || _closeDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete both calibrations first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final topicBase = widget.device.tasmotaTopicBase;
      if (topicBase == null || topicBase.isEmpty) {
        throw Exception('Device has no MQTT topic configured');
      }

      // NOTE: ShutterSetClose1 and ShutterSetOpen1 were already sent
      // when the user pressed STOP during each calibration

      // Set open duration (time to fully open from closed)
      debugPrint('📤 Setting open duration: ${_openDuration}s');
      await _sendCustomCommand(
        topicBase,
        'ShutterOpenDuration1',
        _openDuration.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Set close duration (time to fully close from open)
      debugPrint('📤 Setting close duration: ${_closeDuration}s');
      await _sendCustomCommand(
        topicBase,
        'ShutterCloseDuration1',
        _closeDuration.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Send Restart command to save calibration and reboot device
      debugPrint('📤 Sending Restart 1 command to save calibration');
      await _sendCustomCommand(topicBase, 'Restart', '1');

      debugPrint(
        '✅ Calibration applied: Open=${_openDuration}s, Close=${_closeDuration}s',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Calibration applied successfully!\nOpen: ${_openDuration}s, Close: ${_closeDuration}s\nDevice is restarting...',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Go back after successful calibration
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error applying calibration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply calibration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send custom MQTT command to device
  Future<void> _sendCustomCommand(
    String topicBase,
    String command,
    String payload,
  ) async {
    await _mqttManager.mqttService.sendCustomCommand(
      topicBase,
      command,
      payload,
    );
  }

  Future<void> _resetCalibration() async {
    // Stop any ongoing calibration
    _timer?.cancel();

    // Send 100 seconds for both open and close durations
    // This allows the user to manually open/close the shutter to full limits
    try {
      final topicBase = widget.device.tasmotaTopicBase;
      if (topicBase != null && topicBase.isNotEmpty) {
        debugPrint('📤 Resetting calibration: Setting 100s for both durations');

        // Set open duration to 100 seconds
        await _sendCustomCommand(topicBase, 'ShutterOpenDuration1', '100');
        await Future.delayed(const Duration(milliseconds: 500));

        // Set close duration to 100 seconds
        await _sendCustomCommand(topicBase, 'ShutterCloseDuration1', '100');
        await Future.delayed(const Duration(milliseconds: 500));

        // Send Restart command to save settings
        debugPrint('📤 Sending Restart 1 command to save reset');
        await _sendCustomCommand(topicBase, 'Restart', '1');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Calibration reset to 100s for both directions.\nDevice is restarting...',
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error resetting calibration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset calibration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Reset local state
    setState(() {
      _mode = CalibrationMode.none;
      _isCalibrating = false;
      _elapsedSeconds = 0;
      _openDuration = null;
      _closeDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: HBotColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: HBotColors.cardLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HBotColors.textPrimaryLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Shutter Calibration',
          style: TextStyle(
            color: HBotColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device name
            Text(
              widget.device.deviceName,
              style: const TextStyle(
                color: HBotColors.textPrimaryLight,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Instructions card
            _buildInstructionsCard(),
            const SizedBox(height: HBotSpacing.space6),

            // Close calibration section
            _buildCalibrationSection(
              title: 'Close Calibration',
              description:
                  'Open the shutter completely (100%) manually, then start calibration. The shutter will close. Press STOP when fully closed.',
              isActive: _mode == CalibrationMode.close,
              duration: _closeDuration,
              onStart: _startCloseCalibration,
              icon: Icons.arrow_downward,
              color: Colors.red,
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Open calibration section
            _buildCalibrationSection(
              title: 'Open Calibration',
              description:
                  'Close the shutter completely (0%) manually, then start calibration. The shutter will open. Press STOP when fully open.',
              isActive: _mode == CalibrationMode.open,
              duration: _openDuration,
              onStart: _startOpenCalibration,
              icon: Icons.arrow_upward,
              color: Colors.green,
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Timer display (when calibrating)
            if (_isCalibrating) _buildTimerDisplay(),

            // Stop button (when calibrating)
            if (_isCalibrating) ...[
              const SizedBox(height: HBotSpacing.space6),
              ElevatedButton.icon(
                onPressed: _stopCalibration,
                icon: const Icon(Icons.stop, size: 32),
                label: const Text(
                  'STOP',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                ),
              ),
            ],

            // Apply and Reset buttons
            if (!_isCalibrating) ...[
              const SizedBox(height: HBotSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetCalibration,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HBotColors.textPrimaryLight,
                        side: const BorderSide(color: HBotColors.textTertiaryLight),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: HBotSpacing.space4),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _applyCalibration,
                      icon: const Icon(Icons.check),
                      label: const Text('Apply Calibration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HBotColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: HBotColors.cardLight,
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: HBotColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Calibration Instructions',
                  style: TextStyle(
                    color: HBotColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HBotSpacing.space4),
            const Text(
              '1. Complete BOTH calibrations (close and open)\n'
              '2. Follow the instructions for each calibration\n'
              '3. Press STOP when the shutter reaches its limit\n'
              '4. Click "Apply Calibration" to save settings',
              style: TextStyle(
                color: HBotColors.textSecondaryLight,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationSection({
    required String title,
    required String description,
    required bool isActive,
    required int? duration,
    required VoidCallback onStart,
    required IconData icon,
    required Color color,
  }) {
    final isCompleted = duration != null;
    final canStart = !_isCalibrating;

    return Card(
      color: isActive ? color.withOpacity(0.1) : HBotColors.cardLight,
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: HBotColors.textPrimaryLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${duration}s',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              description,
              style: const TextStyle(
                color: HBotColors.textSecondaryLight,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canStart ? onStart : null,
                icon: Icon(icon),
                label: Text(isCompleted ? 'Recalibrate' : 'Start Calibration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: HBotColors.textTertiaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Card(
      color: HBotColors.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          children: [
            const Text(
              'Calibration in Progress',
              style: TextStyle(
                color: HBotColors.textPrimaryLight,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              '$_elapsedSeconds',
              style: TextStyle(
                color: HBotColors.primary,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Text(
              'seconds',
              style: TextStyle(color: HBotColors.textSecondaryLight, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

enum CalibrationMode { none, close, open }
