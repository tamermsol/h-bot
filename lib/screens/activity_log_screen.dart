import 'package:flutter/material.dart';
import '../services/activity_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_shell.dart';

class ActivityLogScreen extends StatefulWidget {
  final String? deviceId;
  final String? deviceName;

  const ActivityLogScreen({super.key, this.deviceId, this.deviceName});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final ActivityLogService _logService = ActivityLogService();
  List<ActivityEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      if (widget.deviceId != null) {
        _events = await _logService.getDeviceActivity(widget.deviceId!, limit: 100);
      } else {
        _events = await _logService.getRecentActivity(limit: 100);
      }
    } catch (e) {
      debugPrint('Failed to load activity: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HBotColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: HBotColors.surfaceLight,
        foregroundColor: HBotColors.textPrimaryLight,
        elevation: 0,
        title: Text(widget.deviceName != null
            ? '${widget.deviceName} History'
            : 'Activity Log'),
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: ResponsiveShell(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: HBotColors.primary))
            : _events.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadEvents,
                    child: _buildEventList(),
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: HBotColors.textTertiaryLight),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HBotColors.textPrimaryLight,
              fontFamily: 'DM Sans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Device events will appear here as they happen',
            style: TextStyle(
              fontSize: 14,
              color: HBotColors.textSecondaryLight,
              fontFamily: 'DM Sans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    // Group events by date
    final Map<String, List<ActivityEvent>> grouped = {};
    for (final event in _events) {
      final dateKey = _formatDate(event.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final events = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: HBotColors.textTertiaryLight,
                  fontFamily: 'DM Sans',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...events.map(_buildEventTile),
          ],
        );
      },
    );
  }

  Widget _buildEventTile(ActivityEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HBotColors.cardLight,
        borderRadius: BorderRadius.circular(HBotRadius.medium),
        border: Border.all(color: HBotColors.borderLight, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.deviceName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: HBotColors.textPrimaryLight,
                          fontFamily: 'DM Sans',
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(event.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: HBotColors.textTertiaryLight,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: HBotColors.textSecondaryLight,
                    fontFamily: 'DM Sans',
                  ),
                ),
                if (event.details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.details!,
                    style: TextStyle(
                      fontSize: 11,
                      color: HBotColors.textTertiaryLight,
                      fontFamily: 'DM Sans',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(dt.year, dt.month, dt.day);

    if (eventDate == today) return 'Today';
    if (eventDate == yesterday) return 'Yesterday';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HBotColors.cardLight,
        title: const Text('Clear Activity Log?'),
        content: const Text('This will permanently delete all logged events.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.deviceId != null) {
                await _logService.clearDevice(widget.deviceId!);
              } else {
                await _logService.clearAll();
              }
              _loadEvents();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
