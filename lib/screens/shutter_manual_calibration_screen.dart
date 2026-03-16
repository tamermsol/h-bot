import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';

/// Screen for manual shutter calibration by entering times directly
class ShutterManualCalibrationScreen extends StatefulWidget {
  final Device device;

  const ShutterManualCalibrationScreen({super.key, required this.device});

  @override
  State<ShutterManualCalibrationScreen> createState() =>
      _ShutterManualCalibrationScreenState();
}

class _ShutterManualCalibrationScreenState
    extends State<ShutterManualCalibrationScreen> {
  final MqttDeviceManager _mqttManager = MqttDeviceManager();
  final _formKey = GlobalKey<FormState>();

  // Controllers for time inputs
  final TextEditingController _openTimeController = TextEditingController();
  final TextEditingController _closeTimeController = TextEditingController();

  // Current shutter position
  ShutterPosition _currentPosition = ShutterPosition.unknown;

  @override
  void dispose() {
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  Future<void> _applyManualCalibration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentPosition == ShutterPosition.unknown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select current shutter position'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final topicBase = widget.device.tasmotaTopicBase;
      if (topicBase == null || topicBase.isEmpty) {
        throw Exception('Device is not configured for remote control');
      }

      final openTime = int.parse(_openTimeController.text);
      final closeTime = int.parse(_closeTimeController.text);

      // Send the appropriate SetClose or SetOpen command based on current position
      if (_currentPosition == ShutterPosition.fullyClosed) {
        // Shutter is at 0%, send ShutterSetClose1
        debugPrint('📤 Sending ShutterSetClose1 (shutter at 0%)');
        await _sendCustomCommand(topicBase, 'ShutterSetClose1', '');
        await Future.delayed(const Duration(milliseconds: 500));
      } else if (_currentPosition == ShutterPosition.fullyOpen) {
        // Shutter is at 100%, send ShutterSetOpen1
        debugPrint('📤 Sending ShutterSetOpen1 (shutter at 100%)');
        await _sendCustomCommand(topicBase, 'ShutterSetOpen1', '');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Set open duration
      debugPrint('📤 Setting open duration: ${openTime}s');
      await _sendCustomCommand(
        topicBase,
        'ShutterOpenDuration1',
        openTime.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Set close duration
      debugPrint('📤 Setting close duration: ${closeTime}s');
      await _sendCustomCommand(
        topicBase,
        'ShutterCloseDuration1',
        closeTime.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // Send Restart command to save calibration
      debugPrint('📤 Sending Restart 1 command to save calibration');
      await _sendCustomCommand(topicBase, 'Restart', '1');

      debugPrint(
        '✅ Manual calibration applied: Open=${openTime}s, Close=${closeTime}s',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Calibration applied successfully!\nOpen: ${openTime}s, Close: ${closeTime}s\nDevice is restarting...',
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
      debugPrint('❌ Error applying manual calibration: $e');
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: context.hCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.hTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Manual Calibration',
          style: TextStyle(
            color: context.hTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device name
              Text(
                widget.device.deviceName,
                style: TextStyle(
                  color: context.hTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HBotSpacing.space6),

              // Instructions card
              _buildInstructionsCard(),
              const SizedBox(height: HBotSpacing.space6),

              // Current position selection
              _buildPositionSelector(),
              const SizedBox(height: HBotSpacing.space6),

              // Open time input
              _buildTimeInput(
                controller: _openTimeController,
                label: 'Open Duration (seconds)',
                hint: 'Enter time to fully open',
                icon: Icons.arrow_upward,
                color: Colors.green,
              ),
              const SizedBox(height: HBotSpacing.space4),

              // Close time input
              _buildTimeInput(
                controller: _closeTimeController,
                label: 'Close Duration (seconds)',
                hint: 'Enter time to fully close',
                icon: Icons.arrow_downward,
                color: Colors.red,
              ),
              const SizedBox(height: HBotSpacing.space6),

              // Apply button
              ElevatedButton.icon(
                onPressed: _applyManualCalibration,
                icon: const Icon(Icons.check),
                label: const Text(
                  'Apply Calibration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HBotColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: context.hCard,
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
                Text(
                  'Manual Calibration',
                  style: TextStyle(
                    color: context.hTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              '1. Move your shutter to either fully open (100%) or fully closed (0%)\n'
              '2. Select the current position below\n'
              '3. Enter the time (in seconds) it takes to:\n'
              '   • Fully open from closed position\n'
              '   • Fully close from open position\n'
              '4. Click "Apply Calibration" to save',
              style: TextStyle(
                color: context.hTextSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionSelector() {
    return Card(
      color: context.hCard,
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Shutter Position',
              style: TextStyle(
                color: context.hTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Text(
              'Select where your shutter is right now:',
              style: TextStyle(color: context.hTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: HBotSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: _buildPositionButton(
                    position: ShutterPosition.fullyClosed,
                    label: 'Fully Closed',
                    subtitle: '0%',
                    icon: Icons.arrow_downward,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: HBotSpacing.space4),
                Expanded(
                  child: _buildPositionButton(
                    position: ShutterPosition.fullyOpen,
                    label: 'Fully Open',
                    subtitle: '100%',
                    icon: Icons.arrow_upward,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionButton({
    required ShutterPosition position,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _currentPosition == position;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentPosition = position;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space4),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : context.hBackground,
          border: Border.all(
            color: isSelected ? color : context.hTextTertiary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(HBotRadius.medium),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : context.hTextTertiary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : context.hTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? color : context.hTextTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: context.hCard,
      child: Padding(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: context.hTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HBotSpacing.space4),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: context.hTextPrimary, fontSize: 18),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: context.hTextTertiary),
                suffixText: 'seconds',
                suffixStyle: TextStyle(color: context.hTextSecondary),
                filled: true,
                fillColor: context.hBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HBotRadius.small),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: HBotSpacing.space4,
                  vertical: HBotSpacing.space4,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a time';
                }
                final time = int.tryParse(value);
                if (time == null || time <= 0) {
                  return 'Please enter a valid time (greater than 0)';
                }
                if (time > 300) {
                  return 'Time should be less than 300 seconds';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum ShutterPosition { unknown, fullyClosed, fullyOpen }
