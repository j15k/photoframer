![Header image including the name PhotoFramer and an examples of a framed photograph](assets/images/photoframer.png)


# PhotoFramer

PhotoFramer is a Bash shell script to add professional frames with EXIF metadata and geolocation to your photos.


## Features

- Adds white frame with padding around photos
- Displays photo metadata in bottom frame:
  - Date & time (12-hour format)
  - GPS location (reverse geocoded)
  - Camera settings (ISO, exposure, aperture, focal length)
- Adds custom avatar/logo to bottom frame
- Preserves original image quality and DPI
- Caches geocoding results to avoid rate limits
- Progress bar with ETA for batch processing


## Requirements


### System Dependencies

```bash
sudo apt install imagemagick exiftool bc curl jq coreutils
```


### Font

- Inter font recommended: `Inter[wght].ttf`
- Falls back to system sans if not found


### Avatar/Logo

- PNG file with transparency (recommended)
- Any size (script resizes to 100×100px)


## Installation

1. **Clone or download** the script to your preferred location

2. **Make it executable**:
   ```bash
   chmod +x photoframer.sh
   ```

3. **Edit configuration** in the script:
   ```bash
   # Required changes
   INPUT_DIR="/your/photo/directory"
   OUTPUT_DIR="/your/output/directory"
   AVATAR="/path/to/your/logo.png"
   
   # Required for geocoding (replace with your email)
   NOMINATIM_EMAIL="your-email@example.com"
   
   # Optional: adjust font path
   FONT="/path/to/Inter[wght].ttf"
   ```


## Usage


### Basic Usage

```bash
./photoframer.sh
```


### What it does

1. Scans `INPUT_DIR` for supported images
2. Extracts EXIF metadata and GPS coordinates
3. Reverse-geocodes coordinates to location names
4. Creates framed photo in `OUTPUT_DIR`
5. Preserves original files (input/output must differ)


### Output Format

**Top frame**: 50px white border  
**Left frame**: 50px white border  
**Right frame**: 50px white border  
**Bottom frame**: 200px with:

- Left: `City, Country  ·  YYYY-MM-DD  ·  HH:MM AM/PM`
- Right: `ISO 100  1/250s  f/8  50mm`
- Avatar/logo aligned left


## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `FRAME_PADDING` | 50 | Left/right padding in pixels |
| `TOP_FRAME_HEIGHT` | 50 | Top frame height in pixels |
| `BOTTOM_FRAME_HEIGHT` | 200 | Bottom frame height in pixels |
| `FONT_SIZE` | 26 | Text size in points |
| `TEXT_COLOR` | "#000000" | Text color (hex) |
| `FRAME_COLOR` | "white" | Frame background color |
| `AVATAR_SIZE` | 100 | Avatar size in pixels |
| `SHOW_PROGRESS_BAR` | "true" | Show/hide progress indicator |
| `SHOW_COORDINATES_AS_FALLBACK` | "false" | Show coordinates if no location name |


### Geocoding Settings

| Variable | Description |
|----------|-------------|
| `NOMINATIM_EMAIL` | **Required** - Your email (respects API policy) |
| `NOMINATIM_ACCEPT_LANGUAGE` | Language for location names (default: "en") |
| `CACHE_FILE` | Cache file location (avoid repeated API calls) |


## Examples


### Framed images

You can find many examples of images framed with PhotoFramer here:

- [Pixelfed: @j15k](https://pixelfed.social/j15k)
- [Mastodon: @j15k](https://mastodon.social/@j15k)
- [Bluesky: @j15k.com](https://bsky.app/profile/j15k.com)


### Before framing

```
photo.jpg (4928×3264 pixels)
```

### After framing

```
photo.jpg (5028×3514 pixels)
- 50px top white bar
- 50px left/right padding
- 200px bottom bar with metadata
- Avatar and text overlays
```


## Important Notes


### Directory Safety

- **Input and output directories must be different**
- Script checks this automatically to prevent overwriting originals


### Geocoding API

- Uses Nominatim (OpenStreetMap) - free, no API key required
- **Must provide valid email** in `NOMINATIM_EMAIL`
- 1-second delay between requests (respects API limits)
- Results cached to avoid redundant lookups


### Image Formats

- Supports: JPG, JPEG, PNG (case-insensitive)
- Preserves original quality (no recompression)
- Maintains original DPI for print


## Troubleshooting

### "Input and output directories are the same"

```bash
# Use different directories:
INPUT_DIR="/path/to/originals"
OUTPUT_DIR="/path/to/framed"
```


### No location found

- Check if photo has GPS coordinates: `exiftool -gpslatitude photo.jpg`
- Verify internet connection
- Set `SHOW_COORDINATES_AS_FALLBACK="true"` to show coordinates instead


### Missing EXIF data

Script handles missing values gracefully:
- Missing ISO → `--`
- Missing location → shows date/time only
- Missing GPS → skips location lookup


### Font warnings

- Install Inter font or update `FONT` path
- Script falls back to system sans font automatically


## Logging

- Console output shows progress and current file
- Full log saved to `$OUTPUT_DIR/log.txt`
- Geocoding cache saved to `$OUTPUT_DIR/geocode_cache.txt`
