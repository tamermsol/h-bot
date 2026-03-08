# PowerShell script to download default background images
# Run this script from the project root directory

Write-Host "Setting up default background images..." -ForegroundColor Green

# Create directory
$bgDir = "assets\images\backgrounds"
if (-not (Test-Path $bgDir)) {
    New-Item -ItemType Directory -Force -Path $bgDir | Out-Null
    Write-Host "Created directory: $bgDir" -ForegroundColor Yellow
}

# Define images to download
$images = @{
    "default_1.jpg" = "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1920&q=80"
    "default_2.jpg" = "https://images.unsplash.com/photo-1556912172-45b7abe8b7e1?w=1920&q=80"
    "default_3.jpg" = "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1920&q=80"
    "default_4.jpg" = "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=1920&q=80"
    "default_5.jpg" = "https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?w=1920&q=80"
}

# Download each image
$count = 0
foreach ($filename in $images.Keys) {
    $url = $images[$filename]
    $output = Join-Path $bgDir $filename
    
    if (Test-Path $output) {
        Write-Host "  [$filename] Already exists, skipping..." -ForegroundColor Gray
    } else {
        Write-Host "  Downloading $filename..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
            $count++
            Write-Host "  [$filename] Downloaded successfully!" -ForegroundColor Green
        } catch {
            Write-Host "  [$filename] Failed to download: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Setup complete! Downloaded $count new image(s)." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: flutter pub get" -ForegroundColor White
Write-Host "  2. Hot restart your app (not hot reload)" -ForegroundColor White
Write-Host "  3. Test the background picker in any room" -ForegroundColor White
