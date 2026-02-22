#!/bin/bash

# Generate Sparkle EdDSA Keys for Signing Updates
# This script helps generate the cryptographic keys needed for secure updates

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Sparkle EdDSA Key Generator${NC}"
echo "============================"
echo ""

# Check if Sparkle is installed
if ! command -v generate_keys &> /dev/null; then
    echo -e "${YELLOW}Sparkle tools not found. Installing...${NC}"
    echo ""
    
    if command -v brew &> /dev/null; then
        echo "Installing Sparkle via Homebrew..."
        brew install sparkle
        echo ""
    else
        echo -e "${RED}Error: Homebrew not found${NC}"
        echo "Please install Homebrew first: https://brew.sh"
        echo ""
        echo "Or install Sparkle manually:"
        echo "  1. Download from: https://github.com/sparkle-project/Sparkle/releases"
        echo "  2. Extract and add 'bin' directory to your PATH"
        exit 1
    fi
fi

# Generate keys
echo "🔑 Generating EdDSA key pair..."
echo ""

KEYS_DIR="$(pwd)"
cd "$KEYS_DIR"

# Find generate_keys command
GENERATE_KEYS=""
if [ -f "/opt/homebrew/Caskroom/sparkle/2.8.1/bin/generate_keys" ]; then
    GENERATE_KEYS="/opt/homebrew/Caskroom/sparkle/2.8.1/bin/generate_keys"
elif command -v generate_keys &> /dev/null; then
    GENERATE_KEYS="generate_keys"
else
    # Try to find it dynamically
    SPARKLE_PATH=$(find /opt/homebrew/Caskroom/sparkle -name "generate_keys" -type f 2>/dev/null | grep "bin/generate_keys" | head -1)
    if [ -z "$SPARKLE_PATH" ]; then
        # Try Intel Mac location
        SPARKLE_PATH=$(find /usr/local/Caskroom/sparkle -name "generate_keys" -type f 2>/dev/null | grep "bin/generate_keys" | head -1)
    fi
    
    if [ -n "$SPARKLE_PATH" ]; then
        GENERATE_KEYS="$SPARKLE_PATH"
    fi
fi

if [ -z "$GENERATE_KEYS" ]; then
    echo -e "${RED}Error: generate_keys command not found${NC}"
    echo ""
    echo "Sparkle is installed but the tools are not in PATH."
    echo ""
    echo "Try adding this to your ~/.zshrc:"
    echo "  export PATH=\"/opt/homebrew/Caskroom/sparkle/2.8.1/bin:\$PATH\""
    echo ""
    echo "Or run directly:"
    echo "  /opt/homebrew/Caskroom/sparkle/2.8.1/bin/generate_keys"
    exit 1
fi

echo "Using: $GENERATE_KEYS"
echo ""

# Run generate_keys command
"$GENERATE_KEYS" || {
    echo -e "${RED}Failed to generate keys${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Keys generated successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Display the keys
if [ -f "sparkle_eddsa_public.key" ] && [ -f "sparkle_eddsa_private.key" ]; then
    PUBLIC_KEY=$(cat sparkle_eddsa_public.key)
    
    echo "📍 Location: $KEYS_DIR"
    echo ""
    echo "🔓 Public Key (add to Info.plist):"
    echo "   $PUBLIC_KEY"
    echo ""
    echo "🔐 Private Key: sparkle_eddsa_private.key"
    echo "   ${RED}KEEP THIS SECRET! Never commit to Git!${NC}"
    echo ""
    
    # Update .gitignore
    GITIGNORE="$KEYS_DIR/.gitignore"
    if [ ! -f "$GITIGNORE" ]; then
        echo "sparkle_eddsa_private.key" > "$GITIGNORE"
        echo "📝 Created .gitignore to exclude private key"
    elif ! grep -q "sparkle_eddsa_private.key" "$GITIGNORE"; then
        echo "sparkle_eddsa_private.key" >> "$GITIGNORE"
        echo "📝 Added private key to .gitignore"
    fi
    
    echo ""
    echo "📋 Next steps:"
    echo ""
    echo "1. Update Info.plist with the public key:"
    echo "   <key>SUPublicEDKey</key>"
    echo "   <string>$PUBLIC_KEY</string>"
    echo ""
    echo "2. Store private key securely:"
    echo "   - Keep it in a safe location"
    echo "   - Never commit to version control"
    echo "   - Back it up securely"
    echo ""
    echo "3. Use the private key to sign releases:"
    echo "   sign_update YourApp.dmg sparkle_eddsa_private.key"
    echo ""
else
    echo -e "${RED}Error: Key files not found${NC}"
    exit 1
fi
