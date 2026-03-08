import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/device_timer.dart';
import '../theme/app_theme.dart';

class AddTimerScreen extends StatefulWidget {
  final Device device;
  final int timerIndex;
  final int maxChannels;
  final DeviceTimer? existingTimer;

  const AddTimerScreen({
    super.key,
    required this.device,
    required this.timerIndex,
    required this.maxChannels,
    this.existingTimer,
  });

  @override
  State<AddTimerScreen> createState() => _AddTimerScreenState();
}

class _AddTimerScreenState extends State<AddTimerScreen> {
  late TimerMode _mode;
  late TimeOfDay _time;
  late List<bool> _days;
  late bool _repeat;
  late int _output;
  late TimerAction _action;
  late int _window;

  @override
  void initState() {
    super.initState();

    if (widget.existingTimer != null) {
      _mode = widget.existingTimer!.mode;
      _time = widget.existingTimer!.time;
      _days = List.from(widget.existingTimer!.days);
      _repeat = widget.existingTimer!.repeat;
      _output = widget.existingTimer!.output;
      _action = widget.existingTimer!.action;
      _window = widget.existingTimer!.window;
    } else {
      _mode = TimerMode.time;
      _time = const TimeOfDay(hour: 7, minute: 0);
      _days = [true, true, true, true, true, true, true];
      _repeat = true;
      _output = 1;
      _action = TimerAction.on;
      _window = 0;
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  void _saveTimer() {
    final timer = DeviceTimer(
      index: widget.timerIndex,
      enabled: true,
      mode: _mode,
      time: _time,
      window: _window,
      days: _days,
      repeat: _repeat,
      output: _output,
      action: _action,
    );

    Navigator.pop(context, timer);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.backgroundColor
          : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text(widget.existingTimer == null ? 'Add Timer' : 'Edit Timer'),
        backgroundColor: isDark
            ? AppTheme.backgroundColor
            : AppTheme.lightBackgroundColor,
        actions: [
          TextButton(
            onPressed: _saveTimer,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          80,
        ), // Added bottom padding for navigation bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Mode Section
            _buildSectionTitle('Timer Mode'),
            _buildTimerModeSelector(),
            const SizedBox(height: 12), // Reduced from 24
            // Time Selection (only for Time mode)
            if (_mode == TimerMode.time) ...[
              _buildSectionTitle('Time'),
              _buildTimeSelector(),
              const SizedBox(height: 12), // Reduced from 24
            ],

            // Channel Selection
            _buildSectionTitle('Channel'),
            _buildChannelSelector(),
            const SizedBox(height: 12), // Reduced from 24
            // Action Selection
            _buildSectionTitle('Action'),
            _buildActionSelector(),
            const SizedBox(height: 12), // Reduced from 24
            // Days Selection
            _buildSectionTitle('Days'),
            _buildDaysSelector(),
            const SizedBox(height: 8), // Reduced from 16
            _buildQuickDaySelectors(),
            const SizedBox(height: 12), // Reduced from 24
            // Repeat Option
            _buildRepeatOption(),
            const SizedBox(height: 12), // Reduced from 24
            // Advanced Options
            _buildAdvancedOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.getTextPrimary(context),
        ),
      ),
    );
  }

  Widget _buildTimerModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: TimerMode.values.map((mode) {
          final isSelected = _mode == mode;
          return InkWell(
            onTap: () => setState(() => _mode = mode),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: mode != TimerMode.values.last
                      ? BorderSide(
                          color: AppTheme.getTextSecondary(
                            context,
                          ).withValues(alpha: 0.1),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    mode == TimerMode.sunrise
                        ? Icons.wb_sunny
                        : mode == TimerMode.sunset
                        ? Icons.nights_stay
                        : Icons.schedule,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getTextPrimary(context),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time,
              color: AppTheme.primaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Text(
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // All Channels option
          InkWell(
            onTap: () => setState(() => _output = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _output == 0
                    ? AppTheme.primaryColor
                    : AppTheme.getTextSecondary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.all_inclusive,
                    color: _output == 0
                        ? Colors.white
                        : AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All Channels',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _output == 0
                          ? Colors.white
                          : AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Individual channels
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.maxChannels, (index) {
              final channel = index + 1;
              final isSelected = _output == channel;
              // Calculate width to fit all channels equally
              final buttonWidth =
                  (MediaQuery.of(context).size.width -
                      64 -
                      (widget.maxChannels - 1) * 8) /
                  widget.maxChannels;
              return SizedBox(
                width: buttonWidth,
                child: InkWell(
                  onTap: () => setState(() => _output = channel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.getTextSecondary(
                              context,
                            ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'CH $channel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: TimerAction.values.map((action) {
          final isSelected = _action == action;
          return InkWell(
            onTap: () => setState(() => _action = action),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: action != TimerAction.values.last
                      ? BorderSide(
                          color: AppTheme.getTextSecondary(
                            context,
                          ).withValues(alpha: 0.1),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    action == TimerAction.on
                        ? Icons.power_settings_new
                        : action == TimerAction.off
                        ? Icons.power_off
                        : Icons.sync,
                    color: isSelected
                        ? (action == TimerAction.on
                              ? Colors.green
                              : action == TimerAction.off
                              ? Colors.red
                              : Colors.orange)
                        : AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.getTextPrimary(context),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDaysSelector() {
    final dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final fullDayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final isSelected = _days[index];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: index == 0 || index == 6 ? 0 : 4,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _days[index] = !_days[index];
                  });
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.getTextSecondary(
                            context,
                          ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNames[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fullDayNames[index],
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.getTextSecondary(
                                  context,
                                ).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuickDaySelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickDayButton('Every Day', Icons.calendar_today, () {
            setState(() {
              _days = [true, true, true, true, true, true, true];
            });
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickDayButton('Weekdays', Icons.work_outline, () {
            setState(() {
              _days = [false, true, true, true, true, true, false];
            });
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickDayButton('Weekends', Icons.weekend_outlined, () {
            setState(() {
              _days = [true, false, false, false, false, false, true];
            });
          }),
        ),
      ],
    );
  }

  Widget _buildQuickDayButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.getTextSecondary(context).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppTheme.getTextSecondary(context)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.getTextSecondary(
                  context,
                ).withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatOption() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.repeat, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repeat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Timer will repeat on selected days',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _repeat,
            onChanged: (value) => setState(() => _repeat = value),
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return ExpansionTile(
      title: Text(
        'Advanced Options',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.getTextPrimary(context),
        ),
      ),
      backgroundColor: AppTheme.getCardColor(context),
      collapsedBackgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Random Offset',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add ±$_window minutes random delay for security',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextSecondary(
                    context,
                  ).withValues(alpha: 0.7),
                ),
              ),
              Slider(
                value: _window.toDouble(),
                min: 0,
                max: 15,
                divisions: 15,
                label: '$_window min',
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _window = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
