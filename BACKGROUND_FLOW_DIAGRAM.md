# Background Image Flow Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         User Interface                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Room/Home Screen                                            │
│  └─> Settings Icon                                           │
│       └─> Background Image Dialog                            │
│            ├─> BackgroundImagePicker Widget                  │
│            │    ├─> Default Gallery (5 thumbnails)           │
│            │    ├─> Upload Custom Button                     │
│            │    └─> Remove Button                            │
│            │                                                  │
│            └─> BackgroundImageService                        │
│                 ├─> isDefaultBackground()                    │
│                 ├─> pickImageFromGallery()                   │
│                 ├─> uploadBackgroundImage()                  │
│                 └─> deleteBackgroundImage()                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  Asset Images    │         │  Supabase        │          │
│  │  (Default)       │         │  Storage         │          │
│  │                  │         │  (Custom)        │          │
│  │  assets/images/  │         │  background-     │          │
│  │  backgrounds/    │         │  images/         │          │
│  │  - default_1.jpg │         │  - user uploads  │          │
│  │  - default_2.jpg │         │                  │          │
│  │  - default_3.jpg │         │  (Optional)      │          │
│  │  - default_4.jpg │         │                  │          │
│  │  - default_5.jpg │         │                  │          │
│  └──────────────────┘         └──────────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Display Layer                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  BackgroundContainer Widget                                  │
│  ├─> Checks if URL is default background                    │
│  ├─> If default: Image.asset()                              │
│  ├─> If custom: Image.network()                             │
│  └─> Applies overlay and displays content                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## User Flow: Selecting Default Background

```
User Opens Room
      │
      ▼
Taps Settings Icon
      │
      ▼
Taps "Background Image"
      │
      ▼
Dialog Opens
├─> Shows current background (if any)
├─> Shows gallery of 5 default backgrounds
└─> Shows buttons (Upload Custom, Remove)
      │
      ▼
User Taps Default Background #3
      │
      ▼
onImageSelected("assets/images/backgrounds/default_3.jpg")
      │
      ▼
Update Database
├─> room.backgroundImageUrl = "assets/images/backgrounds/default_3.jpg"
└─> Save to Supabase
      │
      ▼
Reload Room Data
      │
      ▼
BackgroundContainer Renders
├─> Detects it's a default background
├─> Uses Image.asset()
└─> Shows background instantly
      │
      ▼
Done! ✅
```

## User Flow: Uploading Custom Image

```
User Opens Room
      │
      ▼
Taps Settings Icon
      │
      ▼
Taps "Background Image"
      │
      ▼
Dialog Opens
      │
      ▼
User Taps "Upload Custom"
      │
      ▼
Image Picker Opens
      │
      ▼
User Selects Image from Gallery
      │
      ▼
BackgroundImageService.uploadBackgroundImage()
├─> Read image file
├─> Generate unique filename
├─> Upload to Supabase Storage
│   └─> Path: userId/room/roomId/timestamp.jpg
└─> Get public URL
      │
      ▼
Delete Old Image (if exists and not default)
      │
      ▼
onImageSelected(publicUrl)
      │
      ▼
Update Database
├─> room.backgroundImageUrl = publicUrl
└─> Save to Supabase
      │
      ▼
Reload Room Data
      │
      ▼
BackgroundContainer Renders
├─> Detects it's a network image
├─> Uses Image.network()
└─> Shows background after download
      │
      ▼
Done! ✅
```

## Error Handling Flow

```
Upload Custom Image
      │
      ▼
Try Upload to Supabase
      │
      ├─> Success
      │   └─> Show success message
      │       └─> Update UI
      │
      └─> Failure (e.g., Bucket not found)
          └─> Catch error
              └─> Show error message
                  └─> User can still use default backgrounds
                      └─> No app crash ✅
```

## Data Flow

```
┌──────────────┐
│ User Action  │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ BackgroundImagePicker│
│ - Handles UI         │
│ - Shows gallery      │
│ - Handles selection  │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────────┐
│ BackgroundImageService   │
│ - Validates image type   │
│ - Handles upload/delete  │
│ - Manages storage        │
└──────┬───────────────────┘
       │
       ├─> Default Background
       │   └─> Return asset path
       │       └─> No upload needed
       │
       └─> Custom Upload
           └─> Upload to Supabase
               └─> Return public URL
                   │
                   ▼
           ┌──────────────────┐
           │ Supabase Storage │
           │ - Store image    │
           │ - Generate URL   │
           └──────┬───────────┘
                  │
                  ▼
           ┌──────────────────┐
           │ Database Update  │
           │ - Save URL       │
           └──────┬───────────┘
                  │
                  ▼
           ┌──────────────────────┐
           │ BackgroundContainer  │
           │ - Detect image type  │
           │ - Render background  │
           └──────────────────────┘
```

## Component Relationships

```
RoomsScreen / HomeDashboardScreen
    │
    ├─> Uses BackgroundContainer
    │   └─> Displays background behind content
    │
    └─> Shows BackgroundImagePicker in dialog
        │
        ├─> Uses BackgroundImageService
        │   ├─> isDefaultBackground()
        │   ├─> pickImageFromGallery()
        │   ├─> uploadBackgroundImage()
        │   └─> deleteBackgroundImage()
        │
        └─> Callbacks
            └─> onImageSelected(url)
                └─> Updates database
                    └─> Reloads data
                        └─> BackgroundContainer re-renders
```

## Key Design Decisions

1. **Asset vs Network Detection**
   - Check if URL starts with "assets/"
   - Use appropriate Image widget
   - No network call for defaults

2. **No Deletion of Defaults**
   - Default backgrounds are app assets
   - Can't and shouldn't be deleted
   - Only custom uploads are deleted

3. **Graceful Degradation**
   - If Supabase bucket doesn't exist
   - Default backgrounds still work
   - Custom upload shows error but doesn't crash

4. **Instant Selection**
   - Default backgrounds load instantly
   - No upload, no waiting
   - Better UX

5. **Optional Custom Upload**
   - Advanced users can upload
   - Requires Supabase setup
   - Not required for basic functionality
