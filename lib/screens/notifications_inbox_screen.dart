import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/broadcast_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';

/// In-app notification center connected to admin panel broadcasts.
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  final _service = BroadcastService();
  List<BroadcastNotification> _notifications = [];
  bool _isLoading = true;
  int _filterIndex = 0; // 0=All, 1=Alerts, 2=Devices

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await _service.fetchAll();
    if (mounted) {
      setState(() {
        _notifications = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead(_notifications);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HBotColors.sheetBackground,
        title: Text(
          AppStrings.get('clear_notifications_confirm'),
          style: const TextStyle(color: Colors.white, fontFamily: 'Readex Pro', fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppStrings.get('clear_notifications_confirm_body'),
          style: const TextStyle(color: HBotColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.get('clear_all_notifications'),
              style: const TextStyle(color: HBotColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _notifications.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('notifications_cleared'))),
        );
      }
    }
  }

  Future<void> _onTapNotification(BroadcastNotification n) async {
    if (!n.isRead) {
      await _service.markAsRead(n.id);
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final updated = BroadcastNotification(
              id: n.id,
              title: n.localizedTitle,
              body: n.localizedBody,
              target: n.target,
              data: n.data,
              createdAt: n.createdAt,
              sentBy: n.sentBy,
              readBy: [...n.readBy, userId],
            );
            _notifications[idx] = updated;
          }
        }
      });
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: HBotColors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationDetailSheet(notification: n),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return AppStrings.get('notifications_just_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}${AppStrings.get("notifications_minutes_ago")}';
    if (diff.inHours < 24) return '${diff.inHours}${AppStrings.get("notifications_hours_ago")}';
    if (diff.inDays == 1) return AppStrings.get('notifications_yesterday');
    if (diff.inDays < 7) return '${diff.inDays}${AppStrings.get("notifications_days_ago")}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HBotColors.glassBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        title: Text(
          AppStrings.get('notifications_title'),
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                AppStrings.get('notifications_mark_all_read'),
                style: const TextStyle(
                  fontFamily: 'Readex Pro',
                  color: HBotColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
              tooltip: AppStrings.get('clear_all_notifications'),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HBotColors.darkBgTop, HBotColors.darkBgBottom],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          color: HBotColors.primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: HBotColors.primary))
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + HBotSpacing.space3,
                        bottom: HBotSpacing.space6,
                      ),
                      children: _buildSectionedList(),
                    ),
        ),
      ),
    );
  }

  List<BroadcastNotification> get _filteredNotifications {
    if (_filterIndex == 0) return _notifications;
    if (_filterIndex == 1) {
      // Alerts: target 'alert' or no target
      return _notifications.where((n) =>
          n.target == 'alert' || n.target.isEmpty).toList();
    }
    // Devices
    return _notifications.where((n) => n.target == 'device').toList();
  }

  Widget _buildFilterTabs() {
    final labels = ['All', 'Alerts', 'Devices'];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space4,
        vertical: HBotSpacing.space2,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: HBotColors.glassBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HBotColors.glassBorder, width: 1),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(labels.length, (i) {
            final isActive = _filterIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filterIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0x1F0883FD) // rgba(8,131,253,0.12)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Readex Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? HBotColors.primary : HBotColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<Widget> _buildSectionedList() {
    final filtered = _filteredNotifications;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayItems = filtered.where((n) => n.createdAt.isAfter(todayStart)).toList();
    final earlierItems = filtered.where((n) => !n.createdAt.isAfter(todayStart)).toList();

    final widgets = <Widget>[
      _buildFilterTabs(),
    ];

    if (todayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader('Today'));
      for (final n in todayItems) {
        widgets.add(_buildNotificationCard(n));
      }
    }

    if (earlierItems.isNotEmpty) {
      widgets.add(_buildSectionHeader('Earlier'));
      for (final n in earlierItems) {
        widgets.add(_buildNotificationCard(n));
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HBotSpacing.space5, HBotSpacing.space5, HBotSpacing.space4, HBotSpacing.space2),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Readex Pro',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: HBotColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_none_outlined,
                      size: 48,
                      color: HBotColors.textMuted,
                    ),
                    const SizedBox(height: HBotSpacing.space5),
                    Text(
                      AppStrings.get('notifications_inbox_no_notifications_yet'),
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: HBotSpacing.space2),
                    Text(
                      AppStrings.get('notifications_inbox_all_caught_up'),
                      style: const TextStyle(
                        fontFamily: 'Readex Pro',
                        fontSize: 13,
                        color: HBotColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Determine icon + color for a notification based on target/type.
  _NotifStyle _notifStyle(BroadcastNotification n) {
    final target = n.target.toLowerCase();
    if (target == 'alert') {
      return const _NotifStyle(Icons.warning_amber_outlined, Color(0xFFF59E0B));
    }
    if (target == 'device') {
      return const _NotifStyle(Icons.devices_outlined, Color(0xFF34D399));
    }
    // default
    return const _NotifStyle(Icons.notifications_outlined, Color(0xFF0883FD));
  }

  Widget _buildNotificationCard(BroadcastNotification n) {
    final isUnread = !n.isRead;
    final style = _notifStyle(n);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space4,
        vertical: HBotSpacing.space1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTapNotification(n),
          borderRadius: BorderRadius.circular(16),
          splashColor: HBotColors.primary.withOpacity(0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: HBotColors.glassBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread ? HBotColors.glassBorderActive : HBotColors.glassBorder,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: isUnread
                    ? const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xFF0883FD), width: 3),
                        ),
                      )
                    : null,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colored icon — 40x40, 12px radius
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        style.icon,
                        color: style.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.localizedTitle,
                            style: TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            n.localizedBody,
                            style: const TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 12,
                              color: HBotColors.textMuted,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _relativeTime(n.createdAt),
                            style: const TextStyle(
                              fontFamily: 'Readex Pro',
                              fontSize: 10,
                              color: HBotColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Unread dot
                    if (isUnread) ...[
                      const SizedBox(width: HBotSpacing.space2),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: HBotColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style for a notification icon.
class _NotifStyle {
  final IconData icon;
  final Color color;
  const _NotifStyle(this.icon, this.color);
}

/// Bottom sheet showing the full notification detail.
class _NotificationDetailSheet extends StatelessWidget {
  final BroadcastNotification notification;

  const _NotificationDetailSheet({required this.notification});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(HBotSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HBotColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space5),

            // Title
            Text(
              notification.localizedTitle,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),

            // Timestamp
            Text(
              _formatDate(notification.createdAt),
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 12,
                color: HBotColors.textMuted,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),

            Container(height: 0.5, color: HBotColors.glassBorder),
            const SizedBox(height: HBotSpacing.space4),

            // Body
            Text(
              notification.localizedBody,
              style: const TextStyle(
                fontFamily: 'Readex Pro',
                fontSize: 15,
                color: HBotColors.textMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: HBotSpacing.space6),

            // Close button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: HBotColors.primary),
                  foregroundColor: HBotColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HBotRadius.medium),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Readex Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space3),
          ],
        ),
      ),
    );
  }
}
