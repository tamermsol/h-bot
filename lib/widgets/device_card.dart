import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DeviceCard extends StatelessWidget {
  final String title;
  final IconData icon;

  /// Optional explicit online flag. If null the caller's previous behavior
  /// should provide a computed boolean; keep the existing `isOn` for backward
  /// compatibility.
  final bool? isOnline;
  final bool isOn;
  final String? value;
  final Function(bool) onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DeviceCard({
    super.key,
    required this.title,
    required this.icon,
    this.isOnline,
    required this.isOn,
    required this.onToggle,
    this.value,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isOn
                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOn
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.textHint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    icon,
                    color: isOn ? AppTheme.primaryColor : AppTheme.textHint,
                    size: 24,
                  ),
                ),
                Switch(
                  value: isOn,
                  onChanged: onToggle,
                  activeThumbColor: AppTheme.primaryColor,
                  inactiveThumbColor: AppTheme.textHint,
                  inactiveTrackColor: AppTheme.textHint.withValues(alpha: 0.3),
                ),
              ],
            ),

            const Spacer(),

            // Device title
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isOn ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Value display (if provided)
            if (value != null) ...[
              const SizedBox(height: 4),
              Text(
                value!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOn ? AppTheme.primaryColor : AppTheme.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // Status indicator
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: (isOnline ?? isOn)
                        ? AppTheme.accentColor
                        : AppTheme.textHint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (isOnline ?? isOn) ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: (isOnline ?? isOn)
                        ? AppTheme.accentColor
                        : AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
