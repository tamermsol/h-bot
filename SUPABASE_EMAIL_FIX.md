# Fix Supabase Email Confirmation Issue

## 🚨 **The Problem**
Email confirmation links redirect to `localhost:3000` instead of working with your mobile app.

## 🛠️ **Solution Options**

### **Option 1: Disable Email Confirmation (Recommended for Testing)**

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `mvmvqycvorstsftcldzs`
3. Go to **Authentication** → **Settings**
4. Find **"Enable email confirmations"**
5. **Turn it OFF**
6. Save changes

**Result**: Users can sign up and use the app immediately without email confirmation.

### **Option 2: Configure Mobile Deep Links (Advanced)**

If you want to keep email confirmation:

1. In Supabase Dashboard → **Authentication** → **URL Configuration**
2. Set **Site URL** to: `com.example.hbot://login-callback/`
3. Add **Redirect URLs**:
   - `com.example.hbot://login-callback/`
   - `com.example.hbot://auth/callback/`

### **Option 3: Use Custom Domain (Production)**

For production apps, set up a custom domain that handles the redirect.

## 🧪 **Test After Fix**

1. **Clear app data** (or uninstall/reinstall the app)
2. Try signing up with a new email
3. Should work immediately without email confirmation

## 🔧 **Alternative: Update Auth Configuration**

If you can't access Supabase dashboard, I can update the app to handle this better.

## ⚡ **Quick Test**

Try this test account (if email confirmation is disabled):
- Email: `test@example.com`
- Password: `testpassword123`

## 📱 **Current Status**

- ✅ App builds and runs
- ✅ Supabase connection works
- 🟠 Email confirmation redirects to wrong URL
- ✅ Once confirmed, authentication should work

## 🎯 **Recommended Action**

**For immediate testing**: Disable email confirmation in Supabase dashboard.
**For production**: Set up proper mobile deep links or custom domain.
