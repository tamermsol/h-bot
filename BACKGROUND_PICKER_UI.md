# Background Picker - New UI

## What You'll See

When you tap "Background Image" in room/home settings, you'll see this dialog:

```
┌─────────────────────────────────────────┐
│  Room Background Image              [X] │
├─────────────────────────────────────────┤
│                                         │
│  [Current Background Preview]           │
│  (if one is selected)                   │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Choose a Default Background            │
│                                         │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│  │ 1  │ │ 2  │ │ 3  │ │ 4  │ │ 5  │   │
│  │    │ │    │ │    │ │    │ │    │   │
│  └────┘ └────┘ └────┘ └────┘ └────┘   │
│  ← Scroll horizontally →                │
│                                         │
│  (Selected one has blue border)         │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────┐  ┌──────────┐    │
│  │ 📷 Upload Custom │  │ 🗑 Remove │    │
│  └──────────────────┘  └──────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

## Features

### Default Backgrounds Gallery
- Horizontal scrollable list of 5 backgrounds
- Tap any to select instantly
- Selected background has a blue border (3px)
- Unselected backgrounds have a gray border (1px)
- Each thumbnail is 140x100 pixels

### Current Preview
- Shows the currently selected background at the top
- 150px height, full width
- Rounded corners
- Only shows if a background is selected

### Buttons

**Upload Custom** (Blue)
- Opens image picker
- Uploads to Supabase storage (if configured)
- Shows loading indicator during upload
- Shows success/error message

**Remove** (Red)
- Only shows if a background is selected
- Asks for confirmation
- Removes the background (sets to null)
- Deletes custom uploads from storage
- Keeps default backgrounds (doesn't delete assets)

## User Flow

### Selecting a Default Background
1. User taps any default background thumbnail
2. Background is selected instantly
3. Dialog closes
4. Background appears on the screen
5. No upload, no waiting

### Uploading Custom Image
1. User taps "Upload Custom"
2. Image picker opens
3. User selects image from gallery
4. Loading indicator shows
5. Image uploads to Supabase
6. Success message shows
7. Dialog closes
8. Background appears

### Removing Background
1. User taps "Remove"
2. Confirmation dialog shows
3. User confirms
4. Background is removed
5. Screen returns to default (no background)

## Error Handling

### No Supabase Bucket
- Default backgrounds still work
- "Upload Custom" will show error if bucket doesn't exist
- Error message: "Failed to upload image: Bucket not found"
- User can still use default backgrounds

### Image Load Failure
- Shows gray placeholder with image icon
- Doesn't crash the app
- User can select another background

### Network Issues
- Default backgrounds work offline (they're assets)
- Custom uploads require internet
- Shows appropriate error message

## Comparison: Before vs After

### Before
- Only "Add Background" button
- Required Supabase storage setup
- Required image upload
- Network dependent
- Could fail with bucket errors
- No preview of options

### After
- Gallery of 5 default backgrounds
- No Supabase setup required
- Instant selection
- Works offline
- No bucket errors for defaults
- Visual preview of all options
- Optional custom upload still available
