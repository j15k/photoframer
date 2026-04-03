#!/bin/bash

set -euo pipefail

# Use 3:4 aspect ratio for print

INPUT_DIR="/home/user/Pictures/"
OUTPUT_DIR="/home/user/Pictures/framed"
AVATAR="/home/user/Pictures/avatars/avatar.png"
FONT="/home/user/.local/share/fonts/font.ttf"
FONT_SIZE=26
TEXT_COLOR="#000000"
FRAME_COLOR="white"
FRAME_PADDING=50
BOTTOM_FRAME_HEIGHT=200
TOP_FRAME_HEIGHT=50
AVATAR_SIZE=100
LOG_FILE="$OUTPUT_DIR/output.txt"

# Nominatim API configuration
NOMINATIM_EMAIL="your-email@example.com"  # Replace with your email
NOMINATIM_USER_AGENT="PhotoFramer/1.0"
CACHE_FILE="$OUTPUT_DIR/geocode_cache.txt"
SHOW_COORDINATES_AS_FALLBACK="false"
NOMINATIM_ACCEPT_LANGUAGE="en"  # Request English results from Nominatim

# Calculate vertical center position for bottom frame elements
# Avatar height: 80px, vertically centered in the 140px bottom frame
# So offset from bottom: (140 - 80) / 2 = 30px from bottom
AVATAR_OFFSET_FROM_BOTTOM=50

# Text baseline: we want text aligned with middle of avatar
# Font size 24, so text baseline offset from bottom: AVATAR_OFFSET_FROM_BOTTOM + (AVATAR_SIZE/2) - (FONT_SIZE/2)
TEXT_BASELINE_FROM_BOTTOM=$((AVATAR_OFFSET_FROM_BOTTOM + 20))

# Right side text - single row, vertically centered
RIGHT_TEXT_FROM_BOTTOM=$TEXT_BASELINE_FROM_BOTTOM

# Left side text - now single line with location, date, time
LEFT_TEXT_FROM_BOTTOM=$TEXT_BASELINE_FROM_BOTTOM

# VALIDATE DEPENDENCIES
# ============================================================================
echo "Checking dependencies..."

# Check ImageMagick
if ! command -v identify &> /dev/null || ! command -v convert &> /dev/null; then
    echo "ERROR: ImageMagick (identify/convert) not found."
    echo "Please install: sudo apt install imagemagick -y"
    exit 1
fi

# Check exiftool
if ! command -v exiftool &> /dev/null; then
    echo "ERROR: exiftool not found."
    echo "Please install: sudo apt install exiftool -y"
    exit 1
fi

# Check bc
if ! command -v bc &> /dev/null; then
    echo "ERROR: bc not found."
    echo "Please install: sudo apt install bc -y"
    exit 1
fi

# Check curl
if ! command -v curl &> /dev/null; then
    echo "ERROR: curl not found."
    echo "Please install: sudo apt install curl -y"
    exit 1
fi

# Check jq
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq not found."
    echo "Please install: sudo apt install jq -y"
    exit 1
fi

# Check if font exists
if [ ! -f "$FONT" ]; then
    echo "WARNING: Inter font not found at: $FONT"
    echo "Falling back to system sans font"
    FONT="Sans"
fi

# Check if avatar exists
if [ ! -f "$AVATAR" ]; then
    echo "WARNING: Avatar file not found at: $AVATAR"
fi

echo "All dependencies satisfied."
echo ""

# ============================================================================
# FUNCTIONS
# ============================================================================

# Function to log messages to both console and file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function for debug messages - sends to stderr so they won't be captured
debug() {
    echo "$1" >&2
    echo "$1" >> "$LOG_FILE"
}

# Function to convert DMS to decimal degrees
dms_to_decimal() {
    local dms="$1"
    local direction="$2"
    local decimal=0
    
    if [[ "$dms" =~ ([0-9.]+)[^0-9]*([0-9.]+)[^0-9]*([0-9.]+)? ]]; then
        local degrees="${BASH_REMATCH[1]}"
        local minutes="${BASH_REMATCH[2]}"
        local seconds="${BASH_REMATCH[3]:-0}"
        
        decimal=$(echo "scale=8; $degrees + $minutes/60 + $seconds/3600" | bc)
        
        if [[ "$direction" == "S" ]] || [[ "$direction" == "W" ]]; then
            decimal=$(echo "scale=8; -$decimal" | bc)
        fi
    fi
    
    echo "$decimal"
}

# Function to get location from coordinates - ONLY returns the location string
get_location() {
    local lat="$1"
    local lon="$2"
    local cache_key="${lat},${lon}"
    local location=""
    
    # Check cache first
    if [ -f "$CACHE_FILE" ]; then
        location=$(grep "^${cache_key}|" "$CACHE_FILE" | cut -d'|' -f2)
        if [ -n "$location" ] && [ "$location" != "null" ] && [ "$location" != "__NOLOCATION__" ]; then
            echo "$location"
            return 0
        fi
    fi
    
    # Debug output goes to stderr, not stdout
    debug "    Looking up location for: $lat, $lon"
    
    # Call Nominatim API with English language preference
    local response
    response=$(curl -s "https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&zoom=18&addressdetails=1&accept-language=${NOMINATIM_ACCEPT_LANGUAGE}" \
        -H "User-Agent: ${NOMINATIM_USER_AGENT}" \
        -H "From: ${NOMINATIM_EMAIL}" 2>/dev/null)
    
    # Parse the response to get English location names
    if [ -n "$response" ] && [ "$response" != "[]" ] && [ "$response" != "{}" ]; then
        # Try to get English names first, then fall back to local names
        local city
        city=$(echo "$response" | jq -r '.address.city // .address.town // .address.village // .address.suburb // .address.hamlet // .address.municipality // ""')
        
        local country
        country=$(echo "$response" | jq -r '.address.country // ""')
        
        local state
        state=$(echo "$response" | jq -r '.address.state // .address.region // ""')
        
        # Construct location string in English
        if [ -n "$city" ] && [ -n "$country" ]; then
            location="${city}, ${country}"
        elif [ -n "$city" ]; then
            location="$city"
        elif [ -n "$state" ] && [ -n "$country" ]; then
            location="${state}, ${country}"
        elif [ -n "$country" ]; then
            location="$country"
        else
            # Last resort: use display name but try to get English version
            location=$(echo "$response" | jq -r '.display_name // ""' | cut -d',' -f1-2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
        
        # Clean up location
        location=$(echo "$location" | sed 's/^"//g' | sed 's/"$//g' | xargs)
    fi
    
    # Cache the result
    if [ -n "$location" ]; then
        echo "${cache_key}|${location}" >> "$CACHE_FILE"
        echo "$location"
    else
        echo "${cache_key}|__NOLOCATION__" >> "$CACHE_FILE"
        echo ""
    fi
    
    # Rate limiting
    sleep 1
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

mkdir -p "$OUTPUT_DIR"
# Create empty log and cache files
: > "$LOG_FILE"
: > "$CACHE_FILE"

# Get avatar DPI for print quality preservation
log "Checking avatar DPI..."
AVATAR_DPI=$(identify -format "%x" "$AVATAR" 2>/dev/null | head -1 | cut -d' ' -f1 | sed 's/[^0-9.]//g')
if [ -z "$AVATAR_DPI" ] || [ "$AVATAR_DPI" = "0" ] || [ "$AVATAR_DPI" = "." ]; then
    AVATAR_DPI=300  # Default to 300 if not detected
    log "  Avatar DPI not detected, using default: ${AVATAR_DPI} DPI"
else
    log "  Avatar DPI detected: ${AVATAR_DPI} DPI"
fi

log "=== Image Framing Script Started ==="
log "Input directory: $INPUT_DIR"
log "Output directory: $OUTPUT_DIR"
log "Log file: $LOG_FILE"
log "Geocoding cache: $CACHE_FILE"
log "Avatar DPI: $AVATAR_DPI"
log ""

for img in "$INPUT_DIR"/*.jpg; do
    if [ -f "$img" ]; then
        filename=$(basename "$img")
        log "Processing: $filename"
        
        # Get image dimensions
        dimensions=$(identify -format "%w %h" "$img")
        width=$(echo "$dimensions" | cut -d' ' -f1)
        height=$(echo "$dimensions" | cut -d' ' -f2)
        
        # Calculate new dimensions for framed image
        # Add frame on all sides: top, bottom, left, right
        new_width=$((width + 2 * FRAME_PADDING))
        new_height=$((height + TOP_FRAME_HEIGHT + BOTTOM_FRAME_HEIGHT))
        
        # Get metadata
        # Get metadata
        datetime=$(identify -format "%[EXIF:DateTimeOriginal]" "$img" 2>/dev/null)
        if [ -z "$datetime" ]; then
            datetime=$(date -r "$img" +"%Y:%m:%d %H:%M:%S")
        fi

        # Parse date and time
        date_part=$(echo "$datetime" | cut -d' ' -f1 | tr ':' '-')
        time_part=$(echo "$datetime" | cut -d' ' -f2)

        # ================================================================
        # FIXED TIME FORMATTING - Handles leading zeros safely
        # ================================================================
        # Parse time components safely by stripping leading zeros
        hour=$(echo "$time_part" | cut -d':' -f1 | sed 's/^0*//')
        minute=$(echo "$time_part" | cut -d':' -f2 | sed 's/^0*//')

        # Handle empty values (e.g., if stripping zeros removed everything)
        [ -z "$hour" ] && hour=0
        [ -z "$minute" ] && minute=0

        # Convert to 12-hour format with AM/PM
        if [ "$hour" -ge 12 ]; then
            if [ "$hour" -eq 12 ]; then
                display_hour=12
            else
                display_hour=$((hour - 12))
            fi
            ampm="PM"
        else
            if [ "$hour" -eq 0 ]; then
                display_hour=12
            else
                display_hour=$hour
            fi
            ampm="AM"
        fi

        # Format with leading zero for minute (printf with %02d handles this safely)
        time_formatted=$(printf "%d:%02d %s" "$display_hour" "$minute" "$ampm")
        datetime_combined="${date_part}  ·  ${time_formatted}"
        # ================================================================
        
        # Get GPS coordinates
        log "  Extracting GPS coordinates..."
        
        gps_lat_raw=$(exiftool -GPSLatitude -s3 "$img" 2>/dev/null | head -1)
        gps_lon_raw=$(exiftool -GPSLongitude -s3 "$img" 2>/dev/null | head -1)
        gps_lat_ref=$(exiftool -GPSLatitudeRef -s3 "$img" 2>/dev/null | head -1)
        gps_lon_ref=$(exiftool -GPSLongitudeRef -s3 "$img" 2>/dev/null | head -1)
        
        location=""
        
        if [ -n "$gps_lat_raw" ] && [ -n "$gps_lon_raw" ] && 
           [ "$gps_lat_raw" != "null" ] && [ "$gps_lon_raw" != "null" ] &&
           [ "$gps_lat_raw" != "-" ] && [ "$gps_lon_raw" != "-" ]; then
            
            log "    GPS coordinates found: $gps_lat_raw, $gps_lon_raw"
            
            if [[ "$gps_lat_raw" == *"deg"* ]]; then
                lat_decimal=$(dms_to_decimal "$gps_lat_raw" "${gps_lat_ref:-N}")
                lon_decimal=$(dms_to_decimal "$gps_lon_raw" "${gps_lon_ref:-E}")
            else
                lat_decimal="$gps_lat_raw"
                lon_decimal="$gps_lon_raw"
            fi
            
            log "    Decimal coordinates: $lat_decimal, $lon_decimal"
            
            if [ -n "$lat_decimal" ] && [ -n "$lon_decimal" ] && 
               [ "$lat_decimal" != "0" ] && [ "$lon_decimal" != "0" ]; then
                
                location_result=$(get_location "$lat_decimal" "$lon_decimal")
                
                if [ -n "$location_result" ]; then
                    location="$location_result"
                    log "    Location found: $location"
                else
                    if [ "$SHOW_COORDINATES_AS_FALLBACK" = "true" ]; then
                        coordinates_display=$(printf "%.4f, %.4f" "$lat_decimal" "$lon_decimal")
                        location="$coordinates_display"
                        log "    Using coordinates as fallback: $location"
                    else
                        location=""
                        log "    No location found"
                    fi
                fi
            fi
        else
            log "    No GPS coordinates found"
        fi
        
        # Get EXIF data - FOCAL LENGTH
        focal=$(identify -format "%[EXIF:FocalLength]" "$img" 2>/dev/null | sed 's/[^0-9\/]//g')
        if [ -n "$focal" ] && [ "$focal" != "null" ]; then
            if [[ "$focal" == *"/"* ]]; then
                num=$(echo "$focal" | cut -d'/' -f1)
                den=$(echo "$focal" | cut -d'/' -f2)
                if [ -n "$den" ] && [ "$den" -ne 0 ] 2>/dev/null; then
                    focal=$(echo "scale=1; $num/$den" | bc)
                else
                    focal="$num"
                fi
            fi
            focal="${focal}mm"
        else
            focal="--"
        fi
        
        # Get EXIF data - APERTURE
        aperture=$(identify -format "%[EXIF:FNumber]" "$img" 2>/dev/null)
        if [ -n "$aperture" ] && [ "$aperture" != "null" ]; then
            if [[ "$aperture" == *"/"* ]]; then
                num=$(echo "$aperture" | cut -d'/' -f1)
                den=$(echo "$aperture" | cut -d'/' -f2)
                if [ -n "$den" ] && [ "$den" -ne 0 ] 2>/dev/null; then
                    aperture=$(echo "scale=1; $num/$den" | bc)
                else
                    aperture="$num"
                fi
            fi
            aperture="f/$aperture"
        else
            aperture="--"
        fi
        
        # Get EXIF data - EXPOSURE
        exposure=$(exiftool -ExposureTime -s3 "$img" 2>/dev/null | head -1)
        if [ -n "$exposure" ] && [ "$exposure" != "null" ] && [ "$exposure" != "-" ]; then
            # exiftool often returns fractions like "1/20"
            if [[ "$exposure" == *"/"* ]]; then
                exposure="${exposure}s"
            else
                # If it's a decimal, try to convert to fraction
                exposure_decimal="$exposure"
                if (( $(echo "$exposure_decimal < 1" | bc -l) )); then
                    denominator=$(echo "scale=0; 1 / $exposure_decimal + 0.5" | bc)
                    exposure="1/${denominator}s"
                else
                    exposure="${exposure_decimal}s"
                fi
            fi
        else
            exposure="--"
        fi
        
        # Get EXIF data - ISO (MULTIPLE METHODS)
        iso="--"
        
        # Method 1: Direct EXIF tag with identify
        iso_raw=$(identify -format "%[EXIF:ISOSpeedRatings]" "$img" 2>/dev/null | xargs)
        if [ -n "$iso_raw" ] && [ "$iso_raw" != "null" ] && [ "$iso_raw" != "-" ]; then
            iso_clean="${iso_raw//[^0-9]/}"
            if [ -n "$iso_clean" ]; then
                iso="ISO $iso_clean"
                log "    ISO found via identify: $iso"
            fi
        fi
        
        # Method 2: Try ISO tag with identify
        if [ "$iso" = "--" ]; then
            iso_raw=$(identify -format "%[EXIF:ISO]" "$img" 2>/dev/null | xargs)
            if [ -n "$iso_raw" ] && [ "$iso_raw" != "null" ] && [ "$iso_raw" != "-" ]; then
                iso_clean="${iso_raw//[^0-9]/}"
                if [ -n "$iso_clean" ]; then
                    iso="ISO $iso_clean"
                    log "    ISO found via identify ISO tag: $iso"
                fi
            fi
        fi
        
        # Method 3: Try exiftool
        if [ "$iso" = "--" ]; then
            for tag in "ISO" "ISOSpeed" "ISOSpeedRatings" "BaseISO" "RecommendedExposureIndex"; do
                iso_raw=$(exiftool -$tag -s3 "$img" 2>/dev/null | head -1 | xargs)
                if [ -n "$iso_raw" ] && [ "$iso_raw" != "null" ] && [ "$iso_raw" != "-" ]; then
                    iso_clean="${iso_raw//[^0-9]/}"
                    if [ -n "$iso_clean" ]; then
                        iso="ISO $iso_clean"
                        log "    ISO found via exiftool ($tag): $iso"
                        break
                    fi
                fi
            done
        fi
        
        # Method 4: Try exiftool with verbose output as last resort
        if [ "$iso" = "--" ]; then
            iso_raw=$(exiftool -EXIF:ISO -s3 "$img" 2>/dev/null | head -1 | xargs)
            if [ -n "$iso_raw" ] && [ "$iso_raw" != "null" ] && [ "$iso_raw" != "-" ]; then
                iso_clean="${iso_raw//[^0-9]/}"
                if [ -n "$iso_clean" ]; then
                    iso="ISO $iso_clean"
                    log "    ISO found via exiftool EXIF:ISO: $iso"
                fi
            fi
        fi
        
        # Construct left side text (location + date/time)
        if [ -n "$location" ]; then
            left_text="${location}  ·  ${datetime_combined}"
        else
            left_text="${datetime_combined}"
        fi
        
        # Construct right side text (ISO, exposure, aperture, focal length)
        right_text="${iso}        ${exposure}        ${aperture}        ${focal}"
        
        log "  Debug - Final values:"
        log "    Left text: $left_text"
        log "    Right text: $right_text"
        
        # Create framed image with metadata
        # First, create canvas, then composite the image on top
        # Avatar is resized to exact dimensions while preserving original DPI for print quality
        convert -size "${new_width}x${new_height}" xc:"$FRAME_COLOR" \
            "$img" -geometry +${FRAME_PADDING}+${TOP_FRAME_HEIGHT} -composite \
            -font "$FONT" \
            -pointsize $FONT_SIZE \
            \( "$AVATAR" -resize ${AVATAR_SIZE}x${AVATAR_SIZE} -density "${AVATAR_DPI}" -units PixelsPerInch -background none \) \
            -gravity southwest \
            -geometry +${FRAME_PADDING}+${AVATAR_OFFSET_FROM_BOTTOM} \
            -composite \
            -gravity southwest \
            -fill "$TEXT_COLOR" \
            -annotate +$((FRAME_PADDING + AVATAR_SIZE + FRAME_PADDING - 4))+${LEFT_TEXT_FROM_BOTTOM} "$left_text" \
            -gravity southeast \
            -fill "$TEXT_COLOR" \
            -annotate +${FRAME_PADDING}+${RIGHT_TEXT_FROM_BOTTOM} "$right_text" \
            "$OUTPUT_DIR/$filename" >> "$LOG_FILE" 2>&1
        
        log "  Saved to: $OUTPUT_DIR/$filename"
        log ""
    fi
done

log "=== PhotoFramer Script Completed ==="
log "Complete log saved to: $LOG_FILE"

exit 0
