# Changelog

All notable changes to PhotoFramer will be documented here.


## [1.0.0] - 2026-03-15


### Added

- Initial release
- Image framing with configurable padding and frame heights
- EXIF metadata extraction for:
  - Date and time (DateTimeOriginal)
  - ISO sensitivity (multiple tag fallbacks)
  - Shutter speed (preserves fraction format)
  - Aperture (F-number)
  - Focal length
- GPS coordinate extraction and reverse geocoding via Nominatim
- Location caching to reduce API calls
- Avatar/logo overlay with DPI preservation
- Progress bar with ETA for batch processing
- Comprehensive logging (console + file)
- Dependency validation for all required tools
- Directory safety check (prevents overwriting originals)
- Support for case-insensitive file extensions (.jpg, .jpeg, .JPG, .JPEG, .png, .PNG)
- 12-hour time format with AM/PM
- Graceful handling of missing metadata (displays "--")
- Fallback to system sans font if Inter not found


### Technical

- Written in pure bash with set -euo pipefail for robustness
- Uses bc for floating-point calculations
- Implements Nominatim API best practices (User-Agent, From headers, rate limiting)
- Maintains original image DPI for print quality


### Known Issues

- No resume capability for interrupted batch processing
- Does not handle rotated images automatically
- Single font for all text elements
