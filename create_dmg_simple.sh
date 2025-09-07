#!/bin/bash

# Simple DMG creation without broken macdeployqt

echo "Creating simple DMG for Mercury..."

# Create a temporary folder for the DMG
rm -rf build/dmg_temp
mkdir -p build/dmg_temp

# Copy the app
cp -R build/Mercury.app build/dmg_temp/

# Create Applications symlink
ln -s /Applications build/dmg_temp/Applications

# Create the DMG
hdiutil create -volname "Mercury" \
    -srcfolder build/dmg_temp \
    -ov -format UDZO \
    build/Mercury-Simple.dmg

# Clean up
rm -rf build/dmg_temp

echo "DMG created at: build/Mercury-Simple.dmg"
echo "Size: $(du -h build/Mercury-Simple.dmg | cut -f1)"
echo ""
echo "IMPORTANT: This app will only work on machines with Qt6 installed via Homebrew."
echo "To run on other machines, Qt frameworks need to be bundled properly."