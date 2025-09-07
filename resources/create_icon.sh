#!/bin/bash

# Script to create macOS app icon from Mercury logo
# Usage: ./create_icon.sh input_image.png

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_image.png>"
    echo "Please provide the Mercury logo PNG file as an argument"
    exit 1
fi

INPUT_IMAGE="$1"

if [ ! -f "$INPUT_IMAGE" ]; then
    echo "Error: Input file '$INPUT_IMAGE' not found"
    exit 1
fi

echo "Creating Mercury app icon from $INPUT_IMAGE..."

# Create temporary iconset directory
ICONSET_DIR="Mercury.iconset"
rm -rf "$ICONSET_DIR"
mkdir "$ICONSET_DIR"

# Function to create icon at specific size
create_icon_size() {
    local size=$1
    local scale=$2
    local output_size=$((size * scale))
    local filename=""
    
    if [ $scale -eq 1 ]; then
        filename="icon_${size}x${size}.png"
    else
        filename="icon_${size}x${size}@${scale}x.png"
    fi
    
    echo "Creating $filename (${output_size}x${output_size})..."
    
    # Use sips to resize the image
    sips -z $output_size $output_size "$INPUT_IMAGE" \
         --out "$ICONSET_DIR/$filename" >/dev/null 2>&1
}

# Create all required icon sizes for macOS
# Standard sizes
create_icon_size 16 1
create_icon_size 16 2
create_icon_size 32 1
create_icon_size 32 2
create_icon_size 128 1
create_icon_size 128 2
create_icon_size 256 1
create_icon_size 256 2
create_icon_size 512 1
create_icon_size 512 2

echo "Converting iconset to .icns format..."

# Create the icons directory if it doesn't exist
mkdir -p icons

# Convert the iconset to .icns
iconutil -c icns "$ICONSET_DIR" -o icons/AppIcon.icns

# Clean up
rm -rf "$ICONSET_DIR"

echo "✅ Success! App icon created at: icons/AppIcon.icns"
echo ""
echo "The icon has been created and will be automatically included when building the app."
echo "To test the icon:"
echo "  1. Run: ./clean.sh && ./build.sh"
echo "  2. The Mercury.app will have the new icon"