#!/bin/bash

# Create a proper macOS app bundle
mkdir -p Harbinger.app/Contents/MacOS
mkdir -p Harbinger.app/Contents/Resources

# Copy the executable
cp .build/arm64-apple-macosx/debug/Harbinger Harbinger.app/Contents/MacOS/

# Create Info.plist
cat > Harbinger.app/Contents/Info.plist << 'EOF'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Created Harbinger.app bundle"
echo "To run: open Harbinger.app"