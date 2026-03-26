import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Stores device activity events locally (state changes, online/offline, scenes).
class ActivityLogService {
  static final ActivityLogService _instance = ActivityLogService._();
  factory ActivityLogService() => _instance;
  ActivityLogService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'hbot_activity.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            device_name TEXT NOT NULL,
            event_type TEXT NOT NULL,
            description TEXT NOT NULL,
            details TEXT,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_activity_device ON activity_log(device_id, timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_activity_time ON activity_log(timestamp DESC)',
        );
      },
    );
  }

  /// Log an activity event
  Future<void> log({
    String? deviceId,
    required String deviceName,
    required ActivityEventType eventType,
    required String description,
    String? details,
  }) async {
    try {
      final db = await database;
      await db.insert('activity_log', {
        'device_id': deviceId,
        'device_name': deviceName,
        'event_type': eventType.name,
        'description': description,
        'details': details,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Prune old entries (keep last 1000)
      final count = (await db.rawQuery('SELECT COUNT(*) as c FROM activity_log')).first['c'] as int;
      if (count > 1000) {
        await db.rawDelete(
          'DELETE FROM activity_log WHERE id IN (SELECT id FROM activity_log ORDER BY timestamp ASC LIMIT ?)',
          [count - 1000],
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to log activity: $e');
    }
  }

  /// Get recent activity for all devices
  Future<List<ActivityEvent>> getRecentActivity({int limit = 50, int offset = 0}) async {
    final db = await database;
    final rows = await db.query(
      'activity_log',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ActivityEvent.fromMap).toList();
  }

  /// Get activity for a specific device
  Future<List<ActivityEvent>> getDeviceActivity(String deviceId, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'activity_log',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ActivityEvent.fromMap).toList();
  }

  /// Clear all activity logs
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('activity_log');
  }

  /// Clear activity for a specific device
  Future<void> clearDevice(String deviceId) async {
    final db = await database;
    await db.delete('activity_log', where: 'device_id = ?', whereArgs: [deviceId]);
  }
}

enum ActivityEventType {
  deviceOnline,
  deviceOffline,
  stateChange,
  sceneExecuted,
  timerTriggered,
  firmwareUpdate,
  deviceAdded,
  deviceRemoved,
  deviceRenamed,
}

class ActivityEvent {
  final int id;
  final String? deviceId;
  final String deviceName;
  final ActivityEventType eventType;
  final String description;
  final String? details;
  final DateTime timestamp;

  ActivityEvent({
    required this.id,
    this.deviceId,
    required this.deviceName,
    required this.eventType,
    required this.description,
    this.details,
    required this.timestamp,
  });

  factory ActivityEvent.fromMap(Map<String, dynamic> map) {
    return ActivityEvent(
      id: map['id'] as int,
      deviceId: map['device_id'] as String?,
      deviceName: map['device_name'] as String,
      eventType: ActivityEventType.values.firstWhere(
        (e) => e.name == map['event_type'],
        orElse: () => ActivityEventType.stateChange,
      ),
      description: map['description'] as String,
      details: map['details'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  String get icon {
    switch (eventType) {
      case ActivityEventType.deviceOnline: return '🟢';
      case ActivityEventType.deviceOffline: return '🔴';
      case ActivityEventType.stateChange: return '💡';
      case ActivityEventType.sceneExecuted: return '🎬';
      case ActivityEventType.timerTriggered: return '⏰';
      case ActivityEventType.firmwareUpdate: return '🔄';
      case ActivityEventType.deviceAdded: return '➕';
      case ActivityEventType.deviceRemoved: return '➖';
      case ActivityEventType.deviceRenamed: return '✏️';
    }
  }
}
