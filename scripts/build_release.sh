#!/bin/bash
set -e

# Configuration
APP_NAME="OpenTerm"
SCHEME="OpenTerm"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$BUILD_DIR/Release"
DMG_NAME="${APP_NAME}.dmg"

echo "=== Building $APP_NAME Release ==="
echo "Project: $PROJECT_DIR"

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$RELEASE_DIR"

# Build Release configuration
echo "Building Release configuration..."
xcodebuild -project "$PROJECT_DIR/OpenTerm.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -destination "generic/platform=macOS" \
    clean build \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Find the built app
APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app"
    exit 1
fi

echo "Built app: $APP_PATH"

# Copy to release directory
cp -R "$APP_PATH" "$RELEASE_DIR/"

# Ad-hoc sign all embedded dylibs and the app
echo "Ad-hoc signing embedded frameworks..."
FRAMEWORKS_DIR="$RELEASE_DIR/${APP_NAME}.app/Contents/Frameworks"
if [ -d "$FRAMEWORKS_DIR" ]; then
    for lib in "$FRAMEWORKS_DIR"/*.dylib; do
        if [ -f "$lib" ]; then
            echo "  Signing: $(basename "$lib")"
            codesign -s - --force --timestamp=none "$lib"
        fi
    done
fi

echo "Ad-hoc signing app bundle..."
codesign -s - --force --deep --timestamp=none "$RELEASE_DIR/${APP_NAME}.app"

# Verify signature
echo "Verifying code signature..."
codesign -vvv "$RELEASE_DIR/${APP_NAME}.app" 2>&1 || echo "Warning: Signature verification reported issues (expected for ad-hoc signing)"

# Create ZIP
echo "Creating ZIP archive..."
cd "$RELEASE_DIR"
zip -r -y "${APP_NAME}.zip" "${APP_NAME}.app"
echo "Created: $RELEASE_DIR/${APP_NAME}.zip"

# Create DMG
echo "Creating DMG..."
DMG_TEMP="$BUILD_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "${APP_NAME}.app" "$DMG_TEMP/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$RELEASE_DIR/$DMG_NAME"

echo "Created: $RELEASE_DIR/$DMG_NAME"

# Cleanup temp
rm -rf "$DMG_TEMP"

# Show results
echo ""
echo "=== Build Complete ==="
echo "Release files:"
ls -lh "$RELEASE_DIR"
echo ""
echo "App size:"
du -sh "$RELEASE_DIR/${APP_NAME}.app"
echo ""
echo "Ready for distribution:"
echo "  ZIP: $RELEASE_DIR/${APP_NAME}.zip"
echo "  DMG: $RELEASE_DIR/$DMG_NAME"
