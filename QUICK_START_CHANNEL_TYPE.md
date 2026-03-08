# Quick Start: Channel Type Feature

## 🚀 3 Steps to Enable Channel Types

### Step 1: Run Database Migration (5 minutes)

1. Open your Supabase project dashboard
2. Go to **SQL Editor** (left sidebar)
3. Click **New Query**
4. Copy and paste this entire file: `supabase_migrations/add_channel_type_simple.sql`
5. Click **Run** (or press Ctrl+Enter)
6. Wait for "Success" message

**Expected Output:**
```
Success. No rows returned

Query Results:
column_name   | data_type | column_default
--------------+-----------+----------------
channel_type  | text      | 'light'::text
```

### Step 2: Restart Your Flutter App

```bash
# Stop the app
# Then restart it
flutter run
```

Or just hot restart in your IDE (Shift+R in VS Code)

### Step 3: Test It!

1. Open any relay device in your app
2. Long-press on any channel
3. You'll see a dialog with:
   - **Rename Channel**
   - **Light** (💡) ← Default, currently selected
   - **Switch** (⚡)
4. Tap "Switch" to change the icon
5. See the icon change from 💡 to ⚡

## ✅ That's It!

Your channel type feature is now working!

## 🎯 What You Can Do Now

- **Change any channel to Switch**: Long-press → Select "Switch"
- **Change back to Light**: Long-press → Select "Light"
- **Rename channels**: Long-press → Select "Rename Channel"
- **Mix and match**: Some channels as lights, others as switches

## 📱 Visual Guide

### Before (All Default Light)
```
┌─────────┐  ┌─────────┐
│    💡    │  │    💡    │
│Channel 1│  │Channel 2│
└─────────┘  └─────────┘
```

### After (Mixed Types)
```
┌─────────┐  ┌─────────┐
│    💡    │  │    ⚡    │
│ Light 1 │  │ Switch 2│
└─────────┘  └─────────┘
```

## 🐛 Troubleshooting

### Error: "Could not find the function"
→ **Solution**: Run the migration again (Step 1)

### Icons not changing
→ **Solution**: Restart the app (Step 2)

### Changes not saving
→ **Solution**: Check Supabase connection

## 📚 More Info

- Full documentation: `CHANNEL_TYPE_FEATURE.md`
- Testing guide: `CHANNEL_TYPE_TESTING_GUIDE.md`
- API reference: `CHANNEL_TYPE_API_REFERENCE.md`
- Fix guide: `FIX_CHANNEL_TYPE_ISSUES.md`

## 🎉 Success Indicators

✅ No error messages when changing type  
✅ Icon changes immediately (💡 ↔ ⚡)  
✅ Changes persist after closing/reopening  
✅ Can rename channels and keep type  

---

**Need Help?** Check `FIX_CHANNEL_TYPE_ISSUES.md` for detailed troubleshooting.
