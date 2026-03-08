# Google Sign-In Cancellation Fix

## Problem
When a user starts the Google sign-in process but cancels/interrupts it (closes the Google OAuth screen), the app would sometimes show the home screen in a "guest mode" state with no devices, instead of returning to the sign-in screen.

## Root Cause
The sign-in flow wasn't properly validating that a session was actually created after the OAuth process. When the user cancelled:
1. `signInWithOAuth` would return `false`
2. The app would check if `result` was true
3. But it didn't verify that an actual session was created
4. In some edge cases, the app might navigate to HomeScreen without a valid session

## Solution
Added additional validation to ensure a valid session exists before navigating to the home screen, and improved error messaging for cancelled sign-ins.

## Changes Made

### 1. Sign-In Screen (`lib/screens/sign_in_screen.dart`)

**Added Supabase import:**
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

**Enhanced `_signInWithGoogle()` method:**
```dart
Future<void> _signInWithGoogle() async {
  setState(() => _isLoading = true);

  try {
    final result = await _authService.signInWithGoogle().timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        throw Exception('Google sign-in timed out. Please try again.');
      },
    );

    // Only navigate if sign-in was successful AND we have a session
    if (result && mounted) {
      // Double-check that we actually have a session
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // Sign-in returned true but no session - treat as cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google sign-in was cancelled. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (mounted) {
      // Sign-in returned false - user cancelled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in was cancelled. Please try again.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    // Error handling...
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Key improvements:**
- ✅ Validates that `Supabase.instance.client.auth.currentSession` is not null
- ✅ Only navigates to HomeScreen if session exists
- ✅ Shows clear message when sign-in is cancelled
- ✅ Stays on sign-in screen if no session is created

### 2. Auth Wrapper (`lib/screens/auth_wrapper.dart`)

**Improved session validation:**
```dart
// Check if we have valid auth data and session
final hasSession =
    snapshot.hasData &&
    snapshot.data!.session != null;

// If user is signed in with valid session, show home screen
if (hasSession) {
  return const HomeScreen();
}

// If user is not signed in or session is invalid, show sign in screen
return const SignInScreen();
```

**Key improvements:**
- ✅ Validates session exists before showing HomeScreen
- ✅ Removed redundant null check (session.user is never null if session exists)
- ✅ Ensures app always returns to SignInScreen if no valid session

## How It Works

### Normal Sign-In Flow:
1. User clicks "Sign in with Google"
2. Google OAuth screen opens
3. User completes sign-in
4. `signInWithOAuth` returns `true`
5. Session is created
6. App validates session exists
7. Navigate to HomeScreen ✅

### Cancelled Sign-In Flow:
1. User clicks "Sign in with Google"
2. Google OAuth screen opens
3. User cancels/closes the screen
4. `signInWithOAuth` returns `false`
5. No session is created
6. App checks session - it's null
7. Show "cancelled" message
8. Stay on SignInScreen ✅

### Edge Case (OAuth returns true but no session):
1. User clicks "Sign in with Google"
2. OAuth process completes
3. `signInWithOAuth` returns `true`
4. But session creation fails
5. App checks session - it's null
6. Show "cancelled" message
7. Stay on SignInScreen ✅

## User Experience

### Before Fix:
- User cancels Google sign-in
- App might show HomeScreen with no data
- User sees "No homes yet" / "0 devices"
- Confusing "guest mode" state

### After Fix:
- User cancels Google sign-in
- Orange snackbar: "Google sign-in was cancelled. Please try again."
- App stays on SignInScreen
- User can try again or use email/password

## Testing Checklist

- [ ] Start Google sign-in and complete it successfully - should navigate to HomeScreen
- [ ] Start Google sign-in and cancel immediately - should stay on SignInScreen with message
- [ ] Start Google sign-in and close the browser - should stay on SignInScreen with message
- [ ] Start Google sign-in and wait for timeout - should show timeout error
- [ ] Check that existing signed-in users still work correctly
- [ ] Verify AuthWrapper doesn't show HomeScreen without valid session

## Files Modified

- `lib/screens/sign_in_screen.dart`
  - Added Supabase import
  - Enhanced `_signInWithGoogle()` with session validation
  - Improved error messages

- `lib/screens/auth_wrapper.dart`
  - Improved session validation logic
  - Removed redundant null check

## Related Components

- `lib/auth/auth_repo.dart` - Handles OAuth flow
- `lib/services/auth_service.dart` - Auth service wrapper
- `lib/screens/home_screen.dart` - Destination after successful sign-in

## Notes

- The fix ensures the app never shows HomeScreen without a valid session
- Users who cancel sign-in will always return to SignInScreen
- Clear messaging helps users understand what happened
- The AuthWrapper acts as a final safety net to prevent invalid states
