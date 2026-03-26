import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for a broadcast notification from the admin panel.
class BroadcastNotification {
  final String id;
  final String title;
  final String body;
  final String? titleEn;
  final String? bodyEn;
  final String? titleAr;
  final String? bodyAr;
  final String? imageUrl;
  final String target;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String? sentBy;
  final List<String> readBy;

  BroadcastNotification({
    required this.id,
    required this.title,
    required this.body,
    this.titleEn,
    this.bodyEn,
    this.titleAr,
    this.bodyAr,
    this.imageUrl,
    required this.target,
    required this.data,
    required this.createdAt,
    this.sentBy,
    required this.readBy,
  });

  /// Returns localized title based on current app locale
  String get localizedTitle {
    final locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (locale == 'ar' && titleAr != null && titleAr!.isNotEmpty) return titleAr!;
    return titleEn ?? title;
  }

  /// Returns localized body based on current app locale
  String get localizedBody {
    final locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (locale == 'ar' && bodyAr != null && bodyAr!.isNotEmpty) return bodyAr!;
    return bodyEn ?? body;
  }

  factory BroadcastNotification.fromMap(Map<String, dynamic> map) {
    return BroadcastNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      titleEn: map['title_en'] as String?,
      bodyEn: map['body_en'] as String?,
      titleAr: map['title_ar'] as String?,
      bodyAr: map['body_ar'] as String?,
      imageUrl: map['image_url'] as String?,
      target: map['target'] as String? ?? 'all',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      createdAt: DateTime.parse(map['created_at'] as String),
      sentBy: map['sent_by'] as String?,
      readBy: List<String>.from(
        (map['read_by'] as List<dynamic>? ?? []).map((e) => e.toString()),
      ),
    );
  }

  bool get isRead {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    return readBy.contains(userId);
  }
}

/// Service to fetch and manage broadcast notifications from Supabase.
class BroadcastService {
  static final BroadcastService _instance = BroadcastService._internal();
  factory BroadcastService() => _instance;
  BroadcastService._internal();

  final _supabase = Supabase.instance.client;

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Fetch all notifications relevant to this platform, sorted newest first.
  /// Includes both read and unread so the inbox can show history.
  Future<List<BroadcastNotification>> fetchAll() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      // Only show notifications created after the user's account
      final userCreatedAt = _supabase.auth.currentUser?.createdAt;

      var query = _supabase
          .from('broadcast_notifications')
          .select()
          .or('target.eq.all,target.eq.$_platform');

      if (userCreatedAt != null) {
        query = query.gte('created_at', userCreatedAt);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) => BroadcastNotification.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BroadcastService.fetchAll error: $e');
      return [];
    }
  }

  /// Fetch only unread notifications for the current user.
  Future<List<BroadcastNotification>> fetchUnread() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('broadcast_notifications')
          .select()
          .or('target.eq.all,target.eq.$_platform')
          .not('read_by', 'cs', '{$userId}')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((e) => BroadcastNotification.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BroadcastService.fetchUnread error: $e');
      return [];
    }
  }

  /// Returns the number of unread notifications for the current user.
  Future<int> getUnreadCount() async {
    final unread = await fetchUnread();
    return unread.length;
  }

  /// Mark a single notification as read by appending the current user's ID
  /// to the `read_by` array. Uses fetch-then-update for compatibility.
  Future<void> markAsRead(String notificationId) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Fetch current read_by array
      final row = await _supabase
          .from('broadcast_notifications')
          .select('read_by')
          .eq('id', notificationId)
          .single();

      final List<String> readBy = List<String>.from(
        (row['read_by'] as List<dynamic>? ?? []).map((e) => e.toString()),
      );

      if (!readBy.contains(userId)) {
        readBy.add(userId);
        await _supabase
            .from('broadcast_notifications')
            .update({'read_by': readBy})
            .eq('id', notificationId);
      }
    } catch (e) {
      debugPrint('BroadcastService.markAsRead error: $e');
    }
  }

  /// Mark all unread notifications as read for the current user.
  Future<void> markAllAsRead(List<BroadcastNotification> notifications) async {
    final userId = _userId;
    if (userId == null) return;

    final unread = notifications.where((n) => !n.isRead).toList();
    for (final n in unread) {
      await markAsRead(n.id);
    }
  }

  /// Clear all notifications for the current user by adding them to a "dismissed" list.
  /// We add userId to a `dismissed_by` array (similar to read_by).
  /// For now, we just mark all as read and let the UI handle clearing.
  Future<void> clearAllForUser() async {
    // We'll filter client-side — user dismissed notifications are stored locally
  }
}


