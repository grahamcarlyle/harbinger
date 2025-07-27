#!/bin/bash

# Create a proper macOS app bundle
# Usage: ./create_app.sh [release|debug]
BUILD_TYPE=${1:-debug}

echo "🔨 Creating Harbinger.app bundle (${BUILD_TYPE} build)..."

mkdir -p Harbinger.app/Contents/MacOS
mkdir -p Harbinger.app/Contents/Resources

# Determine build path based on type
if [ "$BUILD_TYPE" = "release" ]; then
    # For release builds, use universal binary from swift build -c release
    if [ -f ".build/apple/Products/Release/Harbinger" ]; then
        cp .build/apple/Products/Release/Harbinger Harbinger.app/Contents/MacOS/
    else
        echo "❌ Release build not found. Run: swift build -c release --arch arm64 --arch x86_64"
        exit 1
    fi
else
    # For debug builds, use existing debug path
    if [ -f ".build/arm64-apple-macosx/debug/Harbinger" ]; then
        cp .build/arm64-apple-macosx/debug/Harbinger Harbinger.app/Contents/MacOS/
    else
        echo "❌ Debug build not found. Run: swift build"
        exit 1
    fi
fi

# Make executable
chmod +x Harbinger.app/Contents/MacOS/Harbinger

# Create Info.plist with dynamic versioning
VERSION="1.0.0"
BUILD_NUMBER="1"

# Try to get version from git tag if available
if git describe --tags --exact-match 2>/dev/null; then
    VERSION=$(git describe --tags --exact-match | sed 's/^v//')
fi

# Use git commit count as build number
if git rev-list --count HEAD 2>/dev/null; then
    BUILD_NUMBER=$(git rev-list --count HEAD)
fi

cat > Harbinger.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Harbinger</string>
    <key>CFBundleExecutable</key>
    <string>Harbinger</string>
    <key>CFBundleIdentifier</key>
    <string>com.harbinger.statusbar</string>
    <key>CFBundleName</key>
    <string>Harbinger</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Created Harbinger.app bundle (${BUILD_TYPE})"
echo "   Version: ${VERSION}, Build: ${BUILD_NUMBER}"
echo "   To run: open Harbinger.app"