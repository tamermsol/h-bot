import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_repo.dart';
import '../models/profile.dart';

class AuthService {
  final AuthRepo _authRepo = AuthRepo();

  // Get current user
  User? get currentUser => _authRepo.currentUser;

  // Auth state changes stream
  Stream<AuthState> get authStateChanges => _authRepo.authStateChanges;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _authRepo.signInWithEmail(email, password);
  }

  // Register with email and password
  Future<AuthResponse> registerWithEmailAndPassword(
    String email,
    String password, {
    String? fullName,
    String? phoneNumber,
  }) async {
    return await _authRepo.signUpWithEmail(
      email,
      password,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    return await _authRepo.signInWithGoogle();
  }

  // Sign out
  Future<void> signOut() async {
    await _authRepo.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _authRepo.resetPassword(email);
  }

  // Get current user profile
  Future<Profile?> getCurrentProfile() async {
    return await _authRepo.getCurrentProfile();
  }

  // Update current user profile
  Future<Profile?> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    return await _authRepo.updateProfile(
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
  }

  // Resend email confirmation
  Future<void> resendEmailConfirmation(String email) async {
    await _authRepo.resendEmailConfirmation(email);
  }

  // Change password
  Future<void> changePassword(String newPassword) async {
    await _authRepo.changePassword(newPassword);
  }

  // Check if user can change password (email auth only)
  bool canChangePassword() {
    return _authRepo.canChangePassword();
  }

  // Verify OTP
  Future<void> verifyOtp(String email, String token) async {
    await _authRepo.verifyOtp(email, token);
  }

  // Resend OTP
  Future<void> resendOtp(String email) async {
    await _authRepo.resendOtp(email);
  }

  // Verify password reset OTP and update password
  Future<void> verifyPasswordResetOtp(
    String email,
    String token,
    String newPassword,
  ) async {
    await _authRepo.verifyPasswordResetOtp(email, token, newPassword);
  }

  // Delete user account
  Future<void> deleteAccount() async {
    await _authRepo.deleteAccount();
  }
}
