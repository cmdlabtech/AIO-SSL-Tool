#!/bin/bash

# Release Script for AIO SSL Tool
# Automates the process of creating a signed release with Sparkle updates

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}AIO SSL Tool - Release Builder${NC}"
echo "================================"
echo ""

# Check if version argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./release.sh <version>"
    echo "Example: ./release.sh 6.0.1"
    exit 1
fi

VERSION="$1"
DMG_NAME="AIOSSLTool-macOS-v${VERSION}.dmg"
BUILD_DIR="$(pwd)"
APP_PATH="$BUILD_DIR/AIO SSL Tool.app"
RELEASES_DIR="$BUILD_DIR/../../releases/v${VERSION}"

echo -e "${YELLOW}Building release v${VERSION}...${NC}"
echo ""

# Step 1: Update version in Info.plist
echo "📝 Updating Info.plist with version ${VERSION}..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist
VERSION_NUMBER=$(echo $VERSION | cut -d'.' -f1)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION_NUMBER}" Info.plist
echo -e "${GREEN}✓ Version updated${NC}"
echo ""

# Step 2: Build the app
echo "🔨 Building application..."
./build.sh
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}✗ Build failed - app not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Step 3: Create releases directory
echo "📁 Creating release directory..."
mkdir -p "$RELEASES_DIR"
echo -e "${GREEN}✓ Directory created: $RELEASES_DIR${NC}"
echo ""

# Step 4: Create DMG
echo "💿 Creating DMG..."
DMG_PATH="$RELEASES_DIR/$DMG_NAME"
if [ -f "$DMG_PATH" ]; then
    echo "Removing existing DMG..."
    rm "$DMG_PATH"
fi

hdiutil create \
    -volname "AIO SSL Tool v${VERSION}" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}"
echo ""

# Step 5: Get file size
FILE_SIZE=$(ls -l "$DMG_PATH" | awk '{print $5}')
echo "📊 File size: $FILE_SIZE bytes"
echo ""

# Step 6: Sign with Sparkle (if private key exists)
PRIVATE_KEY="$BUILD_DIR/../../sparkle_eddsa_private.key"
if [ -f "$PRIVATE_KEY" ]; then
    echo "🔐 Signing DMG with Sparkle..."
    
    # Check if sign_update command exists
    if command -v sign_update &> /dev/null; then
        SIGNATURE=$(sign_update "$DMG_PATH" "$PRIVATE_KEY" | grep "sparkle:edSignature" | cut -d'"' -f2)
        echo -e "${GREEN}✓ DMG signed${NC}"
        echo ""
        echo "EdDSA Signature:"
        echo "$SIGNATURE"
        echo ""
    else
        echo -e "${YELLOW}⚠ sign_update not found. Install Sparkle tools:${NC}"
        echo "  brew install sparkle"
        echo ""
        SIGNATURE="SIGNATURE_NEEDED"
    fi
else
    echo -e "${YELLOW}⚠ Private key not found at: $PRIVATE_KEY${NC}"
    echo "Generate keys with: ./generate_keys"
    echo ""
    SIGNATURE="SIGNATURE_NEEDED"
fi

# Step 7: Generate appcast entry
echo "📋 Generating appcast entry..."
APPCAST_ENTRY="$RELEASES_DIR/appcast-entry.xml"
cat > "$APPCAST_ENTRY" << EOF
<!-- Add this entry to appcast.xml -->
<item>
    <title>Version ${VERSION}</title>
    <link>https://github.com/YOUR_USERNAME/AIO-SSL-Tool/releases/tag/v${VERSION}</link>
    <sparkle:version>${VERSION}</sparkle:version>
    <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
    <description><![CDATA[
        <h2>What's New in ${VERSION}</h2>
        <ul>
            <li>Add your release notes here</li>
            <li>List new features and bug fixes</li>
        </ul>
    ]]></description>
    <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S +0000")</pubDate>
    <enclosure 
        url="https://github.com/YOUR_USERNAME/AIO-SSL-Tool/releases/download/v${VERSION}/${DMG_NAME}" 
        sparkle:version="${VERSION}" 
        sparkle:shortVersionString="${VERSION}"
        length="${FILE_SIZE}" 
        type="application/octet-stream"
        sparkle:edSignature="${SIGNATURE}" />
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
</item>
EOF

echo -e "${GREEN}✓ Appcast entry saved to: appcast-entry.xml${NC}"
echo ""

# Step 8: Create release notes template
NOTES_FILE="$RELEASES_DIR/RELEASE_NOTES.md"
cat > "$NOTES_FILE" << EOF
# AIO SSL Tool v${VERSION}

## What's New

- Feature 1
- Feature 2

## Bug Fixes

- Fix 1
- Fix 2

## Improvements

- Improvement 1
- Improvement 2

## Installation

Download \`${DMG_NAME}\` and drag "AIO SSL Tool" to your Applications folder.

## Upgrading

If you have automatic updates enabled, you'll be notified automatically. Otherwise, download and install this version to replace your existing installation.

---

**Full Changelog**: https://github.com/YOUR_USERNAME/AIO-SSL-Tool/compare/v6.0.0...v${VERSION}
EOF

echo -e "${GREEN}✓ Release notes template created${NC}"
echo ""

# Step 9: Update README.md and appcast.xml automatically
echo "📝 Updating README.md and appcast.xml..."
cd "$BUILD_DIR/../.."
if [ -f "./update_version.sh" ]; then
    ./update_version.sh macos "$VERSION" "$FILE_SIZE"
    echo -e "${GREEN}✓ README and appcast updated${NC}"
else
    echo -e "${YELLOW}⚠ update_version.sh not found, skipping auto-update${NC}"
fi
cd "$BUILD_DIR"
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Release v${VERSION} ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📦 Release artifacts:"
echo "  - DMG: $RELEASES_DIR/$DMG_NAME"
echo "  - Appcast entry: $RELEASES_DIR/appcast-entry.xml"
echo "  - Release notes: $RELEASES_DIR/RELEASE_NOTES.md"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Review and edit release notes:"
echo "   open $NOTES_FILE"
echo ""
echo "2. Test the DMG:"
echo "   open $DMG_PATH"
echo ""
echo "3. Create GitHub release:"
echo "   gh release create v${VERSION} \"$DMG_PATH\" \\"
echo "     --title \"AIO SSL Tool v${VERSION}\" \\"
echo "     --notes-file \"$NOTES_FILE\""
echo ""
echo "4. Update appcast.xml:"
echo "   cat $APPCAST_ENTRY"
echo "   # Add the entry to the top of appcast.xml <channel> section"
echo ""
echo "5. Commit and push changes:"
echo "   git add appcast.xml Info.plist"
echo "   git commit -m 'Release v${VERSION}'"
echo "   git push"
echo ""
echo -e "${YELLOW}⚠ Don't forget to update YOUR_USERNAME in the URLs!${NC}"
echo ""
