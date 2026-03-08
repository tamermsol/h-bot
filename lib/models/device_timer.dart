import 'package:flutter/material.dart';

/// Model for HBOT device timer
class DeviceTimer {
  final int index; // Timer index (1-16)
  bool enabled;
  TimerMode mode; // Time, Sunrise, Sunset
  TimeOfDay time;
  int window; // Random offset in minutes (0-15)
  List<bool> days; // [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
  bool repeat;
  int output; // Channel/Relay number (1-4)
  TimerAction action; // OFF, ON, TOGGLE

  DeviceTimer({
    required this.index,
    this.enabled = true,
    this.mode = TimerMode.time,
    required this.time,
    this.window = 0,
    List<bool>? days,
    this.repeat = true,
    this.output = 1,
    this.action = TimerAction.on,
  }) : days = days ?? [true, true, true, true, true, true, true];

  /// Convert to HBOT Timer command format (Tasmota-compatible)
  /// Returns a list of commands - one for each channel when output=0 (all channels)
  List<String> toTasmotaCommands(int maxChannels) {
    final daysStr = days.map((d) => d ? '1' : '0').join();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    // If output is 0 (all channels), create separate timer commands for each channel
    if (output == 0) {
      final commands = <String>[];
      for (int ch = 1; ch <= maxChannels; ch++) {
        // Use different timer indices for each channel to avoid conflicts
        final timerIdx = index + (ch - 1);
        commands.add(
          'Timer$timerIdx {"Enable":${enabled ? 1 : 0},"Mode":${mode.value},"Time":"$timeStr","Window":$window,"Days":"$daysStr","Repeat":${repeat ? 1 : 0},"Output":$ch,"Action":${action.value}}',
        );
      }
      return commands;
    }

    // Single channel timer
    return [
      'Timer$index {"Enable":${enabled ? 1 : 0},"Mode":${mode.value},"Time":"$timeStr","Window":$window,"Days":"$daysStr","Repeat":${repeat ? 1 : 0},"Output":$output,"Action":${action.value}}',
    ];
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use toTasmotaCommands() instead')
  String toTasmotaCommand() {
    final daysStr = days.map((d) => d ? '1' : '0').join();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return 'Timer$index {"Enable":${enabled ? 1 : 0},"Mode":${mode.value},"Time":"$timeStr","Window":$window,"Days":"$daysStr","Repeat":${repeat ? 1 : 0},"Output":$output,"Action":${action.value}}';
  }

  /// Get human-readable time string
  String getTimeString() {
    if (mode == TimerMode.sunrise) {
      return 'Sunrise';
    } else if (mode == TimerMode.sunset) {
      return 'Sunset';
    }
    return time.format(
      TimeOfDay(hour: 0, minute: 0).toString().split('(')[0] as BuildContext,
    );
  }

  /// Get active days as string
  String getActiveDaysString() {
    if (days.every((d) => d)) return 'Every day';
    if (days.sublist(1, 6).every((d) => d) && !days[0] && !days[6]) {
      return 'Weekdays';
    }
    if (days[0] && days[6] && days.sublist(1, 6).every((d) => !d)) {
      return 'Weekends';
    }

    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final activeDays = <String>[];
    for (int i = 0; i < days.length; i++) {
      if (days[i]) activeDays.add(dayNames[i]);
    }
    return activeDays.join(', ');
  }

  /// Copy with modifications
  DeviceTimer copyWith({
    int? index,
    bool? enabled,
    TimerMode? mode,
    TimeOfDay? time,
    int? window,
    List<bool>? days,
    bool? repeat,
    int? output,
    TimerAction? action,
  }) {
    return DeviceTimer(
      index: index ?? this.index,
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      time: time ?? this.time,
      window: window ?? this.window,
      days: days ?? List.from(this.days),
      repeat: repeat ?? this.repeat,
      output: output ?? this.output,
      action: action ?? this.action,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'enabled': enabled,
      'mode': mode.value,
      'hour': time.hour,
      'minute': time.minute,
      'window': window,
      'days': days,
      'repeat': repeat,
      'output': output,
      'action': action.value,
    };
  }

  /// Create from JSON
  factory DeviceTimer.fromJson(Map<String, dynamic> json) {
    return DeviceTimer(
      index: json['index'] as int,
      enabled: json['enabled'] as bool? ?? true,
      mode: TimerMode.values.firstWhere((m) => m.value == json['mode']),
      time: TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int),
      window: json['window'] as int? ?? 0,
      days: (json['days'] as List).cast<bool>(),
      repeat: json['repeat'] as bool? ?? true,
      output: json['output'] as int,
      action: TimerAction.values.firstWhere((a) => a.value == json['action']),
    );
  }
}

/// Timer mode enum
enum TimerMode {
  time(0, 'Time'),
  sunrise(1, 'Sunrise'),
  sunset(2, 'Sunset');

  final int value;
  final String label;
  const TimerMode(this.value, this.label);
}

/// Timer action enum
enum TimerAction {
  off(0, 'Turn OFF'),
  on(1, 'Turn ON'),
  toggle(2, 'Toggle');

  final int value;
  final String label;
  const TimerAction(this.value, this.label);
}
