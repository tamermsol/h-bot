import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'channel_card.dart';
import '../l10n/app_strings.dart';

/// Grid of channel controls with optional bulk actions
/// Always 2-column layout. Scrollable for 8+ channels.
class ChannelGrid extends StatelessWidget {
  final int channelCount;
  final Map<int, bool> channelStates;
  final Map<int, String> channelNames;
  final Map<int, String> channelTypes;
  final bool canControl;
  final void Function(int channel, bool value) onToggleChannel;
  final void Function(int channel)? onChannelLongPress;
  final VoidCallback? onAllOn;
  final VoidCallback? onAllOff;
  final bool showBulkControls;
  final bool compact; // For dashboard cards — smaller sizing

  const ChannelGrid({
    super.key,
    required this.channelCount,
    required this.channelStates,
    this.channelNames = const {},
    this.channelTypes = const {},
    this.canControl = true,
    required this.onToggleChannel,
    this.onChannelLongPress,
    this.onAllOn,
    this.onAllOff,
    this.showBulkControls = true,
    this.compact = false,
  });

  String _getChannelName(int channel) {
    return channelNames[channel] ?? 'Channel $channel';
  }

  String _getChannelType(int channel) {
    return channelTypes[channel] ?? 'light';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Channel cards in 2-column grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: compact ? HBotSpacing.space2 : HBotSpacing.space3,
            mainAxisSpacing: compact ? HBotSpacing.space2 : HBotSpacing.space3,
            childAspectRatio: compact ? 1.8 : 1.5,
          ),
          itemCount: channelCount,
          itemBuilder: (context, index) {
            final channel = index + 1;
            return ChannelCard(
              channelNumber: channel,
              channelName: _getChannelName(channel),
              channelType: _getChannelType(channel),
              isOn: channelStates[channel] ?? false,
              canControl: canControl,
              onToggle: (value) => onToggleChannel(channel, value),
              onLongPress: onChannelLongPress != null
                  ? () => onChannelLongPress!(channel)
                  : null,
            );
          },
        ),

        // Bulk controls for multi-channel devices
        if (showBulkControls && channelCount > 1) ...[
          SizedBox(height: compact ? HBotSpacing.space2 : HBotSpacing.space4),
          Row(
            children: [
              Expanded(
                child: _BulkButton(
                  label: AppStrings.get('channel_grid_all_on'),
                  icon: Icons.flash_on,
                  onTap: canControl ? onAllOn : null,
                  isPrimary: true,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? HBotSpacing.space2 : HBotSpacing.space3),
              Expanded(
                child: _BulkButton(
                  label: AppStrings.get('channel_grid_all_off'),
                  icon: Icons.flash_off,
                  onTap: canControl ? onAllOff : null,
                  isPrimary: false,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BulkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool compact;

  const _BulkButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isPrimary = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: HBotRadius.mediumRadius,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? HBotSpacing.space2 : HBotSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: isPrimary
                ? HBotColors.primary.withOpacity(0.1)
                : context.hSurface.withOpacity(0.5),
            borderRadius: HBotRadius.mediumRadius,
            border: Border.all(
              color: isPrimary
                  ? HBotColors.primary.withOpacity(0.3)
                  : context.hBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: compact ? 16 : 18,
                color: isPrimary
                    ? HBotColors.primary
                    : context.hTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: isPrimary
                      ? HBotColors.primary
                      : context.hTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
