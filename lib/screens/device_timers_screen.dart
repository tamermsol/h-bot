import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/phosphor_icons.dart';
import 'dart:convert';
import '../models/device.dart';
import '../models/device_timer.dart';
import '../services/mqtt_device_manager.dart';
import 'add_timer_screen.dart';

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
          'Loaded ${_timers.length} timers for ${widget.device.deviceName}',
        );
      }

      _calculateOccupiedIndices();
    } catch (e) {
      debugPrint('Error loading timers: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _calculateOccupiedIndices() {
    _occupiedIndices.clear();
    final maxChannels = widget.device.channels ?? 1;

    for (final timer in _timers) {
      if (timer.output == 0) {
        for (int ch = 0; ch < maxChannels; ch++) {
          _occupiedIndices.add(timer.index + ch);
        }
      } else {
        _occupiedIndices.add(timer.index);
      }
    }

    debugPrint(
      'Occupied timer indices: $_occupiedIndices (${_occupiedIndices.length}/16)',
    );
  }

  int? _getNextAvailableIndex({required int slotsNeeded}) {
    for (int startIdx = 1; startIdx <= 16; startIdx++) {
      bool canFit = true;
      for (int offset = 0; offset < slotsNeeded; offset++) {
        final checkIdx = startIdx + offset;
        if (checkIdx > 16 || _occupiedIndices.contains(checkIdx)) {
          canFit = false;
          break;
        }
      }
      if (canFit) return startIdx;
    }
    return null;
  }

  Future<void> _saveTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'device_timers_${widget.device.id}';
      final timersJson = json.encode(_timers.map((t) => t.toJson()).toList());
      await prefs.setString(key, timersJson);
    } catch (e) {
      debugPrint('Error saving timers: $e');
    }
  }

  Future<void> _addTimer() async {
    final maxChannels = widget.device.channels ?? 1;
    _calculateOccupiedIndices();

    final hasAnySpace = _getNextAvailableIndex(slotsNeeded: 1) != null;

    if (!hasAnySpace) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(HBotIcons.error, color: const Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Timer Limit Reached',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HBOT devices support a maximum of 16 local timer slots.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                  const SizedBox(height: 12),
                  Text('Currently occupied: ${_occupiedIndices.length}/16 slots',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('(Note: "All Channels" timers use $maxChannels slots)',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 12),
                  const Text('To add more timers, please delete an existing timer.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Color(0xFF0883FD))),
              ),
            ],
          ),
        );
      }
      return;
    }

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
      final slotsNeeded = result.output == 0 ? maxChannels : 1;
      final finalIndex = _getNextAvailableIndex(slotsNeeded: slotsNeeded);

      if (finalIndex == null) {
        if (mounted) {
          final availableSlots = 16 - _occupiedIndices.length;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Not Enough Contiguous Slots',
                style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600)),
              content: Text(
                'This timer needs $slotsNeeded contiguous slot${slotsNeeded > 1 ? 's' : ''}, but only $availableSlots available.',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF0883FD))),
                ),
              ],
            ),
          );
        }
        return;
      }

      final finalTimer = result.copyWith(index: finalIndex);
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
        if (index != -1) _timers[index] = result;
        _calculateOccupiedIndices();
      });
      await _saveTimers();
      await _sendTimerToDevice(result);
    }
  }

  Future<void> _toggleTimer(DeviceTimer timer) async {
    final updatedTimer = timer.copyWith(enabled: !timer.enabled);
    setState(() {
      final index = _timers.indexWhere((t) => t.index == timer.index);
      if (index != -1) _timers[index] = updatedTimer;
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Timer',
          style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete this timer?\n\n'
          'This will free $slotsFreed timer slot${slotsFreed > 1 ? 's' : ''}.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final disabledTimer = timer.copyWith(enabled: false);
      await _sendTimerToDevice(disabledTimer);

      setState(() {
        _timers.removeWhere((t) => t.index == timer.index);
        _calculateOccupiedIndices();
      });
      await _saveTimers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Timer deleted ($slotsFreed slot${slotsFreed > 1 ? 's' : ''} freed, ${_occupiedIndices.length}/16 used)',
            ),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendTimerToDevice(DeviceTimer timer) async {
    try {
      await _syncDeviceTime();

      final maxChannels = widget.device.channels ?? 1;
      final commands = timer.toTasmotaCommands(maxChannels);

      for (final command in commands) {
        await widget.mqttManager.publishCommand(widget.device.id, command);
        if (commands.length > 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              timer.output == 0
                  ? 'Timer ${timer.index} set for all channels'
                  : 'Timer ${timer.index} ${timer.enabled ? "enabled" : "disabled"}',
            ),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending timer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update timer: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cancelConflictingTimers(DeviceTimer newTimer) async {
    try {
      final conflictingTimers = _timers.where((existingTimer) {
        if (existingTimer.index == newTimer.index) return false;
        final channelsOverlap =
            (newTimer.output == 0 || existingTimer.output == 0) ||
            (newTimer.output == existingTimer.output);
        if (!channelsOverlap) return false;
        if (newTimer.mode == TimerMode.time &&
            existingTimer.mode == TimerMode.time) {
          final newMinutes = newTimer.time.hour * 60 + newTimer.time.minute;
          final existingMinutes =
              existingTimer.time.hour * 60 + existingTimer.time.minute;
          final timeDiff = (newMinutes - existingMinutes).abs();
          if (timeDiff > 1) return false;
        } else if (newTimer.mode != existingTimer.mode) {
          return false;
        }
        for (int i = 0; i < 7; i++) {
          if (newTimer.days[i] && existingTimer.days[i]) return true;
        }
        return false;
      }).toList();

      if (conflictingTimers.isNotEmpty) {
        for (final conflictingTimer in conflictingTimers) {
          final disabledTimer = conflictingTimer.copyWith(enabled: false);
          await _sendTimerToDevice(disabledTimer);
          final index = _timers.indexWhere((t) => t.index == conflictingTimer.index);
          if (index != -1) _timers[index] = disabledTimer;
        }
        await _saveTimers();
      }
    } catch (e) {
      debugPrint('Error canceling conflicting timers: $e');
    }
  }

  Future<void> _syncDeviceTime() async {
    setState(() => _isSyncingTime = true);
    try {
      final now = DateTime.now();
      final timezoneOffset = now.timeZoneOffset.inHours;
      final timezoneCommand = 'Timezone $timezoneOffset';
      await widget.mqttManager.publishCommand(widget.device.id, timezoneCommand);
      final timeStr = now.toIso8601String().split('.')[0];
      final timeCommand = 'Time $timeStr';
      await widget.mqttManager.publishCommand(widget.device.id, timeCommand);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Failed to sync device time: $e');
    } finally {
      if (mounted) setState(() => _isSyncingTime = false);
    }
  }

  // ─── Day labels matching v0 ───
  static const _dayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  // Map our days array (Sun=0...Sat=6) to v0 display order (Mo=0...Su=6)
  // Our model: [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
  // v0 display: [Mo, Tu, We, Th, Fr, Sa, Su]
  static const _dayIndexMap = [1, 2, 3, 4, 5, 6, 0]; // v0 index -> our model index

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── AppBar per v0: back button, "Device Timers" centered, Plus button ──
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Back button: 36x36 rounded-xl
                  _V0AppBarButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(HBotIcons.back, size: 20, color: Color(0xFF1F2937)),
                  ),
                  const Expanded(
                    child: Text(
                      'Device Timers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  // Plus button: 36x36 rounded-xl, #EFF6FF bg, #0883FD icon
                  GestureDetector(
                    onTap: _addTimer,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(HBotIcons.add, size: 18, color: Color(0xFF0883FD)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0883FD)))
                : _timers.isEmpty
                    ? _buildEmptyState()
                    : _buildTimersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer icon in 64x64 #F5F7FA circle
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                shape: BoxShape.circle,
              ),
              child: Icon(HBotIcons.timer, size: 28, color: Color(0xFFD1D5DB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No timers set',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to create a timer for this device',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimersList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _timers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildTimerCard(_timers[index]),
    );
  }

  Widget _buildTimerCard(DeviceTimer timer) {
    // Determine icon/colors based on mode
    final IconData iconData;
    final Color iconColor;
    final Color iconBg;

    if (timer.mode == TimerMode.sunrise) {
      iconData = HBotIcons.lightbulb;
      iconColor = const Color(0xFFF59E0B);
      iconBg = const Color(0xFFFFFBEB);
    } else if (timer.mode == TimerMode.sunset) {
      iconData = HBotIcons.scenes;
      iconColor = const Color(0xFF8B5CF6);
      iconBg = const Color(0xFFF5F3FF);
    } else {
      iconData = HBotIcons.accessTime;
      iconColor = const Color(0xFF3B82F6);
      iconBg = const Color(0xFFEFF6FF);
    }

    // Format time for display
    final hour12 = timer.time.hour == 0
        ? 12
        : timer.time.hour > 12
            ? timer.time.hour - 12
            : timer.time.hour;
    final timeStr = '${hour12.toString().padLeft(2, '0')}:${timer.time.minute.toString().padLeft(2, '0')}';
    final period = timer.time.hour >= 12 ? 'PM' : 'AM';

    // Channel text
    final channelText = timer.output == 0
        ? 'All Channels'
        : 'Channel ${timer.output}';

    return GestureDetector(
      onTap: () => _editTimer(timer),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: timer.enabled ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle: 40x40
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),

              // Content column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time + period + ON/OFF badge
                    Row(
                      children: [
                        // Time: 22px bold
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // AM/PM: 13px semibold #6B7280
                        Text(
                          period,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const Spacer(),
                        // ON/OFF badge: rounded-full
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: timer.action == TimerAction.on
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            timer.action == TimerAction.on ? 'ON' : 'OFF',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: timer.action == TimerAction.on
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Channel text: 12px #9CA3AF
                    Text(
                      channelText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Day circles: 24x24 rounded-full
                    Row(
                      children: List.generate(7, (i) {
                        final modelIndex = _dayIndexMap[i];
                        final isActive = timer.days[modelIndex];
                        return Padding(
                          padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF0883FD)
                                  : const Color(0xFFE5E7EB),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _dayLabels[i][0],
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right side: toggle + trash
              Column(
                children: [
                  // Toggle switch: 40x22
                  _V0TimerToggle(
                    value: timer.enabled,
                    onChanged: () => _toggleTimer(timer),
                  ),
                  const SizedBox(height: 12),
                  // Trash icon
                  GestureDetector(
                    onTap: () => _deleteTimer(timer),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(HBotIcons.delete, size: 15, color: const Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AppBar button: 36x36 rounded-xl, active:bg-[#F5F7FA]
class _V0AppBarButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _V0AppBarButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Timer toggle: 40x22, matching v0 timer card toggle
class _V0TimerToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onChanged;

  const _V0TimerToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0883FD) : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
