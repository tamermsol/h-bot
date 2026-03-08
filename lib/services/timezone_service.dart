import 'package:flutter/foundation.dart';
import '../core/supabase_client.dart';

/// Service for handling timezone conversions between local (Egypt) and UTC
///
/// IMPORTANT: This service assumes Egypt timezone is UTC+2 (no DST handling).
/// For production with DST support, use the `timezone` package.
class TimezoneService {
  static final TimezoneService _instance = TimezoneService._internal();

  factory TimezoneService() {
    return _instance;
  }

  TimezoneService._internal();

  /// Egypt timezone offset from UTC (in hours)
  /// Egypt Standard Time (EET) is UTC+2
  /// Note: Egypt does NOT observe DST as of 2023
  static const int egyptUtcOffsetHours = 2;

  /// Fetch the current server UTC time from Supabase
  ///
  /// This ensures we use the server's clock, not the device's potentially
  /// incorrect local time.
  ///
  /// Returns: DateTime in UTC
  Future<DateTime> fetchServerUtcNow() async {
    try {
      final response = await supabase.rpc('get_server_time');

      if (response == null) {
        throw 'Server time RPC returned null';
      }

      final utcNowStr = response['utc_now'] as String;
      final serverUtcNow = DateTime.parse(utcNowStr).toUtc();

      debugPrint('🕐 Server UTC time: $serverUtcNow');
      return serverUtcNow;
    } catch (e) {
      debugPrint(
        '⚠️ Failed to fetch server time, falling back to device time: $e',
      );
      // Fallback to device time if RPC fails
      return DateTime.now().toUtc();
    }
  }

  /// Convert UTC DateTime to Egypt local time
  ///
  /// Egypt is UTC+2 (no DST)
  DateTime utcToEgypt(DateTime utcTime) {
    return utcTime.add(Duration(hours: egyptUtcOffsetHours));
  }

  /// Convert Egypt local time to UTC
  ///
  /// Egypt is UTC+2 (no DST)
  DateTime egyptToUtc(DateTime egyptTime) {
    return egyptTime.subtract(Duration(hours: egyptUtcOffsetHours));
  }

  /// Build UTC hour/minute for scene trigger based on user's local selection
  ///
  /// This function:
  /// 1. Gets server UTC time (not device time)
  /// 2. Converts to Egypt time
  /// 3. Builds the next occurrence of the selected time
  /// 4. Converts back to UTC
  /// 5. Returns UTC hour/minute to store in database
  ///
  /// Parameters:
  /// - selectedHour: User's selected hour in Egypt time (0-23)
  /// - selectedMinute: User's selected minute (0-59)
  /// - selectedDays: Days of week (1=Monday, 7=Sunday) or null for every day
  ///
  /// Returns: Map with 'hour' and 'minute' in UTC
  Future<Map<String, int>> buildTriggerUtcHourMinute(
    int selectedHour,
    int selectedMinute,
    List<int>? selectedDays,
  ) async {
    // Step 1: Get server UTC time (authoritative clock)
    final serverUtcNow = await fetchServerUtcNow();

    // Step 2: Convert server time to Egypt time
    final egyptNow = utcToEgypt(serverUtcNow);

    debugPrint('🕐 Server UTC now: $serverUtcNow');
    debugPrint('🕐 Egypt now: $egyptNow');
    debugPrint(
      '🕐 User selected: ${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} Egypt time',
    );

    // Step 3: Build the next occurrence of selected time in Egypt timezone
    DateTime nextOccurrenceEgypt = DateTime(
      egyptNow.year,
      egyptNow.month,
      egyptNow.day,
      selectedHour,
      selectedMinute,
      0,
      0,
      0,
    );

    // If the selected time has already passed today, move to tomorrow
    if (nextOccurrenceEgypt.isBefore(egyptNow) ||
        nextOccurrenceEgypt.isAtSameMomentAs(egyptNow)) {
      nextOccurrenceEgypt = nextOccurrenceEgypt.add(const Duration(days: 1));
      debugPrint('🕐 Selected time already passed today, using tomorrow');
    }

    // If specific days are selected, find the next matching day
    if (selectedDays != null && selectedDays.isNotEmpty) {
      // Convert DateTime.weekday (1=Monday, 7=Sunday) to match our format
      int currentWeekday = nextOccurrenceEgypt.weekday;

      // Find next matching day
      int daysToAdd = 0;
      for (int i = 0; i < 7; i++) {
        final checkDay = (currentWeekday + i - 1) % 7 + 1;
        if (selectedDays.contains(checkDay)) {
          daysToAdd = i;
          break;
        }
      }

      if (daysToAdd > 0) {
        nextOccurrenceEgypt = nextOccurrenceEgypt.add(
          Duration(days: daysToAdd),
        );
        debugPrint('🕐 Next matching day is in $daysToAdd day(s)');
      }
    }

    debugPrint('🕐 Next occurrence (Egypt): $nextOccurrenceEgypt');

    // Step 4: Convert Egypt time to UTC
    final nextOccurrenceUtc = egyptToUtc(nextOccurrenceEgypt);

    debugPrint('🕐 Next occurrence (UTC): $nextOccurrenceUtc');
    debugPrint(
      '🕐 Storing UTC hour=${nextOccurrenceUtc.hour}, minute=${nextOccurrenceUtc.minute}',
    );

    // Step 5: Return UTC hour/minute
    return {'hour': nextOccurrenceUtc.hour, 'minute': nextOccurrenceUtc.minute};
  }

  /// Convert stored UTC hour/minute back to Egypt time for display
  ///
  /// This is used when showing the trigger time to the user
  Map<String, int> utcHourMinuteToEgypt(int utcHour, int utcMinute) {
    // Create a dummy UTC datetime with the stored hour/minute
    final utcTime = DateTime.utc(2024, 1, 1, utcHour, utcMinute);

    // Convert to Egypt time
    final egyptTime = utcToEgypt(utcTime);

    return {'hour': egyptTime.hour, 'minute': egyptTime.minute};
  }

  /// Format time for display in Egypt timezone
  String formatEgyptTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get day name from day number (1=Monday, 7=Sunday)
  String getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// Get short day name from day number (1=Mon, 7=Sun)
  String getShortDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '?';
    }
  }
}
