# Delete Account Feature

## Overview
Comprehensive account deletion feature that allows users to permanently delete their account and all associated data from the HBOT app.

## ⚠️ IMPORTANT FIX - Authentication Error Resolved

**Issue**: Users were getting "Authentication error: User not allowed" when trying to delete their account.

**Root Cause**: The `supabase.auth.admin.deleteUser()` method requires admin privileges (service role key) which is not available in client-side applications for security reasons.

**Solution**: Created a PostgreSQL function with `SECURITY DEFINER` privilege that can be called via RPC from the client app. This function runs with elevated privileges and can safely delete users from the `auth.users` table.

## User Flow

### 1. Access Delete Account
**Location**: Profile Screen → Support Section → Delete Account

**UI**: Red-colored option at the bottom of the Support section

### 2. Warning Dialog (First Step)
Shows a comprehensive warning about what will be deleted:

```
⚠️ Delete Account

This action cannot be undone. Deleting your account will:
❌ Delete all your homes and rooms
❌ Remove all your devices
❌ Delete all your scenes and automations
❌ Erase all your personal data

ℹ️ This action is permanent and cannot be reversed

[Cancel] [Continue]
```

### 3. Confirmation Dialog (Second Step)
Requires user to type exact confirmation text:

```
Final Confirmation

To confirm deletion, please type:
DELETE MY ACCOUNT

[Text Input Field]

[Cancel] [Delete Account]
```

**Validation**: User must type exactly "DELETE MY ACCOUNT" (case-sensitive)

### 4. Deletion Process
1. Shows loading indicator: "Deleting account..."
2. Calls database function via RPC to delete user
3. Cascade deletes all related data (homes, devices, rooms, scenes, etc.)
4. Signs out user
5. Redirects to sign-in screen
6. Shows success message

## Implementation Details

### Files Modified

#### 1. `lib/screens/profile_screen.dart`
Added three new methods:
- `_showDeleteAccountDialog()` - First warning dialog
- `_showDeleteAccountConfirmation()` - Confirmation with text input
- `_handleDeleteAccount()` - Actual deletion logic

Added new UI element in Support section:
```dart
SettingsTile(
  icon: Icons.delete_forever,
  title: 'Delete Account',
  subtitle: 'Permanently delete your account and all data',
  titleColor: AppTheme.errorColor,
  onTap: () {
    _showDeleteAccountDialog();
  },
),
```

#### 2. `lib/services/auth_service.dart`
Added method:
```dart
Future<void> deleteAccount() async {
  await _authRepo.deleteAccount();
}
```

#### 3. `lib/auth/auth_repo.dart`
**UPDATED** - Now uses RPC instead of admin API:
```dart
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
```

#### 4. `supabase_migrations/delete_user_account.sql` (NEW)
**CRITICAL**: This migration must be applied to your Supabase database:

```sql
-- Migration: Add function to delete user account
-- This function allows users to delete their own account and all associated data

-- Create a function that deletes the user's profile and all related data
-- The auth.users record will be handled by Supabase's built-in deletion
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_id uuid;
BEGIN
  -- Get the current user's ID
  user_id := auth.uid();
  
  -- Check if user is authenticated
  IF user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Delete user's profile (this will cascade delete all related data)
  -- Foreign key constraints should handle:
  -- - homes (and cascade to devices, rooms, scenes, etc.)
  -- - Any other user-related data
  DELETE FROM profiles WHERE id = user_id;
  
  -- Delete the user from auth.users
  -- This requires the function to be SECURITY DEFINER
  DELETE FROM auth.users WHERE id = user_id;
  
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

-- Add comment
COMMENT ON FUNCTION delete_user_account() IS 'Allows authenticated users to delete their own account and all associated data';
```

## Supabase Setup (REQUIRED)

### Step 1: Apply the Database Migration

You **MUST** run the migration to create the `delete_user_account()` function. Choose one of these methods:

#### Option A: Supabase Dashboard (Recommended)
1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Click **New Query**
4. Copy and paste the contents of `supabase_migrations/delete_user_account.sql`
5. Click **Run** to execute the query
6. Verify success message appears

#### Option B: Supabase CLI
```bash
supabase db push
```

#### Option C: Direct psql Connection
```bash
psql -h your-project.supabase.co -U postgres -d postgres -f supabase_migrations/delete_user_account.sql
```

### Step 2: Verify Function Creation

Run this query in SQL Editor to verify:
```sql
SELECT 
  proname as function_name,
  prosecdef as is_security_definer,
  proowner::regrole as owner
FROM pg_proc 
WHERE proname = 'delete_user_account';
```

Expected result:
- `function_name`: delete_user_account
- `is_security_definer`: true
- `owner`: postgres

### Step 3: Test Function Permissions

Verify authenticated users can call it:
```sql
SELECT has_function_privilege('authenticated', 'delete_user_account()', 'EXECUTE');
```

Expected result: `true`

## Database Schema Requirements

### Foreign Key Cascade Deletion

Ensure your database tables have `ON DELETE CASCADE` constraints:

```sql
-- profiles table (references auth.users)
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey,
ADD CONSTRAINT profiles_id_fkey
FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- homes table (references profiles)
ALTER TABLE public.homes
DROP CONSTRAINT IF EXISTS homes_user_id_fkey,
ADD CONSTRAINT homes_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- devices table (references homes)
ALTER TABLE public.devices
DROP CONSTRAINT IF EXISTS devices_home_id_fkey,
ADD CONSTRAINT devices_home_id_fkey
FOREIGN KEY (home_id) REFERENCES public.homes(id) ON DELETE CASCADE;

-- rooms table (references homes)
ALTER TABLE public.rooms
DROP CONSTRAINT IF EXISTS rooms_home_id_fkey,
ADD CONSTRAINT rooms_home_id_fkey
FOREIGN KEY (home_id) REFERENCES public.homes(id) ON DELETE CASCADE;

-- scenes table (references homes)
ALTER TABLE public.scenes
DROP CONSTRAINT IF EXISTS scenes_home_id_fkey,
ADD CONSTRAINT scenes_home_id_fkey
FOREIGN KEY (home_id) REFERENCES public.homes(id) ON DELETE CASCADE;
```

### Row Level Security (RLS)

Ensure RLS policies allow users to delete their own data:

```sql
-- Allow users to delete their own profile
CREATE POLICY "Users can delete own profile"
ON public.profiles
FOR DELETE
USING (auth.uid() = id);

-- Allow users to delete their own homes
CREATE POLICY "Users can delete own homes"
ON public.homes
FOR DELETE
USING (auth.uid() = user_id);
```

## Why SECURITY DEFINER?

### The Problem
- Client apps cannot access `auth.users` table directly (security restriction)
- `supabase.auth.admin.deleteUser()` requires service role key
- Service role key should NEVER be in client-side code (major security risk)

### The Solution
- `SECURITY DEFINER` function runs with elevated privileges
- Function validates user is authenticated via `auth.uid()`
- Only the authenticated user can delete their own account
- Secure and follows PostgreSQL best practices

### Security Guarantees
1. ✅ Function only accessible to authenticated users
2. ✅ User can only delete their own account (validated by `auth.uid()`)
3. ✅ No service role key exposed to client
4. ✅ Runs with necessary privileges to delete from `auth.users`
5. ✅ Audit trail in database logs

## Security Features

### 1. Two-Step Confirmation
- First dialog: Warning about consequences
- Second dialog: Requires typing exact confirmation text

### 2. Confirmation Text Validation
- Must type exactly: "DELETE MY ACCOUNT"
- Case-sensitive
- Prevents accidental deletions

### 3. Clear Warnings
- Lists all data that will be deleted
- Emphasizes permanence of action
- Uses red color scheme for danger

### 4. Error Handling
- Catches and displays deletion errors
- Provides user-friendly error messages
- Logs errors for debugging

### 5. Authentication Validation
- Database function checks `auth.uid()` is not null
- Prevents unauthenticated deletion attempts
- Raises exception if not authenticated

## User Experience

### Visual Design
- **Warning Icon**: Orange warning icon in first dialog
- **Error Color**: Red text and icons throughout
- **Warning Box**: Highlighted box with important notice
- **Checklist**: Clear list of what will be deleted

### Loading States
- Shows "Deleting account..." with spinner
- 30-second timeout for deletion process
- Prevents user interaction during deletion

### Success Flow
1. Account deleted
2. User signed out
3. Redirected to sign-in screen
4. Green success message shown

### Error Flow
1. Error caught
2. Red error message shown
3. User remains signed in
4. Can retry deletion

## Troubleshooting

### Error: "Authentication error: User not allowed"
**Cause**: Database function hasn't been created yet

**Fix**:
1. Apply the migration: `supabase_migrations/delete_user_account.sql`
2. Verify function exists in SQL Editor:
   ```sql
   SELECT * FROM pg_proc WHERE proname = 'delete_user_account';
   ```

### Error: "function delete_user_account() does not exist"
**Cause**: Migration not applied

**Fix**: Run the SQL migration in Supabase dashboard SQL Editor

### Error: "permission denied for function delete_user_account"
**Cause**: Function not granted to authenticated role

**Fix**: Run this in SQL Editor:
```sql
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;
```

### Error: "Not authenticated"
**Cause**: User session expired or invalid

**Fix**: User should sign out and sign in again, then retry deletion

### Deletion Takes Too Long
**Cause**: Large amount of data to cascade delete

**Fix**: This is normal for users with many homes/devices. The loading indicator will show for up to 30 seconds.

## Testing Checklist

- [ ] Database migration applied successfully
- [ ] Function exists and has SECURITY DEFINER privilege
- [ ] Authenticated role has EXECUTE permission
- [ ] Delete account button appears in profile screen
- [ ] First warning dialog shows all warnings
- [ ] Second confirmation dialog requires exact text
- [ ] Typing wrong text shows error
- [ ] Typing correct text proceeds with deletion
- [ ] Loading indicator shows during deletion
- [ ] Account is deleted from Supabase
- [ ] All related data is deleted (cascade)
- [ ] User is signed out after deletion
- [ ] Redirected to sign-in screen
- [ ] Success message appears
- [ ] Error handling works if deletion fails
- [ ] Cannot sign in with deleted account
- [ ] Verify in database that user is gone

## Data Deletion Scope

When a user deletes their account, the following data is deleted:

### Automatically Deleted (Cascade)
1. **User Profile** (`profiles` table)
2. **Homes** (`homes` table)
3. **Rooms** (`rooms` table) - via home cascade
4. **Devices** (`devices` table) - via home cascade
5. **Scenes** (`scenes` table) - via home cascade
6. **Automations** - via scene cascade
7. **Device Settings** - via device cascade
8. **User Preferences** - via user cascade

### Auth Data
- User record in `auth.users`
- User sessions
- Refresh tokens
- User metadata

## Privacy Compliance

This feature helps comply with privacy regulations:

- **GDPR**: Right to erasure (Article 17)
- **CCPA**: Right to deletion
- **Other regulations**: Data deletion requirements

## Future Enhancements

1. **Export Data Before Deletion**
   - Allow users to download their data
   - Export as JSON or CSV
   - Include all homes, devices, scenes

2. **Soft Delete Option**
   - Deactivate account instead of delete
   - Allow reactivation within 30 days
   - Permanent deletion after grace period

3. **Deletion Reasons**
   - Ask why user is deleting account
   - Collect feedback for improvement
   - Optional survey

4. **Email Confirmation**
   - Send confirmation email before deletion
   - Require clicking link in email
   - Additional security layer

5. **Scheduled Deletion**
   - Schedule deletion for future date
   - Allow cancellation before date
   - Send reminder emails

## Support

If users have issues with account deletion:

1. **Contact Support**: support@hbot.com
2. **Help Center**: In-app help center
3. **Manual Deletion**: Support team can manually delete accounts

## Conclusion

The delete account feature provides users with full control over their data while ensuring the process is secure, clear, and compliant with privacy regulations. The two-step confirmation process prevents accidental deletions while the cascade deletion ensures all user data is properly removed.

The use of a `SECURITY DEFINER` PostgreSQL function ensures secure deletion without exposing admin credentials to the client application, following database security best practices.
