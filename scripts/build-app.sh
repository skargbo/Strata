#!/bin/bash
set -e

# Build Strata.app bundle
# Usage: ./scripts/build-app.sh [--release]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="Strata"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Parse arguments
BUILD_CONFIG="debug"
if [[ "$1" == "--release" ]]; then
    BUILD_CONFIG="release"
fi

echo "🔨 Building Strata ($BUILD_CONFIG)..."

# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"

# Build the executable
cd "$PROJECT_ROOT"
if [[ "$BUILD_CONFIG" == "release" ]]; then
    swift build -c release
    EXECUTABLE_PATH=".build/release/Strata"
else
    swift build
    EXECUTABLE_PATH=".build/debug/Strata"
fi

echo "📦 Creating app bundle..."

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/Strata"

# Copy Info.plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy bridge folder (including node_modules)
echo "📋 Copying bridge files..."
cp -R "$PROJECT_ROOT/bridge" "$APP_BUNDLE/Contents/Resources/"

# Copy app icon if it exists
if [[ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Sign the app (ad-hoc for local use)
echo "🔏 Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "⚠️  Signing skipped (not critical for local use)"

echo ""
echo "✅ Build complete: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install to Applications:"
echo "  cp -R $APP_BUNDLE /Applications/"
