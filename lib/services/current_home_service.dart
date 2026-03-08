import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Service to manage the currently selected home across the app
/// This allows different screens to know which home is currently active
class CurrentHomeService {
  static final CurrentHomeService _instance = CurrentHomeService._internal();
  factory CurrentHomeService() => _instance;
  CurrentHomeService._internal();

  static const String _currentHomeIdKey = 'current_home_id';
  
  // Stream controller to notify listeners when home changes
  final _homeChangeController = StreamController<String?>.broadcast();
  
  String? _cachedHomeId;

  /// Get stream of home changes
  Stream<String?> get homeChanges => _homeChangeController.stream;

  /// Get the currently selected home ID
  Future<String?> getCurrentHomeId() async {
    if (_cachedHomeId != null) {
      return _cachedHomeId;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _cachedHomeId = prefs.getString(_currentHomeIdKey);
    return _cachedHomeId;
  }

  /// Set the currently selected home ID
  Future<void> setCurrentHomeId(String? homeId) async {
    _cachedHomeId = homeId;
    final prefs = await SharedPreferences.getInstance();
    
    if (homeId != null) {
      await prefs.setString(_currentHomeIdKey, homeId);
    } else {
      await prefs.remove(_currentHomeIdKey);
    }
    
    // Notify listeners
    _homeChangeController.add(homeId);
  }

  /// Clear the current home selection
  Future<void> clearCurrentHome() async {
    await setCurrentHomeId(null);
  }

  /// Dispose the service (cleanup)
  void dispose() {
    _homeChangeController.close();
  }
}

