#!/bin/bash

# Automated Version Update Script
# Updates README.md download links and appcast.xml

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}Error: Platform and version required${NC}"
    echo "Usage: ./update_version.sh <platform> <version> [file_size]"
    echo "Examples:"
    echo "  ./update_version.sh macos 6.1.0 2826770"
    echo "  ./update_version.sh windows 6.1.0"
    echo "  ./update_version.sh both 6.1.0 2826770"
    exit 1
fi

PLATFORM="$1"
VERSION="$2"
FILE_SIZE="${3:-0}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
README="$REPO_ROOT/README.md"
APPCAST="$REPO_ROOT/appcast.xml"

echo -e "${GREEN}Updating version links to v${VERSION}${NC}"
echo ""

# Cross-platform sed in-place function
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Update README.md
update_readme() {
    local platform=$1
    local version=$2
    
    if [ "$platform" == "macos" ] || [ "$platform" == "both" ]; then
        echo "📝 Updating macOS download link in README..."
        
        # Update macOS link - version in label and URL path, but DMG filename is just AIOSSLTool.dmg
        sed_inplace -E "s|(macOS\*\* \| \[\*\*Download DMG \(v)[0-9.]+(\)\*\*\]\(https://github.com/[^/]+/[^/]+/releases/download/v)[0-9.]+(/AIOSSLTool.dmg\))|\1${version}\2${version}\3|g" "$README"
        
        echo -e "${GREEN}✓ macOS link updated to v${version}${NC}"
    fi
    
    if [ "$platform" == "windows" ] || [ "$platform" == "both" ]; then
        echo "📝 Updating Windows download link in README..."
        
        # Update Windows link - version in label and URL path
        sed_inplace -E "s|(Windows\*\* \| \[\*\*Download EXE \(v)[0-9.]+(\)\*\*\]\(https://github.com/[^/]+/[^/]+/releases/download/v)[0-9.]+(/AIO-SSL-Tool.exe\))|\1${version}\2${version}\3|g" "$README"
        
        echo -e "${GREEN}✓ Windows link updated to v${version}${NC}"
    fi
}

# Update appcast.xml
update_appcast() {
    local version=$1
    local file_size=$2
    local version_number=$(echo $version | cut -d'.' -f1)
    
    if [ "$file_size" -eq 0 ]; then
        echo -e "${YELLOW}⚠ File size not provided, skipping appcast update${NC}"
        return
    fi
    
    echo "📝 Updating appcast.xml..."
    
    # Update sparkle:version in the first item (latest release)
    sed_inplace -E "0,/<sparkle:version>[^<]+<\/sparkle:version>/s//<sparkle:version>${version_number}<\/sparkle:version>/" "$APPCAST"
    
    # Update sparkle:shortVersionString in the first item
    sed_inplace -E "0,/<sparkle:shortVersionString>[^<]+<\/sparkle:shortVersionString>/s//<sparkle:shortVersionString>${version}<\/sparkle:shortVersionString>/" "$APPCAST"
    
    # Update file size in the first enclosure
    sed_inplace -E "0,/length=\"[0-9]+\"/s//length=\"${file_size}\"/" "$APPCAST"
    
    # Update sparkle:version in the first enclosure
    sed_inplace -E "0,/sparkle:version=\"[^\"]+\"/s//sparkle:version=\"${version_number}\"/" "$APPCAST"
    
    # Update sparkle:shortVersionString in the first enclosure  
    sed_inplace -E "0,/sparkle:shortVersionString=\"[^\"]+\"/s//sparkle:shortVersionString=\"${version}\"/" "$APPCAST"
    
    echo -e "${GREEN}✓ Appcast updated to v${version} (build ${version_number}, size ${file_size})${NC}"
}

# Main execution
update_readme "$PLATFORM" "$VERSION"

if [ "$PLATFORM" == "macos" ] || [ "$PLATFORM" == "both" ]; then
    update_appcast "$VERSION" "$FILE_SIZE"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Version update complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Review changes:"
echo "   git diff README.md appcast.xml"
echo ""
echo "2. Commit changes:"
echo "   git add README.md appcast.xml"
echo "   git commit -m 'Update download links to v${VERSION}'"
echo "   git push"
echo ""
