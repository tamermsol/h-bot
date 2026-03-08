# Download Default Background Images

## Quick Setup

Here are direct links to free, high-quality smart home themed backgrounds from Unsplash:

### Option 1: Download Manually

1. Create the folder:
```cmd
mkdir assets\images\backgrounds
```

2. Download these images (right-click → Save As):

**default_1.jpg** - Modern Smart Home Living Room
https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1920&q=80

**default_2.jpg** - Dark Modern Interior
https://images.unsplash.com/photo-1556912172-45b7abe8b7e1?w=1920&q=80

**default_3.jpg** - Smart Home Office
https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1920&q=80

**default_4.jpg** - Modern Kitchen
https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1920&q=80

**default_5.jpg** - Cozy Living Space
https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1920&q=80

3. Save each image with the exact filename shown above into `assets/images/backgrounds/`

### Option 2: Use PowerShell to Download

Run this PowerShell script:

```powershell
# Create directory
New-Item -ItemType Directory -Force -Path "assets\images\backgrounds"

# Download images
$images = @{
    "default_1.jpg" = "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1920&q=80"
    "default_2.jpg" = "https://images.unsplash.com/photo-1556912172-45b7abe8b7e1?w=1920&q=80"
    "default_3.jpg" = "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1920&q=80"
    "default_4.jpg" = "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1920&q=80"
    "default_5.jpg" = "https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1920&q=80"
}

foreach ($filename in $images.Keys) {
    $url = $images[$filename]
    $output = "assets\images\backgrounds\$filename"
    Write-Host "Downloading $filename..."
    Invoke-WebRequest -Uri $url -OutFile $output
}

Write-Host "All images downloaded successfully!"
```

### Option 3: Use Your Own Images

If you prefer to use your own images:

1. Find or create 5 images (JPG format recommended)
2. Resize them to 1920x1080 or similar
3. Name them exactly: `default_1.jpg`, `default_2.jpg`, etc.
4. Place them in `assets/images/backgrounds/`

## After Adding Images

1. Run: `flutter pub get`
2. Hot restart your app (not hot reload)
3. Test the background picker

## Troubleshooting

If images don't show:
- Verify filenames are exactly correct (case-sensitive)
- Verify files are in `assets/images/backgrounds/` folder
- Run `flutter clean` then `flutter pub get`
- Do a full restart (not hot reload)
