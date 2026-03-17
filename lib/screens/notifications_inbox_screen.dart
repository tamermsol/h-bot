import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/broadcast_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _onTapNotification(BroadcastNotification n) async {
    if (!n.isRead) {
      await _service.markAsRead(n.id);
      // Update local state optimistically
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId != null) {
            final updated = BroadcastNotification(
              id: n.id,
              title: n.title,
              body: n.body,
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

    // Show full notification in a bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: context.hCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificationDetailSheet(notification: n),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Format as date
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: context.hBackground,
      appBar: AppBar(
        backgroundColor: context.hCard,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  color: HBotColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: HBotColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: HBotSpacing.space3,
                    ),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_notifications[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // Wrap in ListView so pull-to-refresh works on empty state
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: HBotColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  size: 32,
                  color: HBotColors.primary,
                ),
              ),
              const SizedBox(height: HBotSpacing.space5),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.hTextPrimary,
                ),
              ),
              const SizedBox(height: HBotSpacing.space2),
              Text(
                "You're all caught up!",
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 14,
                  color: context.hTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(BroadcastNotification n) {
    final isUnread = !n.isRead;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HBotSpacing.space4,
        vertical: HBotSpacing.space1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTapNotification(n),
          borderRadius: BorderRadius.circular(HBotRadius.medium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isUnread
                  ? HBotColors.primarySurface
                  : context.hCard,
              borderRadius: BorderRadius.circular(HBotRadius.medium),
              border: Border(
                left: BorderSide(
                  color: isUnread ? HBotColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(HBotSpacing.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bell icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isUnread
                          ? HBotColors.primary.withOpacity(0.15)
                          : HBotColors.neutral100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnread
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_outlined,
                      color: isUnread
                          ? HBotColors.primary
                          : HBotColors.iconDefault,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: HBotSpacing.space3),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontFamily: 'DM Sans',
                                  fontSize: 15,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: context.hTextPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: HBotSpacing.space2),
                            Text(
                              _relativeTime(n.createdAt),
                              style: TextStyle(
                                fontFamily: 'DM Sans',
                                fontSize: 12,
                                color: context.hTextTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.body,
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontSize: 13,
                            color: context.hTextSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
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
                  color: context.hTextTertiary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: HBotSpacing.space5),

            // Title
            Text(
              notification.title,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.hTextPrimary,
              ),
            ),
            const SizedBox(height: HBotSpacing.space2),

            // Timestamp
            Text(
              _formatDate(notification.createdAt),
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 12,
                color: context.hTextTertiary,
              ),
            ),
            const SizedBox(height: HBotSpacing.space4),

            const Divider(),
            const SizedBox(height: HBotSpacing.space4),

            // Body
            Text(
              notification.body,
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontSize: 15,
                color: context.hTextSecondary,
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
                    fontFamily: 'DM Sans',
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
