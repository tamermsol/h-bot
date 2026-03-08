import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';
import '../services/mqtt_device_manager.dart';
import '../theme/app_theme.dart';

/// Widget for controlling shutter devices with slider and buttons
class ShutterControlWidget extends StatefulWidget {
  final Device device;
  final MqttDeviceManager? mqttManager;
  final int shutterIndex; // Which shutter (1-based index)

  const ShutterControlWidget({
    super.key,
    required this.device,
    this.mqttManager,
    this.shutterIndex = 1,
  });

  @override
  State<ShutterControlWidget> createState() => _ShutterControlWidgetState();
}

class _ShutterControlWidgetState extends State<ShutterControlWidget> {
  late MqttDeviceManager _mqttManager;
  StreamSubscription? _deviceStateSubscription;
  StreamSubscription? _connectionStateSubscription;
  MqttConnectionState _connectionState = MqttConnectionState.disconnected;

  // Shutter state
  double _currentPosition = 0.0; // 0 = closed, 100 = open
  bool _isMoving = false;
  double _sliderValue = 0.0;
  Timer? _stateRefreshTimer;

  // Track expected target position for optimistic update filtering
  int? _expectedTargetPosition;

  // Debounce timer for slider to avoid spamming commands while dragging
  Timer? _sliderDebounceTimer;

  // Track shutter direction for button highlighting
  // 0 = stopped, 1 = opening (moving up), -1 = closing (moving down)
  int _shutterDirection = 0;

  // Animation style: 'shutter', 'curtain', or 'none'
  String _animationStyle = 'shutter';

  @override
  void initState() {
    super.initState();
    _mqttManager = widget.mqttManager ?? MqttDeviceManager();

    // Load animation preference from storage
    _loadAnimationPreference();

    // Load initial position SYNCHRONOUSLY before first build (like dashboard does)
    // This ensures the UI shows the actual position immediately, not 0%
    _loadInitialPositionSync();

    _initializeShutter();
    _startPeriodicStateRefresh();
  }

  @override
  void dispose() {
    _deviceStateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _stateRefreshTimer?.cancel();
    _sliderDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShutterControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If device changed, re-initialize
    if (oldWidget.device.id != widget.device.id) {
      _initializeShutter();
    }
  }

  Future<void> _initializeShutter() async {
    try {
      // Listen to connection state changes
      _connectionStateSubscription = _mqttManager.connectionStateStream.listen((
        state,
      ) {
        if (mounted) {
          setState(() {
            _connectionState = state;
          });

          // When connection is established, immediately request state
          if (state == MqttConnectionState.connected) {
            debugPrint(
              '🔌 Shutter ${widget.device.name}: MQTT connected, requesting state',
            );
            _requestCurrentState();
          }
        }
      });

      // Set initial connection state
      _connectionState = _mqttManager.connectionState;

      // CRITICAL FIX FOR ISSUE 1: Register device with minimal blocking
      // We need to await this to ensure the device is registered before commands can be sent
      // However, we'll optimize the registerDevice method to be faster
      debugPrint(
        '🚀 Shutter ${widget.device.name}: Registering device for immediate control',
      );

      // Register device - this MUST complete before first control command
      // Otherwise commands will fail silently because device isn't in _registeredDevices
      await _mqttManager.registerDevice(widget.device);

      debugPrint(
        '✅ Shutter ${widget.device.name}: Device registered, ready for control',
      );

      // Listen to device state updates
      final stream = _mqttManager.getDeviceStateStream(widget.device.id);
      if (stream != null) {
        _deviceStateSubscription = stream.listen((state) {
          _handleDeviceStateUpdate(state);
        });
      }

      // NOTE: Initial position is now loaded SYNCHRONOUSLY in initState()
      // This ensures the UI shows the actual position immediately (like dashboard)
      // No need to load it again here

      // Request fresh state from device to ensure accuracy
      // This will update the position if it has changed since the cached value
      // Use fire-and-forget (no await) to avoid blocking initialization
      debugPrint(
        '🔄 Shutter ${widget.device.name}: Requesting fresh state from device (non-blocking)',
      );
      _requestCurrentState().catchError((e) {
        debugPrint('⚠️ Error requesting initial state: $e');
      });

      // Request again after a short delay to ensure we get the state
      // (some devices may be slow to respond or MQTT may have latency)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          debugPrint(
            '🔄 Shutter ${widget.device.name}: Requesting state (retry)',
          );
          _requestCurrentState();
        }
      });
    } catch (e) {
      debugPrint('Error initializing shutter control: $e');
    }
  }

  /// Load animation preference from SharedPreferences
  Future<void> _loadAnimationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStyle = prefs.getString('shutter_animation_style');
      if (savedStyle != null && mounted) {
        setState(() {
          _animationStyle = savedStyle;
        });
        debugPrint('📱 Loaded animation style: $savedStyle');
      }
    } catch (e) {
      debugPrint('Error loading animation preference: $e');
    }
  }

  /// Save animation preference to SharedPreferences
  Future<void> _saveAnimationPreference(String style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shutter_animation_style', style);
      debugPrint('💾 Saved animation style: $style');
    } catch (e) {
      debugPrint('Error saving animation preference: $e');
    }
  }

  /// Load initial position from MQTT cache SYNCHRONOUSLY (called in initState)
  /// CRITICAL: This must be synchronous to ensure position is set before first build
  /// This is how the dashboard card works - it loads position immediately
  void _loadInitialPositionSync() {
    try {
      // ONLY get position from MQTT manager's cached state
      // NO database queries for state - state comes ONLY from MQTT
      final cachedPosition = _mqttManager.getShutterPosition(
        widget.device.id,
        widget.shutterIndex,
      );

      debugPrint(
        '📍 Shutter ${widget.device.name}: Loaded SYNC position: $cachedPosition%',
      );

      // Set the position immediately (before first build)
      // This ensures the UI shows the actual position from the start
      _currentPosition = cachedPosition.toDouble();
      _sliderValue = cachedPosition.toDouble();
    } catch (e) {
      debugPrint('Error loading initial shutter position: $e');
    }
  }

  /// Request current state from the device
  Future<void> _requestCurrentState() async {
    try {
      // Use immediate state request for faster response
      await _mqttManager.requestDeviceStateImmediate(widget.device.id);

      // Also request regular state as backup with minimal delay
      await Future.delayed(const Duration(milliseconds: 50));
      await _mqttManager.requestDeviceState(widget.device.id);
    } catch (e) {
      debugPrint('Error requesting shutter state: $e');
    }
  }

  /// Start periodic state refresh to keep UI in sync
  void _startPeriodicStateRefresh() {
    // Refresh state every 10 seconds to ensure UI stays in sync with device
    // This is more aggressive to catch external changes (physical switches, other apps)
    _stateRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _connectionState == MqttConnectionState.connected) {
        debugPrint('🔄 Shutter ${widget.device.name}: Periodic state refresh');
        _requestCurrentState();
      }
    });
  }

  void _handleDeviceStateUpdate(Map<String, dynamic> state) {
    if (!mounted) return;

    // Get shutter position directly from state data (not cached)
    final shutterKey = 'Shutter${widget.shutterIndex}';
    int? newPosition;
    int? newDirection;

    final shutterData = state[shutterKey];
    if (shutterData is int) {
      newPosition = shutterData.clamp(0, 100);
    } else if (shutterData is double) {
      newPosition = shutterData.round().clamp(0, 100);
    } else if (shutterData is String) {
      newPosition = int.tryParse(shutterData)?.clamp(0, 100);
    } else if (shutterData is Map<String, dynamic>) {
      // Handle object form: {"Position": 50, "Direction": 1, ...}
      final pos = shutterData['Position'];
      if (pos is int) {
        newPosition = pos.clamp(0, 100);
      } else if (pos is double) {
        newPosition = pos.round().clamp(0, 100);
      } else if (pos is String) {
        newPosition = int.tryParse(pos)?.clamp(0, 100);
      }

      // Extract direction: 0 = stopped, 1 = opening (up), -1 = closing (down)
      final dir = shutterData['Direction'];
      if (dir is int) {
        newDirection = dir;
      }
    }

    // CRITICAL FIX FOR ISSUE 2: Always update direction from MQTT data
    // This ensures the blue glow indicator updates in real-time based on MQTT data
    // Direction is now ALWAYS provided by MQTT service (even if 0 for stopped)
    // We trust MQTT data completely and never override it locally
    if (newDirection != null && newDirection != _shutterDirection) {
      setState(() {
        _shutterDirection = newDirection!;
        debugPrint(
          '🧭 Shutter ${widget.device.name}: Direction updated to $_shutterDirection (${_shutterDirection == 1
              ? "opening"
              : _shutterDirection == -1
              ? "closing"
              : "stopped"})',
        );
      });
    }

    // Only update position if it actually changed to avoid unnecessary rebuilds
    if (newPosition != null && newPosition != _currentPosition.toInt()) {
      // SMART FILTERING: Ignore optimistic updates that jump to target position
      // If we're moving and the new position is the expected target (0 or 100),
      // ignore it - this is likely an optimistic update from the MQTT service
      // We want to show progressive movement, not jump to the final position
      if (_isMoving && _expectedTargetPosition != null) {
        if (newPosition == _expectedTargetPosition) {
          debugPrint(
            '🚫 Shutter ${widget.device.name}: Ignoring optimistic update to target $newPosition% (currently moving)',
          );
          return; // Ignore this update - it's the optimistic jump
        }

        // If we got a different position while moving, it's real device feedback
        // Clear the expected target so we accept all future updates
        debugPrint(
          '✅ Shutter ${widget.device.name}: Received real position $newPosition% (was expecting $_expectedTargetPosition%), accepting progressive updates',
        );
        _expectedTargetPosition = null;
      }

      debugPrint(
        '📊 Shutter ${widget.device.name}: Position updated from ${_currentPosition.toInt()}% to $newPosition%',
      );

      setState(() {
        _currentPosition = newPosition!.toDouble();
        _sliderValue = newPosition.toDouble();

        // Only set _isMoving = false if we've reached the expected target
        // or if we weren't expecting a target (manual stop, external control)
        if (_expectedTargetPosition == null ||
            newPosition == _expectedTargetPosition) {
          _isMoving = false;
          _expectedTargetPosition = null;
        }

        // CRITICAL FIX FOR ISSUE 2: NEVER override direction here
        // Direction is ALWAYS provided by MQTT service and updated above
        // We trust MQTT data completely - it's the source of truth
      });
    }
  }

  Future<void> _openShutter() async {
    if (!_isConnected) return;

    setState(() {
      _isMoving = true;
      _expectedTargetPosition = 100; // Expect to reach 100% (fully open)
    });

    try {
      // CRITICAL FIX FOR ISSUE 2: MQTT service now handles optimistic direction update
      // Direction will be set to 1 (opening) by the MQTT service and propagated back
      // via the state stream, ensuring consistent state across all widgets
      await _mqttManager.openShutter(widget.device.id, widget.shutterIndex);
    } catch (e) {
      debugPrint('Error opening shutter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open shutter: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isMoving = false;
          _expectedTargetPosition = null;
        });
      }
    }
  }

  Future<void> _closeShutter() async {
    if (!_isConnected) return;

    setState(() {
      _isMoving = true;
      _expectedTargetPosition = 0; // Expect to reach 0% (fully closed)
    });

    try {
      // CRITICAL FIX FOR ISSUE 2: MQTT service now handles optimistic direction update
      // Direction will be set to -1 (closing) by the MQTT service and propagated back
      await _mqttManager.closeShutter(widget.device.id, widget.shutterIndex);
    } catch (e) {
      debugPrint('Error closing shutter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close shutter: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isMoving = false;
          _expectedTargetPosition = null;
        });
      }
    }
  }

  Future<void> _stopShutter() async {
    if (!_isConnected) return;

    setState(() {
      _isMoving = false;
      _expectedTargetPosition = null; // No expected target when stopping
    });

    try {
      // CRITICAL FIX FOR ISSUE 2: MQTT service now handles optimistic direction update
      // Direction will be set to 0 (stopped) by the MQTT service and propagated back
      await _mqttManager.stopShutter(widget.device.id, widget.shutterIndex);
    } catch (e) {
      debugPrint('Error stopping shutter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop shutter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle slider value changes with debouncing to avoid spamming commands
  /// This is called on every slider movement (onChanged)
  void _onSliderChanged(double value) {
    // Update UI immediately for smooth slider movement
    setState(() {
      _sliderValue = value;
    });

    // Cancel any pending command
    _sliderDebounceTimer?.cancel();

    // Schedule a new command after a short delay (300ms)
    // This ensures we don't spam commands while the user is actively dragging
    // but still send commands quickly (much faster than onChangeEnd)
    _sliderDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        debugPrint(
          '🎚️ Shutter ${widget.device.name}: Slider debounced to ${value.round()}%',
        );
        _setPosition(value);
      }
    });
  }

  /// Handle slider drag end - send final position immediately
  /// This is called when the user releases the slider (onChangeEnd)
  void _onSliderChangeEnd(double value) {
    // Cancel any pending debounced command
    _sliderDebounceTimer?.cancel();

    // Send the final position immediately
    debugPrint(
      '🎚️ Shutter ${widget.device.name}: Slider released at ${value.round()}%',
    );
    _setPosition(value);
  }

  Future<void> _setPosition(double position) async {
    if (!_isConnected) return;

    // Guard: only publish if value is finite
    if (!position.isFinite) {
      debugPrint('⚠️ Ignoring non-finite position: $position');
      return;
    }

    // Clamp to 0..100
    final clampedPosition = position.clamp(0.0, 100.0);
    final targetPosition = clampedPosition.round();

    setState(() {
      _isMoving = true;
      _sliderValue = clampedPosition;
      _expectedTargetPosition = targetPosition; // Expect to reach this position
    });

    try {
      // CRITICAL FIX FOR ISSUE 2: MQTT service now handles optimistic direction update
      // Direction will be calculated by the MQTT service based on current vs target position
      // and propagated back via the state stream
      await _mqttManager.setShutterPosition(
        widget.device.id,
        widget.shutterIndex,
        targetPosition,
      );
    } catch (e) {
      debugPrint('Error setting shutter position: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set position: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isMoving = false;
          _expectedTargetPosition = null;
        });
      }
    }
  }

  bool get _isConnected => _connectionState == MqttConnectionState.connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status and animation style selector
          _buildConnectionIndicator(),
          const SizedBox(height: AppTheme.paddingMedium),

          // Animated visualization
          if (_animationStyle != 'none') ...[
            _buildAnimatedVisualization(),
            const SizedBox(height: AppTheme.paddingLarge),
          ],

          // Control buttons (Close, Stop, Open)
          _buildControlButtons(),
          const SizedBox(height: AppTheme.paddingLarge),

          // Position slider
          _buildPositionSlider(),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Row(
      children: [
        // Removed green/red connection indicator dot - not useful
        const Spacer(),
        // Animation style selector
        PopupMenuButton<String>(
          icon: Icon(
            _animationStyle == 'shutter'
                ? Icons.window
                : _animationStyle == 'curtain'
                ? Icons.curtains
                : Icons.visibility_off,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          onSelected: (value) {
            setState(() {
              _animationStyle = value;
            });
            // Save the preference
            _saveAnimationPreference(value);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'shutter',
              child: Row(
                children: [
                  Icon(Icons.window, size: 20),
                  SizedBox(width: 8),
                  Text('Shutter'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'curtain',
              child: Row(
                children: [
                  Icon(Icons.curtains, size: 20),
                  SizedBox(width: 8),
                  Text('Curtain'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'none',
              child: Row(
                children: [
                  Icon(Icons.visibility_off, size: 20),
                  SizedBox(width: 8),
                  Text('None'),
                ],
              ),
            ),
          ],
        ),
        if (_isMoving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedVisualization() {
    return _animationStyle == 'shutter'
        ? _buildShutterAnimation()
        : _buildCurtainAnimation();
  }

  Widget _buildShutterAnimation() {
    final safePosition = _currentPosition.isFinite
        ? _currentPosition.clamp(0.0, 100.0)
        : 0.0;

    // Calculate how much of the window is covered (0% = fully open, 100% = fully closed)
    final closedPercentage = 100 - safePosition;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: Colors.grey[700]!, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall - 2),
        child: Stack(
          children: [
            // Window background (visible when open)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.lightBlue[200]!, Colors.lightBlue[100]!],
                ),
              ),
            ),

            // Shutter slats (rolling down from top)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              left: 0,
              right: 0,
              height: (200 * closedPercentage / 100),
              child: Container(
                decoration: BoxDecoration(color: Colors.grey[300]),
                child: CustomPaint(
                  painter: _ShutterSlatsPainter(
                    slatCount: (closedPercentage / 5).ceil(),
                  ),
                ),
              ),
            ),

            // Shutter box at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[600]!, width: 2),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurtainAnimation() {
    final safePosition = _currentPosition.isFinite
        ? _currentPosition.clamp(0.0, 100.0)
        : 0.0;

    // Calculate how much the curtains are open (0% = fully closed, 100% = fully open)
    final openPercentage = safePosition;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: Colors.grey[700]!, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall - 2),
        child: Stack(
          children: [
            // Window background (visible when open)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.lightBlue[200]!, Colors.lightBlue[100]!],
                ),
              ),
            ),

            // Curtain rod at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 15,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // Left curtain panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 15,
              left: 0,
              bottom: 0,
              width:
                  MediaQuery.of(context).size.width *
                  0.5 *
                  (1 - openPercentage / 100),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.blueGrey[700]!,
                      Colors.blueGrey[600]!,
                      Colors.blueGrey[700]!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: CustomPaint(painter: _CurtainFoldsPainter()),
              ),
            ),

            // Right curtain panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 15,
              right: 0,
              bottom: 0,
              width:
                  MediaQuery.of(context).size.width *
                  0.5 *
                  (1 - openPercentage / 100),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.blueGrey[700]!,
                      Colors.blueGrey[600]!,
                      Colors.blueGrey[700]!,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: CustomPaint(painter: _CurtainFoldsPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    // Determine which button should be highlighted based on shutter direction
    // Direction: 0 = stopped, 1 = opening (up), -1 = closing (down)
    final bool isClosing = _shutterDirection == -1;
    final bool isStopped = _shutterDirection == 0;
    final bool isOpening = _shutterDirection == 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Close button (highlighted when closing)
        _buildControlButton(
          icon: Icons.arrow_circle_down,
          label: 'Close',
          onPressed: _isConnected ? _closeShutter : null,
          isHighlighted: isClosing,
        ),

        // Stop button (highlighted when stopped)
        _buildControlButton(
          icon: Icons.pause_circle,
          label: 'Stop',
          onPressed: _isConnected ? _stopShutter : null,
          isHighlighted: isStopped,
        ),

        // Open button (highlighted when opening)
        _buildControlButton(
          icon: Icons.arrow_circle_up,
          label: 'Open',
          onPressed: _isConnected ? _openShutter : null,
          isHighlighted: isOpening,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isHighlighted = false,
  }) {
    // CRITICAL FIX FOR ISSUE 2: Proper blue shadow/glow for active buttons
    // All buttons are grey by default
    // Active button (based on shutter direction) has blue shadow/glow
    // Shadow remains visible continuously while in that state

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            // BLUE SHADOW/GLOW when highlighted (active state)
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cardColor,
              // ALL BUTTONS GREY by default, active button also grey (shadow provides the blue)
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                side: BorderSide(
                  color: isHighlighted ? AppTheme.primaryColor : Colors.grey,
                  width: isHighlighted ? 2 : 1,
                ),
              ),
              elevation: 0, // Remove default elevation to show custom shadow
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 32),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSlider() {
    // Sanitize values before rendering (guard against NaN/Infinity)
    final safeCurrentPosition = _currentPosition.isFinite
        ? _currentPosition.clamp(0.0, 100.0)
        : 0.0;
    final safeSliderValue = _sliderValue.isFinite
        ? _sliderValue.clamp(0.0, 100.0)
        : 0.0;

    return Column(
      children: [
        // Position percentage display
        Text(
          '${safeCurrentPosition.round()}%',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),

        // Slider
        Row(
          children: [
            const Text(
              'Close',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            Expanded(
              child: Slider(
                value: safeSliderValue,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${safeSliderValue.round()}%',
                activeColor: AppTheme.primaryColor,
                inactiveColor: AppTheme.textSecondary.withOpacity(0.3),
                // Use debounced handler for onChanged to send commands while dragging
                // This provides fast feedback (300ms) instead of waiting for onChangeEnd
                onChanged: _isConnected ? _onSliderChanged : null,
                // Also handle onChangeEnd to send final position immediately
                onChangeEnd: _isConnected ? _onSliderChangeEnd : null,
              ),
            ),
            const Text(
              'Open',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for shutter slats
class _ShutterSlatsPainter extends CustomPainter {
  final int slatCount;

  _ShutterSlatsPainter({required this.slatCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (slatCount <= 0) return;

    final slatHeight = 10.0;
    final slatSpacing = 2.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < slatCount; i++) {
      final y = i * (slatHeight + slatSpacing);
      if (y >= size.height) break;

      // Main slat
      paint.color = Colors.grey[300]!;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, slatHeight), paint);

      // Shadow on bottom of slat
      paint.color = Colors.grey[500]!;
      canvas.drawRect(
        Rect.fromLTWH(0, y + slatHeight - 2, size.width, 2),
        paint,
      );

      // Highlight on top of slat
      paint.color = Colors.grey[200]!;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ShutterSlatsPainter oldDelegate) {
    return oldDelegate.slatCount != slatCount;
  }
}

/// Custom painter for curtain folds
class _CurtainFoldsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw vertical folds
    final foldCount = (size.width / 20).ceil();
    for (int i = 0; i < foldCount; i++) {
      final x = i * 20.0;

      // Darker fold line
      paint.color = Colors.black.withOpacity(0.3);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      // Lighter highlight next to fold
      if (x + 10 < size.width) {
        paint.color = Colors.white.withOpacity(0.1);
        canvas.drawLine(Offset(x + 10, 0), Offset(x + 10, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CurtainFoldsPainter oldDelegate) => false;
}
