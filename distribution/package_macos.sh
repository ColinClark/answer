#!/bin/bash

# macOS Application Packaging Script for Answer
# This script automates the build, signing, and notarization process

set -e  # Exit on error

# Configuration
APP_NAME="Mercury"
BUNDLE_ID="com.statista.answer"
VERSION="1.0.0"
DEFAULT_TEAM_ID="Tracking"
DEFAULT_APPLE_ID="colin@clark.ws"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Answer macOS Packaging Script ===${NC}"

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    if ! command -v cmake &> /dev/null; then
        echo -e "${RED}Error: CMake is not installed${NC}"
        exit 1
    fi
    
    if ! command -v macdeployqt &> /dev/null; then
        echo -e "${YELLOW}Warning: macdeployqt not found in PATH${NC}"
        echo "Searching for macdeployqt..."
        
        # Common Qt installation paths
        QT_PATHS=(
            "/opt/homebrew/opt/qt@6/bin/macdeployqt"
            "/usr/local/opt/qt@6/bin/macdeployqt"
            "/opt/local/libexec/qt6/bin/macdeployqt"
            "$HOME/Qt/6.*/macos/bin/macdeployqt"
        )
        
        for path in "${QT_PATHS[@]}"; do
            if [[ -f $(echo $path) ]]; then
                MACDEPLOYQT=$(echo $path)
                echo -e "${GREEN}Found macdeployqt at: $MACDEPLOYQT${NC}"
                break
            fi
        done
        
        if [[ -z "$MACDEPLOYQT" ]]; then
            echo -e "${RED}Error: Could not find macdeployqt${NC}"
            echo "Please install Qt6 or set the path manually"
            exit 1
        fi
    else
        MACDEPLOYQT="macdeployqt"
    fi
}

# Build the application
build_app() {
    echo -e "${YELLOW}Building application...${NC}"
    
    # Clean previous build
    rm -rf build
    mkdir build
    cd build
    
    # Configure and build
    cmake .. -DCMAKE_BUILD_TYPE=Release
    cmake --build . --config Release
    
    cd ..
    echo -e "${GREEN}Build complete!${NC}"
}

# Deploy Qt dependencies
deploy_qt() {
    echo -e "${YELLOW}Deploying Qt dependencies...${NC}"
    
    cd build
    # The app will be named Mercury.app after the CMake changes
    if [[ -f "Mercury.app/Contents/MacOS/Mercury" ]]; then
        # Deploy with WebEngine support - need to add webenginecore explicitly
        $MACDEPLOYQT Mercury.app \
            -qmldir=../qml \
            -always-overwrite \
            -verbose=2
        
        # Manually ensure WebEngine process helper is included
        if [[ -d "/opt/homebrew/lib/QtWebEngineCore.framework/Helpers" ]]; then
            echo "Copying QtWebEngineProcess helper..."
            cp -R "/opt/homebrew/lib/QtWebEngineCore.framework/Helpers" \
                "Mercury.app/Contents/Frameworks/QtWebEngineCore.framework/" 2>/dev/null || true
        fi
    else
        # Fallback to old name if not rebuilt yet
        $MACDEPLOYQT answer.app -qmldir=../qml -always-overwrite
    fi
    cd ..
    
    echo -e "${GREEN}Qt deployment complete!${NC}"
}

# Sign the application
sign_app() {
    echo -e "${YELLOW}Signing application...${NC}"
    
    # Check for signing identity
    if [[ -z "$SIGNING_IDENTITY" ]]; then
        echo -e "${YELLOW}No SIGNING_IDENTITY set. Checking for available identities...${NC}"
        security find-identity -v -p codesigning
        echo ""
        echo "Set SIGNING_IDENTITY environment variable to one of the above"
        echo "Example: export SIGNING_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\""
        return
    fi
    
    cd build
    
    # Determine app name
    if [[ -d "Mercury.app" ]]; then
        APP_BUNDLE="Mercury.app"
        APP_EXEC="Mercury"
    else
        APP_BUNDLE="answer.app"
        APP_EXEC="answer"
    fi
    
    # Sign frameworks
    echo "Signing frameworks..."
    find $APP_BUNDLE/Contents/Frameworks -name "*.framework" -exec \
        codesign --force --verify --verbose --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp {} \;
    
    # Sign plugins
    echo "Signing plugins..."
    find $APP_BUNDLE/Contents/PlugIns -name "*.dylib" -exec \
        codesign --force --verify --verbose --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp {} \;
    
    # Sign main executable
    echo "Signing main executable..."
    codesign --force --verify --verbose --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp \
        $APP_BUNDLE/Contents/MacOS/$APP_EXEC
    
    # Sign app bundle with entitlements
    echo "Signing app bundle..."
    codesign --force --verify --verbose --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp \
        --entitlements ../distribution/entitlements.plist \
        $APP_BUNDLE
    
    cd ..
    echo -e "${GREEN}Signing complete!${NC}"
}

# Create DMG
create_dmg() {
    echo -e "${YELLOW}Creating DMG...${NC}"
    
    cd build
    
    # Determine app name
    if [[ -d "Mercury.app" ]]; then
        APP_BUNDLE="Mercury.app"
    else
        APP_BUNDLE="answer.app"
    fi
    
    # Create temporary directory for DMG contents
    rm -rf dmg_contents
    mkdir dmg_contents
    cp -R $APP_BUNDLE dmg_contents/
    ln -s /Applications dmg_contents/Applications
    
    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder dmg_contents \
        -ov -format UDZO \
        "${APP_NAME}-${VERSION}.dmg"
    
    # Clean up
    rm -rf dmg_contents
    
    cd ..
    echo -e "${GREEN}DMG created: build/${APP_NAME}-${VERSION}.dmg${NC}"
}

# Notarize the application
notarize_app() {
    echo -e "${YELLOW}Notarizing application...${NC}"
    
    # Use defaults if not set
    if [[ -z "$TEAM_ID" ]]; then
        TEAM_ID="$DEFAULT_TEAM_ID"
    fi
    
    if [[ -z "$APPLE_ID" ]]; then
        APPLE_ID="$DEFAULT_APPLE_ID"
    fi
    
    if [[ -z "$APP_PASSWORD" ]]; then
        echo -e "${YELLOW}App-specific password not set${NC}"
        echo "Set the following environment variable:"
        echo "  export APP_PASSWORD=\"your-app-specific-password\""
        echo ""
        echo "Using defaults:"
        echo "  APPLE_ID: $APPLE_ID"
        echo "  TEAM_ID: $TEAM_ID"
        return
    fi
    
    cd build
    
    # Store credentials if not already stored
    xcrun notarytool store-credentials "AC_PASSWORD" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" 2>/dev/null || true
    
    # Submit for notarization
    echo "Submitting for notarization (this may take several minutes)..."
    xcrun notarytool submit "${APP_NAME}-${VERSION}.dmg" \
        --keychain-profile "AC_PASSWORD" \
        --wait
    
    # Staple the ticket
    echo "Stapling ticket..."
    xcrun stapler staple "${APP_NAME}-${VERSION}.dmg"
    
    cd ..
    echo -e "${GREEN}Notarization complete!${NC}"
}

# Main execution
main() {
    check_requirements
    
    echo ""
    echo "Select operation:"
    echo "1) Full build and package (unsigned)"
    echo "2) Full build, sign, and package"
    echo "3) Full build, sign, package, and notarize"
    echo "4) Sign existing build only"
    echo "5) Create DMG from existing build"
    echo "6) Notarize existing DMG"
    read -p "Enter choice (1-6): " choice
    
    case $choice in
        1)
            build_app
            deploy_qt
            create_dmg
            ;;
        2)
            build_app
            deploy_qt
            sign_app
            create_dmg
            ;;
        3)
            build_app
            deploy_qt
            sign_app
            create_dmg
            notarize_app
            ;;
        4)
            sign_app
            ;;
        5)
            create_dmg
            ;;
        6)
            notarize_app
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}=== Packaging Complete ===${NC}"
    if [[ -f "build/${APP_NAME}-${VERSION}.dmg" ]]; then
        echo -e "Output: ${GREEN}build/${APP_NAME}-${VERSION}.dmg${NC}"
        echo -e "Size: $(du -h build/${APP_NAME}-${VERSION}.dmg | cut -f1)"
    fi
}

# Run main function
main