import 'dart:async';

/// Simple event notifier for room changes
/// This allows any screen to notify the dashboard when rooms are updated
class RoomChangeNotifier {
  static final RoomChangeNotifier _instance = RoomChangeNotifier._internal();
  factory RoomChangeNotifier() => _instance;
  RoomChangeNotifier._internal();

  final _controller = StreamController<void>.broadcast();

  /// Stream that emits when rooms are changed
  Stream<void> get roomChanges => _controller.stream;

  /// Notify all listeners that rooms have changed
  void notifyRoomChanged() {
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
