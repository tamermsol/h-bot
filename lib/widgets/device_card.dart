import 'package:flutter/material.dart';
import '../models/device.dart';
import '../utils/phosphor_icons.dart';

/// v0 Toggle switch: w-11 (44px) h-6 (24px), thumb w-5 (20px) h-5 (20px)
/// ON: #0883FD, OFF: #D1D5DB
class V0Toggle extends StatelessWidget {
  final bool value;
  final Function(bool)? onChanged;

  const V0Toggle({
    super.key,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF0883FD)
              : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
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

// ─── Type config matching v0 TYPE_CFG ───
final _typeCfg = <DeviceType, _TypeCfgEntry>{
  DeviceType.relay: _TypeCfgEntry(
    icon: HBotIcons.power,
    color: const Color(0xFF3B82F6),
    bg: const Color(0xFFEFF6FF),
  ),
  DeviceType.dimmer: _TypeCfgEntry(
    icon: HBotIcons.lightbulb,
    color: const Color(0xFFF59E0B),
    bg: const Color(0xFFFFFBEB),
  ),
  DeviceType.sensor: _TypeCfgEntry(
    icon: HBotIcons.thermometer,
    color: const Color(0xFF10B981),
    bg: const Color(0xFFECFDF5),
  ),
  DeviceType.shutter: _TypeCfgEntry(
    icon: HBotIcons.shutter,
    color: const Color(0xFF8B5CF6),
    bg: const Color(0xFFF5F3FF),
  ),
};

class _TypeCfgEntry {
  final IconData icon;
  final Color color;
  final Color bg;
  const _TypeCfgEntry({
    required this.icon,
    required this.color,
    required this.bg,
  });
}

_TypeCfgEntry _getCfg(DeviceType? type) {
  return _typeCfg[type] ?? _typeCfg[DeviceType.relay]!;
}

/// Device Card — GRID layout per v0 DeviceCardGrid
/// bg #F5F7FA, rounded-2xl (16px), p-3.5 (14px), border 1px #E5E7EB
class DeviceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool? isOnline;
  final bool isOn;
  final String? value;
  final String? roomName;
  final Function(bool) onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? deviceColor;
  final Color? deviceBgColor;
  final DeviceType? deviceType;
  final bool isLoading;
  // Sensor-specific
  final double? temperature;
  final double? humidity;
  // Shutter-specific
  final int? position;
  // Dimmer-specific
  final int? brightness;

  const DeviceCard({
    super.key,
    required this.title,
    required this.icon,
    this.isOnline,
    required this.isOn,
    required this.onToggle,
    this.value,
    this.roomName,
    this.onTap,
    this.onLongPress,
    this.deviceColor,
    this.deviceBgColor,
    this.deviceType,
    this.isLoading = false,
    this.temperature,
    this.humidity,
    this.position,
    this.brightness,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cfg = _getCfg(widget.deviceType);
    final online = widget.isOnline ?? widget.isOn;
    final bool unreachable = widget.isOnline == false && !widget.isOn;
    final isOn = widget.isOn;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Opacity(
            opacity: unreachable ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: icon circle LEFT, online dot RIGHT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 40x40 rounded-full icon circle
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.deviceBgColor ?? cfg.bg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.deviceColor ?? cfg.color,
                          size: 18,
                        ),
                      ),
                      // Online dot: w-2.5 h-2.5 (10px)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12), // mb-3

                  // Device name: 13px bold #1F2937, truncate
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Room: 11px #9CA3AF, mt-0.5, mb-2.5
                  if (widget.roomName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.roomName!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 10), // mb-2.5

                  // Bottom: type-specific content
                  if (widget.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0883FD),
                        ),
                      ),
                    )
                  else if (widget.deviceType == DeviceType.sensor)
                    _buildSensorBottom()
                  else if (widget.deviceType == DeviceType.shutter)
                    _buildShutterBottom()
                  else if (widget.deviceType == DeviceType.dimmer)
                    _buildDimmerBottom(cfg, isOn, unreachable)
                  else
                    _buildRelayBottom(cfg, isOn, unreachable),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sensor: Thermometer icon + temp + "/ humidity%"
  Widget _buildSensorBottom() {
    return Row(
      children: [
        Icon(HBotIcons.thermometer, size: 12, color: const Color(0xFF10B981)),
        const SizedBox(width: 6),
        Text(
          '${widget.temperature ?? '--'}°C',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '/ ${widget.humidity?.round() ?? '--'}%',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  /// Shutter: "Position" label + percentage, 6px progress bar (#8B5CF6)
  Widget _buildShutterBottom() {
    final pos = widget.position ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Position',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
            Text(
              '$pos%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // h-1.5 (6px) progress bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pos / 100.0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dimmer: brightness% or "OFF" + toggle switch
  Widget _buildDimmerBottom(_TypeCfgEntry cfg, bool isOn, bool unreachable) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isOn ? '${widget.brightness ?? 0}%' : 'OFF',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOn ? cfg.color : const Color(0xFF9CA3AF),
          ),
        ),
        if ((widget.isOnline ?? true))
          V0Toggle(
            value: widget.isOn,
            onChanged: unreachable ? null : widget.onToggle,
          ),
      ],
    );
  }

  /// Relay: "ON"/"OFF" + toggle switch
  Widget _buildRelayBottom(_TypeCfgEntry cfg, bool isOn, bool unreachable) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.value ?? (isOn ? 'ON' : 'OFF'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOn ? cfg.color : const Color(0xFF9CA3AF),
          ),
        ),
        if ((widget.isOnline ?? true))
          V0Toggle(
            value: widget.isOn,
            onChanged: unreachable ? null : widget.onToggle,
          ),
      ],
    );
  }
}

/// Device Card — LIST layout per v0 DeviceCardList
/// bg #F5F7FA, rounded-2xl, px-4 py-3, border #E5E7EB, horizontal layout
class DeviceCardList extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool? isOnline;
  final bool isOn;
  final String? value;
  final String? roomName;
  final Function(bool) onToggle;
  final VoidCallback? onTap;
  final Color? deviceColor;
  final Color? deviceBgColor;
  final DeviceType? deviceType;
  final bool isLoading;
  // Sensor-specific
  final double? temperature;
  // Shutter-specific
  final int? position;

  const DeviceCardList({
    super.key,
    required this.title,
    required this.icon,
    this.isOnline,
    required this.isOn,
    required this.onToggle,
    this.value,
    this.roomName,
    this.onTap,
    this.deviceColor,
    this.deviceBgColor,
    this.deviceType,
    this.isLoading = false,
    this.temperature,
    this.position,
  });

  @override
  State<DeviceCardList> createState() => _DeviceCardListState();
}

class _DeviceCardListState extends State<DeviceCardList> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cfg = _getCfg(widget.deviceType);
    final online = widget.isOnline ?? widget.isOn;
    final bool unreachable = widget.isOnline == false && !widget.isOn;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Opacity(
            opacity: unreachable ? 0.5 : 1.0,
            child: Row(
              children: [
                // 40x40 icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.deviceBgColor ?? cfg.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.deviceColor ?? cfg.color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Name + room column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Online dot: w-2 h-2 (8px)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: online
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      if (widget.roomName != null)
                        Text(
                          widget.roomName!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Right side: sensor=temp, shutter=position%, others=toggle
                if (widget.deviceType == DeviceType.sensor)
                  Text(
                    '${widget.temperature ?? '--'}°C',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  )
                else if (widget.deviceType == DeviceType.shutter)
                  Text(
                    '${widget.position ?? 0}%',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                else if ((widget.isOnline ?? true))
                  V0Toggle(
                    value: widget.isOn,
                    onChanged: unreachable ? null : widget.onToggle,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
