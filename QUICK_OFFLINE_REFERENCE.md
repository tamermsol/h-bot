# Quick Reference: Offline Error Handling

## What Was Fixed

### Problem
- App showed raw technical errors with sensitive database information
- Users saw Supabase URLs, error codes, and stack traces
- Confusing and unprofessional error messages

### Solution
- Created user-friendly error handler
- Added connectivity banner
- Hides all sensitive technical details
- Shows clear, actionable messages

---

## Key Files Created

1. **`lib/utils/error_handler.dart`**
   - Converts technical errors to user-friendly messages
   - Logs details only in debug mode

2. **`lib/widgets/connectivity_banner.dart`**
   - Orange banner showing "No internet connection"
   - Appears at top of screen when offline

3. **`lib/widgets/error_message_widget.dart`**
   - Displays friendly error messages
   - Includes retry button
   - Shows appropriate icons

---

## How to Use in Other Screens

### Replace Old Error Handling
```dart
// ❌ OLD WAY (exposes technical details)
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to load: $e')),
  );
}
```

### Use New Error Handler
```dart
// ✅ NEW WAY (user-friendly)
import '../utils/error_handler.dart';
import '../widgets/error_message_widget.dart';

catch (e) {
  // Log for debugging (only in debug mode)
  ErrorHandler.logError(e, context: 'MyScreen._loadData');
  
  // Show user-friendly message
  ErrorSnackBar.show(context, e);
}
```

---

## Error Message Examples

| Technical Error | User Sees |
|----------------|-----------|
| `SocketException: Failed host lookup` | No internet connection. Please check your network and try again. |
| `TimeoutException after 10s` | Request timed out. Please check your connection and try again. |
| `AuthException: Invalid JWT` | Authentication failed. Please sign in again. |
| `PostgrestException: relation not found` | Unable to complete request. Please try again later. |

---

## Adding Connectivity Banner to New Screens

```dart
import '../widgets/connectivity_banner.dart';
import '../services/network_connectivity_service.dart';

class MyScreen extends StatefulWidget {
  // ... your code
}

class _MyScreenState extends State<MyScreen> {
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    final hasInternet = await NetworkConnectivityService.hasInternetConnectivity();
    if (mounted && hasInternet != _isOnline) {
      setState(() => _isOnline = hasInternet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Screen'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: ConnectivityBanner(isOnline: _isOnline),
        ),
      ),
      body: _buildBody(),
    );
  }
}
```

---

## Showing Error Widget with Retry

```dart
// In your build method
if (_errorMessage != null) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ErrorMessageWidget(
        error: _errorMessage,
        onRetry: _loadData, // Your reload function
      ),
    ),
  );
}
```

---

## Testing

### Test Offline Behavior
1. Turn off WiFi/mobile data
2. Open app
3. Navigate to Scenes/Profile
4. Verify: See "No internet connection" banner
5. Verify: See friendly error message (not technical details)
6. Turn on WiFi
7. Tap "Try Again"
8. Verify: Data loads successfully

### Test Debug Logging
1. Run app in debug mode
2. Turn off WiFi
3. Trigger an error
4. Check console/logs
5. Verify: Technical details are logged
6. Verify: User doesn't see technical details

---

## Security Checklist

When implementing error handling:
- ✅ Never show database URLs
- ✅ Never show API endpoints
- ✅ Never show authentication tokens
- ✅ Never show stack traces
- ✅ Never show error codes
- ✅ Never show query parameters
- ✅ Log technical details only in debug mode
- ✅ Show simple, actionable messages to users

---

## Common Patterns

### Pattern 1: Load Data with Error Handling
```dart
Future<void> _loadData() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await _service.getData();

    setState(() {
      _data = data;
      _isLoading = false;
    });
  } catch (e) {
    ErrorHandler.logError(e, context: 'MyScreen._loadData');
    setState(() {
      _isLoading = false;
      _errorMessage = ErrorHandler.getUserFriendlyMessage(e);
    });
  }
}
```

### Pattern 2: Action with Error Snackbar
```dart
Future<void> _performAction() async {
  try {
    await _service.doSomething();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Success!')),
      );
    }
  } catch (e) {
    ErrorHandler.logError(e, context: 'MyScreen._performAction');
    
    if (mounted) {
      ErrorSnackBar.show(context, e);
    }
  }
}
```

---

## Summary

✅ **Implemented:**
- User-friendly error messages
- Connectivity banner
- Error widgets with retry
- Debug-only logging
- Security improvements

✅ **Updated Screens:**
- Home Screen
- Scenes Screen
- Profile Screen

✅ **Benefits:**
- No sensitive data exposed
- Clear user communication
- Professional appearance
- Better security
- Easier debugging
