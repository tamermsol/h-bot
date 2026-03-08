# Smart Home App - Authentication Setup

This document outlines the authentication features implemented in the Smart Home app based on the Figma design.

## Features Implemented

### 1. Sign In Screen (`lib/screens/sign_in_screen.dart`)
- **Email/Password Authentication**: Users can sign in with their email and password
- **Google Sign-In**: One-tap Google authentication
- **Form Validation**: Email format and password length validation
- **Loading States**: Visual feedback during authentication
- **Error Handling**: User-friendly error messages
- **Forgot Password**: Link to reset password (placeholder)
- **Navigation**: Link to sign up screen

### 2. Sign Up Screen (`lib/screens/sign_up_screen.dart`)
- **Email/Password Registration**: Users can create accounts with email and password
- **Google Sign-Up**: One-tap Google account creation
- **Password Confirmation**: Ensures passwords match
- **Form Validation**: Comprehensive input validation
- **Terms & Privacy**: Legal compliance notice
- **Navigation**: Link back to sign in screen

### 3. Authentication Service (`lib/services/auth_service.dart`)
- **Firebase Auth Integration**: Complete Firebase Authentication setup
- **Google Sign-In Integration**: Google authentication provider
- **Error Handling**: Comprehensive error message mapping
- **State Management**: Authentication state stream
- **Password Reset**: Email-based password reset functionality

### 4. Authentication Wrapper (`lib/screens/auth_wrapper.dart`)
- **State-Based Routing**: Automatically routes users based on auth state
- **Loading States**: Shows loading indicator during auth checks
- **Seamless Navigation**: Smooth transitions between auth and app screens

## Design Implementation

### Colors (Based on Figma Design)
- **Background**: `#1C1C1E` (Dark theme)
- **Primary Accent**: `#FF9500` (Orange from Figma)
- **Text Colors**: White with various opacities
- **Input Fields**: Custom styling matching Figma design

### Typography
- **Font Family**: System fonts (PingFang SC on iOS, similar on other platforms)
- **Font Weights**: Semibold (600) for headings, Regular (400) for body text
- **Font Sizes**: 32px for main titles, 16px for body text, 14px for secondary text

### UI Components
- **Smart Input Fields**: Custom input fields with consistent styling
- **Buttons**: Rounded corners (12px radius) with proper spacing
- **Loading Indicators**: Consistent with app theme
- **Error Messages**: Toast notifications with red background

## Firebase Setup Required

To complete the authentication setup, you need to:

1. **Create a Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Enable Authentication

2. **Configure Authentication Providers**:
   - Enable Email/Password authentication
   - Enable Google Sign-In provider
   - Add your app's SHA-1 fingerprint for Android

3. **Update Firebase Configuration**:
   - Replace placeholder values in `lib/firebase_options.dart`
   - Add your actual Firebase project configuration

4. **Add Google Logo**:
   - Replace `assets/images/google_logo.png` with the actual Google logo
   - Download from [Google Brand Resources](https://developers.google.com/identity/branding-guidelines)

## File Structure

```
lib/
├── screens/
│   ├── auth_wrapper.dart          # Authentication state management
│   ├── sign_in_screen.dart        # Sign in UI
│   ├── sign_up_screen.dart        # Sign up UI
│   └── home_screen.dart           # Main app screen (updated with sign out)
├── services/
│   └── auth_service.dart          # Authentication business logic
├── widgets/
│   └── smart_input_field.dart     # Custom input field component
├── firebase_options.dart          # Firebase configuration
└── main.dart                      # App entry point with Firebase init
```

## Usage

1. **First Time Users**: Directed to sign in screen
2. **Sign Up Flow**: Email/password or Google sign up
3. **Sign In Flow**: Email/password or Google sign in
4. **Authenticated Users**: Automatically directed to home screen
5. **Sign Out**: Available in home screen menu

## Security Features

- **Input Validation**: Client-side validation for all inputs
- **Error Handling**: Secure error messages without exposing sensitive info
- **State Management**: Proper authentication state handling
- **Auto-logout**: Handles authentication state changes automatically

## Next Steps

1. Set up actual Firebase project
2. Configure authentication providers
3. Add proper Google logo asset
4. Test authentication flow
5. Add forgot password functionality
6. Implement user profile management
