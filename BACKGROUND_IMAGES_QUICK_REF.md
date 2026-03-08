# Background Images - Quick Reference

## 🚀 Quick Start (3 Steps)

### 1. Run Migration
```bash
# In Supabase SQL Editor, run:
supabase_migrations/add_background_images.sql
```

### 2. Verify Storage
- Go to Supabase Dashboard → Storage
- Confirm `background-images` bucket exists and is public

### 3. Test in App
- Rooms: Tap ⋮ on room card → "Background Image"
- Dashboard: Tap ⚙️ in header → "Dashboard Background"

## 📍 Where to Find Things

### Add Room Background
```
Rooms Screen → Room Card → ⋮ Menu → "Background Image"
```

### Add Dashboard Background
```
Home Dashboard → ⚙️ Settings → "Dashboard Background"
```

## 🔑 Key Files

| Purpose | File |
|---------|------|
| Migration | `supabase_migrations/add_background_images.sql` |
| Image Service | `lib/services/background_image_service.dart` |
| Picker Widget | `lib/widgets/background_image_picker.dart` |
| Display Widget | `lib/widgets/background_container.dart` |
| Room Model | `lib/models/room.dart` |
| Home Model | `lib/models/home.dart` |

## 🎨 Features at a Glance

✅ Upload images from gallery  
✅ Change existing backgrounds  
✅ Remove backgrounds  
✅ Auto-resize (1920x1080, 85% quality)  
✅ Gradient overlay for readability  
✅ User-specific storage  
✅ Automatic cleanup  

## 🔐 Storage Path Format

```
background-images/{user_id}/{type}/{entity_id}/{timestamp}.{ext}
```

Example:
```
background-images/abc123/room/room456/1708617600000.jpg
background-images/abc123/home/home789/1708617601000.jpg
```

## 💡 Tips

- Images are automatically optimized
- Old images are deleted when changing
- Works offline (cached by Flutter)
- Supports JPG, PNG, and other common formats
- No size limit (but optimized to 1920x1080)

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Upload fails | Check internet & Supabase quota |
| Image not showing | Verify bucket is public |
| Permission error | Ensure user is authenticated |
| Slow loading | Images are cached after first load |

## 📱 Platform Notes

**iOS**: Add photo library permission to Info.plist  
**Android**: Permissions handled automatically  
**Web**: Works with file picker  

## ✨ That's It!

Simple, elegant, and ready to use. Enjoy customizing your smart home! 🏠
