import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthRepo {
  final SupabaseClient supabase = Supabase.instance.client;

  // Store pending profile data to avoid race conditions during signup
  final Map<String, Map<String, String?>> _pendingProfileData = {};

  AuthRepo() {
    // Listen for auth state changes to create profiles for new users
    _setupAuthListener();
  }

  /// Setup auth state listener to handle profile creation
  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final user = data.session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        // Check if this is a new user (no profile exists)
        try {
          final existingProfile = await supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (existingProfile == null) {
            // New user - create profile with available data
            String? fullName;
            String? phoneNumber;

            // Check if we have pending profile data from signup
            final pendingData = _pendingProfileData[user.id];
            if (pendingData != null) {
              fullName = pendingData['fullName'];
              phoneNumber = pendingData['phoneNumber'];
              // Clean up pending data
              _pendingProfileData.remove(user.id);
            } else {
              // Try to get full name from user metadata (Google sign-in)
              if (user.userMetadata?['full_name'] != null) {
                fullName = user.userMetadata!['full_name'] as String?;
              } else if (user.userMetadata?['name'] != null) {
                fullName = user.userMetadata!['name'] as String?;
              }
            }

            debugPrint('🆕 New user detected, creating profile...');
            await _createProfile(user.id, fullName, phoneNumber);
          }
        } catch (e) {
          debugPrint('❌ Error checking/creating profile for new user: $e');
        }
      }
    });
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      debugPrint('🔐 Starting email sign-in for: $email');

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ Sign-in response received: ${response.user?.id}');
      return response;
    } catch (e) {
      debugPrint('❌ Sign-in error: $e');
      throw _handleAuthException(e);
    }
  }

  /// Sign up with email and password, optionally creating a profile
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      debugPrint('🔐 Starting email sign-up for: $email');

      // Sign up with email and password
      // Supabase will automatically send a confirmation email if "Confirm email" is enabled
      // The email template should include {{ .Token }} to display the OTP code
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone_number': phoneNumber},
      );

      debugPrint('📧 Sign-up response received: ${response.user?.id}');
      debugPrint('📧 Email confirmed: ${response.user?.emailConfirmedAt}');

      // Store the profile data for the auth state change listener to use
      // This avoids race conditions between signup and auth state change
      if (response.user != null) {
        _pendingProfileData[response.user!.id] = {
          'fullName': fullName,
          'phoneNumber': phoneNumber,
        };
      }

      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google OAuth using Supabase
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google OAuth sign-in...');

      // Use Supabase OAuth flow with timeout
      final response = await supabase.auth
          .signInWithOAuth(
            OAuthProvider.google,
            redirectTo: 'com.example.hbot://login-callback/',
            authScreenLaunchMode: LaunchMode.externalApplication,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏰ Google OAuth timeout after 30 seconds');
              throw Exception('Google sign-in timed out. Please try again.');
            },
          );

      debugPrint('📱 OAuth response received: $response');
      return response;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Get current user
  User? get currentUser => supabase.auth.currentUser;

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Resend email confirmation
  Future<void> resendEmailConfirmation(String email) async {
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Change password for current user
  /// Only works for users who signed up with email/password
  Future<void> changePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      debugPrint('🔐 Changing password for user: ${user.id}');

      // Update password using Supabase auth
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('Failed to update password');
      }

      debugPrint('✅ Password changed successfully');
    } catch (e) {
      debugPrint('❌ Failed to change password: $e');
      throw _handleAuthException(e);
    }
  }

  /// Check if current user signed in with email/password
  /// Returns true if user can change password (email auth)
  /// Returns false if user signed in with OAuth (Google, etc.)
  bool canChangePassword() {
    final user = currentUser;
    if (user == null) return false;

    // Check if user has email auth provider
    // OAuth users will have 'google', 'github', etc. as their provider
    final appMetadata = user.appMetadata;
    final provider = appMetadata['provider'] as String?;

    debugPrint('🔍 User auth provider: $provider');
    return provider == 'email';
  }

  /// Verify OTP code sent to email (uses Supabase Auth built-in OTP)
  Future<void> verifyOtp(String email, String token) async {
    try {
      debugPrint('🔐 Verifying OTP for email: $email');

      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );

      if (response.user == null) {
        throw Exception('Invalid or expired verification code. Please try again.');
      }

      debugPrint('✅ OTP verified successfully');
    } catch (e) {
      debugPrint('❌ OTP verification failed: $e');
      throw _handleAuthException(e);
    }
  }

  /// Resend OTP to email
  Future<void> resendOtp(String email) async {
    try {
      debugPrint('📧 Resending OTP to: $email');
      await supabase.auth.resend(type: OtpType.signup, email: email);
      debugPrint('✅ OTP resent successfully');
    } catch (e) {
      debugPrint('❌ Failed to resend OTP: $e');
      throw _handleAuthException(e);
    }
  }

  /// Send password reset OTP
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      debugPrint('📧 Sending password reset OTP to: $email');
      // This uses Supabase's built-in recovery flow which sends an OTP via custom SMTP
      await supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset OTP sent');
    } catch (e) {
      debugPrint('❌ Failed to send reset OTP: $e');
      throw _handleAuthException(e);
    }
  }

  /// Verify password reset OTP and update password
  Future<void> verifyPasswordResetOtp(
    String email,
    String token,
    String newPassword,
  ) async {
    try {
      debugPrint('🔐 Verifying password reset OTP for: $email');

      // Verify OTP for password recovery
      final response = await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: token,
      );

      if (response.user == null) {
        throw Exception('Invalid or expired reset code. Please try again.');
      }

      debugPrint('✅ OTP verified, updating password');

      // Update the password
      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      debugPrint('✅ Password updated successfully');
    } catch (e) {
      debugPrint('❌ Password reset failed: $e');
      throw _handleAuthException(e);
    }
  }

  /// Create profile for new user with validation
  Future<void> _createProfile(
    String userId,
    String? fullName,
    String? phoneNumber,
  ) async {
    try {
      debugPrint('🔄 Creating profile for user: $userId');
      debugPrint('📝 Full name: "$fullName"');
      debugPrint('📞 Phone: "$phoneNumber"');

      // Validate inputs (but allow empty/null values)
      if (fullName != null &&
          fullName.isNotEmpty &&
          !Profile.isValidFullName(fullName)) {
        throw Exception('Invalid full name provided');
      }

      if (phoneNumber != null &&
          phoneNumber.isNotEmpty &&
          !Profile.isValidPhoneNumber(phoneNumber)) {
        throw Exception(
          'Invalid phone number format. Use E.164 format (e.g., +1234567890)',
        );
      }

      // Prepare profile data - only include non-empty values
      final profileData = <String, dynamic>{
        'id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only add full_name if it's not empty
      if (fullName != null && fullName.trim().isNotEmpty) {
        profileData['full_name'] = fullName.trim();
      }

      // Only add phone_number if it's not empty
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        profileData['phone_number'] = phoneNumber.trim();
      }

      debugPrint('📤 Inserting profile data: $profileData');

      // Use upsert to handle potential race conditions
      await supabase.from('profiles').upsert(profileData);

      debugPrint('✅ Profile created/updated successfully for user: $userId');
    } catch (e) {
      debugPrint('❌ Failed to create profile: $e');

      // Always rethrow to see what's going wrong
      rethrow;
    }
  }

  /// Get current user's profile
  Future<Profile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to get profile: $e');
      return null;
    }
  }

  /// Update current user's profile
  Future<Profile?> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Validate inputs
      if (!Profile.isValidFullName(fullName)) {
        throw Exception('Invalid full name provided');
      }

      if (!Profile.isValidPhoneNumber(phoneNumber)) {
        throw Exception(
          'Invalid phone number format. Use E.164 format (e.g., +1234567890)',
        );
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName.trim();
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber.trim();

      final response = await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', user.id)
          .select()
          .single();

      debugPrint('✅ Profile updated successfully');
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Failed to update profile: $e');
      rethrow;
    }
  }

  /// Handle authentication exceptions
  String _handleAuthException(dynamic e) {
    debugPrint('Auth error: $e');

    if (e is AuthException) {
      debugPrint('AuthException message: ${e.message}');
      switch (e.message) {
        case 'Invalid login credentials':
          return 'Invalid email or password. Please try again.';
        case 'Email not confirmed':
          return 'Please check your email and confirm your account.';
        case 'User already registered':
          return 'An account with this email already exists.';
        case 'Password should be at least 6 characters':
          return 'Password must be at least 6 characters long.';
        case 'signup disabled':
          return 'Sign up is currently disabled. Please contact support.';
        default:
          return 'Authentication error: ${e.message}';
      }
    }

    if (e is PostgrestException) {
      debugPrint('PostgrestException: ${e.message}');
      return 'Database error: ${e.message}';
    }

    return 'An unexpected error occurred: $e';
  }

  /// Delete user account
  /// This will delete the user from auth.users and cascade delete all related data
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      debugPrint('🗑️ Deleting account for user: ${user.id}');

      // Call the database function to delete the user account
      // This function has SECURITY DEFINER privilege to delete from auth.users
      await supabase.rpc('delete_user_account');

      debugPrint('✅ Account deletion initiated');

      // Sign out the user (the account is already deleted)
      await supabase.auth.signOut();

      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      throw _handleAuthException(e);
    }
  }
}
