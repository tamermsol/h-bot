class PresenceUtils {
  /// Determine whether a device is online based on a combined state map.
  ///
  /// Rules:
  /// - If `state['health']` exists, return true only when it's 'ONLINE'.
  /// - Else, if `state['lastPing']` is present and parseable as an ISO datetime,
  ///   treat the device as online when the last ping is within [graceSeconds].
  /// - Else, if [allowFallbackToOnlineFlag] is true and state['online'] is present,
  ///   return that value. Otherwise return false.
  static bool isDeviceOnlineFromState(
    Map<String, dynamic>? state, {
    int graceSeconds = 120,
    bool allowFallbackToOnlineFlag = false,
  }) {
    // New stricter behavior: prefer explicit health, then lastPing freshness.
    if (state == null) return false;

    final health = state['health'];
    if (health != null) {
      try {
        return (health as String).toUpperCase() == 'ONLINE';
      } catch (_) {}
    }

    final lastPingRaw = state['lastPing'];
    if (lastPingRaw != null) {
      try {
        final lastPing = DateTime.parse(lastPingRaw as String);
        final age = DateTime.now().difference(lastPing).inSeconds;
        return age <= graceSeconds;
      } catch (_) {}
    }

    // No implicit online from cached state map anymore. Only allow explicit
    // 'online' fallback when caller intentionally allows it.
    if (allowFallbackToOnlineFlag && state.containsKey('online')) {
      final online = state['online'];
      if (online is bool) return online;
      if (online is String) {
        final lower = online.toLowerCase();
        return lower == 'true' || lower == 'online';
      }
    }

    return false;
  }

  /// New explicit helper that requires availability (LWT) or a fresh lastSeen.
  static bool isOnline({
    required String? availability, // 'online'|'offline'|null
    required DateTime? lastSeen,
    required Duration ttl,
  }) {
    if (availability == 'offline') return false;
    if (availability == 'online') {
      if (lastSeen == null) return false;
      return DateTime.now().difference(lastSeen) < ttl;
    }
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) < ttl;
  }
}
