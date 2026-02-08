#!/bin/bash

# Build script for AIO SSL Tool macOS app
# This script sets up and builds the Xcode project

set -e

echo "🔧 AIO SSL Tool - macOS Build Script"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "AIOSSLToolApp.swift" ]; then
    echo -e "${RED}❌ Error: Please run this script from the macOS/AIOSSLTool directory${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Step 1: Checking Xcode installation...${NC}"
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode is not installed. Please install Xcode from the App Store.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Xcode found${NC}"
echo ""

echo -e "${BLUE}📦 Step 2: Building with Swift Package Manager...${NC}"
BUILD_TYPE="${1:-release}"

if [ "$BUILD_TYPE" == "debug" ]; then
    echo "Building Debug configuration..."
    swift build -c debug
    BUILD_PATH=".build/debug"
else
    echo "Building Release configuration..."
    swift build -c release
    BUILD_PATH=".build/release"
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

echo -e "${BLUE}📦 Step 4: Creating app bundle...${NC}"
APP_NAME="AIO SSL Tool"
APP_BUNDLE="${APP_NAME}.app"
EXECUTABLE_NAME="AIOSSLTool"

# Remove old app bundle if it exists
if [ -d "${APP_BUNDLE}" ]; then
    rm -rf "${APP_BUNDLE}"
fi

# Create app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_PATH}/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}"

# Copy Info.plist
cp Info.plist "${APP_BUNDLE}/Contents/"

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
fi

echo -e "${GREEN}✓ App bundle created${NC}"
echo ""

echo -e "${BLUE}📦 Step 5: Code signing...${NC}"
# Ad-hoc sign the app (works without developer certificate)
codesign --force --deep --sign - "${APP_BUNDLE}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ App signed successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Code signing failed, but continuing...${NC}"
fi
echo ""

echo -e "${BLUE}📦 Step 6: Removing quarantine attributes...${NC}"
# Remove quarantine attribute that macOS adds
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
echo -e "${GREEN}✓ Quarantine attributes removed${NC}"
echo ""

echo -e "${GREEN}🎉 Build Complete!${NC}"
echo ""
echo -e "${BLUE}To run the app:${NC}"
echo "  open '${APP_BUNDLE}'"
echo ""
echo -e "${BLUE}Or from terminal:${NC}"
echo "  ./'${APP_BUNDLE}/Contents/MacOS/${EXECUTABLE_NAME}'"
echo ""
echo -e "${YELLOW}Note: If you still see the 'damaged' error:${NC}"
echo "  1. Right-click the app and select 'Open'"
echo "  2. Click 'Open' in the security dialog"
echo "  3. Or run: xattr -cr '${APP_BUNDLE}' && open '${APP_BUNDLE}'"
