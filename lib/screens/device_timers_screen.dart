import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/device.dart';
import '../models/device_timer.dart';
import '../theme/app_theme.dart';
import '../services/mqtt_device_manager.dart';
import 'add_timer_screen.dart';
import '../widgets/responsive_shell.dart';
import '../l10n/app_strings.dart';

class DeviceTimersScreen extends StatefulWidget {
  final Device device;
  final MqttDeviceManager mqttManager;

  const DeviceTimersScreen({
    super.key,
    required this.device,
    required this.mqttManager,
  });

  @override
  State<DeviceTimersScreen> createState() => _DeviceTimersScreenState();
}

class _DeviceTimersScreenState extends State<DeviceTimersScreen> {
  List<DeviceTimer> _timers = [];
  bool _isLoading = true;
  bool _isSyncingTime = false;

  // Track which timer indices are occupied on the device
  Set<int> _occupiedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadTimers();
  }

  Future<void> _loadTimers() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'device_timers_${widget.device.id}';
      final timersJson = prefs.getString(key);

      if (timersJson != null) {
        final List<dynamic> timersList = json.decode(timersJson);
        _timers = timersList.map((t) => DeviceTimer.fromJson(t)).toList();
        debugPrint(
          '📱 Loaded ${_timers.length} timers for ${widget.device.deviceName}',
        );
      }

      // Calculate occupied indices
      _calculateOccupiedIndices();
    } catch (e) {
      debugPrint('Error loading timers: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Calculate which timer indices are occupied on the device
  /// "All Channels" timers occupy multiple indices (one per channel)
  void _calculateOccupiedIndices() {
    _occupiedIndices.clear();
    final maxChannels = widget.device.channels ?? 1;

    for (final timer in _timers) {
      if (timer.output == 0) {
        // All channels timer occupies multiple indices
        for (int ch = 0; ch < maxChannels; ch++) {
          _occupiedIndices.add(timer.index + ch);
        }
      } else {
        // Single channel timer occupies one index
        _occupiedIndices.add(timer.index);
      }
    }

    debugPrint(
      '📊 Occupied timer indices: $_occupiedIndices (${_occupiedIndices.length}/16)',
    );
  }

  /// Get the next available timer index
  /// Returns null if no slots available
  int? _getNextAvailableIndex({required int slotsNeeded}) {
    // Find first contiguous block of available indices
    for (int startIdx = 1; startIdx <= 16; startIdx++) {
      bool canFit = true;

      // Check if we have enough contiguous slots
      for (int offset = 0; offset < slotsNeeded; offset++) {
        final checkIdx = startIdx + offset;
        if (checkIdx > 16 || _occupiedIndices.contains(checkIdx)) {
          canFit = false;
          break;
        }
      }

      if (canFit) {
        return startIdx;
      }
    }

    return null; // No available slots
  }

  Future<void> _saveTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'device_timers_${widget.device.id}';
      final timersJson = json.encode(_timers.map((t) => t.toJson()).toList());
      await prefs.setString(key, timersJson);
      debugPrint(
        '💾 Saved ${_timers.length} timers for ${widget.device.deviceName}',
      );
    } catch (e) {
      debugPrint('Error saving timers: $e');
    }
  }

  Future<void> _addTimer() async {
    // First, let user configure the timer to know how many slots needed
    final maxChannels = widget.device.channels ?? 1;

    // Recalculate occupied indices to ensure we have fresh data
    _calculateOccupiedIndices();

    // Check if we have at least 1 slot available (for single channel timer)
    final hasAnySpace = _getNextAvailableIndex(slotsNeeded: 1) != null;

    if (!hasAnySpace) {
      // Truly no space at all - all 16 slots occupied
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.hCard,
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Timer Limit Reached',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HBOT devices support a maximum of 16 local timer slots.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Currently occupied: ${_occupiedIndices.length}/16 slots',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(Note: "All Channels" timers use $maxChannels slots)',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.hTextSecondary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'To add more timers, please delete an existing timer or use Scene Control for advanced automation.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.get('common_ok')),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Let user configure the timer first
    // We'll use a temporary index just for the UI
    final tempIndex = _getNextAvailableIndex(slotsNeeded: 1) ?? 1;

    final result = await Navigator.push<DeviceTimer>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTimerScreen(
          device: widget.device,
          timerIndex: tempIndex,
          maxChannels: maxChannels,
        ),
      ),
    );

    if (result != null) {
      // Calculate actual slots needed for this timer
      final slotsNeeded = result.output == 0 ? maxChannels : 1;

      // Verify we have enough contiguous slots for this specific timer
      final finalIndex = _getNextAvailableIndex(slotsNeeded: slotsNeeded);

      if (finalIndex == null) {
        // Not enough contiguous slots for this specific timer configuration
        if (mounted) {
          final availableSlots = 16 - _occupiedIndices.length;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: context.hCard,
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Not Enough Contiguous Slots',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This timer needs $slotsNeeded contiguous slot${slotsNeeded > 1 ? 's' : ''}, but only $availableSlots slot${availableSlots != 1 ? 's are' : ' is'} available.',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Currently occupied: ${_occupiedIndices.length}/16 slots',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Options:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Create a single-channel timer instead',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Delete an existing timer to free more slots',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Use Scene Control for unlimited timers',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.get('common_ok')),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Update timer index to the final allocated index
      final finalTimer = result.copyWith(index: finalIndex);

      // Cancel any existing timers that conflict with this new timer
      await _cancelConflictingTimers(finalTimer);

      setState(() {
        _timers.add(finalTimer);
        _calculateOccupiedIndices();
      });
      await _saveTimers();
      await _sendTimerToDevice(finalTimer);
    }
  }

  Future<void> _editTimer(DeviceTimer timer) async {
    final result = await Navigator.push<DeviceTimer>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTimerScreen(
          device: widget.device,
          timerIndex: timer.index,
          maxChannels: widget.device.channels ?? 1,
          existingTimer: timer,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        final index = _timers.indexWhere((t) => t.index == result.index);
        if (index != -1) {
          _timers[index] = result;
        }
        _calculateOccupiedIndices(); // Recalculate after edit
      });
      await _saveTimers();
      await _sendTimerToDevice(result);
    }
  }

  Future<void> _toggleTimer(DeviceTimer timer) async {
    final updatedTimer = timer.copyWith(enabled: !timer.enabled);
    setState(() {
      final index = _timers.indexWhere((t) => t.index == timer.index);
      if (index != -1) {
        _timers[index] = updatedTimer;
      }
      // Recalculate in case enable/disable affects slot tracking
      _calculateOccupiedIndices();
    });
    await _saveTimers();
    await _sendTimerToDevice(updatedTimer);
  }

  Future<void> _deleteTimer(DeviceTimer timer) async {
    final maxChannels = widget.device.channels ?? 1;
    final slotsFreed = timer.output == 0 ? maxChannels : 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.hCard,
        title: Text(AppStrings.get('device_timers_delete_timer')),
        content: Text(
          'Are you sure you want to delete this timer?\n\n'
          'This will free $slotsFreed timer slot${slotsFreed > 1 ? 's' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.get('device_timers_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: HBotColors.error),
            child: Text(AppStrings.get('device_timers_delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // First disable the timer on the device
      final disabledTimer = timer.copyWith(enabled: false);
      await _sendTimerToDevice(disabledTimer);

      // Then remove from local storage and recalculate slots
      setState(() {
        _timers.removeWhere((t) => t.index == timer.index);
        _calculateOccupiedIndices(); // Recalculate immediately
      });
      await _saveTimers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timer deleted and disabled on device\n'
              'Freed $slotsFreed slot${slotsFreed > 1 ? 's' : ''} (${_occupiedIndices.length}/16 used)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendTimerToDevice(DeviceTimer timer) async {
    try {
      // First, sync device time with phone time
      await _syncDeviceTime();

      // Get timer commands (may be multiple for "all channels")
      final maxChannels = widget.device.channels ?? 1;
      final commands = timer.toTasmotaCommands(maxChannels);

      debugPrint('📤 Sending ${commands.length} timer command(s)');
      debugPrint('📤 Device ID: ${widget.device.id}');
      debugPrint('📤 Device Topic: ${widget.device.tasmotaTopicBase}');

      // Send each command via MQTT
      for (final command in commands) {
        debugPrint('📤 Command: $command');
        await widget.mqttManager.publishCommand(widget.device.id, command);
        // Small delay between commands to avoid overwhelming the device
        if (commands.length > 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      debugPrint('✅ Timer command(s) sent successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              timer.output == 0
                  ? 'Timer ${timer.index} set for all channels'
                  : 'Timer ${timer.index} ${timer.enabled ? "enabled" : "disabled"}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending timer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.get('device_timers_failed_to_update_timer_e')),
            backgroundColor: HBotColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Cancel any existing timers that conflict with the new timer
  /// This prevents multiple timers from triggering at the same time
  Future<void> _cancelConflictingTimers(DeviceTimer newTimer) async {
    try {
      // Find timers that might conflict:
      // - Same time (or close to it)
      // - Same channel or all channels
      // - Overlapping days
      final conflictingTimers = _timers.where((existingTimer) {
        // Skip if it's the same timer (editing case)
        if (existingTimer.index == newTimer.index) return false;

        // Check if channels overlap
        final channelsOverlap =
            (newTimer.output == 0 || existingTimer.output == 0) ||
            (newTimer.output == existingTimer.output);

        if (!channelsOverlap) return false;

        // Check if times are close (within 1 minute)
        if (newTimer.mode == TimerMode.time &&
            existingTimer.mode == TimerMode.time) {
          final newMinutes = newTimer.time.hour * 60 + newTimer.time.minute;
          final existingMinutes =
              existingTimer.time.hour * 60 + existingTimer.time.minute;
          final timeDiff = (newMinutes - existingMinutes).abs();

          if (timeDiff > 1) return false; // Not close enough to conflict
        } else if (newTimer.mode != existingTimer.mode) {
          return false; // Different modes (sunrise/sunset) don't conflict
        }

        // Check if days overlap
        for (int i = 0; i < 7; i++) {
          if (newTimer.days[i] && existingTimer.days[i]) {
            return true; // Found overlapping day
          }
        }

        return false;
      }).toList();

      if (conflictingTimers.isNotEmpty) {
        debugPrint(
          '🔄 Found ${conflictingTimers.length} conflicting timer(s), disabling them...',
        );

        for (final conflictingTimer in conflictingTimers) {
          // Disable the conflicting timer
          final disabledTimer = conflictingTimer.copyWith(enabled: false);
          await _sendTimerToDevice(disabledTimer);

          // Update in local list
          final index = _timers.indexWhere(
            (t) => t.index == conflictingTimer.index,
          );
          if (index != -1) {
            _timers[index] = disabledTimer;
          }

          debugPrint('   ❌ Disabled Timer ${conflictingTimer.index}');
        }

        await _saveTimers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Disabled ${conflictingTimers.length} conflicting timer(s)',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error canceling conflicting timers: $e');
      // Don't throw - continue with timer creation even if conflict resolution fails
    }
  }

  /// Sync device time with phone time
  Future<void> _syncDeviceTime() async {
    setState(() => _isSyncingTime = true);

    try {
      final now = DateTime.now();

      // Set device time using Time command (format: 0 = standard time, 1-3 = timezone offset)
      // We'll use timezone offset to match phone time
      final timezoneOffset = now.timeZoneOffset.inHours;

      // Tasmota Time command: 0=standard, 1=+1hr, 2=+2hr, etc., -1=-1hr, etc.
      // But we need to set actual time, so use Timezone command
      final timezoneCommand = 'Timezone $timezoneOffset';
      await widget.mqttManager.publishCommand(
        widget.device.id,
        timezoneCommand,
      );

      debugPrint('⏰ Synced device timezone to UTC$timezoneOffset');

      // Also set the actual time using Time command with timestamp
      // Format: Time YYYY-MM-DDTHH:MM:SS
      final timeStr = now.toIso8601String().split(
        '.',
      )[0]; // Remove milliseconds
      final timeCommand = 'Time $timeStr';
      await widget.mqttManager.publishCommand(widget.device.id, timeCommand);

      debugPrint('⏰ Synced device time to: $timeStr');

      // Small delay to let device process time sync
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('⚠️ Failed to sync device time: $e');
      // Don't throw - continue with timer setup even if time sync fails
    } finally {
      if (mounted) {
        setState(() => _isSyncingTime = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSpace = _getNextAvailableIndex(slotsNeeded: 1) != null;

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.device.name} Timers'),
            Text(
              '${_occupiedIndices.length}/16 slots used • ${_timers.length} timer${_timers.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: _occupiedIndices.length >= 16
                    ? Colors.orange
                    : context.hTextSecondary,
                fontWeight: _occupiedIndices.length >= 16
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: context.hBackground,
        actions: [
          if (_isSyncingTime)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (hasSpace && !_isSyncingTime)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addTimer,
              tooltip: AppStrings.get('device_timers_add_timer'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timers.isEmpty
          ? _buildEmptyState()
          : _buildTimersList(),
      floatingActionButton: hasSpace && !_isSyncingTime
          ? FloatingActionButton(
              onPressed: _addTimer,
              backgroundColor: HBotColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_off_outlined,
            size: 80,
            color: context.hTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Timers Set',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.hTextSecondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first timer',
            style: TextStyle(
              fontSize: 14,
              color: context.hTextSecondary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Up to 16 local timers supported',
            style: TextStyle(
              fontSize: 12,
              color: context.hTextSecondary.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _timers.length,
      itemBuilder: (context, index) {
        final timer = _timers[index];
        return _buildTimerCard(timer);
      },
    );
  }

  Widget _buildTimerCard(DeviceTimer timer) {
    final maxChannels = widget.device.channels ?? 1;
    final slotsUsed = timer.output == 0 ? maxChannels : 1;

    return Card(
      color: context.hCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HBotRadius.medium),
      ),
      child: InkWell(
        onTap: () => _editTimer(timer),
        borderRadius: BorderRadius.circular(HBotRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Timer Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: timer.enabled
                      ? HBotColors.primary.withOpacity(0.2)
                      : context.hTextSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  timer.mode == TimerMode.sunrise
                      ? Icons.wb_sunny
                      : timer.mode == TimerMode.sunset
                      ? Icons.nights_stay
                      : Icons.schedule,
                  color: timer.enabled
                      ? HBotColors.primary
                      : context.hTextSecondary,
                ),
              ),
              const SizedBox(width: 16),

              // Timer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          timer.mode == TimerMode.time
                              ? '${timer.time.hour.toString().padLeft(2, '0')}:${timer.time.minute.toString().padLeft(2, '0')}'
                              : timer.mode.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: timer.enabled
                                ? context.hTextPrimary
                                : context.hTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timer.action == TimerAction.on
                                ? Colors.green.withOpacity(0.2)
                                : timer.action == TimerAction.off
                                ? Colors.red.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timer.action.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: timer.action == TimerAction.on
                                  ? Colors.green
                                  : timer.action == TimerAction.off
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${timer.output == 0 ? "All Channels" : "Channel ${timer.output}"} • ${timer.getActiveDaysString()}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.hTextSecondary.withOpacity(0.8),
                      ),
                    ),
                    Row(
                      children: [
                        if (!timer.repeat)
                          Text(
                            'Once only • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.hTextSecondary.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          'Slots ${timer.index}-${timer.index + slotsUsed - 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.hTextSecondary.withOpacity(0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Toggle Switch
              Switch(
                value: timer.enabled,
                onChanged: (_) => _toggleTimer(timer),
                activeColor: HBotColors.primary,
              ),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: HBotColors.error,
                onPressed: () => _deleteTimer(timer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
